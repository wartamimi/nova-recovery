# Installing NOVA Recovery

> **No NOVA image exists yet.** This page sets out the procedure for when one exists. Every build is **EXPERIMENTAL** until device testing is recorded in `TEST_REPORT.md`.

## Before you start

1. The phone must be a **POCO M3 (`citrus`)**. Check it in Settings → About phone, or with `adb shell getprop ro.product.device` (must print `citrus`). Do not use NOVA on Redmi 9T (`lime`) or other chime devices.
2. The bootloader must be unlocked through Xiaomi's official unlock process. Unlocking wipes the phone.
3. Back up everything you care about to another device. Custom recoveries can fail to decrypt data.
4. Check the image: `sha256sum -c SHA256SUMS`.

## Test first: temporary boot (nothing is written)

```bash
adb reboot bootloader
fastboot boot NOVA-Recovery-citrus.img
```

If the phone boots into NOVA, check that touch, display, USB and decryption work before you install. If `fastboot boot` is not supported on your firmware, stop and report it. Do not flash an untested image.

## Permanent install (manual, your decision)

Only after a successful temporary boot:

```bash
fastboot flash recovery NOVA-Recovery-citrus.img
fastboot reboot recovery     # or hold Vol+ and Power
```

Stock MIUI may replace a custom recovery on its next boot. Boot straight into recovery after flashing.

## Going back to stock

Flash the `recovery.img` from the official fastboot ROM that matches your installed MIUI version.
