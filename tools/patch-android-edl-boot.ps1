<#
.SYNOPSIS
  Adds Android-side ADB EDL reboot support using this project's OrangeFox.

.DESCRIPTION
  Run from Windows while the phone is booted into the EDL-enabled OrangeFox
  recovery. It preserves the existing boot image's header and ramdisk,
  including Magisk, and replaces only the kernel and DTB.
#>
[CmdletBinding()]
param(
    [ValidateSet('a', 'b')]
    [string]$Slot,
    [switch]$Flash
)

$ErrorActionPreference = 'Stop'
$Adb = 'adb'

function Invoke-AdbShell([string]$Command) {
    $result = & $Adb shell $Command
    if ($LASTEXITCODE -ne 0) { throw "adb shell failed: $Command" }
    return ($result | Out-String).Trim()
}

if ((& $Adb get-state 2>$null).Trim() -ne 'device') {
    throw 'No ADB device is available. Boot the EDL-enabled OrangeFox recovery and enable ADB.'
}

if (-not $Slot) {
    $Slot = (Invoke-AdbShell 'getprop ro.boot.slot_suffix').TrimStart('_')
}
if ($Slot -notin @('a', 'b')) {
    throw "Could not determine an A/B slot (got '$Slot'). Re-run with -Slot a or -Slot b."
}

$bootPartition = "/dev/block/bootdevice/by-name/boot_$Slot"
$recoveryPartition = "/dev/block/bootdevice/by-name/recovery_$Slot"
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $PSScriptRoot "boot_$Slot-before-edl-$timestamp.img"
$patched = Join-Path $PSScriptRoot "boot_$Slot-edl-$timestamp.img"

Write-Host "Target slot: $Slot"
Invoke-AdbShell "test -x /sbin/magiskboot && test -b $bootPartition && test -b $recoveryPartition" | Out-Null

Write-Host "Backing up $bootPartition to $backup"
& $Adb pull $bootPartition $backup
if ($LASTEXITCODE -ne 0) { throw 'Could not pull the current boot image.' }

& $Adb push $backup /tmp/of-edl-base.img
if ($LASTEXITCODE -ne 0) { throw 'Could not upload the boot-image backup.' }

$buildCommand = "rm -rf /tmp/of-edl-recovery /tmp/of-edl-boot && " +
    "mkdir /tmp/of-edl-recovery /tmp/of-edl-boot && " +
    "cd /tmp/of-edl-recovery && /sbin/magiskboot unpack $recoveryPartition && " +
    "test -f kernel && test -f kernel_dtb && " +
    "cd /tmp/of-edl-boot && /sbin/magiskboot unpack /tmp/of-edl-base.img && " +
    "cp /tmp/of-edl-recovery/kernel kernel && " +
    "cp /tmp/of-edl-recovery/kernel_dtb dtb && " +
    "/sbin/magiskboot repack /tmp/of-edl-base.img /tmp/of-edl-boot/boot-edl.img"
Invoke-AdbShell $buildCommand | Out-Null
$deviceHash = (Invoke-AdbShell 'sha256sum /tmp/of-edl-boot/boot-edl.img').Split()[0].ToLower()

& $Adb pull /tmp/of-edl-boot/boot-edl.img $patched
if ($LASTEXITCODE -ne 0) { throw 'Could not download the patched boot image.' }
$hostHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $patched).Hash.ToLower()
if ($hostHash -ne $deviceHash) { throw 'Patched boot-image hash mismatch; refusing to flash.' }

Write-Host "Created: $patched"
Write-Host "Backup:  $backup"
Write-Host "SHA-256: $hostHash"

if (-not $Flash) {
    Write-Host 'Not flashed. Re-run with -Flash after reviewing the two image paths above.'
    exit 0
}

Invoke-AdbShell "dd if=/tmp/of-edl-boot/boot-edl.img of=$bootPartition bs=4M >/dev/null 2>&1 && sync" | Out-Null
$writtenHash = (Invoke-AdbShell "sha256sum $bootPartition").Split()[0].ToLower()
if ($writtenHash -ne $hostHash) { throw 'On-device boot-image hash mismatch after flash.' }

Write-Host 'Flash verified. Rebooting Android.'
& $Adb reboot system
