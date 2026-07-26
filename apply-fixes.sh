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

# The recovery staging directory can retain the old upstream keystore2.rc
# during an incremental build even after the source overlay has been copied.
# Refresh it explicitly so the disabled late-init trigger is always packaged.
KEYSTORE_INIT="$HERE/overlay/system/security/keystore2/keystore2.rc"
KEYSTORE_INIT_OUT="$FOX/out/target/product/caymanslm/recovery/root/system/etc/init/keystore2.rc"
if [ -f "$KEYSTORE_INIT_OUT" ]; then
  cp -f "$KEYSTORE_INIT" "$KEYSTORE_INIT_OUT"
  echo "  refreshed generated keystore2 init"
fi

apply_repo_patch() {
  local repo="$1"
  local patch="$2"
  local patch_name
  patch_name="$(basename "$patch")"
  if git -C "$repo" apply --check --recount --unidiff-zero "$patch" 2>/dev/null; then
    git -C "$repo" apply --recount --unidiff-zero "$patch"
    echo "  applied $patch_name"
  elif git -C "$repo" apply --reverse --check --recount --unidiff-zero "$patch" 2>/dev/null; then
    echo "  $patch_name already applied"
  else
    echo "error: $patch_name does not apply cleanly in $repo" >&2
    exit 1
  fi
}

RECOVERY_REPO="$FOX/bootable/recovery"
for PATCH in \
  "$HERE/patches/caymanslm-drm-page-flip.patch" \
  "$HERE/patches/caymanslm-listbox-single-render.patch" \
  "$HERE/patches/caymanslm-start-prepdecrypt-after-fstab.patch" \
  "$HERE/patches/caymanslm-skip-empty-theme-reload.patch" \
  "$HERE/patches/caymanslm-time-settings-migration.patch" \
  "$HERE/patches/caymanslm-three-channel-flashlight.patch" \
  "$HERE/patches/bootloader-message-misc-fallback.patch" \
  "$HERE/patches/caymanslm-battery-charge-responsiveness.patch" \
  "$HERE/patches/caymanslm-flashimage-options-listbox.patch"; do
  apply_repo_patch "$RECOVERY_REPO" "$PATCH"
done

apply_repo_patch "$FOX/device/qcom/twrp-common" \
  "$HERE/patches/caymanslm-prepdecrypt-no-ready-sleep.patch"
apply_repo_patch "$FOX/device/qcom/twrp-common" \
  "$HERE/patches/caymanslm-qti-crypto-service-identity.patch"
# These init fragments are copied into the ramdisk without dependable
# incremental dependency edges. Keep an existing staging tree in sync.
for CRYPTO_INIT in \
  init.recovery.qcom_decrypt.rc \
  init.recovery.qcom_decrypt.fbe.rc; do
  CRYPTO_INIT_SRC="$FOX/device/qcom/twrp-common/crypto/$CRYPTO_INIT"
  if [ "$CRYPTO_INIT" = "init.recovery.qcom_decrypt.fbe.rc" ]; then
    CRYPTO_INIT_SRC="$FOX/device/qcom/twrp-common/crypto_fbe/$CRYPTO_INIT"
  fi
  for CRYPTO_INIT_OUT in \
    "$FOX/out/target/product/caymanslm/root/$CRYPTO_INIT" \
    "$FOX/out/target/product/caymanslm/recovery/root/$CRYPTO_INIT"; do
    if [ -f "$CRYPTO_INIT_OUT" ]; then
      cp -f "$CRYPTO_INIT_SRC" "$CRYPTO_INIT_OUT"
    fi
  done
done
# This script is copied through a qcom makefile without a reliable incremental
# dependency edge. Refresh the staged ramdisk copy after applying its patch.
PREPDECRYPT_SRC="$FOX/device/qcom/twrp-common/crypto/system/bin/prepdecrypt.sh"
for PREPDECRYPT_OUT in \
  "$FOX/out/target/product/caymanslm/root/system/bin/prepdecrypt.sh" \
  "$FOX/out/target/product/caymanslm/recovery/root/system/bin/prepdecrypt.sh"; do
  if [ -f "$PREPDECRYPT_OUT" ]; then
    cp -f "$PREPDECRYPT_SRC" "$PREPDECRYPT_OUT"
  fi
done
echo "  refreshed generated prepdecrypt script"
apply_repo_patch "$FOX/frameworks/native" \
  "$HERE/patches/caymanslm-recovery-service-wait-100ms.patch"
apply_repo_patch "$FOX/system/libhidl" \
  "$HERE/patches/caymanslm-hidl-service-wait-100ms.patch"

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
