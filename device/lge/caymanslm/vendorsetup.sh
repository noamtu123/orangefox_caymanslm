#!/bin/bash

export FOX_AB_DEVICE=1
export FOX_BUILD_TYPE="${FOX_BUILD_TYPE:-Unofficial}"
export FOX_DISABLE_UPDATEZIP=1
export FOX_RECOVERY_INSTALL_PARTITION=/dev/block/bootdevice/by-name/recovery
export FOX_USE_BASH_SHELL=1
export FOX_USE_LZ4_BINARY=1
export FOX_USE_NANO_EDITOR=1
export FOX_USE_TAR_BINARY=1
export FOX_USE_ZSTD_BINARY=1
