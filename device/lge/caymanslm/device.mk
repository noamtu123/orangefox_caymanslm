LOCAL_PATH := device/lge/caymanslm

PRODUCT_USE_DYNAMIC_PARTITIONS := true

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.recovery.caymanslm.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.caymanslm.rc

PRODUCT_PACKAGES += \
    fastbootd
