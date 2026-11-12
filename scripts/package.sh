#!/usr/bin/env bash
# NOVA Recovery - package a verified build into release/.
#
# Refuses to package unless scripts/verify.sh has passed for the same image.
# Releases are labelled EXPERIMENTAL until device testing is recorded in
# docs/TEST_REPORT.md with "DEVICE_TESTED: yes".
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd sha256sum python3

INFO="${NOVA_ROOT}/out/build-info.env"
REPORT="${NOVA_ROOT}/out/verify-report.json"
[[ -f "$INFO" && -f "$REPORT" ]] || die "Run scripts/build.sh and scripts/verify.sh first."
# shellcheck disable=SC1090
source "$INFO"

python3 -I -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if r["ok"] else 1)' "$REPORT" \
  || die "Last verification failed. Not packaging."
img_sha=$(sha256sum "$BUILD_IMAGE" | cut -d' ' -f1)
rep_sha=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["sha256"])' "$REPORT")
[[ "$img_sha" == "$rep_sha" ]] || die "Image changed since verification. Re-run scripts/verify.sh."

label="${NOVA_RELEASE_LABEL}"
if grep -qx "DEVICE_TESTED: yes" "${NOVA_ROOT}/docs/TEST_REPORT.md" 2>/dev/null; then
  label="BETA"
fi

out="${NOVA_RELEASE_DIR}"
mkdir -p "$out"
name="NOVA-Recovery-${NOVA_DEVICE}.img"
cp "$BUILD_IMAGE" "$out/$name"
( cd "$out" && sha256sum "$name" > SHA256SUMS )

kver=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("kernel_version","unknown"))' "$REPORT")
cat > "$out/BUILD_INFO.txt" <<INFO_EOF
${NOVA_RELEASE_NAME} (${label})
Device target:        Xiaomi POCO M3 (${NOVA_DEVICE}), recovery partition
Build date (UTC):     ${BUILD_DATE_UTC}
NOVA revision:        ${NOVA_REV}
TWRP version:         ${TWRP_VERSION}
Manifest revision:    ${MANIFEST_REV}
bootable/recovery:    ${BOOTABLE_RECOVERY_REV}
Lunch target:         ${LUNCH_TARGET}
Kernel:               ${kver}
Build environment:    ${HOST}
SHA-256:              ${img_sha}

Known limitations: see CHANGELOG.md and TEST_REPORT.md.
INFO_EOF

cp "${NOVA_ROOT}/docs/CHANGELOG.md" "${NOVA_ROOT}/docs/INSTALL.md" "$out/"
if [[ -f "${NOVA_ROOT}/docs/TEST_REPORT.md" ]]; then
  cp "${NOVA_ROOT}/docs/TEST_REPORT.md" "$out/"
else
  printf '# Test report\n\nDEVICE_TESTED: no\n\nThis build has passed static, build and image checks only. It is EXPERIMENTAL.\n' > "$out/TEST_REPORT.md"
fi

ok "Packaged ${label} release in ${out}"
[[ "$label" == "EXPERIMENTAL" ]] && warn "This build is EXPERIMENTAL: not tested on a device."
exit 0
