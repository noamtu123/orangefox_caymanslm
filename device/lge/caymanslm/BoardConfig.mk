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

# -------------------------------------------------------------------------
# Partition sizes (from EDL dumps / LineageOS)
# -------------------------------------------------------------------------
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
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
# Device uses plain FBE (fileencryption=ice). PLATFORM_VERSION /
# PLATFORM_SECURITY_PATCH are intentionally left to the base defaults;
# prepdecrypt runs with SETPATCH=false on recovery-partition devices.
# -------------------------------------------------------------------------
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
BOARD_USES_QCOM_DECRYPTION := true
BOARD_USES_QCOM_FBE_DECRYPTION := true

# Recovery sepolicy for the bundled crypto services.
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

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
