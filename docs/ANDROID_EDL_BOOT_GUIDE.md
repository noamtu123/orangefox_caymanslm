# Enable Android ADB EDL reboot

This is for the LG Velvet 4G LM-G910EMW (caymanslm) only. It creates a boot
image from your own phone's current boot slot, retaining its header and ramdisk
(including Magisk if present) while adding the EDL-enabled kernel and DTB.

Do not use it on the 5G Velvet or any other model. Do not flash an image made
for another phone or slot.

## Prerequisites

1. Install and boot this project's EDL-enabled OrangeFox recovery in the slot
   you intend to patch. It must be visible as ADB device.
2. On Windows, clone/download this repository and open PowerShell in its root.
   Ensure adb is on PATH.
3. Have at least 250 MB free in `artifacts/`, where the automatic backup and
   the generated image are written. `fastboot` must be on PATH as well as adb.

## Build first, then flash

The first command creates a rollback backup and patched image; it does not
change the phone.

~~~powershell
.\tools\patch-android-edl-boot.ps1
~~~

Review the printed paths, then flash the verified result:

~~~powershell
.\tools\patch-android-edl-boot.ps1 -Flash
~~~

For a non-active slot, specify it explicitly in both runs, for example
-Slot b. That slot's recovery image must be this EDL-enabled build.

The script SHA-256-checks the built image against the on-device copy before it
will flash anything. With `-Flash` it then reboots the phone into the
bootloader and writes the image with `fastboot flash boot_<slot>` — LG's aboot
refuses `recovery` but accepts `boot`, so nothing is dd'd over a live
partition — and reboots Android. If the flash fails, the phone is left in the
bootloader and the printed rollback command restores the backup.

Once Android ADB is available, test:

~~~powershell
adb reboot edl
~~~

Success is a black screen and Windows detecting Qualcomm HS-USB QDLoader 9008.
Hold Power for roughly 10-15 seconds to leave EDL.

## Rollback

Boot OrangeFox again, push the automatically created backup image to /tmp, and
flash it back to the matching boot slot. Do not flash it to the other slot.
