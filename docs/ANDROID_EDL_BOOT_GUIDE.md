# Enable Android ADB EDL reboot

This is for the LG Velvet 4G LM-G910EMW (caymanslm) only. Do not use it on the
5G Velvet or any other model.

`adb reboot edl` already works from OrangeFox, because the recovery is built
with the EDL kernel patch. From Android it does nothing useful: Android runs
its own kernel out of `boot_<slot>`, and the stock LG kernel has the Qualcomm
emergency-download path compiled out behind `CONFIG_LGE_HANDLE_PANIC`.

`tools/patch-android-edl-boot.ps1` copies the EDL-enabled kernel and its DTB
out of the OrangeFox recovery partition into each boot image, leaving that
image's header and ramdisk — including Magisk — untouched. That is the entire
change: same Android, same root, EDL reboot now works.

## Prerequisites

1. Install this project's EDL-enabled OrangeFox recovery, and boot it. The
   kernel is read from the recovery *partition*, so a RAM-booted
   (`fastboot boot`) recovery is not enough.
2. On Windows, open PowerShell in the repository root. Both `adb` and
   `fastboot` must be on PATH.
3. Have ~400 MB free for backups and patched images. In a repo checkout they go
   to `artifacts/edl-backup/`; running the script standalone they go to an
   `edl-backup/` folder beside it. Override with `-BackupDir <path>`.

The script refuses to run against anything whose device codename is not
`caymanslm`, checked over adb or `fastboot getvar product` depending on the
mode the phone is in. The partition paths and the kernel are specific to this
phone, so it stops rather than writing a foreign kernel into someone's boot.

## Usage

~~~powershell
.\tools\patch-android-edl-boot.ps1
~~~

It asks whether to **patch** or **restore**. Both actions are safe to re-run.

### patch

For each of `boot_a` and `boot_b` it checks whether that slot already carries
the EDL kernel. Slots that do are reported as already patched and skipped.
Slots that do not are backed up to `artifacts/edl-backup/boot_<slot>-stock.img`,
patched, hash-checked, and written.

An existing stock backup is never overwritten. Backups are only ever taken from
an unpatched image, so a backup cannot silently become a patched one.

The kernel source is whichever recovery partition actually carries the EDL
kernel — not each slot's own recovery. Slot B's recovery may still be stock,
and sourcing from it would inject a stock kernel into `boot_b`, which is the
opposite of the goal. If neither recovery slot has it, the script stops without
writing anything.

### restore

Writes `artifacts/edl-backup/boot_<slot>-stock.img` back to each slot. If a
backup is missing it says so per slot, and if neither exists it stops without
touching the phone.

## How "already patched" is decided

By looking for the string `Failed to set secure EDLOAD mode` in the unpacked
kernel. That symbol sits behind `CONFIG_LGE_HANDLE_PANIC`, which the kernel
patch opens up — verified as 1 hit on the patched kernel and 0 on both the
stock boot and stock recovery kernels. It makes the check exact rather than a
guess, and it doubles as proof that the kernel being patched *with* is genuinely
EDL-capable.

## Writing

Images are written through the bootloader with `fastboot flash boot_<slot>`.
LG's aboot refuses `recovery` but accepts `boot`, so nothing is `dd`'d over a
live partition. The script reboots the phone to the bootloader itself. If a
flash fails, the phone is left in the bootloader rather than stranded mid-write.

## Testing it

Once Android ADB is available:

~~~powershell
adb reboot edl
~~~

Success is a black screen and Windows detecting Qualcomm HS-USB QDLoader 9008.
Hold Power for roughly 10-15 seconds to leave EDL.

Note that `adb reboot <anything-else>` boots normally rather than reporting an
error — Android never validates that string, so this is stock behaviour and not
a sign that the patch failed.

## Rollback

~~~powershell
.\tools\patch-android-edl-boot.ps1 -Action restore
~~~
