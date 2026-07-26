# OrangeFox Recovery — LG Velvet 4G (`caymanslm`)

Unofficial OrangeFox `fox_14.1` (R12.0) for the **LG Velvet 4G, LM-G910EMW**,
with working Qualcomm FBE `/data` decryption — including PIN, password and
pattern.

> **LM-G910EMW only.** Not the 5G Velvet (`caymanlm` / SDM765G) — different SoC,
> different device.

## Highlights

- **FBE `/data` decryption** with no credential set, and with PIN / password /
  pattern. Verified against the stock Android 12 firmware (G91030a).
- **Magisk 30.7** in the installer zip.
- **`adb reboot edl` from Android**, via an optional boot-image patch — see
  [the EDL guide](docs/ANDROID_EDL_BOOT_GUIDE.md).
- Flashlight fixed (this panel needs both torch channels driven).

## Install

LG's bootloader rejects `fastboot flash recovery` on this device even when
unlocked, so installation goes through the zip. The zip is also what writes the
Fox Addons payload (`Magisk.zip`, `uninstall.zip`, AromaFM) to internal storage
— flash only the `.img` and Fox Addons will correctly report *"file doesn't
exist"* when you try to install Magisk.

```sh
fastboot boot OrangeFox-R12.0-Unofficial-caymanslm.img
adb sideload OrangeFox-R12.0-Unofficial-caymanslm.zip
```

The first command RAM-boots the recovery without installing it; the second
installs it for real.

Alternatively, `adb push` the zip to `/tmp` and flash it from within OrangeFox.
When flashing a raw `.img` there instead (Install → Flash Image), *Options →
flash to both slots* writes both.

Back up your stock `boot` and `recovery` partitions before you start.

## Decryption

This device's kernel is **legacy fscrypt** — Qualcomm ICE, policy v1, driven by
the old `add_key` keyring API, with no fscrypt v2 `FS_IOC_ADD_ENCRYPTION_KEY`
ioctl. Android 12's `vold` installs FBE keys only through that v2 ioctl, so key
install failed with `ENOTTY`. The fix restores vold's legacy key path.

Credential decrypt needed a second fix: the ramdisk had no root
`/vendor/etc/vintf/manifest.xml`, and libvintf only scans the manifest
*fragment* directory once that root file parses. Keymaster and gatekeeper were
therefore undeclared, keystore2's shared-secret negotiation ran with zero
participants, and gatekeeper could match the PIN but never mint an auth token.

Details in [`device/lge/caymanslm/README.md`](device/lge/caymanslm/README.md).

## Repo layout

| Path | Contents |
|---|---|
| `device/lge/caymanslm/` | device tree |
| `overlay/` | whole-file fixes to upstream repos |
| `patches/` | narrow upstream fixes as diffs |
| `kernel-patches/` | Qualcomm EDL kernel patch |
| `apply-fixes.sh` | re-applies all of the above after a `repo sync` |
| `tools/` | EDL boot patcher, build helper |

There are **no forks** — every upstream change lives here as an overlay file or
a patch. [`OVERLAY.md`](OVERLAY.md) explains each one.

## Building

```sh
cd ~/fox && repo sync
/path/to/this/repo/apply-fixes.sh
source build/envsetup.sh
lunch twrp_caymanslm-ap2a-eng
mka recoveryimage
```

Produces both the `.img` and the `.zip` in `$OUT`. `apply-fixes.sh` also fetches
the pinned Magisk release by version and SHA256.

Keep `vendorsetup.sh` **LF-only**: shell does not strip a trailing CR the way
make and XML parsers do, and CRLF there silently corrupts every exported build
variable.

## Contributing

Pull requests are welcome — fixes, improvements, or support for related LG
devices.

## Licence

[GPL-3.0](LICENSE).

Upstream components keep their own terms: AOSP and TWRP sources under
Apache-2.0, and the kernel patch under GPL-2.0 to match the kernel it applies
to. The vendor binaries under `device/lge/caymanslm/recovery/root/vendor/` are
proprietary Qualcomm/LG components extracted from this device's own G91030a
firmware and redistributed unmodified for use on the device they came from.

Built on [OrangeFox Recovery](https://gitlab.com/OrangeFox) and TWRP, with
kernel source from LineageOS `lineage-22.2`.
