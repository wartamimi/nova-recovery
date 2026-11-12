# NOVA Recovery — Device Research: Xiaomi POCO M3 (`citrus`)

Phase 1 deliverable. Research date: 2026-11-12.

Every fact below is tagged with how confident we are in it:

| Tag | Meaning |
|---|---|
| **[VERIFIED-SRC]** | Read directly from source code, a stock kernel binary, or a stock-derived file, with the commit pinned below. |
| **[CROSS-CHECKED]** | Two or more independent trees agree. |
| **[CONFLICT]** | Sources disagree. Must be resolved on a real device before use. |
| **[UNVERIFIED]** | Plausible, but has no primary source yet. Must not be used in a build without checking. |

Nothing here has been checked against a physical POCO M3 yet. That happens in Phase 3 with the read-only probe script `tests/device/probe_device.sh`.

---

## 1. Summary of findings

1. **No official TWRP exists for citrus.** twrp.me has no citrus page. Every public citrus recovery tree is unofficial, and all of them date from the Android 10 / MIUI 12 era (Dec 2020 to Apr 2021).
2. **The 2021 trees will not decrypt current firmware.** They are set up for FBE v1 with legacy ICE (`fileencryption=ice:aes-256-cts`). The final MIUI 14 (Android 12) stock kernel has `CONFIG_FS_ENCRYPTION_INLINE_CRYPT=y`, `CONFIG_BLK_INLINE_ENCRYPTION=y`, and legacy PFK disabled. The current ROM fstab uses FBE v2 (`aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized`) with hardware-wrapped keys and metadata encryption. NOVA must target FBE v2 decryption. We cannot reuse the old crypto config.
3. **Recovery boot architecture is the classic non-A/B layout** [CROSS-CHECKED]. There is a dedicated 128 MiB `recovery` partition, boot image header **v2**, a separate `dtbo` partition, and the DTB is appended to the boot image. Recovery is not part of boot (no `BOARD_USES_RECOVERY_AS_BOOT`, no `vendor_boot`). Dynamic partitions (`super`) are used, so TWRP needs fastbootd support.
4. **citrus and lime share a kernel and almost all of the platform.** The official Xiaomi kernel branch `lime-q-oss` ships both `citrus-perf_defconfig` and `lime-perf_defconfig`, and they differ by a single line (`CONFIG_CPU_FREQ_STAT`). Modern ROMs build both from one unified `chime` tree. But the **super partition size and group name disagree across sources** (see §5), so citrus partition config must not be copied from lime/chime/juice without checking.
5. **Recommended upstream:** `minimal-manifest-twrp/platform_manifest_twrp_aosp`, branch **`twrp-12.1`** (TWRP **3.7.1_12**), plus `device/qcom/twrp-common` for Qualcomm FBE decryption. This is the conventional base for a 4.19-kernel, header-v2, Android-12-final Qualcomm device. `twrp-14.1` (3.7.1_14) is the fallback if 12.1 decryption fails.
6. **Custom-theme mechanism found in upstream** [VERIFIED-SRC]. `TW_CUSTOM_THEME` copies **only one XML file** into `/twres/`, and the common `portrait.xml` is still included. So NOVA's images and fonts must be installed into `$(TARGET_RECOVERY_ROOT_OUT)/twres/` by the device makefiles. This shapes the Phase 4 design.

---

## 2. Device identity

| Property | Value | Source / tag |
|---|---|---|
| Marketing name | POCO M3 | [CROSS-CHECKED] |
| Codename | `citrus` | [CROSS-CHECKED] |
| Unified family | `chime` (citrus + lime/lemon/pomelo); older name `juice` | `libinit/init_chime.cpp`, OTA asserts `citrus,chime,juice` [VERIFIED-SRC] |
| Global model | `M2010J19CG` | twrpdtgen tree from stock firmware [VERIFIED-SRC] |
| India model | `M2010J19CI` | [UNVERIFIED] |
| Variant detection | `ro.boot.product.hardware.sku` = `citrus` | `libinit_variant.cpp` [VERIFIED-SRC] |
| SoC | Qualcomm SM6115 Snapdragon 662, platform name `bengal` | `TARGET_BOARD_PLATFORM := bengal` [CROSS-CHECKED] |
| CPU | 4× Kryo 260 Gold 2.0 GHz + 4× Kryo 260 Silver 1.8 GHz (`cortex-a73` variant used in trees) | [CROSS-CHECKED] |
| GPU | Adreno 610 | [CROSS-CHECKED] |
| Arch | arm64 primary, arm (armv7/armv8) secondary | [CROSS-CHECKED] |
| Display | 1080 × 2340, density 440 | `TARGET_SCREEN_DENSITY := 440` [CROSS-CHECKED] |
| Backlight node | `/sys/class/backlight/panel0-backlight/brightness`, max 2047 | three 2021 trees agree; stock `init.recovery.qcom.rc` writes it [CROSS-CHECKED] |
| RAM | 4 GB / 6 GB | spec sheet [UNVERIFIED on device] |
| Internal storage | UFS (`4804000.ufshc`), 64 GB / 128 GB | ROM fstab `sysfs_path` [VERIFIED-SRC]; UFS revision [UNVERIFIED] |
| microSD | Dedicated slot, SDHCI controller `4784000.sdhci` | ROM fstab [VERIFIED-SRC] |
| Battery | 6000 mAh | spec sheet |
| Launch firmware | Android 10, MIUI 12 (`PRODUCT_SHIPPING_API_LEVEL := 29`) | [VERIFIED-SRC] |
| Final official firmware | Android 12, MIUI 14 **V14.0.2.0.SJFMIXM** (global) | fingerprint `POCO/citrus_global/citrus:12/RKQ1.211130.001/V14.0.2.0.SJFMIXM:user/release-keys` [VERIFIED-SRC] |

**What must be confirmed on the user's own phone** (before Phase 3 config is final): the exact model number, region (global / EEA / India / Taiwan), installed firmware version, and whether a custom ROM is installed. Encryption behaviour depends on these.

---

## 3. Source repositories inspected

All clones were shallow and read-only. Pinned commits:

### 3.1 TWRP upstream

| Repo | Branch | Commit | Notes |
|---|---|---|---|
| `minimal-manifest-twrp/platform_manifest_twrp_aosp` | `twrp-12.1` | `6dc117d9cbd08430daa16db2013560e1c4017fa8` | **Recommended** manifest |
| ″ | `twrp-14.1` | `cb31ddec08f495d3f70631b22140642d0045ba0d` | Fallback |
| `TeamWin/android_bootable_recovery` | `android-12.1` | `5c3d206a5eeb3d446bcda8248a405a4b278bab5c` (2025-09-02) | `TW_MAIN_VERSION_STR "3.7.1_12"` |
| ″ | `android-14.1` | `426b747737e7ce9e9e17da5b4d2ba883f296aec7` (2025-09-08) | `"3.7.1_14"` |
| `TeamWin/android_device_qcom_twrp-common` | `android-12.1` | `98506f7919102378c8d52ee7d6a94a867f1b4c55` | Qualcomm FBE decrypt helpers (same commit on 12.1/14/14.1) |

Upstream TWRP has branches `twrp-11`, `twrp-12.1`, `twrp-14`, `twrp-14.1` for the AOSP minimal manifest. The Omni manifest is legacy (≤ `twrp-10.0-deprecated`) and is **not** suitable.

### 3.2 citrus / chime device trees

| Repo | Branch | Commit | Era | Value to NOVA |
|---|---|---|---|---|
| `twrpdtgen/android_device_xiaomi_citrus` | `citrus_global-user-12-RKQ1.211130.001-V14.0.2.0.SJFMIXM-release-keys` | `fe3da6511c2d…` (2026-02-06) | MIUI 14 / A12 | **Highest.** Auto-generated from the **stock** recovery image by SebaUbuntu's twrpdtgen. Gives the real cmdline, header version, offsets, stock prebuilt kernel/dtb/dtbo, stock recovery rc files. The "TODO: Fix hardcoded value" entries (super sizes) are generator guesses. |
| `darkpewds6969/twrp_poco_citrus` | `android-10.0` | `a19ea9b7417b…` (2021-02-14) | MIUI 12 / A10 | Reference TWRP tree: brightness, touch firmware, keymaster/qseecomd blob list. Its crypto config is outdated. |
| `Caca0/android_device_poco_citrus-TWRP` | `android-10.0` | `17fedddea126…` (2021-01-27) | A10 | Most complete `twrp.flags` (EFS, modem, persist, AVB partitions) |
| `PitchBlackRecoveryDevices/android_device_xiaomi_citrus-pbrp` | `android-10.0` | `a503f3d105de…` (2020-12-16) | A10 | Alternate recovery fstab |
| `geoanto555/android_device_poco-xiaomi_citrus` | `android-10` | `1d67c5b131e7…` | A10 | Omni-based, legacy |
| `mastersenpai05/twrp_device_xiaomi_juice` | `android-10.0` | `939665c380bf…` | A10 | Unified juice reference only |
| `PixelExperience-Devices/device_xiaomi_chime` | `thirteen` | `27f63602d791…` (2024-02-09) | A13 ROM | **Current ROM fstab** (built against MIUI 14 vendor), partition sizes, libinit variant logic, list of recovery touch-firmware blobs |
| `chimeOSS/device_xiaomi_citrus` | `thirteen` | `32f85915132d…` | A13 ROM | citrus is a thin wrapper around `device_xiaomi_chime` |
| `xiaomi-sm6115/device_xiaomi_citrus` | `13` | `ac5801f85ff4…` | A13 ROM | Prebuilt-kernel ROM tree |
| `kidzz1965/device-xiaomi-citrus` | `trixie` | `be8953e1b3ad…` | postmarketOS-style | Not relevant to recovery |

Also found, not cloned: `Night-Raids-Reborn/device_xiaomi_citrus`, `PixelOS-Devices-old/device_xiaomi_citrus`, `IDN-Labs/device_xiaomi_citrus`, `Joe7500/device_xiaomi_chime` (branches up to `lineage-24.0`, so actively maintained).

### 3.3 Kernel source

| Repo | Branch | Commit | Kernel | Notes |
|---|---|---|---|---|
| `MiCode/Xiaomi_Kernel_OpenSource` | `lime-q-oss` | `02ca1a919564…` (2020-12-18) | 4.19.95 | **Official Xiaomi release.** Has `vendor/citrus-perf_defconfig`. Android 10 era. |
| `PixelExperience-Devices/kernel_xiaomi_chime` | `thirteen` | `344cfe53fc0c…` (2023-10-27) | 4.19.225 | Community, CAF-merged, `bengal_defconfig` + `chime.config` fragments |
| `Joe7500/kernel_xiaomi_chime` | `main` | `b5a4fbb7d3b1…` (2025-07-10) | 4.19.191 | Community; has `citrus-stock-perf_defconfig` |

Xiaomi has not published an `-r-oss` or `-s-oss` branch for citrus/lime, so the official source lags the final firmware (4.19.95 vs stock 4.19.157).

---

## 4. Kernel information

### 4.1 Stock kernel (from MIUI V14.0.2.0.SJFMIXM recovery, via twrpdtgen prebuilt)

```
Linux version 4.19.157-perf-g1a6087bc0325-dirty (builder@non-pangu-pod-hmglr)
(clang version 10.0.7 for Android NDK, GNU ld 2.27.0.20170315)
#1 SMP PREEMPT Thu Mar 30 21:59:49 CST 2023
```

- Format: `Image.gz` (gzip). The decompressed image is 34,730,496 bytes. [VERIFIED-SRC]
- `CONFIG_IKCONFIG` is embedded. The full extracted config is saved at `docs/reference/stock-kernel-config_V14.0.2.0.SJFMIXM.txt`.
- DTB: FDT v17, packed as a multi-DTB `dtb.img` (4.4 MB). `dtbo.img` is 4.9 MB, which fits the 16 MiB `dtbo` partition.

### 4.2 Recovery-relevant kernel config (stock, verified from IKCONFIG)

| Area | Config | Meaning for NOVA |
|---|---|---|
| Touch | `TOUCHSCREEN_NT36672A=y`, `TOUCHSCREEN_FT8719=y`, `SYNAPTICS_TCM=y`, `SYNAPTICS_DSX=y` | Touch drivers are **built in**, so no modules need loading. Kernel strings show panel combos: Tianma NT36672, Truly NT36672A/D, Huaxing and CSOT FT8719. |
| Touch firmware | requests `novatek_ts_fw.bin`, `novatek_ts_mp.bin`, `focaltech_ts_fw*.bin` | Firmware must be in `/vendor/firmware` inside the recovery ramdisk, or touch may fail on some panels. |
| Storage | `SCSI_UFS_QCOM=y`, `SCSI_UFS_QCOM_ICE=y`, `MMC_SDHCI_MSM=y` | UFS internal; SDHCI for microSD |
| Encryption | `FS_ENCRYPTION=y`, `FS_ENCRYPTION_INLINE_CRYPT=y`, `BLK_INLINE_ENCRYPTION=y`, `DM_DEFAULT_KEY=y`, `QTI_HW_KEY_MANAGER=y`, `# CONFIG_ENABLE_LEGACY_PFK is not set` | **FBE v2 + inline crypto + hardware-wrapped keys + metadata encryption via dm-default-key** |
| Filesystems | `F2FS_FS=y`, `EXFAT_FS=y`, `NTFS_FS=y` (+RW), `VFAT`, `SDCARD_FS=y` | microSD can be exFAT, FAT32 or NTFS |
| USB | `USB_CONFIGFS=y`, `USB_CONFIGFS_F_FS=y`, MTP/PTP functions | ADB and MTP via configfs (`sys.usb.configfs 1`, per stock rc) |
| Debug | `PSTORE_RAM=y`, `PSTORE_LAST_KMSG=y`, `PSTORE_PMSG=y` | `/sys/fs/pstore` gives post-crash logs, which is useful for boot debugging |

### 4.3 Kernel strategy

Use the **stock prebuilt kernel + dtb + dtbo** from the firmware the user actually runs. This is standard practice for TWRP and avoids the gap between the 4.19.95 official source and the 4.19.157 stock kernel. Before use, NOVA will:

1. take the stock `recovery.img` from the **official** fastboot ROM for the user's region and version,
2. unpack it with `unpack_bootimg` and compare its kernel/dtb SHA-256 with the twrpdtgen copy,
3. pin the hashes in `device/xiaomi/citrus/prebuilt/SHA256SUMS`.

Building from source is a later option (MiCode `lime-q-oss` + `citrus-perf_defconfig`), not the baseline.

---

## 5. Partition map

### 5.1 Physical partitions (by-name), cross-referenced

| Mount / name | Type | Block device | Size (bytes) | Tag | Notes |
|---|---|---|---|---|---|
| boot | emmc | `/dev/block/bootdevice/by-name/boot` | 134,217,728 (128 MiB) | [CROSS-CHECKED] | header v2 |
| recovery | emmc | `…/by-name/recovery` | 134,217,728 (128 MiB) | [CROSS-CHECKED] | **NOVA target** |
| dtbo | emmc | `…/by-name/dtbo` | 16,777,216 (16 MiB) | [VERIFIED-SRC] PE | |
| vbmeta | emmc | `…/by-name/vbmeta` | ? | [UNVERIFIED size] | |
| vbmeta_system | emmc | `…/by-name/vbmeta_system` | ? | [UNVERIFIED size] | present in Caca0 tree |
| super | — | `…/by-name/super` | **8,589,934,592** (PE) **vs 9,126,805,504** (twrpdtgen) | **[CONFLICT]** | See 5.2 |
| cache | ext4 | `…/by-name/cache` | 402,653,184 (384 MiB) | [VERIFIED-SRC] PE | |
| metadata | ext4 | `/dev/block/by-name/metadata` | ? | [CROSS-CHECKED path] | needed for metadata decryption |
| userdata | f2fs | `…/by-name/userdata` | depends on storage size | [CROSS-CHECKED] | |
| persist | ext4 | `…/by-name/persist` | ? | [CROSS-CHECKED] | **Never format.** Holds sensor/calibration data. |
| misc | emmc | `…/by-name/misc` | ? | [CROSS-CHECKED] | BCB / reboot commands |
| cust | ext4 | `…/by-name/cust` | ? | [CROSS-CHECKED] | Xiaomi-specific |
| modem | vfat/emmc | `…/by-name/modem` | ? | [CROSS-CHECKED] | mounted as `/vendor/firmware_mnt`; needed for decrypt on some setups |
| bluetooth, dsp | emmc | `…/by-name/bluetooth`, `…/dsp` | ? | [CROSS-CHECKED] | |
| modemst1, modemst2, fsc, fsg | emmc | `…/by-name/…` | ? | [CROSS-CHECKED] | **EFS / IMEI. Back up, never wipe.** |

Slot suffixes: **none** (non-A/B). No tree defines `AB_OTA_UPDATER`. [CROSS-CHECKED]

### 5.2 Dynamic partitions (super) — CONFLICT

| Source | Super size | Group | Group size | Logical partitions |
|---|---|---|---|---|
| darkpewds 2021 TWRP (A10) | 8,589,934,592 | `qti_dynamic_partitions` | 8,589,934,592 | system, vendor, product |
| PE chime (A13 ROM, MIUI 14 vendor) | 8,589,934,592 | `qti_dynamic_partitions` | 8,589,934,592 | system, system_ext, vendor, product |
| twrpdtgen (MIUI 14 stock recovery) | 9,126,805,504 | `xiaomi_dynamic_partitions` | 9,122,611,200 | system, system_ext, vendor, product |

For a **recovery** build these values only matter in metadata. TWRP reads the live super metadata through `liblp`, so it does not need the exact size to mount logical partitions. NOVA's tree will still record the real value. **Resolve with `lpdump` or `/sys/class/block/<super>/size × 512` on the user's device.** Until then, `BOARD_SUPER_PARTITION_SIZE` is marked unverified in the tree.

Logical partitions on MIUI 12.5+ / custom ROMs: `system`, `system_ext`, `vendor`, `product` [CROSS-CHECKED, A12/A13]. MIUI 12 A10 had no `system_ext`. On some MIUI builds an `odm` partition may exist inside super [UNVERIFIED].

### 5.3 Removable storage — CONFLICT

| Source | microSD node |
|---|---|
| Caca0, PBRP (2021) | `/dev/block/mmcblk0p1` (fallback `/dev/block/mmcblk0`) |
| twrpdtgen (generated) | `/dev/block/mmcblk1p1` |
| PE ROM fstab | sysfs `/devices/platform/soc/4784000.sdhci/mmc_host*` (voldmanaged) |

Internal storage is UFS (`sdX`), so the SD card is most likely the **only** MMC device, which means `mmcblk0`. The twrpdtgen value looks like the generator's generic default. **Check with `/proc/partitions` with a card inserted.** USB-OTG appears as `/dev/block/sdg1` in the 2021 trees because UFS LUNs take `sda` to `sdf`. That is plausible but [UNVERIFIED].

### 5.4 fstab for current firmware (from PE `fstab.qcom`, built on MIUI 14 vendor)

```
/dev/block/by-name/metadata  /metadata  ext4  … wait,formattable,check,…,wrappedkey,first_stage_mount
/dev/block/bootdevice/by-name/userdata  /data  f2fs  …,inlinecrypt
    latemount,wait,check,formattable,
    fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized,
    keydirectory=/metadata/vold/metadata_encryption,quota,reservedsize=128M,
    sysfs_path=/sys/devices/platform/soc/4804000.ufshc,checkpoint=fs
```

Compare the 2021 TWRP trees: `fileencryption=ice:aes-256-cts` plus `wrappedkey`. That is FBE v1, which only fits MIUI 12 / Android 10 data.

---

## 6. Recovery boot architecture

| Item | Value | Tag |
|---|---|---|
| A/B | No | [CROSS-CHECKED] |
| Recovery partition | Yes, dedicated, 128 MiB | [CROSS-CHECKED] |
| Recovery-as-boot / vendor_boot | No / No | [CROSS-CHECKED] |
| Boot header version | **2** (DTB inside the image) | [CROSS-CHECKED: stock dtgen + PE + 2021 trees] |
| Page size | 4096 | [CROSS-CHECKED] |
| Base / kernel / ramdisk / second / tags / dtb offsets | `0x0` / `0x8000` / `0x01000000` / `0xf00000` / `0x100` / `0x01f00000` | [CROSS-CHECKED] |
| Recovery DTBO | included (`BOARD_INCLUDE_RECOVERY_DTBO := true`) | [CROSS-CHECKED] |
| Kernel image name | `Image.gz` | [VERIFIED-SRC] |
| Kernel cmdline (stock) | `console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0x4a90000 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 loop.max_part=7 androidboot.fstab_suffix=default buildvariant=user` | [VERIFIED-SRC] |
| AVB | enabled; recovery signed with test key in TWRP trees (SHA256_RSA4096 from dtgen) | [VERIFIED-SRC] |
| Anti-rollback hack | `PLATFORM_SECURITY_PATCH := 2099-12-31` used by all trees so keymaster accepts the recovery | [CROSS-CHECKED] |
| Pixel format | `RGBX_8888` (TWRP trees) vs `BGRA_8888` (PE ROM) | **[CONFLICT]**. RGBX_8888 is what the working TWRP builds used; test colours on device. |
| Display offsets | `TW_Y_OFFSET := 80`, `TW_H_OFFSET := -80` in darkpewds tree (teardrop notch) | [UNVERIFIED] |
| fastbootd | Required (dynamic partitions). 2021 tree used `android.hardware.fastboot@1.0-impl-mock` + `fastbootd`. | [VERIFIED-SRC] |

**Bootloader note:** Xiaomi's Qualcomm bootloader honours `fastboot boot recovery.img` on many devices, but this is [UNVERIFIED] for citrus on MIUI 14 firmware. Temporary boot is the first thing to test in Stage 4, before any `fastboot flash recovery`.

**MIUI restore-on-boot:** stock MIUI replaces a custom recovery on first boot unless it is prevented. This is a standard Xiaomi behaviour [UNVERIFIED for citrus specifically]. INSTALL.md will cover this.

---

## 7. Encryption and decryption compatibility

| Firmware | FBE | Keys | Recovery needs |
|---|---|---|---|
| MIUI 12 (A10) | v1, `ice:aes-256-cts` | wrapped, metadata enc. | legacy ICE: the 2021 trees cover this |
| MIUI 12.5 (A11) | v2 likely | wrapped | [UNVERIFIED] |
| MIUI 13/14 (A12) | **v2**, `aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized` | **hardware-wrapped**, metadata enc. via dm-default-key | QTI keymaster 4.x + gatekeeper + `qseecomd` from the matching vendor, `device/qcom/twrp-common` decrypt services, `TW_INCLUDE_CRYPTO`, `TW_INCLUDE_FBE_METADATA_DECRYPT`, `BOARD_USES_QCOM_FBE_DECRYPTION`, `TW_USE_FSCRYPT_POLICY := 2` |
| AOSP A13+ ROMs on MIUI 14 vendor | v2 (same as MIUI 14 vendor fstab) | wrapped | same as above |

Vendor manifest (PE chime): `android.hardware.keymaster@4.0::IKeymasterDevice/default` and `@4.1` vendor libs, `android.hardware.gatekeeper@1.0`. [VERIFIED-SRC]

Known problem: XDA's coverage of the first citrus TWRP (3.5.0, Dec 2020) reported that "data decryption doesn't seem to work upon the second reboot". Decryption is the highest-risk feature. **NOVA must not claim decryption works until it has been tested on the user's device with disposable data.**

Upstream support check: `bootable/recovery` `android-12.1` `partition.cpp` parses `fileencryption=`, `keydirectory=`, `wrappedkey`, and `metadata_encryption=…:wrappedkey_v0` [VERIFIED-SRC].

---

## 8. Touchscreen, USB, display, storage support

- **Touch:** drivers are built into the kernel. Firmware blobs required in `recovery/root/vendor/firmware/`. The list comes from PE `proprietary-files-recovery.txt` (taken from **lime** MIUI V14.0.5.0, so check it against citrus vendor):
  `focaltech_ts_fw.bin`, `focaltech_ts_fw_TRULY.bin`, `nt33672a_{tianma,truly}_novatek_ts_{fw,mp}.bin`, `nt33672d_{tianma,xinli}_novatek_ts_{fw,mp}.bin`, plus `aw87359_*`/`aw87519_*` (amplifier, not touch).
  The 2021 citrus TWRP shipped `novatek_ts_fw.bin`, `novatek_ts_mp.bin`, `focaltech_ts_fw.bin` (MIUI 12 names). Which panel the user has decides which blob matters, so find it from `dmesg` / `/proc/tp_info`-style nodes [UNVERIFIED path].
  Note: PE's list has a typo (`recovery/root/endor/firmware/…`) for one Tianma blob, which shows these lists need care.
  `TW_INPUT_BLACKLIST := "hbtp_vm"` is used by all trees.
- **USB:** configfs. Stock rc sets `sys.usb.configfs 1` and the UDC from `ro.boot.usbcontroller`. 2021 trees use `TW_EXCLUDE_DEFAULT_USB_INIT := true` with their own `init.recovery.usb.rc`.
- **Brightness:** `/sys/class/backlight/panel0-backlight/brightness`, max 2047, default 1200.
- **microSD:** see §5.3. exFAT/NTFS supported by kernel; `TW_INCLUDE_NTFS_3G` optional.
- **Internal storage:** `RECOVERY_SDCARD_ON_DATA := true` (`/data/media/0`), so internal storage only shows once `/data` is decrypted.

---

## 9. Android version and firmware dependencies

| Dependency | Source | Status |
|---|---|---|
| Stock kernel/dtb/dtbo | user's firmware recovery.img | must match the installed firmware generation |
| QTI keymaster/gatekeeper/qseecomd blobs | `vendor` image of the user's firmware | must match. Mixing A10 blobs with A12 vendor breaks decryption. |
| Touch firmware | `vendor/firmware` | panel dependent |
| VINTF manifest fragments | vendor | needed so the recovery's hwservicemanager can register keymaster |

Practical rule: **NOVA builds target MIUI 14 (V14.0.2.0) vendor and AOSP ROMs built on it.** MIUI 12/A10 support is out of scope unless the user's phone is still on it.

---

## 10. Related devices (reference only, not copied)

| Device | Codename | Relationship | Safe to reuse |
|---|---|---|---|
| Redmi 9T | lime | same kernel source, same defconfig (one-line diff), same chime tree | kernel config, touch drivers, rc scripts **after review** |
| Redmi 9 Power / Note 9 4G | lemon / pomelo | variants in chime | as above |
| Redmi 9T (old unified) | juice | pre-chime unified tree | historical only |

The brief warns against assuming Redmi 9T and POCO M3 partition layouts are identical. Super group naming already differs between sources (§5.2), and the PE recovery blob list is from lime firmware. Every partition-level value in NOVA's citrus tree will cite a citrus source or a device probe.

---

## 11. Known compatibility problems

1. **FBE v2 + wrapped keys decryption** is the main risk (see §7).
2. **Decryption failing after a second reboot** was reported on early citrus TWRP.
3. **Stale community trees:** every TWRP-specific citrus tree is from 2020–21 and targets twrp-10.0 / Omni. None build on twrp-12.1 without porting.
4. **Pixel format conflict** (RGBX_8888 vs BGRA_8888) may show wrong colours. Test on device.
5. **Notch offset** (`TW_Y_OFFSET 80`) may cut the top of the NOVA header if it is wrong.
6. **MIUI restores stock recovery** on boot unless prevented.
7. **Anti-rollback:** the keymaster security-patch check needs the 2099 patch-level hack, which is standard but must be documented.
8. **microSD node conflict** (`mmcblk0` vs `mmcblk1`).
9. **Super size and group-name conflict** (§5.2). Not fatal for recovery, but must be corrected.

---

## 12. Unverified assumptions (must be closed in Phase 3)

| # | Assumption | How to verify (read-only) |
|---|---|---|
| U1 | User's device is citrus (M2010J19CG/CI) on V14.0.2.0 or similar A12 firmware | `adb shell getprop ro.product.device ro.product.model ro.build.fingerprint ro.boot.product.hardware.sku` |
| U2 | Bootloader is unlocked | `fastboot getvar unlocked` (read-only) |
| U3 | super size and group name | `adb shell lpdump` (root/recovery) or block size from `/sys/class/block` |
| U4 | microSD node | `adb shell cat /proc/partitions` with card inserted |
| U5 | Pixel format | visual check during temporary boot |
| U6 | Touch panel vendor/IC | `adb shell dmesg \| grep -iE "nt36|fts|focal"` (root) or `/sys` touch nodes |
| U7 | `fastboot boot` works on citrus | Stage 4 test, the only non-persistent boot path |
| U8 | Stock recovery kernel hashes match twrpdtgen | unpack the official ROM's recovery.img |
| U9 | Exact keymaster version used by recovery decrypt (4.0 vs 4.1) | `vendor/etc/vintf/manifest.xml` from the user's firmware |
| U10 | `vbmeta`, `vbmeta_system`, `persist`, `metadata`, EFS sizes | `adb shell ls -l /dev/block/by-name` + `/proc/partitions` |

`tests/device/probe_device.sh` collects U1, U3, U4, U6 and U10 with **read-only** commands only.

---

## 13. Decisions for Phase 2–3

| Decision | Choice | Reason |
|---|---|---|
| Manifest | `minimal-manifest-twrp/platform_manifest_twrp_aosp` @ `twrp-12.1` (`6dc117d9…`) | Matches the device's final Android version and header v2; most-used branch for SM6115 devices |
| Fallback | `twrp-14.1` (`cb31ddec…`) | If 12.1 decryption fails |
| Device tree base | New `device/xiaomi/citrus`, written for twrp-12.1. Boot params from twrpdtgen (stock), partition flags from Caca0/darkpewds, crypto from current PE fstab + qcom twrp-common. | No existing tree is current *and* TWRP-specific |
| Kernel | Stock prebuilt from official V14.0.2.0 recovery, hash-pinned | Matches what runs on the device |
| Theme | `TW_THEME := portrait_hdpi` base + `TW_CUSTOM_THEME` NOVA `ui.xml`, with assets installed into `/twres` by device makefile | Only supported custom-theme path upstream |

---

## Sources

- TWRP sources: https://github.com/TeamWin/android_bootable_recovery, https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp, https://github.com/TeamWin/android_device_qcom_twrp-common
- Device trees: links in §3 (all `https://github.com/<owner>/<repo>`)
- Kernel: https://github.com/MiCode/Xiaomi_Kernel_OpenSource/tree/lime-q-oss
- XDA, *POCO M3 and Xiaomi Mi 10i / Mi 10T Lite receive unofficial TWRP ports*: https://www.xda-developers.com/poco-m3-xiaomi-mi-10i-10t-lite-unofficial-twrp-ports/
- PixelExperience citrus wiki: https://wiki.pixelexperience.org/devices/citrus
