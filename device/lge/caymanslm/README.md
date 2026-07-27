# OrangeFox device tree — LG Velvet 4G (`caymanslm`, LM-G910EMW)

OrangeFox `fox_14.1` recovery for the LG Velvet 4G (Snapdragon 845, codename
`caymanslm`), with working Qualcomm FBE `/data` decryption.

**Scope:** LM-G910EMW only (any region firmware). **Not** the 5G Velvet
(`caymanlm` / SDM765G — a different device).

## Architecture

- **Base:** OrangeFox `fox_14.1` minimal manifest.
- **Kernel:** built from source — `kernel/lge/sdm845` (LineageOS lineage-22.2),
  `lineageos_caymanslm_defconfig` (proven display/touch/UFS/USB drivers, clean cmdline).
- **Firmware target:** Android 12 system on Android 11 vendor (`G91030a`);
  Keymaster **@4.0** / Gatekeeper **@1.0** / qseecom **@1.0**.
- **Decrypt blobs:** the FBE blob closure (`blob-manifest.txt`) is extracted from
  the device's own `G91030a` vendor and bundled into the recovery ramdisk at
  `/vendor` — slot-agnostic (no live vendor mount) and region-correct.

Kernel source is pinned in `manifests/caymanslm.xml`.

## Decryption — working

`/data` FBE decryption works on-device (verified against stock A12 ROM data; a
LineageOS install on this same kernel uses the same scheme and is expected to work too).

This device's kernel — stock and our LineageOS build alike — is **legacy fscrypt**:
Qualcomm ICE, policy **v1**, driven by the old `add_key` keyring API. It has **no**
fscrypt v2 `FS_IOC_ADD_ENCRYPTION_KEY` ioctl. Android-12 `vold` installs FBE keys
*only* via that v2 ioctl, so key install failed with `ENOTTY`. The fix restores
vold's legacy key path (`installKeyLegacy`, with an `ENOTTY` fallback) — see
`overlay/system/vold/`. The keymaster/keystore2 crypto chain (qseecomd + bundled
HAL, a servicemanager VINTF add-gate bypass so keystore2 registers, and
`prepdecrypt` patchlevel handling) supports it.

## Build

Built in WSL — there is no CI. After a `repo sync`, run the repo-root
`apply-fixes.sh` to re-apply the upstream overlay fixes, then:

```sh
source build/envsetup.sh && lunch twrp_caymanslm-ap2a-eng && mka recoveryimage
```

This emits **both** outputs in `$OUT`:

| Output | Use |
|---|---|
| `OrangeFox-R12.0-Unofficial-caymanslm.img` | `fastboot boot` for testing, or Flash Recovery |
| `OrangeFox-R12.0-Unofficial-caymanslm.zip` | installer — also deploys the addon payload |

The zip bundles **Magisk 30.7**, pinned by version and SHA256 in `apply-fixes.sh`
and fetched on demand into the gitignored `prebuilt/` cache. The same file is
shipped as both `Magisk.zip` and `uninstall.zip`, which is how upstream does it.

`vendorsetup.sh` must stay **LF-only**. Shell — unlike make and XML — does not
strip a trailing CR, so CRLF there appends `\r` to every exported value: it
silently defeated the `= "1"` flag tests, put a literal CR inside the recovery
zip's *filename* via `FOX_BUILD_TYPE`, and wrote
`RECOVERY_PARTITION=...recovery^M` into the ramdisk's `fox.cfg`. `.gitattributes`
pins LF; don't let an editor convert it back.

## Flashing (LM-G910EMW)

A/B device with dedicated `recovery_a` / `recovery_b` partitions.

- **`fastboot flash recovery_a` is BLOCKED** by LG's bootloader — it reports
  *"Cannot flash this partition in unlocked state"* even though the device is
  unlocked (an LG per-partition restriction; `boot` flashes fine, `recovery` does not).
- To install: flash the image from **within a running OrangeFox**
  (Install → Flash Recovery), or `fastboot boot <recovery.img>` to **RAM-boot** it
  for testing.
- Flashing **both** recovery slots is allowed now that bring-up is done (decrypt,
  including PIN/password/pattern, and the UI fixes are all working). The
  *Options → Flash to both slots* checkbox on the Flash Image screen does this:
  it flashes the current slot, then repeats against the other one via
  `Override_Active_Slot()`. That only retargets which physical partition TWRP
  writes — it does not call the bootloader's `set_active_boot_slot`, so it
  cannot leave the device booting the wrong slot.
  It **does** overwrite slot B's stock recovery, so keep a restore path intact
  before using it: dump both recovery partitions to your PC first
  (`adb pull /dev/block/bootdevice/by-name/recovery_b`), and remember EDL still
  works as a last resort. Restore from those if a build ever turns out to be
  unbootable on both slots. Those dumps are per-device and are not shipped in
  this repo.
- Flashing the bare `recovery.img` does **not** deploy the Fox addons. The
  installer zip carries `sdcard/Fox/FoxFiles/{Magisk.zip,uninstall.zip}` and
  `sdcard/Fox/fox.bashrc`; a raw image flash writes only the partition.
  AromaFM is deliberately **not** shipped — it renders straight to a framebuffer
  this DRM/KMS-only panel does not have, so it segfaulted on every run. See
  `FOX_DELETE_AROMAFM` in `vendorsetup.sh`. Until those files exist, Fox Addons → Install/Uninstall
  Magisk correctly reports *"file doesn't exist! please reflash recovery using
  the installation zip"*. That message is accurate, not a build fault. Fix it by
  flashing `OrangeFox-R12.0-Unofficial-caymanslm.zip` from within OrangeFox, or
  by copying those files out of the zip to `/sdcard` by hand. They live on
  userdata, so this only needs doing once per `/data` wipe.
  Prefer the zip when installing normally — it is the image plus that payload.

### Android EDL reboot

The EDL kernel fix is included in recovery, so `adb reboot edl` works from
OrangeFox. For it to work from Android too, the Android boot image must also
carry that kernel and its matching DTB, while keeping its own header and
ramdisk (including Magisk).

`edl-boot-script/patch-android-edl-boot.ps1` does this against your own phone's boot
slots, so no device-specific boot image is ever shared. It backs up each slot
before touching it and can restore them. See
[`edl-boot-script/`](../../../edl-boot-script/README.md).

## Backup and ROM rollback

LG's firmware servers are gone, so there is no KDZ to fall back on. The fstab
therefore covers **every partition on the device**, but in two tiers.

**Default list (7).** Boot, Recovery, DTBO, Vbmeta, Vbmeta System, Data, Super —
exactly what a ROM install rewrites, and nothing else. `vbmeta` is the only
non-obvious one: LineageOS flashes a vbmeta with verification disabled, so
without it in the backup you can restore stock `super` but never stock AVB
state. Because every entry here is rollback-relevant, "tick everything" is the
correct action rather than a trap.

**Advanced list (55 more), `advbackup=1`.** Hidden until Settings → Backup →
*Show additional partitions to backup* (`fox_adv_backup`) is enabled — see
`partitionmanager.cpp`, which ORs `Can_Be_Adv_Backed_Up` with that setting.
Covers the bootloader chain (`xbl`, `abl`, `tz`, `hyp`, `keymaster`, `laf`, ...),
the per-handset data (`persist`, `p_persist_lg`, `drm`, `modemst1/2`, `fsg`),
provisioning state (`frp`, `devinfo`), and the Qualcomm/LG platform partitions.

Not exposed anywhere, deliberately: `ALIGN_TO_128K_1/2` and `grow` (GPT padding,
no content), `pstore` (volatile kernel ring buffer), and `system`/`vendor`/
`product` (logical — they live inside `super`, which is backed up whole).

**Backing anything up is safe; restoring is where the hazards are**, and the
Restore screen ticks whatever a backup folder contains. Never restore
`modemst1`/`modemst2`/`fsg` over working ones — stale radio NV is a way to
*create* the IMEI loss you were insuring against. Never restore `frp` (can
reassert a Google account lock on a device you legitimately reset) or `devinfo`
(bootloader unlock state). The bootloader chain is largely academic as a
recovery backup anyway: if any of it is damaged the device cannot reach recovery
to restore it.

For the tier below recovery, prefer an **EDL firehose dump** — it captures all
of the above byte-exact plus the GPT, which TWRP has no concept of and cannot
back up at all.

`super` needs no fstab entry: `Setup_Super_Partition()` adds it automatically as
a raw image whenever `/dev/block/by-name/super` exists.

**Rollback set for a ROM swap** — a LineageOS install writes `super_empty.img`,
`boot`, `dtbo`, `recovery` and `vbmeta`. `super_empty.img` erases super's LP
metadata outright, taking the whole dynamic-partition layout with it, so a raw
`super` image is the *only* way back. Tick: **Super, Boot, DTBO, Vbmeta,
Recovery, Data**.

Super is 20 GiB (`BOARD_SUPER_PARTITION_SIZE`), and `Raw_Read_Write` is a flat
1 MB block copy — no compression, no sparse-skip, no splitting. So it needs an
**exFAT or ext4** destination (FAT32 caps files at 4 GB) and it cannot live on
internal storage, which is the `/data` being backed up in the same run.

**Restoring across a ROM change requires formatting `/data` first.** `/data` is
`BM_FILES` — a tar of *decrypted* content, with the keyblob under
`/data/unencrypted` deliberately excluded (see `Decrypt_FBE_DE()`). So the
backup carries no key, and the format costs nothing. It is also mandatory: the
on-disk keyblob is version-bound, and once the newer ROM's vold has stamped it,
a lower-`os_version` ROM's keymaster rejects it. Order: restore firmware →
format `/data` → boot the ROM once so vold mints a fresh key and creates the
user-0 CE directories → restore Data.

## Safety

Flashing both recovery slots is no longer off-limits (see *Flashing* above) —
bring-up is finished. Keep your own dump of slot B's stock recovery, plus EDL,
as the restore path before using *Flash to both slots*, and don't let both slots
carry the same untested build.

Never touch userdata / metadata / persist / PINs / FBE keys / IMEI.
