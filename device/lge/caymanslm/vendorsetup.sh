#!/bin/bash

export FOX_AB_DEVICE=1
export FOX_BUILD_TYPE="${FOX_BUILD_TYPE:-Unofficial}"
export FOX_DISABLE_UPDATEZIP=1

# Maintainer shown on the About page.
export OF_MAINTAINER="noamtu123"

# Default timezone: OrangeFox otherwise defaults to Central Europe
# (CET-1;CEST,...), which shows ~2 h behind local time here. Israel (IST/IDT).
export OF_DEFAULT_TIMEZONE="IST-2IDT,M3.4.4/26,M10.5.0"

export FOX_RECOVERY_INSTALL_PARTITION=/dev/block/bootdevice/by-name/recovery
export FOX_USE_BASH_SHELL=1
export FOX_USE_LZ4_BINARY=1
export FOX_USE_NANO_EDITOR=1
export FOX_USE_TAR_BINARY=1
export FOX_USE_ZSTD_BINARY=1
