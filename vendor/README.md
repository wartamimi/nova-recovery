# vendor/

Proprietary files (QTI keymaster, gatekeeper, qseecomd, touch firmware) are **never committed**. Phase 3 adds an extract script that copies them from the user's own POCO M3 firmware (official fastboot ROM or a running phone) into `device/xiaomi/citrus/recovery/root/vendor/`. That path is git-ignored.

Blob list to verify against the citrus vendor image: DEVICE_RESEARCH.md §8 and §9.
