#!/usr/bin/env bash
# NOVA Recovery - build the recovery image for POCO M3 (citrus).
#
# Validates configuration, runs static checks, selects the citrus target and
# runs the standard TWRP build (`mka recoveryimage`). Saves a full log and
# stops on the first error. This script NEVER talks to a connected phone.
#
# Usage: scripts/build.sh [--skip-static]
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

SKIP_STATIC=0
[[ "${1:-}" == "--skip-static" ]] && SKIP_STATIC=1

# ---- Validate ---------------------------------------------------------------
[[ -f "${NOVA_SRC_DIR}/build/envsetup.sh" ]] || die "No synced source at ${NOVA_SRC_DIR}. Run scripts/sync.sh first."
[[ -f "${NOVA_SRC_DIR}/bootable/recovery/variables.h" ]] || die "bootable/recovery missing in ${NOVA_SRC_DIR}."
DT="${NOVA_ROOT}/device/${NOVA_VENDOR}/${NOVA_DEVICE}"
for f in BoardConfig.mk device.mk "twrp_${NOVA_DEVICE}.mk" AndroidProducts.mk; do
  [[ -f "${DT}/$f" ]] || die "Device tree incomplete: ${DT}/$f is missing (Phase 3 not done yet)."
done
[[ -L "${NOVA_SRC_DIR}/device/${NOVA_VENDOR}/${NOVA_DEVICE}" ]] || die "Device tree not linked into source. Run scripts/sync.sh."

if (( ! SKIP_STATIC )); then
  log "Running static checks"
  "${NOVA_ROOT}/tests/build/static_checks.sh"
fi

# ---- Build ------------------------------------------------------------------
mkdir -p "${NOVA_OUT_LOG_DIR}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="${NOVA_OUT_LOG_DIR}/build-${STAMP}.log"
log "Building ${NOVA_LUNCH_TARGET}; log: ${LOG}"

cd "${NOVA_SRC_DIR}"
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C

set +u   # envsetup.sh is not nounset-clean
# shellcheck disable=SC1091
source build/envsetup.sh >/dev/null
lunch "${NOVA_LUNCH_TARGET}"
set -u

start=$(date +%s)
if ! mka -j"${NOVA_JOBS}" recoveryimage 2>&1 | tee "${LOG}"; then
  die "Build FAILED after $(( $(date +%s) - start ))s. See ${LOG}"
fi
end=$(date +%s)

IMG="${OUT}/recovery.img"
[[ -f "${IMG}" ]] || die "Build reported success but ${IMG} does not exist. See ${LOG}"
grep -q "#### build completed successfully" "${LOG}" || die "Build log has no success marker. Not treating this as a successful build."

# ---- Metadata for verify/package -------------------------------------------
INFO="${NOVA_ROOT}/out/build-info.env"
mkdir -p "$(dirname "$INFO")"
{
  echo "BUILD_DATE_UTC=${STAMP}"
  echo "BUILD_SECONDS=$((end-start))"
  echo "BUILD_LOG=${LOG}"
  echo "BUILD_IMAGE=${IMG}"
  echo "LUNCH_TARGET=${NOVA_LUNCH_TARGET}"
  echo "TWRP_VERSION=${NOVA_TWRP_VERSION}"
  echo "MANIFEST_REV=${NOVA_MANIFEST_REV}"
  echo "BOOTABLE_RECOVERY_REV=$(git -C bootable/recovery rev-parse HEAD)"
  echo "NOVA_REV=$(git -C "${NOVA_ROOT}" rev-parse HEAD 2>/dev/null || echo uncommitted)"
  echo "HOST=$(. /etc/os-release && echo "$PRETTY_NAME") $(uname -r)"
} > "$INFO"

ok "Build finished in $((end-start))s: ${IMG}"
log "Next: scripts/verify.sh"
