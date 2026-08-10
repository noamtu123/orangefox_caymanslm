#
# BoardConfig.mk — OrangeFox (fox_14.1) recovery for LG Velvet 4G
# caymanslm / LM-G910EMW / SDM845.
#
# Self-contained: values are copied from the hardware-validated LineageOS
# lineage-22.2 tree (device/lge/caymanslm + device/lge/sdm845-common) and from
# the user's own EDL/super dumps. We intentionally do NOT `include` the
# LineageOS common BoardConfig — it pulls in LineageOS/CAF-only sepolicy and
# compatibility-matrix repos absent from the OrangeFox manifest.
#
# Firmware target: A12 system / A11 vendor split (G91030a), keymaster @4.0.
#

DEVICE_PATH := device/lge/caymanslm

# -------------------------------------------------------------------------
# Platform / architecture (from sdm845-common)
# -------------------------------------------------------------------------
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := kryo385

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := kryo385

TARGET_BOARD_PLATFORM := sdm845
TARGET_BOARD_PLATFORM_GPU := qcom-adreno630
TARGET_BOOTLOADER_BOARD_NAME := sdm845
TARGET_NO_BOOTLOADER := true
BOARD_VENDOR := lge
BOARD_USES_QCOM_HARDWARE := true

# Allow copying the bundled vendor ELF decrypt blobs via PRODUCT_COPY_FILES
# (see device.mk). Same mechanism LineageOS/TheMuppets use for vendor blobs.
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# -------------------------------------------------------------------------
# A/B + dynamic partitions
# -------------------------------------------------------------------------
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += boot dtbo product recovery system vbmeta vendor
BOARD_USES_METADATA_PARTITION := true

# NOTE: PRODUCT_USE_DYNAMIC_PARTITIONS is a *product* variable in the
# release-config (Android-14+) build system and is readonly by the time
# board_config.mk is parsed — assigning it here fails with "cannot assign to
# readonly variable". It is set on the product side in device.mk instead.
BOARD_SUPER_PARTITION_SIZE := 21470642176
BOARD_SUPER_PARTITION_GROUPS := lge_dynamic_partitions
BOARD_LGE_DYNAMIC_PARTITIONS_PARTITION_LIST := product system vendor
# super / 2 - 4 MiB overhead (matches LineageOS sizing)
BOARD_LGE_DYNAMIC_PARTITIONS_SIZE := $(shell expr $(BOARD_SUPER_PARTITION_SIZE) / 2 - 4194304)

BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_PRODUCT := product

# -------------------------------------------------------------------------
# Kernel — built from LineageOS source (the proven, BGRA-capable kernel)
# -------------------------------------------------------------------------
TARGET_KERNEL_SOURCE := kernel/lge/sdm845
TARGET_KERNEL_CONFIG := lineageos_caymanslm_defconfig

BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb
BOARD_KERNEL_SEPARATED_DTBO := true
BOARD_INCLUDE_RECOVERY_DTBO := true

# Clean LineageOS cmdline (matches the from-source kernel) + device suffixes.
# NOTE: the stock `video=vfb...` cmdline belongs to the stock A11 kernel and is
# deliberately NOT used here.
BOARD_KERNEL_CMDLINE := msm_rtb.filter=0x237 ehci-hcd.park=3
BOARD_KERNEL_CMDLINE += lpm_levels.sleep_disabled=1 service_locator.enable=1
BOARD_KERNEL_CMDLINE += swiotlb=2048 androidboot.configfs=true
BOARD_KERNEL_CMDLINE += androidboot.usbcontroller=a600000.dwc3
BOARD_KERNEL_CMDLINE += loop.max_part=7
BOARD_KERNEL_CMDLINE += androidboot.boot_devices=soc/1d84000.ufshc
BOARD_KERNEL_CMDLINE += androidboot.hardware=caymanslm
BOARD_KERNEL_CMDLINE += androidboot.fstab_suffix=caymanslm

# Recovery boot-image geometry.
# Header v1 (NOT v2): the from-source kernel is Image.gz-dtb, i.e. the DTB is
# appended inside the kernel — there is no separate dtb image. Header v2 has a
# mandatory dtb section and mkbootimg aborts with "DTB image must not be empty"
# when none is supplied. Header v1 still carries recovery_dtbo (which we use via
# BOARD_INCLUDE_RECOVERY_DTBO) but has no separate-dtb requirement. This matches
# how LineageOS builds this device from source (appended-dtb kernel, no forced
# v2). The earlier "v2" value came from repacking the *stock* recovery, whose
# prebuilt kernel carried a separate dtb — not applicable to a source build.
# Offsets validated from stock recovery; still valid for v1.
BOARD_BOOT_HEADER_VERSION := 1
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset 0x01000000
BOARD_MKBOOTIMG_ARGS += --tags_offset 0x00000100

# os_version / os_patch_level in the boot header are LOAD-BEARING FOR FBE
# DECRYPTION -- they are not cosmetic build metadata.
#
# The bootloader passes the *booted image's* header values to the TEE, and
# Keymaster compares them against the values baked into the FBE key. A key may
# be upgraded to a HIGHER patch level, never downgraded to a lower one. So the
# recovery must declare a level >= the level of the ROM that created the key.
# prepdecrypt cannot fix this: it resetprops ro.build.version.*, but the TEE's
# value comes from the image header, which no property can influence.
#
# The base defaults (PLATFORM_VERSION 14 / PLATFORM_SECURITY_PATCH 2024-09-05)
# happened to work against stock A12, whose key is 12 / 2022-08 -- older, so the
# key was simply upgraded upward. They break against LineageOS 22.2, whose key is
# 15 / 2026-08: newer than the recovery, so the required upgrade is a downgrade
# and Keymaster refuses it. Observed as (found 2026-08-11):
#     KeyMasterHalDevice: Begin send cmd failed        resp->status: -62  (KEY_REQUIRES_UPGRADE)
#     KeyMasterHalDevice: Upgrade key send cmd failed  resp->status: -38  (INVALID_ARGUMENT)
#     keystore2: Upgrade failed. Error::Km(r#INVALID_ARGUMENT)
#     recovery: decryptWithKeystoreKey failed / fscrypt_initialize_systemwide_keys returned fail
# and on-screen as a recovery that cannot decrypt /data at all.
#
# BOARD_MKBOOTIMG_ARGS is expanded AFTER INTERNAL_MKBOOTIMG_VERSION_ARGS in
# build/make/core/Makefile, so these win.
#
# Set deliberately FAR AHEAD of any ROM this recovery will ever service, so it
# never needs bumping when LineageOS ships a monthly security patch or a new
# Android release. Both fields matter: os_patch_level covers monthly updates,
# os_version covers major upgrades (an Android 16 ROM would otherwise reintroduce
# the same failure).
#
# Setting it ahead is safe because the recovery never persists an upgraded key.
# This vold fork writes the upgraded blob to a tmpfs path and has the commit path
# disabled -- system/vold/KeyStorage.cpp, BeginKeystoreOp():
#     std::string temp_dir = "/tmp/" + blob_dir + "/";
#     auto upgraded_blob_file = temp_dir + kFn_keymaster_key_blob;
#     // auto upgraded_blob_file = dir + "/" + kFn_keymaster_key_blob_upgraded;
# with CommitUpgradedKey()/DeleteUpgradedKey() commented out. So the key is
# upgraded in-session only and the ROM's on-disk blob is never rewritten -- which
# is also why stock A12 kept booting fine for weeks while this recovery was
# upgrading its 2022-08 key to 2024-09 on every visit.
#
# Encoding limits (the header packs these into one 32-bit field at offset 44):
# version fields are 7 bits each (max 127), and the patch level is
# ((year-2000) << 4) | month, so the latest representable is 2127-12.
#
# Verified on-device 2026-08-11 against LineageOS 22.2's key (15 / 2026-08):
# "Data successfully decrypted", CE storage readable, zero fscrypt failures.
BOARD_MKBOOTIMG_ARGS += --os_version 20.0.0
BOARD_MKBOOTIMG_ARGS += --os_patch_level 2099-12-01

# Ramdisk compression: LZMA shrinks the (currently bloated) recovery ramdisk
# well below the stock ~28 MB baseline. Paired with OF_USE_LZMA_COMPRESSION in
# the OrangeFox section. The from-source kernel has LZMA support built in.
BOARD_RAMDISK_USE_LZMA := true

# -------------------------------------------------------------------------
# Partition sizes (from EDL dumps / LineageOS)
# -------------------------------------------------------------------------
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
# Build and pad to 64 MiB, rather than the physical 100 MiB partition capacity.
# The image header carries the actual component lengths; 64 MiB leaves ample
# room for the current ~38 MiB payload while keeping downloads reasonable.
# Physical recovery_a/recovery_b capacity: 104857600 bytes.
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67108864
# BOARD_BOOTIMAGE_PARTITION_SIZE intentionally omitted: this is a recovery-only
# build (no boot image produced). The LineageOS value (67108864) also disagrees
# with the EDL dumps (boot_a/b = 100663296); left out to avoid a wrong assertion.

# -------------------------------------------------------------------------
# Filesystems
# -------------------------------------------------------------------------
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_HAS_LARGE_FILESYSTEM := true

# -------------------------------------------------------------------------
# Recovery / display / input
# -------------------------------------------------------------------------
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
# This device keeps its valid time-of-day offset in /persist/time/ats_2.
# twrp-functions.cpp includes that directory in its ATS search.
TARGET_RECOVERY_QCOM_RTC_FIX := true
TARGET_SCREEN_DENSITY := 420
BOARD_HAS_NO_SELECT_BUTTON := true

TW_THEME := portrait_hdpi
TW_SCREEN_BLANK_ON_BOOT := true
TW_BRIGHTNESS_PATH := /sys/class/backlight/panel0-backlight/brightness
TW_MAX_BRIGHTNESS := 365
TW_DEFAULT_BRIGHTNESS := 180
TW_INPUT_BLACKLIST := hbtp_vm
TW_USE_TOOLBOX := true
TW_EXTRA_LANGUAGES := true
TW_INCLUDE_FASTBOOTD := true
TW_INCLUDE_RESETPROP := true
TW_HAS_EDL_MODE := true
RECOVERY_SDCARD_ON_DATA := true

# Battery: read the real fuel-gauge node (probed readable on-device). Without an
# explicit path the health-service lookup fails and the status bar shows "!".
TW_CUSTOM_BATTERY_PATH := /sys/class/power_supply/battery

# Vibration: this device's vibrator is the Immersion tspdrv driver (/dev/tspdrv
# exists on-device), NOT a timed_output / qpnp-haptics node. This flag routes
# TWRP/OrangeFox haptics through the tspdrv ioctl path.
TW_HAPTICS_TSPDRV := true

# USB: provide our own recovery USB configfs init (see rootdir).
TW_EXCLUDE_DEFAULT_USB_INIT := true

# MTP disabled for initial bring-up (ADB validated first, per handoff policy).
TW_EXCLUDE_MTP := true

# -------------------------------------------------------------------------
# Crypto — Qualcomm FBE (keymaster @4.0 / gatekeeper @1.0 / qseecom @1.0)
#
# BOARD_USES_QCOM_FBE_DECRYPTION is the master switch: it makes
# device/qcom/twrp-common define the qcom_decrypt / qcom_decrypt_fbe modules,
# which install init.recovery.qcom_decrypt(.fbe).rc + prepdecrypt.sh and drive
# the qseecomd -> keymaster/gatekeeper startup chain. Without it, the
# qcom_decrypt* entries in device.mk PRODUCT_PACKAGES silently resolve to
# nothing and the decrypt trigger chain never enters the ramdisk.
#
# The bundled service binaries live in recovery/root/system/bin (the path
# twrp-common's service defs exec from on Android-10+ trees); the ELF closure
# lives in recovery/root/vendor/lib64 (reached via each service's
# LD_LIBRARY_PATH=/vendor/lib64:...). fox_14.1 auto-detects the keymaster
# version from the on-device vendor manifest, with the bundled ramdisk manifest
# as fallback.
#
# Device uses plain FBE (fileencryption=ice). prepdecrypt runs with
# SETPATCH=true here (forced by init.recovery.caymanslm.rc) so it resetprops the
# installed ROM's OS version and patch level. That covers the *property* side
# only -- the boot header's os_version/os_patch_level are equally load-bearing
# and are pinned via BOARD_MKBOOTIMG_ARGS above; see the comment there.
# -------------------------------------------------------------------------
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
BOARD_USES_QCOM_DECRYPTION := true
BOARD_USES_QCOM_FBE_DECRYPTION := true

# Enabling the FBE decrypt path pulls libsysutils.so into the recovery binary's
# NEEDED closure, but the base image doesn't ship it, so recovery aborts at load
# with "library libsysutils.so not found" and init respawns it in a 5s crash
# loop (blank screen). Force the module into the ramdisk by name (it has a
# recovery variant upstream). NOTE: this OrangeFox base has NO
# TW_RECOVERY_ADDITIONAL_RELINK_* handling — that mechanism is a no-op here, so
# the module-name request below is what actually installs the library.
TARGET_RECOVERY_DEVICE_MODULES += libsysutils

# Recovery sepolicy for the bundled crypto services.
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# -------------------------------------------------------------------------
# Logging / diagnostics — ship logd + logcat in the recovery ramdisk.
#
# The base OrangeFox image strips the log daemon, so there is no logcat, no
# logd, and native tombstones land on encrypted /data (unreadable). That makes
# every runtime failure (e.g. a keystore2 Rust panic during FBE decrypt) a
# black box. These two flags put logd + its init service and the logcat binary
# into the ramdisk and route logging through logd, so `adb shell logcat` works
# and crash_dump's "Abort message: ..." is readable on-device.
#
# NOTE: the guard in bootable/recovery/Android.mk is TWRP_INCLUDE_LOGCAT (full
# "TWRP_" prefix), NOT the classic TW_INCLUDE_LOGCAT — the latter is a dead
# variable in this OrangeFox base. With TARGET_USES_LOGD, this pulls in
# logcat + logd + libsysutils + libnl + init.recovery.logd.rc.
# -------------------------------------------------------------------------
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true

# strace + native crash capture in the ramdisk. strace gives syscall-level
# tracing independent of whether logd is up; crash_dump64 + tombstoned turn
# native aborts (logd, keystore2, ...) into readable tombstones.
#
# IMPORTANT: strace, crash_dump and tombstoned are NOT recovery_available
# upstream, so soong SILENTLY skips them when requested by their plain module
# name (they install to /system/bin, a partition recovery never mounts). Two
# things are required, both in place:
#   1. recovery_available:true in external/strace/Android.bp and
#      system/core/debuggerd/Android.bp — applied by the CI "Patch OrangeFox
#      source" step (WSL applies the same seds locally);
#   2. request the .recovery-suffixed module names here.
TARGET_RECOVERY_DEVICE_MODULES += strace.recovery
TARGET_RECOVERY_DEVICE_MODULES += crash_dump.recovery tombstoned.recovery

# -------------------------------------------------------------------------
# Verified Boot — device is unlocked for bring-up; recovery flashed to one slot.
# -------------------------------------------------------------------------
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3

# -------------------------------------------------------------------------
# OrangeFox
# -------------------------------------------------------------------------
OF_AB_DEVICE_WITH_RECOVERY_PARTITION := 1
OF_USE_MAGISKBOOT := 1
OF_USE_MAGISKBOOT_FOR_ALL_PATCHES := 1
OF_NO_REFLASH_CURRENT_ORANGEFOX := 1
OF_SCREEN_H := 2460
OF_STATUS_H := 90
OF_STATUS_INDENT_LEFT := 48
OF_STATUS_INDENT_RIGHT := 48
OF_ALLOW_DISABLE_NAVBAR := 0

# Flashlight: the rear LED requires both torch channels to be configured before
# the shared switch is enabled. OrangeFox applies these paths in numeric order
# and appends /brightness + /max_brightness itself.
OF_FLASHLIGHT_ENABLE := 1
OF_FL_PATH1 := /sys/class/leds/led:torch_0
OF_FL_PATH2 := /sys/class/leds/led:torch_1
OF_FL_PATH3 := /sys/class/leds/led:switch_0

# Battery: use the legacy polling services (OrangeFox doc: for status-bar % that
# misreads, e.g. stuck at 100%/"!"), alongside TW_CUSTOM_BATTERY_PATH above.
OF_USE_LEGACY_BATTERY_SERVICES := 1

# Ramdisk size: enable LZMA compression (pairs with BOARD_RAMDISK_USE_LZMA).
OF_USE_LZMA_COMPRESSION := 1

# Boot speed: don't re-run the whole startup process after decryption succeeds
# (trims several seconds off the OrangeFox-logo wait).
OF_NO_RELOAD_AFTER_DECRYPTION := 1
