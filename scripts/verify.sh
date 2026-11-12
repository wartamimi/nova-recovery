#!/usr/bin/env bash
# NOVA Recovery - verify build outputs (read-only).
#
# Checks: image exists, Android boot image header v2, fits the 128 MiB citrus
# recovery partition, arm64 kernel, DTB present, ramdisk contains TWRP and NOVA
# resources, build metadata present, SHA-256 recorded.
#
# Usage: scripts/verify.sh [IMAGE]
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd python3 sha256sum

INFO="${NOVA_ROOT}/out/build-info.env"
[[ -f "$INFO" ]] || die "No build metadata at out/build-info.env. Run scripts/build.sh first."
# shellcheck disable=SC1090
source "$INFO"
IMG="${1:-${BUILD_IMAGE}}"
[[ -f "$IMG" ]] || die "Image not found: $IMG"

# citrus recovery partition: 134217728 bytes (docs/DEVICE_RESEARCH.md section 5.1)
RECOVERY_PARTITION_BYTES=134217728
REPORT="${NOVA_ROOT}/out/verify-report.json"

log "Inspecting ${IMG}"
python3 -I "${NOVA_ROOT}/scripts/lib/bootimg_inspect.py" "$IMG" \
  --expect-header 2 \
  --max-size "${RECOVERY_PARTITION_BYTES}" \
  --require system/bin/recovery twres/ui.xml twres/fonts system/etc/recovery.fstab \
  --json "$REPORT" >/dev/null || {
    python3 -I -c 'import json,sys; [print(("PASS " if c["pass"] else "FAIL ")+c["check"]+(" — "+c["detail"] if c["detail"] else "")) for c in json.load(open(sys.argv[1]))["checks"]]' "$REPORT"
    die "Image verification FAILED. Report: ${REPORT}"
  }
python3 -I -c 'import json,sys; [print("PASS "+c["check"]) for c in json.load(open(sys.argv[1]))["checks"]]' "$REPORT"

for k in BUILD_DATE_UTC MANIFEST_REV BOOTABLE_RECOVERY_REV LUNCH_TARGET; do
  [[ -n "${!k:-}" ]] || die "Build metadata missing ${k}"
done
grep -q "#### build completed successfully" "${BUILD_LOG}" || die "Build log ${BUILD_LOG} has no success marker."

sha256sum "$IMG" | tee "${NOVA_ROOT}/out/recovery.img.sha256"
ok "Verification passed. Report: ${REPORT}"
