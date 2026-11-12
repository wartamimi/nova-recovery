# NOVA Recovery: instructions for Claude

NOVA Recovery is a TWRP 3.7.1 (`twrp-12.1`) based recovery for the Xiaomi POCO M3 (`citrus`, SM6115/bengal, arm64, 1080×2340). The interface is a NOVA theme written in TWRP's XML GUI format. The recovery engine is upstream TWRP, unmodified.

Read first: `docs/DEVICE_RESEARCH.md` (facts and their confidence tags) and `docs/ARCHITECTURE.md`.

## Hard rules

- Follow `.claude/rules/recovery-safety.md` at all times. Never flash, erase, format, wipe or reboot a phone. Never put such commands in scripts.
- Never invent partition names, sizes, offsets or mount points. Every value in `device/xiaomi/citrus` must cite a source in DEVICE_RESEARCH.md or a device probe. Values tagged [CONFLICT] or [UNVERIFIED] stay marked in comments until they are resolved.
- citrus is not lime/chime/juice. Related trees are references only.
- Do not fork or rewrite `bootable/recovery` operations (partitions, mount, zip install, image flash, backup/restore, sideload, logging). Use TWRP GUI actions.
- Do not claim a build succeeded without a log containing `#### build completed successfully`. Do not claim touch, decryption or flashing work without a device test.

## Workflow

Phase order: research → skeleton → TWRP integration → design system → UI → functional wiring → build env → testing → release. At the end of each phase report: completed work, files created/modified, errors, unresolved issues, next phase. Then update `docs/CHANGELOG.md`.

## Commands

- Static checks: `tests/build/static_checks.sh`
- Build: `scripts/build.sh` → `scripts/verify.sh` → `scripts/package.sh`
- Device facts (read-only): `tests/device/probe_device.sh adb|fastboot`
