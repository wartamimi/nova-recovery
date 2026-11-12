#!/usr/bin/env bash
# NOVA Recovery - shared helpers for scripts/*.sh
# Sourced, not executed. Every script that sources this runs with `set -euo pipefail`.

NOVA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export NOVA_ROOT

# Load project configuration (paths, pinned revisions, target).
# shellcheck source=../../nova/config/build.env
source "${NOVA_ROOT}/nova/config/build.env"

# Allow per-user overrides without editing tracked files.
if [[ -f "${NOVA_ROOT}/nova/config/build.local.env" ]]; then
  # shellcheck disable=SC1091
  source "${NOVA_ROOT}/nova/config/build.local.env"
fi

if [[ -t 1 ]]; then
  _c_red=$'\033[31m'; _c_yel=$'\033[33m'; _c_blu=$'\033[34m'; _c_grn=$'\033[32m'; _c_off=$'\033[0m'
else
  _c_red=""; _c_yel=""; _c_blu=""; _c_grn=""; _c_off=""
fi

log()  { printf '%s[nova]%s %s\n' "$_c_blu" "$_c_off" "$*"; }
ok()   { printf '%s[ ok ]%s %s\n' "$_c_grn" "$_c_off" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$_c_yel" "$_c_off" "$*" >&2; }
die()  { printf '%s[fail]%s %s\n' "$_c_red" "$_c_off" "$*" >&2; exit 1; }

# Ask a yes/no question. Defaults to "no". Non-interactive shells always get "no"
# unless NOVA_ASSUME_YES=1 is set explicitly by the user.
confirm() {
  local prompt="$1" reply
  if [[ "${NOVA_ASSUME_YES:-0}" == "1" ]]; then return 0; fi
  if [[ ! -t 0 ]]; then warn "Non-interactive shell: answering 'no' to: $prompt"; return 1; fi
  read -r -p "$prompt [y/N] " reply
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

require_cmd() {
  local c
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || die "Required command not found: $c (run scripts/setup.sh)"; done
}

# NOVA scripts never talk to a phone's partitions. This guard exists so that a
# future edit cannot slip a flashing command into a build script unnoticed:
# tests/build/static_checks.sh greps scripts/ for forbidden commands.
export NOVA_FORBIDDEN_DEVICE_CMDS='fastboot[[:space:]]+(flash|erase|format|wipe|-w|update|oem|flashing|boot|reboot|set_active)|adb[[:space:]]+reboot|adb[[:space:]].*(dd[[:space:]]|mkfs|wipe|format)'
