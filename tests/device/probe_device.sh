#!/usr/bin/env bash
# NOVA Recovery - READ-ONLY device probe for POCO M3 (citrus).
#
# Collects the facts that docs/DEVICE_RESEARCH.md section 12 lists as
# unverified. Uses only getprop, ls, cat and `fastboot getvar`. It never
# flashes, erases, formats, reboots or writes to the phone.
#
# Usage:
#   Phone booted to Android, USB debugging on:   tests/device/probe_device.sh adb
#   Phone in fastboot mode:                      tests/device/probe_device.sh fastboot
# Output: out/device-probe-<timestamp>.txt
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODE="${1:-adb}"
mkdir -p "$ROOT/out"
OUTF="$ROOT/out/device-probe-$(date +%Y%m%d-%H%M%S).txt"

section() { printf '\n===== %s =====\n' "$1" | tee -a "$OUTF"; }
run()     { printf '$ %s\n' "$*" | tee -a "$OUTF"; "$@" 2>&1 | tee -a "$OUTF" || true; }
ash()     { run adb shell "$@"; }

case "$MODE" in
  adb)
    command -v adb >/dev/null || { echo "adb not found"; exit 1; }
    [[ "$(adb get-state 2>/dev/null)" == "device" || "$(adb get-state 2>/dev/null)" == "recovery" ]] \
      || { echo "No device in adb (Android or recovery) state."; exit 1; }
    section "U1 identity and firmware"
    for p in ro.product.device ro.product.vendor.device ro.product.model ro.product.vendor.model \
             ro.boot.product.hardware.sku ro.boot.hwc ro.build.fingerprint ro.vendor.build.fingerprint \
             ro.build.version.release ro.build.version.incremental ro.miui.ui.version.name \
             ro.vendor.build.security_patch ro.boot.verifiedbootstate ro.boot.flash.locked \
             ro.boot.dynamic_partitions ro.boot.slot_suffix ro.crypto.state ro.crypto.type \
             ro.boot.bootdevice ro.boot.usbcontroller ro.hardware ro.board.platform; do
      printf '%s=' "$p" | tee -a "$OUTF"; adb shell getprop "$p" 2>&1 | tee -a "$OUTF"
    done
    section "U10 by-name partitions"
    ash ls -l /dev/block/by-name/
    section "U3/U4/U10 partition sizes (blocks of 1 KiB)"
    ash cat /proc/partitions
    section "U3 dynamic partitions (needs root or recovery; may fail harmlessly)"
    ash lpdump
    section "Mounts and fstab in use"
    ash cat /proc/mounts
    ash 'ls /vendor/etc/fstab* /odm/etc/fstab* 2>/dev/null; cat /vendor/etc/fstab.qcom 2>/dev/null || cat /vendor/etc/fstab.default 2>/dev/null'
    section "U6 touch panel (dmesg needs root; may fail harmlessly)"
    ash 'ls /sys/class/input/ ; for d in /sys/class/input/input*/name; do echo "$d: $(cat $d)"; done'
    ash 'dmesg 2>/dev/null | grep -iE "nt36|novatek|fts|focal|ft8719|synaptics" | head -40'
    section "U9 keymaster/gatekeeper in vendor manifest"
    ash 'grep -A3 -iE "keymaster|keymint|gatekeeper" /vendor/etc/vintf/manifest.xml /vendor/etc/vintf/manifest/*.xml 2>/dev/null | head -60'
    section "Kernel"
    ash cat /proc/version
    section "Display"
    ash wm size
    ash wm density
    ash 'cat /sys/class/backlight/panel0-backlight/max_brightness 2>/dev/null'
    ;;
  fastboot)
    command -v fastboot >/dev/null || { echo "fastboot not found"; exit 1; }
    section "U2 bootloader state (getvar only)"
    for v in product unlocked secure is-userspace current-slot slot-count \
             partition-size:recovery partition-size:boot partition-size:super \
             partition-size:dtbo partition-size:vbmeta max-download-size; do
      run fastboot getvar "$v"
    done
    ;;
  *) echo "Usage: $0 adb|fastboot"; exit 1;;
esac
echo; echo "Saved: $OUTF"
