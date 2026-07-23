# overlay/

Whole-file overlays of small fixes to **upstream** repos (not our device tree).
These live here as plain files so they're version-controlled in one place — no
per-repo forks, no patch/diff files, no CI `sed`.

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
| `bootable/recovery/etc/init.recovery.logd.rc` | add logd control socket |

**Not here:** `system/vold` (the big FBE decrypt change, `installKeyLegacy`) — it comes
from the fork `noamtu123/android_system_vold@caymanslm-fbe` via the `local_manifest`,
so `repo sync` pulls it automatically.
