# Android build rules

- Upstream: `minimal-manifest-twrp/platform_manifest_twrp_aosp` `twrp-12.1`, pinned in `nova/config/build.env` and `manifest/pinned.xml`. Change pins only on purpose (`scripts/sync.sh --update-pins`) and record why in CHANGELOG.
- Product makefile is `twrp_citrus.mk`; lunch target `twrp_citrus-eng`; build with `mka recoveryimage`.
- Boot image: header v2, page size 4096, offsets from DEVICE_RESEARCH §6. Kernel is the stock prebuilt (`Image.gz`, dtb, dtbo) with SHA-256 pinned in `device/xiaomi/citrus/prebuilt/SHA256SUMS`.
- Proprietary blobs come from the user's own firmware via an extract script. They are never committed and never downloaded from third-party mirrors.
- Every `BoardConfig.mk` value gets a comment citing its source (`# src: DEVICE_RESEARCH §5.1`).
- Keep `ALLOW_MISSING_DEPENDENCIES := true` (minimal manifest).
- Logs go to `out/logs/`. Never trim or rewrite a build log.
