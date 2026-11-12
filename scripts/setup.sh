#!/usr/bin/env bash
# NOVA Recovery - build host check and setup.
#
# Checks the OS, disk, RAM and required tools. Installs missing packages ONLY
# after asking. Never overwrites existing git, repo or shell configuration.
#
# Usage: scripts/setup.sh [--check-only]
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

CHECK_ONLY=0
[[ "${1:-}" == "--check-only" ]] && CHECK_ONLY=1
problems=0

# ---- OS ---------------------------------------------------------------------
log "Checking operating system"
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}:${VERSION_ID:-}" in
    ubuntu:22.04) ok "Ubuntu 22.04 (verified target)";;
    ubuntu:20.04|ubuntu:24.04) warn "Ubuntu ${VERSION_ID}: should work for twrp-12.1, but 22.04 is the verified target";;
    *) warn "Unverified host: ${PRETTY_NAME:-unknown}. NOVA is only validated on Ubuntu 22.04."; problems=$((problems+1));;
  esac
else
  die "Cannot read /etc/os-release. A Linux build host is required."
fi
[[ "$(uname -m)" == "x86_64" ]] || die "AOSP/TWRP host tools require an x86_64 build host (found $(uname -m))."

# ---- Disk -------------------------------------------------------------------
log "Checking disk space for ${NOVA_SRC_DIR}"
mkdir -p "$(dirname "${NOVA_SRC_DIR}")"
avail_gb=$(df -Pk "$(dirname "${NOVA_SRC_DIR}")" | awk 'NR==2 {printf "%d", $4/1024/1024}')
if (( avail_gb < NOVA_MIN_DISK_GB )); then
  warn "Only ${avail_gb} GB free; ${NOVA_MIN_DISK_GB} GB recommended (source ~50 GB + out ~40 GB + ccache)."
  problems=$((problems+1))
else
  ok "${avail_gb} GB free"
fi

# ---- RAM --------------------------------------------------------------------
log "Checking memory"
ram_gb=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
swap_gb=$(awk '/SwapTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
if (( ram_gb + swap_gb < NOVA_MIN_RAM_GB )); then
  warn "RAM+swap is ${ram_gb}+${swap_gb} GB; ${NOVA_MIN_RAM_GB} GB+ recommended. Lower NOVA_JOBS or add swap."
  problems=$((problems+1))
else
  ok "RAM ${ram_gb} GB, swap ${swap_gb} GB"
fi

# ---- Packages ---------------------------------------------------------------
# AOSP 12 host requirements (source.android.com "Establishing a build environment")
# plus tools used by NOVA's own scripts (xmllint, shellcheck, file, python3).
# Android 12 builds use the JDK shipped in prebuilts/jdk, so no system Java is needed.
PKGS=(git git-lfs gnupg flex bison build-essential zip unzip curl zlib1g-dev
      libc6-dev-i386 libncurses5 lib32z1-dev libgl1-mesa-dev libxml2-utils
      xsltproc fontconfig python3 python-is-python3 rsync bc ccache file
      shellcheck openssl)
missing=()
if command -v dpkg-query >/dev/null 2>&1; then
  for p in "${PKGS[@]}"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed" || missing+=("$p")
  done
else
  warn "dpkg-query not available; skipping package check."
fi

if (( ${#missing[@]} )); then
  warn "Missing packages: ${missing[*]}"
  if (( CHECK_ONLY )); then
    problems=$((problems+1))
  elif confirm "Install them now with 'sudo apt-get install'?"; then
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
  else
    warn "Skipped package installation."
    problems=$((problems+1))
  fi
else
  ok "All required packages are installed"
fi

# ---- repo tool --------------------------------------------------------------
if command -v repo >/dev/null 2>&1; then
  ok "repo found: $(command -v repo)"
else
  warn "'repo' not found."
  if (( ! CHECK_ONLY )) && confirm "Download Google's repo launcher to ~/.local/bin/repo?"; then
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/.local/bin/repo.tmp"
    chmod a+x "$HOME/.local/bin/repo.tmp"
    mv "$HOME/.local/bin/repo.tmp" "$HOME/.local/bin/repo"
    ok "Installed ~/.local/bin/repo. Make sure ~/.local/bin is on your PATH."
  else
    problems=$((problems+1))
  fi
fi

# ---- git identity (read-only check) -----------------------------------------
if ! git config --global user.name >/dev/null || ! git config --global user.email >/dev/null; then
  warn "git user.name/user.email are not set. repo needs them; set them yourself with 'git config --global'."
  problems=$((problems+1))
else
  ok "git identity is configured (left unchanged)"
fi

# ---- ccache (opt-in, never forced) ------------------------------------------
if command -v ccache >/dev/null 2>&1; then
  log "ccache is available. To use it, export USE_CCACHE=1 and CCACHE_EXEC=$(command -v ccache) in your own shell profile."
fi

echo
if (( problems )); then
  warn "Setup finished with ${problems} item(s) needing attention."
  exit 2
fi
ok "Build host is ready. Next: scripts/sync.sh"
