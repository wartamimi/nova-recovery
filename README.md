# NOVA Recovery

*A Refined Android Recovery Experience*

NOVA Recovery is a custom recovery for the **Xiaomi POCO M3 (`citrus`, SM6115 / Snapdragon 662)**. It is built on **TWRP 3.7.1 (`twrp-12.1`)**. NOVA keeps TWRP's recovery engine (partitions, flashing, backup, decryption, ADB) unchanged and replaces the interface with a dark-graphite, minimalist theme written in TWRP's own XML GUI format.

> **Status: Phase 1 complete (research). No image has been built yet.** Nothing in this repository has been tested on a device. Do not flash anything from here.

## Layout

| Path | Contents |
|---|---|
| `device/xiaomi/citrus/` | TWRP device tree for citrus (Phase 3) |
| `nova/` | NOVA theme: XML pages, images, fonts, colour tokens, build config |
| `manifest/` | Local manifest and pinned source revisions |
| `scripts/` | `setup`, `sync`, `build`, `verify`, `package`, `clean` |
| `tests/` | Static, partition, UI and read-only device probe tests |
| `docs/` | Research, architecture, build, install, testing, changelog |
| `vendor/` | Notes on proprietary blobs (blobs are never committed) |

## Quick start (Ubuntu 22.04, x86_64)

```bash
scripts/setup.sh      # checks host; installs packages only if you say yes
scripts/sync.sh       # syncs pinned TWRP 12.1 sources to ~/nova-twrp-src
scripts/build.sh      # builds recovery.img (needs Phase 3 device tree)
scripts/verify.sh     # inspects the image
scripts/package.sh    # writes release/
```

None of these scripts communicate with a phone. Installation is manual and is described in `docs/INSTALL.md`.

## Documentation

- [Device research](docs/DEVICE_RESEARCH.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Build](docs/BUILD.md) · [Install](docs/INSTALL.md) · [Testing](docs/TESTING.md) · [Changelog](docs/CHANGELOG.md)

## License

NOVA's own files are licensed under Apache-2.0 (see `LICENSE`). TWRP and AOSP components keep their upstream licenses. See `docs/ARCHITECTURE.md` → *External dependencies and licenses*.
