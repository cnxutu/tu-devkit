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
check 'UFW active' bash -c 'ufw status | grep -q "Status: active"'
check "SSH port $(config_value ssh port) allowed" bash -c "ufw status | grep -Fq '$(config_value ssh port)/tcp'"
check 'fail2ban active' systemctl is-active --quiet fail2ban
if [[ "$(config_bool wireguard enabled)" == true ]]; then check 'WireGuard wg0 active' systemctl is-active --quiet wg-quick@wg0; fi
if [[ "$(config_bool sing_box enabled)" == true ]]; then check 'sing-box active' systemctl is-active --quiet sing-box; fi
exit "$failed"
