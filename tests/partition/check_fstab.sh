#!/usr/bin/env bash
# NOVA Recovery - partition configuration checks for citrus.
# Every partition in the TWRP fstab must appear in the documented partition
# map (docs/DEVICE_RESEARCH.md section 5), and the never-wipe partitions must
# not be marked wipeable or formattable.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DT="$ROOT/device/xiaomi/citrus"
FSTAB="$(find "$DT/recovery/root" -name 'twrp.flags' -o -name 'recovery.fstab' 2>/dev/null | head -1 || true)"
[[ -n "$FSTAB" ]] || { echo "FAIL no recovery fstab/twrp.flags under $DT/recovery/root"; exit 1; }
fail=0

# Partitions documented in DEVICE_RESEARCH.md section 5.1 (by-name).
KNOWN="boot recovery dtbo vbmeta vbmeta_system super cache metadata userdata persist misc cust modem bluetooth dsp modemst1 modemst2 fsc fsg"
# Must never be wiped from the UI.
PROTECTED="persist modemst1 modemst2 fsc fsg modem bluetooth dsp"

while read -r line; do
  [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
  for tok in $line; do
    if [[ "$tok" == /dev/block/*by-name/* ]]; then
      p="${tok##*/}"
      if [[ " $KNOWN " != *" $p "* ]]; then
        echo "FAIL $p is not in the documented citrus partition map: $line"; fail=1
      fi
      if [[ " $PROTECTED " == *" $p "* && "$line" =~ wipeingui|wipeduringfactoryreset|formattable ]]; then
        echo "FAIL protected partition $p is wipeable: $line"; fail=1
      fi
    fi
  done
done < "$FSTAB"

(( fail )) || echo "PASS fstab partitions match documented map ($FSTAB)"
exit $fail
