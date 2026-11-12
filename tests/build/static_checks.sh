#!/usr/bin/env bash
# NOVA Recovery - Stage 1 static checks (docs/TESTING.md).
# - shellcheck on every script
# - XML well-formedness for manifests and NOVA theme files
# - safety: no flashing/erasing commands inside scripts/ or device/
# - device tree checks (once Phase 3 files exist)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0
pass() { printf 'PASS %s\n' "$*"; }
bad()  { printf 'FAIL %s\n' "$*"; fail=1; }

# 1. Shell scripts
mapfile -t sh_files < <(find "$ROOT/scripts" "$ROOT/tests" -name '*.sh' -type f | sort)
if command -v shellcheck >/dev/null; then
  if shellcheck -x -S warning "${sh_files[@]}"; then pass "shellcheck (${#sh_files[@]} files)"; else bad "shellcheck"; fi
else
  for f in "${sh_files[@]}"; do bash -n "$f" || bad "bash -n $f"; done
  pass "bash -n syntax (${#sh_files[@]} files; install shellcheck for full lint)"
fi

# 2. XML
mapfile -t xml_files < <(find "$ROOT/manifest" "$ROOT/nova" "$ROOT/device" -name '*.xml' -type f 2>/dev/null | sort)
if (( ${#xml_files[@]} )); then
  if xmllint --noout "${xml_files[@]}"; then pass "xmllint (${#xml_files[@]} files)"; else bad "xmllint"; fi
fi

# 3. Safety: forbidden device-write commands
# shellcheck source=../../scripts/lib/common.sh
NOVA_FORBIDDEN_DEVICE_CMDS=$(grep -m1 '^export NOVA_FORBIDDEN_DEVICE_CMDS=' "$ROOT/scripts/lib/common.sh" | cut -d"'" -f2)
if grep -rEn --include='*.sh' --include='*.mk' --include='*.rc' "$NOVA_FORBIDDEN_DEVICE_CMDS" \
     "$ROOT/scripts" "$ROOT/device" "$ROOT/tests" 2>/dev/null | grep -v 'NOVA_FORBIDDEN_DEVICE_CMDS'; then
  bad "found device flashing/erasing commands in project scripts (see above)"
else
  pass "no flashing/erasing commands in scripts/, device/, tests/"
fi

# 4. Device tree (Phase 3+)
DT="$ROOT/device/xiaomi/citrus"
if [[ -f "$DT/BoardConfig.mk" ]]; then
  "$ROOT/tests/partition/check_fstab.sh" || fail=1
else
  printf 'SKIP device tree checks (device/xiaomi/citrus not populated yet; Phase 3)\n'
fi

# 5. UI (Phase 5+)
if [[ -x "$ROOT/tests/ui/validate_theme.sh" ]]; then "$ROOT/tests/ui/validate_theme.sh" || fail=1; fi

exit $fail
