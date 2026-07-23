#!/usr/bin/env bash
# apply-fixes.sh — re-apply caymanslm overlay fixes to the OrangeFox build tree.
#
# ~/fox (the OrangeFox source) is assembled by `repo sync`, which resets every
# upstream repo to pristine and would wipe our fixes. This copies overlay/ over
# the tree to restore the small whole-file fixes we make to upstream repos.
#
# Run it once after every `repo sync`, before building.
#
# NOTE: system/vold is NOT handled here — it comes from our own fork automatically
# via .repo/local_manifests/caymanslm.xml (the local_manifest). This overlay only
# covers the small one-file changes in other upstream repos (debug tooling,
# keystore2 VINTF fix, recovery build/timing tweaks).
#
# Usage: ./apply-fixes.sh [FOX_TREE]      (default: $HOME/fox)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FOX="${1:-$HOME/fox}"
[ -d "$FOX" ] || { echo "error: build tree not found: $FOX" >&2; exit 1; }
[ -d "$HERE/overlay" ] || { echo "error: overlay/ not found next to this script" >&2; exit 1; }
echo "Applying overlay fixes to $FOX ..."
cp -av "$HERE/overlay/." "$FOX/" | sed 's/^/  /'
echo "Done. (system/vold is provided by the fork via local_manifest.)"
