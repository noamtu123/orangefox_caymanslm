# OrangeFox for LG Velvet 4G

Initial OrangeFox recovery bring-up for the LG Velvet 4G LM-G910EMW,
codename `caymanslm`.

The device tree is under `device/lge/caymanslm`. It uses stock G91030a slot-A
kernel, DTB, and recovery DTBO prebuilts extracted over EDL.

## GitHub Actions build

Run the **Build OrangeFox** workflow manually. Device-tree pushes do not start
expensive builds automatically. A successful run uploads:

- `recovery-caymanslm.img`
- SHA-256 checksum
- parsed boot-header details
- parsed AVB footer details
- OrangeFox installer ZIP when generated

The workflow uses the official public OrangeFox sync helper with the
`fox_12.1` branch. The first image is experimental and must not be written to
both recovery slots.

See `device/lge/caymanslm/README.md` for the testing policy and
`device/lge/caymanslm/EXTRACTION.md` for stock-image analysis.
