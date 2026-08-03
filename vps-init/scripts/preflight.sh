#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

preflight() {
  require_root
  [[ -r /etc/os-release ]] || die 'Cannot identify operating system.'
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == ubuntu ]] || die 'Only Ubuntu is supported.'
  local major="${VERSION_ID%%.*}"
  [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 22 )) || die 'Ubuntu 22.04 or newer is required.'
  require_command apt-get
  require_command systemctl
  getent hosts archive.ubuntu.com >/dev/null 2>&1 || warn 'Ubuntu archive DNS lookup failed; package installation may fail.'
  info "Environment check passed: Ubuntu ${VERSION_ID}."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then preflight; fi
