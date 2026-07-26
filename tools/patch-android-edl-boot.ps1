<#
.SYNOPSIS
  Adds Android-side ADB EDL reboot support using this project's OrangeFox.

.DESCRIPTION
  Run from Windows while the phone is booted into the EDL-enabled OrangeFox
  recovery. It preserves the existing boot image's header and ramdisk,
  including Magisk, and replaces only the kernel and DTB.

  The image is built on-device with OrangeFox's own magiskboot, pulled back,
  and hash-checked against the device copy. With -Flash it is written through
  the bootloader with `fastboot flash boot_<slot>`: LG's aboot refuses
  `recovery` but accepts `boot`, so there is no need to dd over a live
  partition from inside recovery.

  Images are written to artifacts/ (gitignored), never into tools/.
#>
[CmdletBinding()]
param(
    [ValidateSet('a', 'b')]
    [string]$Slot,
    [switch]$Flash
)

$ErrorActionPreference = 'Stop'
$Adb = 'adb'
$Fastboot = 'fastboot'

function Invoke-AdbShell([string]$Command) {
    $result = & $Adb shell $Command
    if ($LASTEXITCODE -ne 0) { throw "adb shell failed: $Command" }
    return ($result | Out-String).Trim()
}

# OrangeFox's adbd reports the state as 'recovery', not 'device'. Accept both,
# and let the magiskboot/partition probe below be the real "am I in OrangeFox"
# test -- requiring 'device' rejected the exact situation this script documents.
$state = (& $Adb get-state 2>$null)
if ($state) { $state = $state.Trim() }
if ($state -ne 'device' -and $state -ne 'recovery') {
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

# artifacts/ is gitignored; $PSScriptRoot (tools/) is tracked, and dropping
# ~96 MB images there leaves them staged for an accidental commit.
$artifacts = Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts'
if (-not (Test-Path $artifacts)) {
    New-Item -ItemType Directory -Path $artifacts | Out-Null
}
$backup = Join-Path $artifacts "boot_$Slot-before-edl-$timestamp.img"
$patched = Join-Path $artifacts "boot_$Slot-edl-$timestamp.img"

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

# Flash through the bootloader rather than dd'ing the live partition. fastboot
# fails loudly on a short or rejected write, which is the check the old dd path
# was trying (and failing) to make: it compared sha256 of the WHOLE 96 MiB
# partition against the much smaller image file, so it could never match and
# always threw after the write had already succeeded.
Write-Host 'Rebooting to the bootloader ...'
& $Adb reboot bootloader | Out-Null

$deadline = (Get-Date).AddSeconds(120)
$found = $false
while ((Get-Date) -lt $deadline) {
    $devices = (& $Fastboot devices 2>$null) | Out-String
    if ($devices.Trim()) { $found = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $found) {
    throw "No fastboot device appeared within 120s. Put the phone in the bootloader manually, then re-run with -Slot $Slot -Flash."
}

& $Fastboot flash "boot_$Slot" $patched
if ($LASTEXITCODE -ne 0) {
    throw "fastboot flash boot_$Slot failed. The phone is still in the bootloader; restore with: fastboot flash boot_$Slot `"$backup`""
}

Write-Host 'Flash reported OK. Rebooting Android.'
Write-Host "To roll back: fastboot flash boot_$Slot `"$backup`""
& $Fastboot reboot
