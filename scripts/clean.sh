#!/usr/bin/env bash
# NOVA Recovery - clean build outputs. Touches only build directories on this
# computer, never a phone.
#
# Usage: scripts/clean.sh            remove this repo's out/ and release/
#        scripts/clean.sh --installclean   also run `make installclean` in the source tree
#        scripts/clean.sh --full           also delete the source tree's out/ (asks first)
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

rm -rf "${NOVA_ROOT}/out" "${NOVA_RELEASE_DIR}"
ok "Removed NOVA out/ and release/"

case "${1:-}" in
  --installclean)
    [[ -f "${NOVA_SRC_DIR}/build/envsetup.sh" ]] || die "No source tree at ${NOVA_SRC_DIR}"
    cd "${NOVA_SRC_DIR}"
    set +u; source build/envsetup.sh >/dev/null; lunch "${NOVA_LUNCH_TARGET}"; set -u
    make installclean
    ok "installclean done";;
  --full)
    target="${NOVA_SRC_DIR}/out"
    [[ -d "$target" ]] || { ok "Nothing to remove at $target"; exit 0; }
    confirm "Delete ${target} (full rebuild needed afterwards)?" || die "Cancelled."
    rm -rf -- "$target"
    ok "Removed ${target}";;
  "") ;;
  *) die "Unknown option: $1";;
esac
