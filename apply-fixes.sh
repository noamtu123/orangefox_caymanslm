#!/usr/bin/env bash
# apply-fixes.sh — re-apply caymanslm overlay fixes to the OrangeFox build tree.
#
# ~/fox (the OrangeFox source) is assembled by `repo sync`, which resets every
# upstream repo to pristine and would wipe our fixes. This copies overlay/ over
# the tree and applies the narrow upstream patches under patches/.
#
# Run it once after every `repo sync`, before building.
#
# NOTE: this restores ALL upstream-repo fixes, including system/vold's FBE
# decrypt change. There are no forks; the local_manifest only overrides the
# kernel.
#
# Usage: ./apply-fixes.sh [FOX_TREE]      (default: $HOME/fox)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FOX="${1:-$HOME/fox}"
[ -d "$FOX" ] || { echo "error: build tree not found: $FOX" >&2; exit 1; }
[ -d "$HERE/overlay" ] || { echo "error: overlay/ not found next to this script" >&2; exit 1; }
echo "Applying overlay fixes to $FOX ..."
cp -av "$HERE/overlay/." "$FOX/" | sed 's/^/  /'

# The OrangeFox theme copier does not track individual image files as Ninja
# dependencies. Refresh this generated resource when an incremental build tree
# already exists; a clean tree will copy it from overlay normally.
THEME_AVATAR="$HERE/overlay/bootable/recovery/gui/theme/portrait_hdpi/images/Default/About/maintainer.png"
THEME_AVATAR_OUT="$FOX/out/target/product/caymanslm/recovery/root/twres/images/Default/About/maintainer.png"
if [ -f "$THEME_AVATAR_OUT" ]; then
  cp -f "$THEME_AVATAR" "$THEME_AVATAR_OUT"
  echo "  refreshed generated maintainer avatar"
fi

RECOVERY_REPO="$FOX/bootable/recovery"
for PATCH in "$HERE"/patches/*.patch; do
  PATCH_NAME="$(basename "$PATCH")"
  if git -C "$RECOVERY_REPO" apply --check "$PATCH" 2>/dev/null; then
    git -C "$RECOVERY_REPO" apply "$PATCH"
    echo "  applied $PATCH_NAME"
  elif git -C "$RECOVERY_REPO" apply --reverse --check "$PATCH" 2>/dev/null; then
    echo "  $PATCH_NAME already applied"
  else
    echo "error: $PATCH_NAME does not apply cleanly" >&2
    exit 1
  fi
done

KERNEL_REPO="$FOX/kernel/lge/sdm845"
for PATCH in "$HERE"/kernel-patches/*.patch; do
  PATCH_NAME="$(basename "$PATCH")"
  if git -C "$KERNEL_REPO" apply --check "$PATCH" 2>/dev/null; then
    git -C "$KERNEL_REPO" apply "$PATCH"
    echo "  applied kernel $PATCH_NAME"
  elif git -C "$KERNEL_REPO" apply --reverse --check "$PATCH" 2>/dev/null; then
    echo "  kernel $PATCH_NAME already applied"
  else
    echo "error: kernel patch $PATCH_NAME does not apply cleanly" >&2
    exit 1
  fi
done

echo "Done. (All fixes are local overlays/patches; no forks.)"
