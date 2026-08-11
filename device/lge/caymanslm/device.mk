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
#     which does `find -name "*android.hardware.keymaster*"`, can locate it);
#   - VINTF ROOT manifest -> /vendor/etc/vintf/manifest.xml. Required: libvintf
#     only scans the fragment directory above when the root manifest.xml parses
#     first, and the base ramdisk ships none -- so without it the fragment is
#     dead weight, both HALs stay undeclared, keystore2 negotiates the shared
#     HMAC with zero participants, and gatekeeper cannot mint an auth token
#     (PIN decrypt fails with -24 while no-PIN decrypt works). See the header
#     comment in recovery/root/vendor/etc/vintf/manifest.xml.
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
    $(RECOVERY_ROOT)/vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl-qti.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl-qti.so \
    $(RECOVERY_ROOT)/vendor/lib64/libqtikeymaster4.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libqtikeymaster4.so \
    $(RECOVERY_ROOT)/vendor/lib64/libQSEEComAPI.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libQSEEComAPI.so \
    $(RECOVERY_ROOT)/vendor/lib64/libkeymasterutils.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libkeymasterutils.so \
    $(RECOVERY_ROOT)/vendor/lib64/libkeymasterdeviceutils.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libkeymasterdeviceutils.so \
    $(RECOVERY_ROOT)/vendor/lib64/libqcbor.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libqcbor.so \
    $(RECOVERY_ROOT)/vendor/lib64/libdiag.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libdiag.so \
    $(RECOVERY_ROOT)/vendor/lib64/libdrmfs.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libdrmfs.so \
    $(RECOVERY_ROOT)/vendor/lib64/librpmb.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/librpmb.so \
    $(RECOVERY_ROOT)/vendor/lib64/libssd.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libssd.so \
    $(RECOVERY_ROOT)/vendor/etc/vintf/manifest.xml:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/vintf/manifest.xml \
    $(RECOVERY_ROOT)/vendor/etc/vintf/manifest/android.hardware.keymaster_gatekeeper_caymanslm.xml:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/vintf/manifest/android.hardware.keymaster_gatekeeper_caymanslm.xml

# -------------------------------------------------------------------------
# Boot control HAL implementation — REQUIRED FOR SLOT SWITCHING TO WORK.
#
# The AOSP boot HAL service falls back to the generic libboot_control, which
# stores slot state in the `bootloader_control` struct inside the misc
# partition. LG's bootloader does not read that: like other Qualcomm targets it
# keeps slot priority in the GPT partition attribute bits. The result is a HAL
# that accepts setActiveBootSlot(), returns success, updates misc — and changes
# nothing the bootloader will ever look at. Measured on-device 2026-08-11:
# after `bootctl set-active-boot-slot 0`, misc showed slot A priority 15 vs
# slot B 14, while `fastboot getvar current-slot` still reported b.
# (`fastboot set_active` works because it runs inside the bootloader itself.)
#
# bootctrl.sdm845.so is the Qualcomm implementation that drives the GPT
# attributes. libhardware's hw_get_module("bootctrl") probes
# bootctrl.<ro.hardware>.so then bootctrl.<ro.board.platform>.so, and this
# device reports ro.board.platform=sdm845, so the name resolves.
#
# Installed under /vendor/lib64, matching the keymaster/gatekeeper blobs above.
# hw_get_module probes /vendor/lib64/hw as well as /system/lib64/hw, and the
# boot-hal-1-1 service definition in init.recovery.caymanslm.rc sets
# LD_LIBRARY_PATH=/vendor/lib64:/system/lib64 so the closure resolves.
#
# /system/lib64 is NOT usable for this: system/memory/libion already owns a
# soong install rule for recovery/root/system/lib64/libion.so, so a
# PRODUCT_COPY_FILES entry for that path makes ckati fail with "overriding
# commands for target". Requesting it instead via
# TARGET_RECOVERY_DEVICE_MODULES += libion does not help either — that registers
# an install but never pulls the module into the build graph, so no
# android_recovery_arm64 variant is produced and the file simply never appears.
# Shipping our own copy under /vendor/lib64 avoids the contested path entirely.
#
# ELF closure (verified with readelf, 2026-08-11):
#   bootctrl.sdm845.so         -> librecovery_updater_msm, liblog, libcutils,
#                                 libc++, libc, libm, libdl
#   librecovery_updater_msm.so -> libion, libz, liblog, libcutils, libc++, ...
#   libion.so                  -> liblog, libc++, libc, libm, libdl
# Everything not listed below already ships in the ramdisk.
# See blob-manifest.txt for SHA-256s.
# -------------------------------------------------------------------------
# android.hardware.boot@1.0-impl.so is the piece that ties it together, and the
# base ramdisk does NOT have it. What ships there is
# android.hardware.boot@1.0-impl-1.1.so, which implements 1.1 and is built on
# the generic libboot_control — it reads the fstab to find misc and never calls
# hw_get_module, so bootctrl.sdm845.so would sit unused no matter which service
# runs. HIDL passthrough loads "<interface>-impl.so" by exact name, so with only
# the -impl-1.1 variant present the 1.0 service aborts in a restart loop:
#   LegacySupport: Implementation of android.hardware.boot@1.0::IBootControl/
#     default is actually android.hardware.boot@1.1::IBootControl, not a
#     android.hardware.boot@1.0::IBootControl!
# Stock's impl is the real passthrough shim: it calls hw_get_module("bootctrl")
# and hands off to bootctrl.sdm845.so. Its whole NEEDED set (libhidlbase,
# libhardware, libutils, android.hardware.boot@1.0.so, liblog, libc++, bionic)
# already ships in the ramdisk.
PRODUCT_COPY_FILES += \
    $(RECOVERY_ROOT)/vendor/lib64/hw/bootctrl.sdm845.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/hw/bootctrl.sdm845.so \
    $(RECOVERY_ROOT)/vendor/lib64/hw/android.hardware.boot@1.0-impl.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/hw/android.hardware.boot@1.0-impl.so \
    $(RECOVERY_ROOT)/vendor/lib64/librecovery_updater_msm.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/librecovery_updater_msm.so \
    $(RECOVERY_ROOT)/vendor/lib64/libion.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libion.so
