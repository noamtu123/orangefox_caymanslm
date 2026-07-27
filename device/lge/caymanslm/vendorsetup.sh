#!/bin/bash

export FOX_AB_DEVICE=1
export FOX_BUILD_TYPE="${FOX_BUILD_TYPE:-Unofficial}"

# Build the flashable installer zip alongside the raw recovery image.
# The zip is the only thing that deploys the addon payload to userdata:
#   sdcard/Fox/FoxFiles/{Magisk.zip,uninstall.zip}   (AromaFM removed, see below)
#   sdcard/Fox/fox.bashrc
# A bare recovery.img flash writes the partition and nothing else, which is why
# Fox Addons then reports "file doesn't exist" for Install/Uninstall Magisk.
#
# NOTE: keep this file LF-only. It is sourced by the build on Linux, and shell
# (unlike make and XML) does not strip a trailing CR, so CRLF here silently
# appends \r to every value below: it neutered the "= 1" flag tests, put a
# literal CR in the recovery zip's filename via FOX_BUILD_TYPE, and wrote
# RECOVERY_PARTITION=...recovery^M into the ramdisk's fox.cfg.
export FOX_DISABLE_UPDATEZIP=0

# Maintainer shown on the About page.
export OF_MAINTAINER="noamtu123"

# Default timezone: OrangeFox otherwise defaults to Central Europe
# (CET-1;CEST,...), which shows ~2 h behind local time here. Israel (IST/IDT).
export OF_DEFAULT_TIMEZONE="IST-2IDT,M3.4.4/26,M10.5.0"

# AromaFM cannot work on this device, so don't ship it. Its update-binary is a
# stripped 32-bit ARM static ELF from 2015 that draws its own UI straight to the
# framebuffer: `strings` shows only /dev/graphics/fb0 and /dev/fb0, and zero DRM
# symbols (no libdrm, no drmModeGetResources, no /dev/dri). This panel is
# DRM/KMS-only -- /dev/graphics does not exist and neither does /dev/fb0, just
# /dev/dri/card0 -- so the open fails, the old code does not check, and the
# updater dies with SIGSEGV: "Updater process ended with signal: 11". It is not
# fixable short of rewriting a stripped binary, and leaving it in only gives
# every user a red "Failed" screen the first time they tap it.
export FOX_DELETE_AROMAFM=1

export FOX_RECOVERY_INSTALL_PARTITION=/dev/block/bootdevice/by-name/recovery
export FOX_USE_BASH_SHELL=1
export FOX_USE_LZ4_BINARY=1
export FOX_USE_NANO_EDITOR=1
export FOX_USE_TAR_BINARY=1
export FOX_USE_ZSTD_BINARY=1
