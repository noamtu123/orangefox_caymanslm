# OrangeFox Recovery — LG Velvet 4G (`caymanslm`)

Unofficial OrangeFox `fox_14.1` (R12.0) recovery for the **LG Velvet 4G,
LM-G910EMW** (Snapdragon 845, codename `caymanslm`), with working Qualcomm FBE
`/data` decryption — including PIN, password and pattern.

> **LM-G910EMW only.** Not the 5G Velvet (`caymanlm` / SDM765G) — that is a
> different SoC and a different device. Do not flash this there.

## Maintainer

![noamtu123 maintainer profile](assets/noamtu123-maintainer.png)

**noamtu123**

## What works

- **FBE `/data` decryption**, with no credential set and with PIN / password /
  pattern. Verified against the stock Android 12 ROM.
- MTP, ADB, USB OTG, backup/restore, flashing.
- Magisk **30.7** bundled in the installer zip (Fox Addons → Install Magisk).
- Flashlight, correct local time, and a responsive charging indicator.
- **`adb reboot edl` from Android**, via an optional boot-image patch — see
  [the EDL guide](docs/ANDROID_EDL_BOOT_GUIDE.md).

## Install

Grab the **`.zip`**, not the bare `.img`. Both contain the same recovery, but
only the zip also deploys the addon payload (`Magisk.zip`, `uninstall.zip`,
AromaFM, `fox.bashrc`) to internal storage. Flashing only the `.img` leaves Fox
Addons reporting *"file doesn't exist"* for Install/Uninstall Magisk — that
message is accurate, not a fault.

`fastboot flash recovery` is **blocked by LG's bootloader** on this device even
when unlocked ("Cannot flash this partition in unlocked state"). So:

- **From an existing custom recovery:** flash the zip.
- **First time / no custom recovery yet:** `fastboot boot <recovery.img>` to
  RAM-boot it, then flash the zip from within it.

Note that `fastboot flash boot` *is* permitted — it is only `recovery` that LG
restricts.

## Decryption

This device's kernel — stock and LineageOS alike — is **legacy fscrypt**:
Qualcomm ICE, policy v1, driven by the old `add_key` keyring API, with no
fscrypt v2 `FS_IOC_ADD_ENCRYPTION_KEY` ioctl. Android 12 `vold` installs FBE
keys *only* through that v2 ioctl, so key install failed with `ENOTTY`.

The fix restores vold's legacy key path (`installKeyLegacy`, with an `ENOTTY`
fallback). Credential decrypt needed a second fix: the recovery ramdisk had no
root `/vendor/etc/vintf/manifest.xml`, and libvintf only scans the manifest
*fragment* directory once that root file parses — so keymaster@4.0 and
gatekeeper@1.0 were undeclared, keystore2's shared-secret negotiation ran with
zero participants, and gatekeeper could match the PIN but never mint an auth
token.

Full detail in [`device/lge/caymanslm/README.md`](device/lge/caymanslm/README.md).

## Repo layout

| Path | Contents |
|---|---|
| `device/lge/caymanslm/` | the device tree (device-specific detail in its README) |
| `overlay/` | whole-file fixes to **upstream** repos |
| `patches/` | narrow upstream patches applied as diffs |
| `kernel-patches/` | kernel patch enabling Qualcomm EDL |
| `apply-fixes.sh` | re-applies all of the above after a `repo sync` |
| `tools/` | EDL boot patcher, build helper |
| `.github/manifests/caymanslm.xml` | `local_manifest` pinning the kernel source |

There are **no forks**. Every change to an upstream repo lives here as an
overlay file or a patch, and `apply-fixes.sh` restores all of it after a sync.
See [`OVERLAY.md`](OVERLAY.md) for what each one does and why.

## Building

Built locally in a WSL OrangeFox `fox_14.1` tree — there is no CI.

```sh
cd ~/fox && repo sync          # only when you actually need to re-sync
/path/to/this/repo/apply-fixes.sh
source build/envsetup.sh
lunch twrp_caymanslm-ap2a-eng
mka recoveryimage
```

This produces both `OrangeFox-R12.0-Unofficial-caymanslm.img` and `.zip` in
`$OUT`. `apply-fixes.sh` also fetches the pinned Magisk release (by version and
SHA256) into a gitignored `prebuilt/` cache.

The device tree is copied into `~/fox/device/lge/caymanslm`; it is not a `repo`
project. Keep `vendorsetup.sh` **LF-only** — shell does not strip a trailing CR
the way make and XML parsers do, and CRLF there silently corrupts every exported
build variable.

## Licensing and credits

Built on [OrangeFox Recovery](https://gitlab.com/OrangeFox) and TWRP, on top of
AOSP. Kernel source is LineageOS `lineage-22.2` for `kernel/lge/sdm845`, pinned
in the local manifest. Each component keeps its upstream licence — AOSP and
TWRP sources under Apache-2.0, kernel patches under GPL-2.0. The files under
`overlay/` and `patches/` are modifications of those upstream sources and carry
the same terms.

The vendor binaries under `device/lge/caymanslm/recovery/root/vendor/` are
proprietary Qualcomm/LG components extracted from the device's own `G91030a`
firmware, included so the recovery can perform FBE decryption. They are
redistributed here unmodified for use on the device they came from.
