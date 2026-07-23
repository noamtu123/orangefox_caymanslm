# OrangeFox Recovery — LG Velvet 4G (`caymanslm`)

OrangeFox `fox_14.1` recovery for the **LG Velvet 4G, LM-G910EMW** (Snapdragon 845,
codename `caymanslm`), with working Qualcomm FBE `/data` decryption.

> LM-G910EMW only. **Not** the 5G Velvet (`caymanlm` / SDM765G — a different device).

## Repo layout

- `device/lge/caymanslm/` — the device tree (details, decryption, and flashing in its README).
- `overlay/` — whole-file fixes to **upstream** repos, copied over the build tree by
  `apply-fixes.sh` after a `repo sync`. No forks, no patches, no CI (see `OVERLAY.md`).
- `.github/manifests/caymanslm.xml` — `local_manifest` (pins the kernel source).

## Building (WSL, no CI)

Built locally in a WSL OrangeFox `fox_14.1` tree at `~/fox`:

```sh
cd ~/fox && repo sync                     # only when you actually need to re-sync
/mnt/e/orangefox_caymanslm/apply-fixes.sh # re-apply overlay fixes after a sync
source build/envsetup.sh
lunch twrp_caymanslm-ap2a-eng
mka recoveryimage
```

The device tree itself is copied into `~/fox/device/lge/caymanslm` (it is not a
`repo` project). See `device/lge/caymanslm/README.md` for everything device-specific.
