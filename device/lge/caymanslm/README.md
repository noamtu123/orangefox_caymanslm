# OrangeFox device tree for LG Velvet 4G

This is an initial recovery bring-up tree for the LG Velvet 4G LM-G910,
codename `caymanslm`. It is based on EDL dumps from stock firmware G91030a
(V30a, August 2022).

The first build deliberately uses the stock slot-A kernel, DTB, and recovery
DTBO. This limits the initial test to the recovery userspace and preserves the
known-good display, touch, UFS, and USB kernel drivers.

## Build

Place this directory at `device/lge/caymanslm` in an OrangeFox 12.1 source
checkout, then run:

```sh
source build/envsetup.sh
lunch twrp_caymanslm-eng
mka recoveryimage
```

The expected output is `out/target/product/caymanslm/recovery.img` and must not
exceed 104857600 bytes.

## First-boot policy

This tree is untested hardware bring-up code. Keep an EDL restore path and the
original recovery images available. Do not overwrite both recovery slots with
an untested build. Verify the generated boot header, image size, DTB, recovery
DTBO, and AVB footer before any device test.

Initial validation order:

1. Recovery boots and remains responsive.
2. Display orientation, touch coordinates, brightness, and ADB work.
3. Active slot and block-device symlinks are correct.
4. `metadata`, dynamic `system`, `product`, and `vendor` mount read-only.
5. F2FS `data` mounts; test decryption only after collecting recovery logs.
6. Reboot to system, bootloader, recovery, and EDL all work.

The extracted `vbmeta_system_b.bin` is not valid vbmeta: it is a 32 MiB ext4
image. It is not used by this tree.
