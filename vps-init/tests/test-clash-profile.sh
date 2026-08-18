#!/usr/bin/env bash
# shellcheck disable=SC1091 # Test sources the package helper through a computed root.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
source "$ROOT/lib/common.sh"
cp "$ROOT/config/vps.example.yaml" "$tmp/vps.local.yaml"
printf '%s\n' 'MDEyMzQ1Njc4OWFiY2RlZg==' > "$tmp/sing-box-password"

CONFIG_FILE="$tmp/vps.local.yaml" \
SING_BOX_ENDPOINT='192.0.2.1' \
SING_BOX_PASSWORD_FILE="$tmp/sing-box-password" \
VPS_INIT_OUTPUT_DIR="$tmp/output" \
VPS_INIT_STATE_DIR="$tmp/state" \
bash "$ROOT/scripts/generate-clash-profile.sh" >/dev/null

profile="$tmp/output/vps-clash.yaml"
[[ -f "$profile" ]] || { echo 'Clash profile was not generated' >&2; exit 1; }
grep -Fq 'mixed-port: 7890' "$profile"
grep -Fq '    server: "192.0.2.1"' "$profile"
grep -Fq '    password: "MDEyMzQ1Njc4OWFiY2RlZg=="' "$profile"
grep -Fq '    udp: false' "$profile"
grep -Fq 'keep-alive-interval: 15' "$profile"
grep -Fq 'keep-alive-idle: 15' "$profile"
grep -Fq 'disable-keep-alive: false' "$profile"
if grep -Eq '^[[:space:]]*smux:|protocol:[[:space:]]*h2mux' "$profile"; then
  echo 'Clash profile must not enable smux for Codex long connections' >&2
  exit 1
fi
grep -Fq 'tun:' "$profile"
grep -Fq '  enable: true' "$profile"
grep -Fq '  auto-route: true' "$profile"
grep -Fq '  auto-detect-interface: true' "$profile"
grep -Fq '  strict-route: true' "$profile"
grep -Fq '    - any:53' "$profile"
grep -Fq '  listen: 127.0.0.1:1053' "$profile"
grep -Fq '  respect-rules: true' "$profile"
grep -Fq '  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve' "$profile"
grep -Fq "  - 'AND,((NETWORK,UDP),(DST-PORT,443)),REJECT'" "$profile"
grep -Fq '  - DOMAIN-SUFFIX,github.com,🚀 Proxy' "$profile"
grep -Fq '  - name: 🎬 Entertainment' "$profile"
grep -Fq '  - name: 🤖 AI Development' "$profile"
grep -Fq '    type: fallback' "$profile"
grep -Fq '    url: https://chatgpt.com/favicon.ico' "$profile"
grep -Fq '    lazy: false' "$profile"
grep -Fq '    max-failed-times: 2' "$profile"
grep -Fq '    disable-udp: true' "$profile"
grep -Fq '  - DOMAIN-SUFFIX,chatgpt.com,🤖 AI Development' "$profile"
grep -Fq '  - DOMAIN-SUFFIX,openai.com,🤖 AI Development' "$profile"
if sed -n '/  - name: 🤖 AI Development/,/  - name: 🚀 Proxy/p' "$profile" | grep -Fq '      - DIRECT'; then
  echo 'AI Development group must not allow DIRECT' >&2
  exit 1
fi
grep -Fq '  - DOMAIN-SUFFIX,youtube.com,🎬 Entertainment' "$profile"
grep -Fq '  - name: 🎮 Steam CDN' "$profile"
grep -Fq '  - DOMAIN-SUFFIX,steamstatic.com,🎮 Steam CDN' "$profile"
grep -Fq "    '+.steamstatic.com':" "$profile"
grep -Fq "    - '+.steamstatic.com'" "$profile"
if grep -Fq 'GEOSITE,' "$profile"; then
  echo 'Clash profile must not require GeoSite.dat for cold start' >&2
  exit 1
fi
if grep -Fq 'disable-quic:' "$profile"; then
  echo 'unsupported disable-quic setting found in generated profile' >&2
  exit 1
fi
if grep -Eq 'your\.server\.example|CHANGE_ME' "$profile"; then
  echo 'Clash profile contains unresolved placeholders' >&2
  exit 1
fi
if grep -Eq 'VPS-WireGuard|WIREGUARD_PROXY|your\.wireguard\.server' "$profile"; then
  echo 'Clash profile contains a WireGuard node while WireGuard is disabled' >&2
  exit 1
fi

private_line="$(grep -nF '  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve' "$profile" | cut -d: -f1)"
reject_line="$(grep -nF "  - 'AND,((NETWORK,UDP),(DST-PORT,443)),REJECT'" "$profile" | cut -d: -f1)"
business_line="$(grep -nF '  - DOMAIN-SUFFIX,dingtalk.com,' "$profile" | cut -d: -f1)"
geoip_line="$(grep -nF "  - 'GEOIP,CN,DIRECT'" "$profile" | cut -d: -f1)"
match_line="$(grep -nF "  - 'MATCH,🚀 Proxy'" "$profile" | cut -d: -f1)"
steam_cdn_line="$(grep -nF '  - DOMAIN-SUFFIX,steamstatic.com,🎮 Steam CDN' "$profile" | cut -d: -f1)"
steam_web_line="$(grep -nF '  - DOMAIN-SUFFIX,steamcommunity.com,🎬 Entertainment' "$profile" | cut -d: -f1)"
(( private_line < reject_line && reject_line < business_line && business_line < steam_cdn_line && steam_cdn_line < steam_web_line && steam_web_line < geoip_line && geoip_line < match_line )) || {
  echo 'Clash routing rule order is invalid' >&2
  exit 1
}
[[ "$(file_mode "$profile")" == 600 ]] || { echo 'Clash profile permissions must be 600' >&2; exit 1; }

sed '/^wireguard:/,/^sing_box:/ s/  enabled: false/  enabled: true/' "$tmp/vps.local.yaml" > "$tmp/vps-wg.yaml"
CONFIG_FILE="$tmp/vps-wg.yaml" \
SING_BOX_ENDPOINT='192.0.2.1' \
SING_BOX_PASSWORD_FILE="$tmp/sing-box-password" \
VPS_INIT_OUTPUT_DIR="$tmp/output-wg" \
VPS_INIT_STATE_DIR="$tmp/state" \
bash "$ROOT/scripts/generate-clash-profile.sh" >/dev/null
wg_profile="$tmp/output-wg/vps-clash.yaml"
grep -Fq '  - name: "VPS-WireGuard"' "$wg_profile"
grep -Fq '    server: "10.66.66.1"' "$wg_profile"
[[ "$(grep -Fc '    password: "MDEyMzQ1Njc4OWFiY2RlZg=="' "$wg_profile")" == 2 ]]
if grep -Eq 'WIREGUARD_PROXY|your\.wireguard\.server' "$wg_profile"; then
  echo 'WireGuard Clash profile contains unresolved generator markers' >&2
  exit 1
fi
wg_group="$(sed -n '/  - name: 🤖 AI Development/,/  - name: 🚀 Proxy/p' "$wg_profile")"
grep -Fq '      - VPS-WireGuard' <<< "$wg_group"
grep -Fq '      - VPS-SantaClara' <<< "$wg_group"
wg_node_line="$(grep -nF '      - VPS-WireGuard' <<< "$wg_group" | cut -d: -f1)"
public_node_line="$(grep -nF '      - VPS-SantaClara' <<< "$wg_group" | cut -d: -f1)"
(( wg_node_line < public_node_line )) || { echo 'WireGuard node must precede the public fallback' >&2; exit 1; }

sed 's/2022-blake3-aes-128-gcm/2022-blake3-aes-256-gcm/' "$tmp/vps.local.yaml" > "$tmp/vps-256.yaml"
printf '%s\n' 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=' > "$tmp/sing-box-password-256"
CONFIG_FILE="$tmp/vps-256.yaml" \
SING_BOX_ENDPOINT='192.0.2.1' \
SING_BOX_PASSWORD_FILE="$tmp/sing-box-password-256" \
VPS_INIT_OUTPUT_DIR="$tmp/output-256" \
VPS_INIT_STATE_DIR="$tmp/state" \
bash "$ROOT/scripts/generate-clash-profile.sh" >/dev/null
grep -Fq '    cipher: 2022-blake3-aes-256-gcm' "$tmp/output-256/vps-clash.yaml"
grep -Fq '    password: "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY="' "$tmp/output-256/vps-clash.yaml"

if CONFIG_FILE="$tmp/vps.local.yaml" \
  SING_BOX_ENDPOINT='invalid endpoint' \
  SING_BOX_PASSWORD_FILE="$tmp/sing-box-password" \
  VPS_INIT_OUTPUT_DIR="$tmp/invalid-output" \
  VPS_INIT_STATE_DIR="$tmp/state" \
  bash "$ROOT/scripts/generate-clash-profile.sh" >/dev/null 2>&1; then
  echo 'invalid Clash endpoint was accepted' >&2
  exit 1
fi
printf '%s\n' 'dG9vLXNob3J0' > "$tmp/invalid-password"
if CONFIG_FILE="$tmp/vps.local.yaml" \
  SING_BOX_ENDPOINT='192.0.2.1' \
  SING_BOX_PASSWORD_FILE="$tmp/invalid-password" \
  VPS_INIT_OUTPUT_DIR="$tmp/invalid-key-output" \
  VPS_INIT_STATE_DIR="$tmp/state" \
  bash "$ROOT/scripts/generate-clash-profile.sh" >/dev/null 2>&1; then
  echo 'invalid Shadowsocks 2022 key length was accepted' >&2
  exit 1
fi
printf 'vps-init Clash profile test passed\n'
