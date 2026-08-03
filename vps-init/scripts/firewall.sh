#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/config.sh"

ufw_allow_once() {
  local rule="$1" comment="$2"
  ufw status numbered | grep -Fq "$rule" || run ufw allow "$rule" comment "$comment"
}
configure_firewall() {
  local ssh_port wg_port sb_port
  ssh_port="$(config_value ssh port)"; wg_port="$(config_value wireguard port)"; sb_port="$(config_value sing_box port)"
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then
    info "[DRY-RUN] configure UFW: SSH ${ssh_port}/tcp, WireGuard ${wg_port}/udp when enabled, sing-box ${sb_port}/tcp when enabled"
    return 0
  fi
  require_root; require_command ufw
  # Keep the current/new management path before enabling a deny-by-default firewall.
  ufw_allow_once "${ssh_port}/tcp" 'tu-devkit-vps-init ssh'
  if [[ "$(config_bool wireguard enabled)" == true ]]; then ufw_allow_once "${wg_port}/udp" 'tu-devkit-vps-init wireguard'; fi
  if [[ "$(config_bool sing_box enabled)" == true ]]; then ufw_allow_once "${sb_port}/tcp" 'tu-devkit-vps-init sing-box'; fi
  run ufw default deny incoming
  run ufw default allow outgoing
  run ufw --force enable
  if command -v fail2ban-client >/dev/null 2>&1; then run systemctl enable --now fail2ban; fi
  info 'Firewall and fail2ban configuration complete.'
}
