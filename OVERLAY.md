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
| `system/vold/*` (KeyUtil.cpp, FsCrypt.cpp, Decrypt.cpp, KeystoreInfo.cpp, Weaver1.*, Android.bp) | **FBE decrypt**: legacy Qualcomm ICE fscrypt `installKeyLegacy` + ENOTTY fallback + synthetic `/data` fstab entry. KeyUtil.cpp also links the fscrypt keyring into the uid-0 **user session keyring** so adbd (and other init services) can create files under encrypted `/data/media/0` — fixes `adb push` to `/sdcard` failing with ENOKEY after decrypt |
| `bootable/recovery/etc/init/keystore2.rc` **and** `system/security/keystore2/keystore2.rc` | disables upstream's premature `late-init` start; device init starts Keystore2 after Qualcomm Keymaster is ready, avoiding its boot-time abort/retry. **Load-bearing for FBE decrypt.** Two copies on purpose: the file that actually reaches the ramdisk is the `bootable/recovery` one, installed by the `keystore2.rc` prebuilt module in `bootable/recovery/etc/Android.mk` (`LOCAL_SRC_FILES := init/keystore2.rc`) and pulled in via `TWRP_REQUIRED_MODULES`. The `system/security` copy is the Soong `init_rc:` source for the same path and is kept in sync so neither can win with stale content. Reverting the `bootable/recovery` copy silently ships upstream's `on late-init / start keystore2` with no `disabled` line, which breaks decrypt — verified by unpacking the built image, not by reading the tree |
| `patches/bootloader-message-misc-fallback.patch` | use the canonical by-name `misc` node when Android rejects TWRP's four-column fstab; fixes BCB clearing and targeted reboots |
| `patches/caymanslm-time-settings-migration.patch` | migrates the obsolete CET setting to Israel's POSIX rule and enables 24-hour time |
| `patches/caymanslm-three-channel-flashlight.patch` | adds a third OrangeFox flashlight sysfs path; caymanslm requires both torch channels before enabling the shared switch |
| `patches/caymanslm-skip-empty-theme-reload.patch` | skips the post-decrypt `reapply_settings` theme reload entirely — /data auto-decrypts before the first GUI parse, so the custom theme (`/sdcard/Fox/theme/ui.zip`) and `/persist/.foxs` settings are already loaded; avoids a full second UI parse (~2s faster boot) |
| `kernel-patches/caymanslm-edl-warm-reset.patch` | enables Qualcomm EDL on this LG kernel and preserves its EDL cookies with a warm reset |
| `overlay/bootable/recovery/gui/theme/portrait_hdpi/images/Default/About/maintainer.png` | noamtu123's OrangeFox About-page maintainer avatar |
| `vendor/recovery/Files/Magisk.zip` | pinned to **Magisk 30.7** (upstream bundles an older build). Not an overlay file — `apply-fixes.sh` fetches the release apk by version + SHA256 into the gitignored `prebuilt/` cache and copies it in, keeping the 11 MB blob out of git. The apk is itself the recovery-flashable zip, and the build ships it as both `Magisk.zip` and `uninstall.zip` |

Everything is here — there are **no forks**. `apply-fixes.sh` restores all of it after a sync.
