$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

$(call inherit-product, device/lge/caymanslm/device.mk)

PRODUCT_DEVICE := caymanslm
PRODUCT_NAME := twrp_caymanslm
PRODUCT_BRAND := lge
PRODUCT_MODEL := LM-G910
PRODUCT_MANUFACTURER := LGE

PRODUCT_GMS_CLIENTID_BASE := android-lge
