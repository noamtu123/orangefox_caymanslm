# OrangeFox / TWRP product for caymanslm (LG Velvet 4G, LM-G910EMW).

# Inherit AOSP + OrangeFox recovery base
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

# Device
$(call inherit-product, device/lge/caymanslm/device.mk)

PRODUCT_DEVICE := caymanslm
PRODUCT_NAME := twrp_caymanslm
PRODUCT_BRAND := lge
PRODUCT_MODEL := LM-G910EMW
PRODUCT_MANUFACTURER := LGE

PRODUCT_GMS_CLIENTID_BASE := android-lge
