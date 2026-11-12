# Building NOVA Recovery

## Host requirements

- Ubuntu 22.04 x86_64 (verified target; 20.04 and 24.04 are untested)
- 120 GB free disk, 16 GB RAM + swap or more
- No system JDK needed: Android 12.1 builds use `prebuilts/jdk`

`scripts/setup.sh --check-only` reports what is missing. Without `--check-only` it offers to install missing packages with `apt-get` and asks first.

## Steps

```bash
scripts/setup.sh
scripts/sync.sh                 # first run creates manifest/pinned.xml; commit it
scripts/build.sh                # lunch twrp_citrus-eng && mka recoveryimage
scripts/verify.sh
scripts/package.sh
```

- Sources go to `$NOVA_SRC_DIR` (default `~/nova-twrp-src`). Override it in `nova/config/build.local.env`.
- Logs are written to `out/logs/`. A build only counts as successful if its log has `#### build completed successfully` **and** `recovery.img` exists.
- `scripts/sync.sh --update-pins` refreshes upstream revisions on purpose. After that, re-run the whole test plan.

## Pinned upstream

| What | Value |
|---|---|
| Manifest | `minimal-manifest-twrp/platform_manifest_twrp_aosp` @ `twrp-12.1` `6dc117d9cbd08430daa16db2013560e1c4017fa8` |
| TWRP | `3.7.1_12` (`bootable/recovery` android-12.1, head `5c3d206a` at research time; exact SHA recorded in `manifest/pinned.xml` after first sync) |
