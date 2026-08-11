#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2317 # Dynamic module sources; check() invokes functions indirectly.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/common.sh"; source "$ROOT/lib/config.sh"; source "$ROOT/lib/state.sh"
CONFIG_FILE="$ROOT/config/vps.local.yaml"; expected=''
while [[ $# -gt 0 ]]; do case "$1" in
  --config) [[ $# -ge 2 ]] || die '--config requires a file.'; CONFIG_FILE="$2"; shift 2;;
  --profile) [[ $# -ge 2 ]] || die '--profile requires a value.'; expected="$2"; shift 2;;
  -h|--help) echo 'Usage: ./doctor.sh [--config FILE] [--profile quick|secure-transition|secure]'; exit 0;;
  *) die "Unknown argument: $1";;
esac; done
validate_config
profile="${expected:-$(read_profile_state)}"
[[ "$profile" == quick || "$profile" == secure-transition || "$profile" == secure ]] || die 'No valid install state found; pass --profile explicitly or run a profile install.'
failed=0
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then printf 'OK   %s\n' "$label"; else printf 'FAIL %s\n' "$label"; failed=1; fi
}
ufw_rule_present() { ufw status | grep -Fq "$1"; }
port_listening() { ss -H -ltn | awk '{print $4}' | grep -Eq ":$1$"; }
check_sing_box_key() {
  local password_file="$1" key_length="$2" password
  [[ -s "$password_file" ]] || return 1
  password="$(< "$password_file")"; is_base64_key_length "$password" "$key_length"
}
current_port="$(config_value_or ssh current_port 22)"; target_port="$(config_value ssh port)"
check 'UFW active' bash -c 'ufw status | grep -q "Status: active"'
check 'fail2ban active' systemctl is-active --quiet fail2ban
case "$profile" in
  quick)
    check "current SSH port ${current_port} listening" port_listening "$current_port"
    check "current SSH port ${current_port}/tcp allowed" ufw_rule_present "${current_port}/tcp"
    ;;
  secure-transition)
    check "current SSH port ${current_port} listening" port_listening "$current_port"
    check "target SSH port ${target_port} listening" port_listening "$target_port"
    check "current SSH port ${current_port}/tcp allowed" ufw_rule_present "${current_port}/tcp"
    check "target SSH port ${target_port}/tcp allowed" ufw_rule_present "${target_port}/tcp"
    ;;
  secure)
    check "hardened SSH port ${target_port} listening" port_listening "$target_port"
    check "hardened SSH port ${target_port}/tcp allowed" ufw_rule_present "${target_port}/tcp"
    check 'SSH password authentication disabled' grep -Eq '^PasswordAuthentication no$' /etc/ssh/sshd_config.d/99-tu-devkit-vps-init.conf
    ;;
esac
password_file="${SING_BOX_PASSWORD_FILE:-${VPS_INIT_STATE_DIR}/secrets/sing-box-password}"
method="$(config_value sing_box method)"; key_length="$(shadowsocks_key_length "$method")"
check 'sing-box active' systemctl is-active --quiet sing-box
check 'sing-box configuration valid' sing-box check -c /etc/sing-box/config.json
check "sing-box port $(config_value sing_box port)/tcp allowed" ufw_rule_present "$(config_value sing_box port)/tcp"
check "sing-box ${key_length}-byte key valid" check_sing_box_key "$password_file" "$key_length"
check 'sing-box installed version recorded' test -s "${VPS_INIT_STATE_DIR}/sing-box-version"
if [[ "$profile" == secure-transition || "$profile" == secure ]]; then
  check 'WireGuard wg0 active' systemctl is-active --quiet wg-quick@wg0
  check "WireGuard port $(config_value wireguard port)/udp allowed" ufw_rule_present "$(config_value wireguard port)/udp"
fi
if [[ "$profile" == secure-transition ]]; then
  printf '\nNEXT Verify a new key-only SSH session on port %s, then run:\n' "$target_port"
  printf "  ./install.sh --profile secure --finalize --verified-ssh --config '%s'\n" "$CONFIG_FILE"
fi
exit "$failed"
