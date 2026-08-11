#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
grep -Fq 'vps.local.yaml' "$ROOT/.gitignore"
grep -Fq 'output/' "$ROOT/.gitignore"
grep -Fq 'Refusing SSH hardening' "$ROOT/scripts/ssh-hardening.sh"
grep -Fq 'sshd -t' "$ROOT/scripts/ssh-hardening.sh"
grep -Fq 'chmod 600 /etc/wireguard/wg0.conf' "$ROOT/scripts/wireguard.sh"
grep -Fq '# tu-devkit client:' "$ROOT/scripts/wg-add-client.sh"
grep -Fq '/etc/wireguard/wg0.conf' "$ROOT/scripts/wg-remove-client.sh"
grep -Fq 'chmod 600 /etc/sing-box/config.json' "$ROOT/scripts/sing-box.sh"
grep -Fq 'SING_BOX_PASSWORD_FILE' "$ROOT/scripts/generate-clash-profile.sh"
grep -Fq '    udp: false' "$ROOT/scripts/generate-clash-profile.sh"
grep -Fq "  - 'AND,((NETWORK,UDP),(DST-PORT,443)),REJECT'" "$ROOT/scripts/generate-clash-profile.sh"
grep -Fq '    udp: false' "$ROOT/config/clash-verge-profile.template.yaml"
grep -Fq "  - 'AND,((NETWORK,UDP),(DST-PORT,443)),REJECT'" "$ROOT/config/clash-verge-profile.template.yaml"
if grep -Fq 'disable-quic:' "$ROOT/scripts/generate-clash-profile.sh" || grep -Fq 'disable-quic:' "$ROOT/config/clash-verge-profile.template.yaml"; then
  echo 'unsupported disable-quic setting found in Clash configuration' >&2
  exit 1
fi
reject_line="$(grep -nF "  - 'AND,((NETWORK,UDP),(DST-PORT,443)),REJECT'" "$ROOT/config/clash-verge-profile.template.yaml" | cut -d: -f1)"
first_business_rule_line="$(grep -nF '  - DOMAIN-SUFFIX,dingtalk.com,' "$ROOT/config/clash-verge-profile.template.yaml" | cut -d: -f1)"
(( reject_line < first_business_rule_line )) || { echo 'UDP/443 rejection must precede business rules' >&2; exit 1; }
printf 'vps-init security contract test passed\n'
