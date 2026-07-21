# OrangeFox device tree — LG Velvet 4G (caymanslm, LM-G910EMW)

OrangeFox **fox_14.1** recovery for the LG Velvet 4G (Snapdragon 845, codename
`caymanslm`). Built on the hardware-validated LineageOS foundation with the
kernel compiled from source, and with Qualcomm FBE decryption for both stock and
LineageOS `/data`.

**Scope:** LM-G910EMW only (any region firmware). **Not** the 5G Velvet
(`caymanlm`/SDM765G — different device).

## Architecture

- **Base:** OrangeFox `fox_14.1` (Android 15) minimal manifest.
- **Kernel:** built from source — `kernel/lge/sdm845` (LineageOS lineage-22.2),
  `lineageos_caymanslm_defconfig`. This brings the proven display (BGRA_8888),
  touch, UFS, and USB drivers, and the clean cmdline. The stock A11 prebuilt
  kernel is **not** used (its RGBX/`video=vfb` cmdline belong to that kernel).
- **Firmware target:** split-version phone — Android 12 system on Android 11
  vendor (`G91030a`), Keymaster **@4.0** / Gatekeeper **@1.0** / qseecom **@1.0**.
- **Decryption:** the FBE blob closure (see `blob-manifest.txt`) is extracted
  from the device's own `G91030a` vendor and **bundled into the recovery
  ramdisk** at `/vendor`. This is slot-agnostic (does not live-mount vendor) and
  region-correct. fox_14.1 auto-detects the keymaster version from the bundled
  VINTF manifest.

External sources are pinned in `.github/manifests/caymanslm.xml`.

## Build (CI)

Compiled via the manual GitHub Actions workflow (`.github/workflows/build-orangefox.yml`,
`workflow_dispatch` only). It syncs fox_14.1 + the pinned trees, builds the
kernel from source, and produces `out/target/product/caymanslm/recovery.img`.
The workflow has a disk-capacity gate (≥ 25 GiB free after sync) to avoid false
failures. **Expect several build→fix iterations** — a new tree does not compile
clean on the first try.

## Flashing guide (for LM-G910EMW owners)

> **This device is A/B with dedicated `recovery_a`/`recovery_b` partitions. You
> must flash the recovery to your ACTIVE slot, or "reboot to recovery" will just
> launch the other slot's stock recovery.**

1. Unlock the bootloader (erases data).
2. Check your active slot:
   ```sh
   fastboot getvar current-slot        # or: adb shell getprop ro.boot.slot_suffix
   ```
3. Flash to that slot only (example for slot a):
   ```sh
   fastboot flash recovery_a OrangeFox-caymanslm.img
   ```
   Keep the other slot's stock recovery + an EDL restore path as backup.
4. Reboot straight to recovery (don't boot system first, or stock may restore it).

**If you later switch slots or take an OTA**, the bootloader starts using the
other slot's recovery — re-flash OrangeFox to the new active slot. Once you trust
the build, advanced users may flash **both** slots so slot switches don't lose it.

## Decryption support

- **Verified target:** LM-G910EMW on the A11 vendor (`G91030a`) family — stock
  A12 system and LineageOS both ride this vendor, so both decrypt with the same
  bundled stack.
- Boots on any LM-G910EMW regardless of firmware; **significantly older stock
  firmware may boot but fail to decrypt** (different keymaster trustlet). Report
  your `ro.vendor.lge.swversion` if decryption fails.

## Known first-iteration items (need on-device logs)

- SELinux denials while starting the crypto services (`/tmp/recovery.log` from
  the first one-slot decrypt test drives the fixes — do not guess allow rules).
- qseecomd labeling in `sepolicy/vendor/file_contexts`.
- LineageOS (A15) FBE policy/metadata-encryption version handling.
- MTP is disabled for bring-up; validate ADB first, then enable.

## Safety policy

Untested hardware bring-up. Never flash both recovery slots during testing.
Never touch userdata/metadata/persist/PINs/FBE keys/IMEI. No "it works" claim
without an on-device one-slot test with logs.
