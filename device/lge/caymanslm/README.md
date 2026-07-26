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
  installer zip carries `sdcard/Fox/FoxFiles/{Magisk.zip,uninstall.zip,
  AromaFM/AromaFM.zip}` and `sdcard/Fox/fox.bashrc`; a raw image flash writes
  only the partition. Until those files exist, Fox Addons → Install/Uninstall
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

## Safety

Flashing both recovery slots is no longer off-limits (see *Flashing* above) —
bring-up is finished. Keep your own dump of slot B's stock recovery, plus EDL,
as the restore path before using *Flash to both slots*, and don't let both slots
carry the same untested build.

Never touch userdata / metadata / persist / PINs / FBE keys / IMEI.
