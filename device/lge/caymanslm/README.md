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

Kernel source is pinned in `.github/manifests/caymanslm.xml`.

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

## Flashing (LM-G910EMW)

A/B device with dedicated `recovery_a` / `recovery_b` partitions.

- **`fastboot flash recovery_a` is BLOCKED** by LG's bootloader — it reports
  *"Cannot flash this partition in unlocked state"* even though the device is
  unlocked (an LG per-partition restriction; `boot` flashes fine, `recovery` does not).
- To install: flash the image from **within a running OrangeFox**
  (Install → Flash Recovery), or `fastboot boot <recovery.img>` to **RAM-boot** it
  for testing.
- Keep slot B's stock recovery + an EDL restore path as backup. **Do not flash both
  recovery slots** during bring-up.

## Safety

Never flash both recovery slots during testing. Never touch
userdata / metadata / persist / PINs / FBE keys / IMEI.
