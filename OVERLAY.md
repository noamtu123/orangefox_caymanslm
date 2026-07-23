# Upstream source fixes

Most fixes to **upstream** repos (not our device tree) are stored as whole-file
overlays. One narrow patch is kept under `patches/` for
`libbootloader_message`, because only its `/misc` discovery fallback changes.
There are no per-repo forks or CI-only edits.

`repo sync` resets upstream repos to pristine and would wipe these, so after every
sync run `./apply-fixes.sh` (in the repo root), which copies `overlay/` over `~/fox`.

| File | Fix |
|---|---|
| `system/core/debuggerd/Android.bp` | `recovery_available` on crash_dump/tombstoned (native crash capture in recovery) |
| `external/strace/Android.bp` | `recovery_available` on strace (debug tooling) |
| `system/logging/logd/main.cpp` | logd DropPrivs `PLOG(FATAL)`→`ERROR` (logd/logcat work in recovery) |
| `frameworks/native/cmds/servicemanager/ServiceManager.cpp` | skip VINTF-stability add-gate so keystore2 registers (**load-bearing for FBE decrypt**) |
| `bootable/recovery/partition.cpp` | widen `Decrypt_DE` retry window (service-startup timing) |
| `bootable/recovery/partitionmanager.cpp` | include `android_filesystem_config.h` for `AID_MEDIA_RW` (compile fix) |
| `bootable/recovery/twrp-functions.cpp` | reliable fastbootd BCB command and LG `/persist/time/ats_2` clock source |
| `bootable/recovery/etc/init.recovery.logd.rc` | add logd control socket |
| `system/vold/*` (KeyUtil.cpp, FsCrypt.cpp, Decrypt.cpp, KeystoreInfo.cpp, Weaver1.*, Android.bp) | **FBE decrypt**: legacy Qualcomm ICE fscrypt `installKeyLegacy` + ENOTTY fallback + synthetic `/data` fstab entry |
| `patches/bootloader-message-misc-fallback.patch` | use the canonical by-name `misc` node when Android rejects TWRP's four-column fstab; fixes BCB clearing and targeted reboots |
| `patches/caymanslm-time-settings-migration.patch` | migrates the obsolete CET setting to Israel's POSIX rule and enables 24-hour time |
| `patches/caymanslm-three-channel-flashlight.patch` | adds a third OrangeFox flashlight sysfs path; caymanslm requires both torch channels before enabling the shared switch |
| `kernel-patches/caymanslm-edl-warm-reset.patch` | enables Qualcomm EDL on this LG kernel and preserves its EDL cookies with a warm reset |

Everything is here — there are **no forks**. `apply-fixes.sh` restores all of it after a sync.
