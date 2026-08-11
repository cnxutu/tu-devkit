#!/usr/bin/env bash
# shellcheck disable=SC1091 # Module paths are resolved from this script at runtime.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
source "$ROOT/lib/config.sh"

SSH_CANDIDATE=/etc/ssh/sshd_config.d/99-tu-devkit-vps-init.conf

ssh_port_is_listening() {
  local port="$1"
  ss -H -ltn 2>/dev/null | awk '{print $4}' | grep -Eq ":${port}$"
}

write_ssh_policy() {
  local ports="$1" candidate_tmp previous root_login port expected_ports actual_ports
  local -a port_list
  root_login=no; [[ "$(config_bool ssh disable_root_login)" == false ]] && root_login=prohibit-password
  candidate_tmp="$(mktemp)"; previous="${SSH_CANDIDATE}.previous"
  {
    echo '# Managed by tu-devkit vps-init. Remove this file to revert this module policy.'
    IFS=, read -r -a port_list <<< "$ports"
    for port in "${port_list[@]}"; do printf 'Port %s\n' "$port"; done
    printf '%s\n' "PermitRootLogin ${root_login}" 'PasswordAuthentication no' 'KbdInteractiveAuthentication no' 'PermitEmptyPasswords no' 'PubkeyAuthentication yes'
  } > "$candidate_tmp"
  [[ -e "$SSH_CANDIDATE" ]] && cp -a "$SSH_CANDIDATE" "$previous"
  install -d -m 755 /etc/ssh/sshd_config.d
  install -m 600 "$candidate_tmp" "$SSH_CANDIDATE"; rm -f "$candidate_tmp"
  if ! sshd -t; then
    if [[ -e "$previous" ]]; then mv -f "$previous" "$SSH_CANDIDATE"; else rm -f "$SSH_CANDIDATE"; fi
    warn 'Candidate SSH configuration is invalid; the module configuration was restored.'
    return 1
  fi
  expected_ports="$(tr ',' '\n' <<< "$ports" | sort -nu | paste -sd, -)"
  actual_ports="$(sshd -T | awk '$1=="port" {print $2}' | sort -nu | paste -sd, -)"
  if [[ "$actual_ports" != "$expected_ports" ]]; then
    if [[ -e "$previous" ]]; then mv -f "$previous" "$SSH_CANDIDATE"; else rm -f "$SSH_CANDIDATE"; fi
    warn "Effective SSH ports are ${actual_ports:-unknown}, expected ${expected_ports}; the module configuration was restored."
    return 1
  fi
  if ! systemctl reload ssh && ! systemctl reload sshd; then
    if [[ -e "$previous" ]]; then mv -f "$previous" "$SSH_CANDIDATE"; else rm -f "$SSH_CANDIDATE"; fi
    warn 'SSH reload failed; the module configuration was restored.'
    return 1
  fi
  rm -f "$previous"
}

prepare_ssh_hardening() {
  local current_port target_port key_file ports backup_dir
  current_port="$(config_value_or ssh current_port 22)"; target_port="$(config_value ssh port)"
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info "[DRY-RUN] apply SSH transition policy on ${current_port},${target_port}"; return; fi
  require_root; require_command sshd; require_command ss
  key_file="$(config_value ssh admin_authorized_keys_path)"
  [[ -s "$key_file" ]] || die "Refusing SSH hardening: administrator key file is empty or missing: $key_file"
  ssh_port_is_listening "$current_port" || die "Refusing SSH hardening: ssh.current_port ${current_port} is not listening."
  ufw status | grep -Fq "${target_port}/tcp" || die "Refusing SSH hardening: ${target_port}/tcp is not open in UFW."
  backup_dir="${VPS_INIT_STATE_DIR}/backups/ssh"; backup_file "$SSH_CANDIDATE" "$backup_dir"
  ports="$target_port"; [[ "$current_port" == "$target_port" ]] || ports="${current_port},${target_port}"
  write_ssh_policy "$ports" || die 'SSH transition failed.'
  info "SSH key-only policy applied on ${ports}. Keep this session open and verify a new session on ${target_port}."
}

finalize_ssh_hardening() {
  local target_port backup_dir main_config=/etc/ssh/sshd_config main_previous
  target_port="$(config_value ssh port)"
  [[ "${VPS_INIT_VERIFIED_SSH:-0}" == 1 ]] || die 'Refusing SSH finalize: --verified-ssh is required.'
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info "[DRY-RUN] keep only hardened SSH port ${target_port}"; return; fi
  require_root; require_command sshd
  backup_dir="${VPS_INIT_STATE_DIR}/backups/ssh"; backup_file "$SSH_CANDIDATE" "$backup_dir"; backup_file "$main_config" "$backup_dir"
  main_previous="${main_config}.tu-devkit-previous"; cp -a "$main_config" "$main_previous"
  # Ubuntu's main file can contain a provider-defined active Port. The managed
  # drop-in becomes authoritative during finalize, while the backup remains recoverable.
  sed -Ei 's/^([[:space:]]*)Port[[:space:]]+([0-9]+)([[:space:]]*(#.*)?)$/\1# tu-devkit previous Port \2\3/' "$main_config"
  if ! write_ssh_policy "$target_port"; then
    mv -f "$main_previous" "$main_config"
    die 'SSH finalize failed; the main SSH configuration was restored.'
  fi
  rm -f "$main_previous"
  info "SSH hardening finalized on port ${target_port}."
}
