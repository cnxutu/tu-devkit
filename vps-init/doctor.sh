#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/common.sh"; source "$ROOT/lib/config.sh"
CONFIG_FILE="$ROOT/config/vps.local.yaml"; [[ $# -ge 2 && "$1" == --config ]] && CONFIG_FILE="$2"
validate_config
failed=0
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then printf 'OK   %s\n' "$label"; else printf 'FAIL %s\n' "$label"; failed=1; fi
}
check_sing_box_key() {
  local password_file="$1" key_length="$2" password
  [[ -s "$password_file" ]] || return 1
  password="$(< "$password_file")"
  is_base64_key_length "$password" "$key_length"
}
check 'UFW active' bash -c 'ufw status | grep -q "Status: active"'
check "SSH port $(config_value ssh port) allowed" bash -c "ufw status | grep -Fq '$(config_value ssh port)/tcp'"
check 'fail2ban active' systemctl is-active --quiet fail2ban
if [[ "$(config_bool wireguard enabled)" == true ]]; then check 'WireGuard wg0 active' systemctl is-active --quiet wg-quick@wg0; fi
if [[ "$(config_bool sing_box enabled)" == true ]]; then
  password_file="${SING_BOX_PASSWORD_FILE:-${VPS_INIT_STATE_DIR}/secrets/sing-box-password}"
  method="$(config_value sing_box method)"; key_length="$(shadowsocks_key_length "$method")"
  check 'sing-box active' systemctl is-active --quiet sing-box
  check 'sing-box configuration valid' sing-box check -c /etc/sing-box/config.json
  check "sing-box port $(config_value sing_box port)/tcp allowed" bash -c "ufw status | grep -Fq '$(config_value sing_box port)/tcp'"
  check "sing-box ${key_length}-byte key valid" check_sing_box_key "$password_file" "$key_length"
fi
exit "$failed"
