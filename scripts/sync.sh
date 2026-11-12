#!/usr/bin/env bash
# NOVA Recovery - synchronise pinned TWRP sources.
#
# 1. `repo init` the minimal TWRP manifest at the pinned commit (build.env).
# 2. If manifest/pinned.xml exists, sync exactly those project revisions.
#    Otherwise sync the branch heads, then snapshot them into manifest/pinned.xml
#    so every later sync is reproducible.
# 3. Link this repo's device tree and NOVA theme into the source tree.
#
# Usage: scripts/sync.sh [--update-pins]
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd repo git

UPDATE_PINS=0
[[ "${1:-}" == "--update-pins" ]] && UPDATE_PINS=1

PINNED="${NOVA_ROOT}/manifest/pinned.xml"
mkdir -p "${NOVA_SRC_DIR}" "${NOVA_OUT_LOG_DIR}"
cd "${NOVA_SRC_DIR}"

log "Source tree: ${NOVA_SRC_DIR}"
if [[ ! -d .repo ]]; then
  log "repo init ${NOVA_MANIFEST_URL} @ ${NOVA_MANIFEST_BRANCH}"
  repo init --depth=1 --git-lfs -u "${NOVA_MANIFEST_URL}" -b "${NOVA_MANIFEST_BRANCH}"
fi

# Local manifest: only things NOVA adds on top of upstream.
mkdir -p .repo/local_manifests
cp "${NOVA_ROOT}/manifest/nova_local.xml" .repo/local_manifests/nova_local.xml

# Choose which manifest file drives the sync. `repo init` may move the manifest
# checkout, so the pin to NOVA_MANIFEST_REV is applied afterwards and the sync
# runs with --no-manifest-update so repo cannot move it again.
if [[ -f "${PINNED}" && ${UPDATE_PINS} -eq 0 ]]; then
  log "Using exact revisions from manifest/pinned.xml"
  cp "${PINNED}" .repo/manifests/nova_pinned.xml
  repo init -m nova_pinned.xml
  mode="pinned"
else
  log "Using branch heads (first sync or --update-pins)"
  repo init -m default.xml
  mode="heads"
fi

git -C .repo/manifests fetch --depth=1 origin "${NOVA_MANIFEST_REV}"
git -C .repo/manifests checkout -q "${NOVA_MANIFEST_REV}"
ok "Manifest repository pinned at ${NOVA_MANIFEST_REV}"

log "repo sync (${mode})"
repo sync -c --no-manifest-update --no-tags --no-clone-bundle --optimized-fetch --force-sync -j"${NOVA_JOBS}" \
  2>&1 | tee "${NOVA_OUT_LOG_DIR}/sync-$(date +%Y%m%d-%H%M%S).log"

if [[ "${mode}" == "heads" ]]; then
  repo manifest -r -o "${PINNED}"
  ok "Wrote revision snapshot to manifest/pinned.xml. Commit it to pin these sources."
fi

# Link NOVA content into the tree (symlinks, so edits happen in this repo only).
link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    die "$dst exists and is not a NOVA symlink. Refusing to overwrite it."
  fi
  ln -sfn "$src" "$dst"
}
link "${NOVA_ROOT}/device/xiaomi/citrus" "device/xiaomi/citrus"
link "${NOVA_ROOT}/nova"                 "device/xiaomi/citrus-nova"
ok "Linked device/xiaomi/citrus and NOVA theme into the source tree"

bootable_rev=$(git -C bootable/recovery rev-parse HEAD 2>/dev/null || echo unknown)
ok "bootable/recovery at ${bootable_rev}"
