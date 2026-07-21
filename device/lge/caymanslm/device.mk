# device.mk — caymanslm OrangeFox recovery composition.

LOCAL_PATH := device/lge/caymanslm

PRODUCT_USE_DYNAMIC_PARTITIONS := true

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += boot dtbo product recovery system vbmeta vendor
PRODUCT_PACKAGES += \
    android.hardware.boot@1.1-impl \
    android.hardware.boot@1.1-impl.recovery \
    android.hardware.boot@1.1-service \
    update_engine_sideload

# Recovery init
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.recovery.caymanslm.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.caymanslm.rc

# TWRP built-in Qualcomm FBE decrypt helpers (AOSP-side crypto glue)
PRODUCT_PACKAGES += \
    qcom_decrypt \
    qcom_decrypt_fbe

# fastbootd
PRODUCT_PACKAGES += \
    fastbootd

# -------------------------------------------------------------------------
# Bundled FBE decrypt vendor blobs (G91030a / A11, keymaster @4.0).
# Sourced from the user's own vendor_a dump, ELF-closure-verified. Placed into
# the recovery ramdisk at /vendor via explicit PRODUCT_COPY_FILES (deterministic;
# does not rely on the recovery/root auto-include convention).
#
# Copying ELF prebuilts via PRODUCT_COPY_FILES requires the BUILD_BROKEN flag
# set in BoardConfig.mk (BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES) — the same
# mechanism LineageOS/TheMuppets use for vendor blobs.
# See blob-manifest.txt for SHA-256 of each file.
# -------------------------------------------------------------------------
RECOVERY_VENDOR := $(LOCAL_PATH)/recovery/root/vendor

PRODUCT_COPY_FILES += \
    $(RECOVERY_VENDOR)/bin/qseecomd:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/bin/qseecomd \
    $(RECOVERY_VENDOR)/bin/hw/android.hardware.keymaster@4.0-service-qti:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/bin/hw/android.hardware.keymaster@4.0-service-qti \
    $(RECOVERY_VENDOR)/bin/hw/android.hardware.gatekeeper@1.0-service-qti:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/bin/hw/android.hardware.gatekeeper@1.0-service-qti \
    $(RECOVERY_VENDOR)/lib64/vendor.qti.hardware.qseecom@1.0.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/vendor.qti.hardware.qseecom@1.0.so \
    $(RECOVERY_VENDOR)/lib64/libqtikeymaster4.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libqtikeymaster4.so \
    $(RECOVERY_VENDOR)/lib64/libQSEEComAPI.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libQSEEComAPI.so \
    $(RECOVERY_VENDOR)/lib64/libkeymasterutils.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libkeymasterutils.so \
    $(RECOVERY_VENDOR)/lib64/libkeymasterdeviceutils.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libkeymasterdeviceutils.so \
    $(RECOVERY_VENDOR)/lib64/libqcbor.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libqcbor.so \
    $(RECOVERY_VENDOR)/lib64/libdiag.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libdiag.so \
    $(RECOVERY_VENDOR)/lib64/libdrmfs.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libdrmfs.so \
    $(RECOVERY_VENDOR)/etc/init/android.hardware.keymaster@4.0-service-qti.rc:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/init/android.hardware.keymaster@4.0-service-qti.rc \
    $(RECOVERY_VENDOR)/etc/init/android.hardware.gatekeeper@1.0-service-qti.rc:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/init/android.hardware.gatekeeper@1.0-service-qti.rc \
    $(RECOVERY_VENDOR)/etc/init/qseecomd.rc:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/init/qseecomd.rc \
    $(RECOVERY_VENDOR)/etc/vintf/manifest/caymanslm_recovery_crypto_manifest.xml:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/vintf/manifest/caymanslm_recovery_crypto_manifest.xml
