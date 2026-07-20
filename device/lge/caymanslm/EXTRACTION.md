# Stock image analysis

Source device: LG Velvet 4G LM-G910 (`caymanslm`).

## Slot A

- Firmware: G91030a / V30a
- Boot and recovery Android version: 11
- Security patch: 2022-08-01
- Boot header: version 2, 4096-byte pages
- Recovery partition: 104857600 bytes
- Recovery payload before AVB footer: 28729344 bytes
- Kernel: 14388050 bytes, gzip-compressed
- DTB section: 1242145 bytes
- Recovery DTBO section: 817661 bytes
- Ramdisk: gzip-compressed
- Recovery payload SHA-256: `93c095f92f41728c4b59974e787935e31d280c4cb37bf1147d37e6e5469001ed`

Repacking the extracted slot-A kernel, ramdisk, DTB, and recovery DTBO with the
recorded header parameters produces the same payload SHA-256 as stock. The
recovery DTBO is also byte-identical to the meaningful 817661-byte portion of
`dtbo_a.bin`.

## Layout

- A/B boot, DTBO, recovery, and vbmeta partitions
- Dynamic `system`, `product`, and `vendor` partitions
- F2FS userdata with ICE file-based encryption
- ext4 metadata partition
- UFS boot device at `soc/1d84000.ufshc`
- Recovery brightness path at `/sys/class/backlight/panel0-backlight/brightness`

## vbmeta_system

The corrected `vbmeta_system_a.bin` and `vbmeta_system_b.bin` dumps are each
65536 bytes of zeroes. They are valid blank partition reads, not standalone AVB
images. The main `vbmeta_a` and `vbmeta_b` images directly contain descriptors
for the dynamic partitions, so this tree does not use `vbmeta_system`.
