#!/usr/bin/env bash
# shellcheck disable=SC1091 # Module paths are resolved from this script at runtime.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
source "$ROOT/lib/config.sh"
source "$ROOT/lib/state.sh"

ssh_port_is_listening() {
  local port="$1"
  ss -H -ltn 2>/dev/null | awk '{print $4}' | grep -Eq ":${port}$"
}

ufw_allow_managed() {
  local rule="$1" comment="$2"
  if ufw status | grep -Eq "^${rule//\//\\/}[[:space:]]"; then
    info "UFW already allows ${rule}; preserving the existing rule."
    return
  fi
  run ufw allow "$rule" comment "$comment"
  record_managed_ufw_rule "$comment"
}

ufw_allow_wireguard_service() {
  local address="$1" port="$2" comment="tu-devkit-vps-init clash-remote-${2}"
  if ufw status | grep -Fq "$comment"; then record_managed_ufw_rule "$comment"; return; fi
  if ufw status | grep -Eq "^${port}/tcp[[:space:]].*on wg0"; then
    info "UFW already allows ${port}/tcp on wg0; preserving the existing rule."
    return
  fi
  run ufw allow in on wg0 to "$address" port "$port" proto tcp comment "$comment"
  record_managed_ufw_rule "$comment"
}

configure_fail2ban() {
  local ports="$1" candidate=/etc/fail2ban/jail.d/99-tu-devkit-vps-init.local tmp backup_dir previous
  backup_dir="${VPS_INIT_STATE_DIR}/backups/fail2ban"
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info "[DRY-RUN] protect SSH ports ${ports} with fail2ban"; return; fi
  backup_file "$candidate" "$backup_dir"
  previous="${candidate}.previous"; [[ -e "$candidate" ]] && cp -a "$candidate" "$previous"
  tmp="$(mktemp)"
  cat > "$tmp" <<EOF
[sshd]
enabled = true
port = ${ports}
bantime = $(config_value_or fail2ban bantime 1h)
findtime = $(config_value_or fail2ban findtime 10m)
maxretry = $(config_value_or fail2ban maxretry 5)
EOF
  install -m 644 "$tmp" "$candidate"; rm -f "$tmp"
  if ! fail2ban-client -t; then
    if [[ -e "$previous" ]]; then mv -f "$previous" "$candidate"; else rm -f "$candidate"; fi
    die 'Fail2ban configuration is invalid; the module configuration was restored.'
  fi
  if ! systemctl enable --now fail2ban || ! systemctl restart fail2ban; then
    if [[ -e "$previous" ]]; then mv -f "$previous" "$candidate"; else rm -f "$candidate"; fi
    if fail2ban-client -t >/dev/null 2>&1; then systemctl restart fail2ban >/dev/null 2>&1 || true; fi
    die 'Fail2ban restart failed; the module configuration was restored.'
  fi
  rm -f "$previous"
}

configure_firewall() {
  local current_port target_port wg_port sb_port ssh_ports remote_address
  current_port="$(config_value_or ssh current_port 22)"; target_port="$(config_value ssh port)"
  wg_port="$(config_value wireguard port)"; sb_port="$(config_value sing_box port)"
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then
    info "[DRY-RUN] configure ${VPS_INIT_PROFILE:-legacy} UFW and fail2ban without deleting existing rules"
    return 0
  fi
  require_root; require_command ufw; require_command ss; require_command fail2ban-client
  ssh_port_is_listening "$current_port" || die "Refusing to enable UFW: ssh.current_port ${current_port} is not listening."
  ufw_allow_managed "${current_port}/tcp" "tu-devkit-vps-init ssh-current-${current_port}"
  ssh_ports="$current_port"
  if [[ "${VPS_INIT_PROFILE:-legacy}" == secure && "$target_port" != "$current_port" ]]; then
    ufw_allow_managed "${target_port}/tcp" "tu-devkit-vps-init ssh-target-${target_port}"
    ssh_ports="${current_port},${target_port}"
  elif [[ "${VPS_INIT_PROFILE:-legacy}" == legacy && "$target_port" != "$current_port" ]]; then
    ufw_allow_managed "${target_port}/tcp" "tu-devkit-vps-init ssh-target-${target_port}"
  fi
  feature_enabled wireguard && ufw_allow_managed "${wg_port}/udp" "tu-devkit-vps-init wireguard-${wg_port}"
  feature_enabled sing_box && ufw_allow_managed "${sb_port}/tcp" "tu-devkit-vps-init sing-box-${sb_port}"
  if feature_enabled clash_remote; then
    remote_address="$(wireguard_server_ip)"
    ufw_allow_wireguard_service "$remote_address" "$(config_value_or clash_remote port 18080)"
  fi
  run ufw default deny incoming
  run ufw default allow outgoing
  run ufw --force enable
  configure_fail2ban "$ssh_ports"
  info 'Firewall and fail2ban configuration complete; unrelated UFW rules were preserved.'
}

delete_managed_ufw_comment() {
  local comment="$1" number
  managed_ufw_rule_recorded "$comment" || { info "No module-owned UFW rule to remove: $comment"; return; }
  while number="$(ufw status numbered | awk -v marker="$comment" 'index($0, marker) {line=$0; sub(/^\[[[:space:]]*/, "", line); sub(/\].*$/, "", line); n=line} END {print n}')" && [[ -n "$number" ]]; do
    run ufw --force delete "$number"
  done
  forget_managed_ufw_rule "$comment"
}

finalize_firewall() {
  local current_port target_port
  current_port="$(config_value_or ssh current_port 22)"; target_port="$(config_value ssh port)"
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info "[DRY-RUN] finalize UFW and fail2ban on SSH ${target_port}/tcp"; return; fi
  require_root; require_command ufw; require_command fail2ban-client
  ufw_allow_managed "${target_port}/tcp" "tu-devkit-vps-init ssh-target-${target_port}"
  configure_fail2ban "$target_port"
  [[ "$current_port" == "$target_port" ]] || delete_managed_ufw_comment "tu-devkit-vps-init ssh-current-${current_port}"
  info 'Secure firewall finalized; only the module-owned transition rule was removed.'
}
