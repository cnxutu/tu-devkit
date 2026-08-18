#!/usr/bin/env bash
# shellcheck disable=SC1091 # Module paths are resolved from this script at runtime.
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/config.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/sing-box-repository.sh"

setup_sing_box() {
  feature_enabled sing_box || { info 'sing-box is disabled; skipping.'; return 0; }
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info "[DRY-RUN] install and configure sing-box on TCP $(config_value sing_box port)"; return 0; fi
  require_root
  local password_file password port listen method key_length
  password_file="${SING_BOX_PASSWORD_FILE:-${VPS_INIT_STATE_DIR}/secrets/sing-box-password}"
  port="$(config_value sing_box port)"; listen="$(config_value sing_box listen)"; method="$(config_value sing_box method)"
  key_length="$(shadowsocks_key_length "$method")" || die 'Unsupported Shadowsocks 2022 method.'
  [[ "$listen" != 0.0.0.0 ]] || confirm "Expose sing-box on ${listen}:${port}?" || die 'sing-box setup cancelled.'
  install_sing_box_stable
  ensure_private_dir "$(dirname "$password_file")"
  if [[ ! -s "$password_file" ]]; then umask 077; sing-box generate rand --base64 "$key_length" > "$password_file"; chmod 600 "$password_file"; fi
  password="$(< "$password_file")"
  is_base64_key_length "$password" "$key_length" || die "Existing sing-box password is not a valid ${key_length}-byte key for ${method}; rotate it together with every client profile."
  local candidate=/etc/sing-box/config.json config_tmp previous
  install -d -m 750 /etc/sing-box
  backup_file "$candidate" "${VPS_INIT_STATE_DIR}/backups/sing-box"
  config_tmp="$(mktemp)"; previous="${candidate}.previous"
  cat > "$config_tmp" <<EOF
{"dns":{"servers":[{"type":"local","tag":"local"}],"strategy":"ipv4_only"},"route":{"default_domain_resolver":{"server":"local","strategy":"ipv4_only"}},"inbounds":[{"type":"shadowsocks","listen":"${listen}","listen_port":${port},"network":"tcp","method":"${method}","password":"${password}","multiplex":{"enabled":true,"padding":false}}]}
EOF
  [[ -e "$candidate" ]] && cp -a "$candidate" "$previous"
  install -m 600 "$config_tmp" "$candidate"; rm -f "$config_tmp"
  if ! sing-box check -c "$candidate"; then
    if [[ -e "$previous" ]]; then mv -f "$previous" "$candidate"; else rm -f "$candidate"; fi
    die 'sing-box configuration is invalid; the previous module configuration was restored.'
  fi
  rm -f "$previous"
  systemctl enable --now sing-box
  info 'sing-box is configured; its password is stored only in the protected local secret file.'
}
