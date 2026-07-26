#!/usr/bin/env bash
set -eo pipefail
cd "$HOME/fox"
source build/envsetup.sh >/dev/null
lunch twrp_caymanslm-ap2a-eng >/dev/null
mka recoveryimage
