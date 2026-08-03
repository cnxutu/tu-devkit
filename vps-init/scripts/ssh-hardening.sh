#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/config.sh"

harden_ssh() {
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info "[DRY-RUN] validate and apply SSH policy on port $(config_value ssh port)"; return 0; fi
  require_root; require_command sshd
  local port backup_dir candidate key_file candidate_tmp previous root_login
  port="$(config_value ssh port)"; backup_dir="${VPS_INIT_STATE_DIR}/backups/ssh"; candidate="/etc/ssh/sshd_config.d/99-tu-devkit-vps-init.conf"; key_file="$(config_value ssh admin_authorized_keys_path)"
  [[ -s "$key_file" ]] || die "Refusing SSH hardening: administrator key file is empty or missing: $key_file"
  root_login=no; [[ "$(config_bool ssh disable_root_login)" == false ]] && root_login=prohibit-password
  command -v ufw >/dev/null 2>&1 && ufw status | grep -Fq "${port}/tcp" || die "Refusing SSH hardening: ${port}/tcp is not open in UFW."
  confirm 'Confirm a second terminal can log in using the configured administrator SSH key?' || die 'SSH hardening cancelled.'
  backup_file "$candidate" "$backup_dir"; candidate_tmp="$(mktemp)"; previous="${candidate}.previous"
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info "[DRY-RUN] write $candidate"; return 0; fi
  install -d -m 755 /etc/ssh/sshd_config.d
  cat > "$candidate_tmp" <<EOF
# Managed by tu-devkit vps-init. Remove this file to revert this module's SSH policy.
Port ${port}
PermitRootLogin ${root_login}
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
PubkeyAuthentication yes
EOF
  [[ -e "$candidate" ]] && cp -a "$candidate" "$previous"
  install -m 600 "$candidate_tmp" "$candidate"; rm -f "$candidate_tmp"
  if ! sshd -t; then
    [[ -e "$previous" ]] && mv -f "$previous" "$candidate" || rm -f "$candidate"
    die 'Candidate SSH configuration is invalid; this module configuration was restored.'
  fi
  if ! systemctl reload ssh && ! systemctl reload sshd; then
    [[ -e "$previous" ]] && mv -f "$previous" "$candidate" || rm -f "$candidate"
    die 'SSH reload failed; this module configuration was restored.'
  fi
  rm -f "$previous"
  info 'SSH hardening applied. Verify a new SSH session before closing the current one.'
}
