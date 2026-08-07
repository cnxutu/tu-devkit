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
grep -Fq 'disable-quic: true' "$ROOT/scripts/generate-clash-profile.sh"
grep -Fq '    udp: false' "$ROOT/scripts/generate-clash-profile.sh"
printf 'vps-init security contract test passed\n'
