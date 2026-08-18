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
port_listening_only_on() {
  local address="$1" port="$2" listeners
  listeners="$(ss -H -ltn | awk -v suffix=":${port}" '$4 ~ suffix "$" {print $4}')"
  [[ -n "$listeners" ]] && [[ "$listeners" == "${address}:${port}" ]]
}
expected_capability() {
  local capability="$1"
  if [[ -f "$CAPABILITIES_STATE_FILE" ]]; then capability_recorded "$capability"; return; fi
  [[ "$capability" == sing-box ]] && return 0
  [[ "$capability" == wireguard && ( "$profile" == secure-transition || "$profile" == secure ) ]]
}
check_remote_health() {
  local url_file="$1" url
  [[ -s "$url_file" ]] || return 1
  url="$(< "$url_file")"
  printf 'url = "%s"\n' "$url" | curl --fail --silent --output /dev/null --config -
}
check_sing_box_key() {
  local password_file="$1" key_length="$2" password
  [[ -s "$password_file" ]] || return 1
  password="$(< "$password_file")"; is_base64_key_length "$password" "$key_length"
}
check_sing_box_stability() {
  jq -e '
    any(.inbounds[];
      .type == "shadowsocks" and
      .multiplex.enabled == true and
      ((.multiplex.padding // false) == false)
    ) and
    .dns.strategy == "ipv4_only" and
    .route.default_domain_resolver.strategy == "ipv4_only"
  ' /etc/sing-box/config.json >/dev/null
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
check 'sing-box multiplex padding and IPv4 resolver stable' check_sing_box_stability
check "sing-box port $(config_value sing_box port)/tcp allowed" ufw_rule_present "$(config_value sing_box port)/tcp"
check "sing-box ${key_length}-byte key valid" check_sing_box_key "$password_file" "$key_length"
check 'sing-box installed version recorded' test -s "${VPS_INIT_STATE_DIR}/sing-box-version"
if expected_capability wireguard; then
  check 'WireGuard wg0 active' systemctl is-active --quiet wg-quick@wg0
  check "WireGuard port $(config_value wireguard port)/udp allowed" ufw_rule_present "$(config_value wireguard port)/udp"
fi
if expected_capability clash-remote; then
  remote_bind="$(wireguard_server_ip)"; remote_port="$(config_value_or clash_remote port 18080)"
  remote_url_file="${VPS_INIT_STATE_DIR}/secrets/clash-remote-url"
  check 'Clash Remote service active' systemctl is-active --quiet tu-devkit-clash-remote.service
  check "Clash Remote bound only to ${remote_bind}:${remote_port}" port_listening_only_on "$remote_bind" "$remote_port"
  check 'Clash Remote UFW rule limited to wg0' ufw_rule_present "tu-devkit-vps-init clash-remote-${remote_port}"
  check 'Clash Remote published profile permission is 640' test "$(file_mode "${VPS_INIT_STATE_DIR}/subscriptions/vps-clash.yaml" 2>/dev/null)" = 640
  check 'Clash Remote URL permission is 600' test "$(file_mode "$remote_url_file" 2>/dev/null)" = 600
  check 'Clash Remote private HTTP health' check_remote_health "$remote_url_file"
fi
if [[ "$profile" == secure-transition ]]; then
  printf '\nNEXT Verify a new key-only SSH session on port %s, then run:\n' "$target_port"
  printf "  ./install.sh --profile secure --finalize --verified-ssh --config '%s'\n" "$CONFIG_FILE"
fi
exit "$failed"
