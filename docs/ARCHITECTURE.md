# Architecture

## How NOVA relates to TWRP

```
~/nova-twrp-src/                 (repo-synced, NOT in this git repo)
├── bootable/recovery/           TeamWin android-12.1  ← recovery engine + GUI engine, unmodified
├── device/qcom/twrp-common/     TeamWin android-12.1  ← Qualcomm FBE decrypt services
├── device/xiaomi/citrus  ──────► symlink to nova-recovery/device/xiaomi/citrus
├── device/xiaomi/citrus-nova ──► symlink to nova-recovery/nova
└── …AOSP 12.1 build system, prebuilts
```

NOVA does **not** fork `bootable/recovery`. The interface is replaced through the supported theme path:

1. `TW_THEME := portrait_hdpi` keeps the upstream common resources (fonts, languages, `portrait.xml` templates).
2. `TW_CUSTOM_THEME` points at NOVA's `ui.xml`. Upstream (`gui/libguitwrp_defaults.go`, `copyCustomTheme`) copies **that single file** into `/twres/`.
3. NOVA images and fonts are installed into `$(TARGET_RECOVERY_ROOT_OUT)/twres/` by the device makefiles, because the custom-theme hook does not copy them.

Every action in a NOVA page calls an existing TWRP GUI action (`flash`, `wipe`, `nandroid`, `adbsideload`, `reboot`, `terminalcommand`, …). There are no NOVA-specific recovery operations and no mock results.

## Device tree (Phase 3)

| File | Source of truth |
|---|---|
| `BoardConfig.mk` | boot params from stock V14.0.2.0 recovery (twrpdtgen); crypto from MIUI 14 vendor fstab |
| `recovery/root/system/etc/twrp.flags` | partitions in DEVICE_RESEARCH §5.1 only (enforced by `tests/partition/check_fstab.sh`) |
| `prebuilt/` | stock kernel, dtb, dtbo; SHA-256-pinned against the official ROM |
| `recovery/root/vendor/` | keymaster/gatekeeper/qseecomd/touch firmware extracted from the user's firmware (not committed; see `vendor/README.md`) |

## External dependencies and licenses

| Component | Upstream | License |
|---|---|---|
| TWRP `bootable/recovery` | github.com/TeamWin/android_bootable_recovery | Apache-2.0 (AOSP parts), GPL-3.0 (TWRP additions) |
| TWRP minimal manifest | github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp | Apache-2.0 |
| `device/qcom/twrp-common` | github.com/TeamWin/android_device_qcom_twrp-common | Apache-2.0 |
| AOSP 12.1 | android.googlesource.com | Apache-2.0 and others |
| Stock kernel (prebuilt) | Xiaomi, source: github.com/MiCode/Xiaomi_Kernel_OpenSource `lime-q-oss` | GPL-2.0 |
| Proprietary vendor blobs | user's own POCO M3 firmware | Xiaomi/Qualcomm proprietary; never redistributed in this repo |
| Fonts | TBD in Phase 4 (must be OFL/Apache) | — |
| NOVA theme, scripts, docs | this repo | Apache-2.0 |

Because the TWRP GUI engine is GPL-3.0, distributed NOVA images are GPL-3.0 combined works. Release notes must link to the source.
