# Android EDL reboot patch

Makes `adb reboot edl` work from **Android** on the LG Velvet 4G
(LM-G910EMW / `caymanslm`).

## What it does

`adb reboot edl` already works from OrangeFox, because the recovery is built
with the EDL kernel patch. From Android it does nothing useful: Android runs its
own kernel out of `boot_<slot>`, and the stock LG kernel has Qualcomm's
emergency-download path compiled out.

This copies the EDL-enabled kernel into your boot image, so EDL becomes
reachable from a running Android.

## How it works

A boot image is a header, a kernel, a ramdisk and a DTB. The script takes the
kernel and DTB from the OrangeFox recovery partition and swaps them into each
boot image, leaving the header and ramdisk — **including Magisk** — alone.

It tells whether a slot is already patched by looking for a string that only
exists in the EDL kernel, so re-running is safe. The same check confirms the
kernel it is patching *with* is EDL-capable.

Images are written with `fastboot flash boot_<slot>`. LG's bootloader refuses
`recovery` but allows `boot`, so nothing is written over a live partition.

## How to use it

You need `adb` and `fastboot` on PATH, and the OrangeFox recovery **installed**
(not `fastboot boot`-ed — the kernel is read from the partition).

Boot into OrangeFox, then:

```powershell
.\patch-android-edl-boot.ps1
```

Pick **patch** or **restore**:

- **patch** — backs up each slot that is not already patched, patches it, and
  writes it. Already-patched slots are skipped.
- **restore** — writes the backups back.

Backups go to `artifacts/edl-backup/` in a repo checkout, otherwise to an
`edl-backup/` folder beside the script. `-BackupDir <path>` overrides it, and
`-BuildOnly` builds without writing anything.

Once Android is back up, test with `adb reboot edl`. Success is a black screen
and Windows detecting *Qualcomm HS-USB QDLoader 9008*. Hold Power for about
10–15 seconds to leave EDL.

The script refuses to run on any device that is not a `caymanslm`.

> `adb reboot <anything-else>` boots normally instead of reporting an error.
> That is stock Android behaviour — the string is never validated — not a sign
> the patch failed.
