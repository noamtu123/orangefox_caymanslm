<#
.SYNOPSIS
  Makes `adb reboot edl` work from Android on the LG Velvet 4G (caymanslm).

.DESCRIPTION
  Android boots its own kernel from boot_<slot>, and the stock LG kernel has
  the Qualcomm emergency-download path compiled out, so `adb reboot edl` from
  Android does nothing useful. This copies the EDL-enabled kernel and its DTB
  out of the OrangeFox recovery partition into each boot image, leaving that
  image's header and ramdisk -- including Magisk -- untouched. That is the
  whole change: same Android, same root, EDL reboot now works.

  Run it with the phone in the EDL-enabled OrangeFox recovery (it needs that
  recovery's /sbin/magiskboot to unpack and repack). Writing happens through
  the bootloader with fastboot, because LG's aboot accepts `boot` even though
  it refuses `recovery`.

    patch    back up and patch any boot slot that is not already patched
    restore  write the saved stock backups back to both slots

  Both actions are safe to re-run: patch skips slots that already carry the
  EDL kernel, and never overwrites an existing stock backup.

.PARAMETER Action
  'patch' or 'restore'. Prompted for when omitted.
#>
[CmdletBinding()]
param(
    [ValidateSet('patch', 'restore')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'
$Adb = 'adb'
$Fastboot = 'fastboot'
$Slots = @('a', 'b')

# Present only when the EDL kernel is built. enable_emergency_dload_mode() and
# this string sit behind CONFIG_LGE_HANDLE_PANIC, which the kernel patch opens
# up; verified 1 hit on the patched kernel, 0 on both stock boot and stock
# recovery. This is what makes "is it already patched" an exact question rather
# than a guess -- and it also proves the kernel we patch WITH is EDL-capable,
# so a stock recovery partition can never be used as the source.
$EdlMarker = 'Failed to set secure EDLOAD mode'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$BackupDir = Join-Path $RepoRoot 'artifacts\edl-backup'

function Invoke-AdbShell([string]$Command) {
    $result = & $Adb shell $Command
    if ($LASTEXITCODE -ne 0) { throw "adb shell failed: $Command" }
    return ($result | Out-String).Trim()
}

function Get-BootPartition([string]$Slot) {
    return "/dev/block/bootdevice/by-name/boot_$Slot"
}

function Get-RecoveryPartition([string]$Slot) {
    return "/dev/block/bootdevice/by-name/recovery_$Slot"
}

function Get-BackupPath([string]$Slot) {
    return (Join-Path $BackupDir "boot_$Slot-stock.img")
}

# Unpacks an image (file or block device) on the phone and reports whether its
# kernel carries the EDL marker. Returns 'yes', 'no', or 'unreadable'.
function Get-EdlState([string]$Source) {
    # `grep -c` prints 0 AND exits 1 when there is no match, so a `|| echo 0`
    # fallback emits the count twice. Capture it instead, and tag the result so
    # parsing cannot be confused by anything else the tools print.
    $probe = "rm -rf /tmp/edlprobe && mkdir -p /tmp/edlprobe && cd /tmp/edlprobe && " +
        "/sbin/magiskboot unpack $Source >/dev/null 2>&1; " +
        "if [ -f kernel ]; then C=`$(grep -ac '$EdlMarker' kernel 2>/dev/null); echo `"EDL=`${C:-0}`"; " +
        "else echo EDL=unreadable; fi"
    $out = Invoke-AdbShell $probe

    $line = ($out -split "`n" | Where-Object { $_ -match '^EDL=' } | Select-Object -Last 1)
    if (-not $line) { throw "Could not read the EDL state of $Source (got: $out)" }
    $value = $line.Trim().Substring(4)

    if ($value -eq 'unreadable') { return 'unreadable' }
    if ([int]$value -gt 0) { return 'yes' }
    return 'no'
}

function Test-FastbootPresent {
    $devices = (& $Fastboot devices 2>$null) | Out-String
    return [bool]$devices.Trim()
}

function Wait-ForFastboot {
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
        if (Test-FastbootPresent) { return }
        Start-Sleep -Seconds 2
    }
    throw 'No fastboot device appeared within 120s. Put the phone in the bootloader manually and re-run.'
}

# Gets the phone into the bootloader from wherever it currently is.
function Enter-Fastboot {
    if (Test-FastbootPresent) {
        Write-Host 'Phone is already in the bootloader.'
        return
    }
    $state = (& $Adb get-state 2>$null)
    if ($state) { $state = $state.Trim() }
    if ($state -ne 'device' -and $state -ne 'recovery') {
        throw 'Phone is neither in fastboot nor visible over ADB. Connect it and retry.'
    }
    Write-Host 'Rebooting to the bootloader ...'
    & $Adb reboot bootloader | Out-Null
    Wait-ForFastboot
}

function Invoke-FastbootFlash([string]$Slot, [string]$ImagePath) {
    & $Fastboot flash "boot_$Slot" $ImagePath
    if ($LASTEXITCODE -ne 0) {
        throw "fastboot flash boot_$Slot failed. The phone is still in the bootloader."
    }
}

if (-not $Action) {
    Write-Host ''
    Write-Host '  [1] patch    - add the EDL kernel to both boot slots'
    Write-Host '  [2] restore  - put the stock boot images back'
    Write-Host ''
    $choice = Read-Host 'Select 1 or 2'
    if ($choice -eq '1') { $Action = 'patch' }
    elseif ($choice -eq '2') { $Action = 'restore' }
    else { throw "Unrecognised selection '$choice'." }
}

# ---------------------------------------------------------------- restore ---
if ($Action -eq 'restore') {
    $present = @()
    $missing = @()
    foreach ($slot in $Slots) {
        if (Test-Path (Get-BackupPath $slot)) { $present += $slot } else { $missing += $slot }
    }

    foreach ($slot in $missing) {
        Write-Host "backup is missing for boot_$slot ($(Get-BackupPath $slot))"
    }
    if ($present.Count -eq 0) {
        throw 'backup is missing - nothing to restore.'
    }

    Enter-Fastboot
    foreach ($slot in $present) {
        $img = Get-BackupPath $slot
        Write-Host "Restoring boot_$slot from $img"
        Invoke-FastbootFlash $slot $img
    }
    Write-Host 'Restore complete. Rebooting Android.'
    & $Fastboot reboot
    exit 0
}

# ------------------------------------------------------------------ patch ---
$state = (& $Adb get-state 2>$null)
if ($state) { $state = $state.Trim() }
# OrangeFox's adbd reports 'recovery', not 'device'; accept both.
if ($state -ne 'device' -and $state -ne 'recovery') {
    throw 'No ADB device is available. Boot the EDL-enabled OrangeFox recovery and enable ADB.'
}
Invoke-AdbShell 'test -x /sbin/magiskboot' | Out-Null

# Find a recovery partition whose kernel is actually EDL-capable. Sourcing each
# boot slot from its own recovery would inject a stock kernel into any slot
# whose recovery has not been replaced -- the opposite of the goal.
$edlSource = $null
foreach ($slot in $Slots) {
    $rec = Get-RecoveryPartition $slot
    if ((Get-EdlState $rec) -eq 'yes') {
        $edlSource = $rec
        Write-Host "EDL kernel source: recovery_$slot"
        break
    }
}
if (-not $edlSource) {
    throw 'Neither recovery slot carries the EDL kernel. Flash this project''s OrangeFox first (a RAM-booted recovery does not count - the kernel is read from the partition).'
}

$toPatch = @()
foreach ($slot in $Slots) {
    $state = Get-EdlState (Get-BootPartition $slot)
    if ($state -eq 'yes') {
        Write-Host "boot_$slot already patched"
    } elseif ($state -eq 'unreadable') {
        Write-Host "boot_$slot could not be unpacked - skipping"
    } else {
        $toPatch += $slot
    }
}

if ($toPatch.Count -eq 0) {
    Write-Host 'Nothing to do.'
    exit 0
}

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

$built = @{}
foreach ($slot in $toPatch) {
    $bootPart = Get-BootPartition $slot
    $backup = Get-BackupPath $slot

    # Only ever taken from an unpatched image, and never overwritten, so the
    # backup cannot silently become a patched one.
    if (Test-Path $backup) {
        Write-Host "Keeping existing stock backup: $backup"
    } else {
        Write-Host "Backing up boot_$slot to $backup"
        & $Adb pull $bootPart $backup
        if ($LASTEXITCODE -ne 0) { throw "Could not back up boot_$slot; nothing has been written." }
    }

    Write-Host "Building patched boot_$slot ..."
    $out = "/tmp/edlwork/boot-edl-$slot.img"
    $build = "rm -rf /tmp/edlwork && mkdir -p /tmp/edlwork/src /tmp/edlwork/boot && " +
        "cd /tmp/edlwork/src && /sbin/magiskboot unpack $edlSource && " +
        "test -f kernel && test -f kernel_dtb && " +
        "cd /tmp/edlwork/boot && /sbin/magiskboot unpack $bootPart && " +
        "cp /tmp/edlwork/src/kernel kernel && " +
        "cp /tmp/edlwork/src/kernel_dtb dtb && " +
        "/sbin/magiskboot repack $bootPart $out"
    Invoke-AdbShell $build | Out-Null

    $deviceHash = (Invoke-AdbShell "sha256sum $out").Split()[0].ToLower()
    $local = Join-Path $BackupDir "boot_$slot-edl.img"
    & $Adb pull $out $local
    if ($LASTEXITCODE -ne 0) { throw "Could not download the patched boot_$slot." }
    $hostHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $local).Hash.ToLower()
    if ($hostHash -ne $deviceHash) { throw "Patched boot_$slot hash mismatch; refusing to flash." }

    Invoke-AdbShell 'rm -rf /tmp/edlwork /tmp/edlprobe' | Out-Null
    $built[$slot] = $local
    Write-Host "  built $local"
}

Enter-Fastboot

foreach ($slot in $toPatch) {
    Write-Host "Flashing boot_$slot"
    Invoke-FastbootFlash $slot $built[$slot]
}

Write-Host ''
Write-Host 'Done. Rebooting Android; test with: adb reboot edl'
Write-Host "Roll back with: .\tools\patch-android-edl-boot.ps1 -Action restore"
& $Fastboot reboot
