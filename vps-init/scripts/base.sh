#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

install_base() {
  require_root
  local packages=(ca-certificates curl wget vim git htop net-tools unzip ufw fail2ban jq)
  info "Installing or verifying base packages: ${packages[*]}"
  run env DEBIAN_FRONTEND=noninteractive apt-get update
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
  info 'Base packages ready. A reboot is never performed automatically.'
}
