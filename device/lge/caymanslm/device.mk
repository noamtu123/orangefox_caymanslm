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
# Sourced from the user's own vendor_a dump, ELF-closure-verified.
#
# Placement follows the device/qcom/twrp-common contract (enabled via
# BOARD_USES_QCOM_FBE_DECRYPTION in BoardConfig.mk):
#   - service binaries -> recovery ramdisk /system/bin  (twrp-common's
#     init.recovery.qcom_decrypt(.fbe).rc service defs exec from there on
#     Android-10+, and its build-time service_cleanup.bash inspects
#     recovery/root/system/bin);
#   - ELF closure -> recovery ramdisk /vendor/lib64  (reached at runtime via
#     each service's LD_LIBRARY_PATH=/vendor/lib64:...);
#   - VINTF fragment -> /vendor/etc/vintf/manifest (its filename contains
#     "android.hardware.keymaster" so OrangeFox's ramdisk-manifest fallback,
#     which does `find -name "*android.hardware.keymaster*"`, can locate it).
#
# We do NOT bundle the per-service .rc files: twrp-common supplies the
# correctly-sequenced service definitions (qseecomd on the crypto.ready/
# listeners chain, keymaster/gatekeeper gated on listeners-registered).
#
# librpmb.so + libssd.so are qseecomd RUNTIME dlopen() plugins, NOT part of any
# binary's ELF DT_NEEDED closure — so the static closure verification that
# selected the other blobs silently missed them. Proven on-device (2026-07-22):
# without librpmb.so, qseecomd's RPMB_INIT fails ("Init dlopen(librpmb.so)
# failed ... shall not start listener services") -> qseecomd exits ->
# vendor.sys.listeners.registered never becomes true -> keymaster@4.0 never
# starts -> keystore2 aborts (HARDWARE_TYPE_UNAVAILABLE / "Cannot connect to
# Keymint") -> FBE decrypt cannot run. Copying just these two into the ramdisk
# and restarting qseecomd brought the whole chain up + "Successfully registered
# Keystore 2.0 service". These are the minimal proven pair; libssd (secure
# storage daemon) pairs with rpmb for the trustlet's replay-protected storage.
# Other qseecomd dlopen plugins (libsecureui/libdrmtime/libGPreqcancel/libops)
# stay absent on purpose — qseecomd logs them as optional and keeps running.
#
# Copying ELF prebuilts via PRODUCT_COPY_FILES requires the BUILD_BROKEN flag
# set in BoardConfig.mk (BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES) — the same
# mechanism LineageOS/TheMuppets use for vendor blobs.
# See blob-manifest.txt for SHA-256 of each file.
# -------------------------------------------------------------------------
RECOVERY_ROOT := $(LOCAL_PATH)/recovery/root

PRODUCT_COPY_FILES += \
    $(RECOVERY_ROOT)/system/bin/qseecomd:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/qseecomd \
    $(RECOVERY_ROOT)/system/bin/android.hardware.keymaster@4.0-service-qti:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/android.hardware.keymaster@4.0-service-qti \
    $(RECOVERY_ROOT)/system/bin/android.hardware.gatekeeper@1.0-service-qti:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/android.hardware.gatekeeper@1.0-service-qti \
    $(RECOVERY_ROOT)/vendor/lib64/vendor.qti.hardware.qseecom@1.0.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/vendor.qti.hardware.qseecom@1.0.so \
    $(RECOVERY_ROOT)/vendor/lib64/libqtikeymaster4.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libqtikeymaster4.so \
    $(RECOVERY_ROOT)/vendor/lib64/libQSEEComAPI.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libQSEEComAPI.so \
    $(RECOVERY_ROOT)/vendor/lib64/libkeymasterutils.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libkeymasterutils.so \
    $(RECOVERY_ROOT)/vendor/lib64/libkeymasterdeviceutils.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libkeymasterdeviceutils.so \
    $(RECOVERY_ROOT)/vendor/lib64/libqcbor.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libqcbor.so \
    $(RECOVERY_ROOT)/vendor/lib64/libdiag.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libdiag.so \
    $(RECOVERY_ROOT)/vendor/lib64/libdrmfs.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libdrmfs.so \
    $(RECOVERY_ROOT)/vendor/lib64/librpmb.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/librpmb.so \
    $(RECOVERY_ROOT)/vendor/lib64/libssd.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libssd.so \
    $(RECOVERY_ROOT)/vendor/etc/vintf/manifest/android.hardware.keymaster_gatekeeper_caymanslm.xml:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/vintf/manifest/android.hardware.keymaster_gatekeeper_caymanslm.xml
