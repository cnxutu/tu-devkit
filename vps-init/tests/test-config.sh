#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cp "$ROOT/config/vps.example.yaml" "$tmp/good.yaml"
source "$ROOT/lib/common.sh"; source "$ROOT/lib/config.sh"; CONFIG_FILE="$tmp/good.yaml"; validate_config
sed 's/port: 22222/port: 70000/' "$tmp/good.yaml" > "$tmp/bad.yaml"
CONFIG_FILE="$tmp/bad.yaml"; if (validate_config) >/dev/null 2>&1; then echo 'invalid port accepted' >&2; exit 1; fi
sed 's/10.66.66.0\/24/999.66.66.0\/24/' "$tmp/good.yaml" > "$tmp/bad-cidr.yaml"
CONFIG_FILE="$tmp/bad-cidr.yaml"; if (validate_config) >/dev/null 2>&1; then echo 'invalid CIDR accepted' >&2; exit 1; fi
[[ "$(shadowsocks_key_length 2022-blake3-aes-128-gcm)" == 16 ]]
[[ "$(shadowsocks_key_length 2022-blake3-aes-256-gcm)" == 32 ]]
is_base64_key_length 'MDEyMzQ1Njc4OWFiY2RlZg==' 16
if is_base64_key_length 'dG9vLXNob3J0' 16; then echo 'invalid Shadowsocks key length accepted' >&2; exit 1; fi
printf 'vps-init config test passed\n'
