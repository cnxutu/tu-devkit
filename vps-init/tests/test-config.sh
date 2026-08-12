#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034 # Dynamic sources consume CONFIG_FILE.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cp "$ROOT/config/vps.example.yaml" "$tmp/good.yaml"
source "$ROOT/lib/common.sh"; source "$ROOT/lib/config.sh"; CONFIG_FILE="$tmp/good.yaml"; validate_config
[[ "$(config_value_or ssh current_port 22)" == 22 ]]
[[ "$(config_value_or fail2ban maxretry 5)" == 5 ]]
[[ "$(config_value_or wireguard client_mode full)" == full ]]
[[ "$(wireguard_client_allowed_ips)" == 0.0.0.0/0 ]]
[[ "$(config_value_or clash_remote enabled false)" == false ]]
SING_BOX_ENDPOINT=198.51.100.7; export SING_BOX_ENDPOINT
[[ "$(public_endpoint)" == 198.51.100.7 ]]
unset SING_BOX_ENDPOINT
sed 's/port: 22222/port: 70000/' "$tmp/good.yaml" > "$tmp/bad.yaml"
CONFIG_FILE="$tmp/bad.yaml"; if (validate_config) >/dev/null 2>&1; then echo 'invalid port accepted' >&2; exit 1; fi
sed 's/10.66.66.0\/24/999.66.66.0\/24/' "$tmp/good.yaml" > "$tmp/bad-cidr.yaml"
CONFIG_FILE="$tmp/bad-cidr.yaml"; if (validate_config) >/dev/null 2>&1; then echo 'invalid CIDR accepted' >&2; exit 1; fi
[[ "$(shadowsocks_key_length 2022-blake3-aes-128-gcm)" == 16 ]]
[[ "$(shadowsocks_key_length 2022-blake3-aes-256-gcm)" == 32 ]]
is_base64_key_length 'MDEyMzQ1Njc4OWFiY2RlZg==' 16
if is_base64_key_length 'dG9vLXNob3J0' 16; then echo 'invalid Shadowsocks key length accepted' >&2; exit 1; fi
sed 's/maxretry: 5/maxretry: 0/' "$tmp/good.yaml" > "$tmp/bad-fail2ban.yaml"
CONFIG_FILE="$tmp/bad-fail2ban.yaml"; if (validate_config) >/dev/null 2>&1; then echo 'invalid fail2ban maxretry accepted' >&2; exit 1; fi
sed 's/client_mode: full/client_mode: invalid/' "$tmp/good.yaml" > "$tmp/bad-client-mode.yaml"
CONFIG_FILE="$tmp/bad-client-mode.yaml"; if (validate_config) >/dev/null 2>&1; then echo 'invalid WireGuard client mode accepted' >&2; exit 1; fi
sed 's/client_mode: full/client_mode: management/' "$tmp/good.yaml" > "$tmp/management.yaml"
CONFIG_FILE="$tmp/management.yaml"; validate_config; [[ "$(wireguard_client_allowed_ips)" == 10.66.66.0/24 ]]
sed 's/port: 18080/port: 8080/' "$tmp/good.yaml" > "$tmp/bad-remote-port.yaml"
CONFIG_FILE="$tmp/bad-remote-port.yaml"; if (validate_config) >/dev/null 2>&1; then echo 'conflicting Clash Remote port accepted' >&2; exit 1; fi
printf 'vps-init config test passed\n'
