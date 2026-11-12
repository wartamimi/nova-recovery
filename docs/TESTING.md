# Testing

Tests run in five stages. A stage may only start when the one before it has passed. Results go in `docs/TEST_REPORT.md`.

| Stage | What | How | Touches phone? |
|---|---|---|---|
| 1 Static | shell lint, XML, fstab vs partition map, no flash commands in scripts | `tests/build/static_checks.sh` | No |
| 2 Build | clean build, success marker in log, warnings reviewed | `scripts/clean.sh --installclean && scripts/build.sh` | No |
| 3 Image | header v2, ≤128 MiB, arm64 kernel, DTB, ramdisk has TWRP + NOVA files | `scripts/verify.sh` | No |
| 4 Device | identity, bootloader state, firmware, temporary boot, display, touch, USB/MTP, ADB, internal storage, microSD, reboot | `tests/device/probe_device.sh` (read-only) + manual checklist below | Read-only + `fastboot boot` only |
| 5 Functions | each recovery function separately, using disposable data and a verified backup | manual checklist | Yes, only with the owner's explicit go-ahead per step |

## Stage 4 checklist

- [ ] `probe_device.sh adb`: `ro.product.device=citrus`, firmware noted
- [ ] `probe_device.sh fastboot`: `unlocked: yes`, recovery partition size = 134217728
- [ ] `fastboot boot` reaches the NOVA boot screen
- [ ] Colours correct (pixel format), nothing cut off by the notch
- [ ] Touch responds across the whole screen
- [ ] `adb devices` shows `recovery`; MTP visible on PC
- [ ] /data decrypts with the lock-screen PIN (disposable test data)
- [ ] microSD detected and mounted
- [ ] Reboot → System works

## Stage 5 rules

- Never test wipe, format, restore or flash on the user's only copy of data.
- Take a full NOVA backup **and** copy it off the phone before any destructive test.
- Never touch `persist`, `modemst1/2`, `fsc`, `fsg`.
