#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="$ROOT/config/clash-verge-sing-box-minimal.template.yaml"

grep -Fqx 'mixed-port: 7897' "$profile"
grep -Fqx 'mode: rule' "$profile"
grep -Fqx 'ipv6: false' "$profile"
grep -Fqx '    type: ss' "$profile"
grep -Fqx '    server: "<SING_BOX_PUBLIC_HOST>"' "$profile"
grep -Fqx '    port: <SING_BOX_TCP_PORT>' "$profile"
grep -Fqx '    password: "<SING_BOX_PASSWORD>"' "$profile"
grep -Fqx '    udp: false' "$profile"
grep -Fqx '  - MATCH,🚀 VPS' "$profile"
grep -Fqx "  - 'AND,((NETWORK,UDP),(DST-PORT,443)),REJECT'" "$profile"

if grep -Eq '^tun:|VPS-WireGuard|^dns:|type: fallback|^[[:space:]]+- DIRECT$' "$profile"; then
  echo 'minimal sing-box Clash profile includes an out-of-scope feature' >&2
  exit 1
fi

printf 'vps-init minimal sing-box Clash profile test passed\n'
