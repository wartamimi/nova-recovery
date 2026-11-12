# Changelog

## Unreleased

### Phase 1: device research (2026-11-12)
- Added `docs/DEVICE_RESEARCH.md`: verified device identity, boot architecture (non-A/B, header v2, 128 MiB recovery), partition map with conflicts flagged, stock kernel 4.19.157 config, FBE v2 + wrapped-key requirements, upstream choice (`twrp-12.1`).
- Saved the stock kernel config from MIUI V14.0.2.0.SJFMIXM to `docs/reference/`.

### Phase 2: project skeleton (2026-11-12)
- Project layout, Claude rules, build scripts (setup/sync/build/verify/package/clean), boot image inspector, static, partition and read-only device-probe tests, documentation stubs.
