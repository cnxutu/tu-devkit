#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for file in install.sh doctor.sh wg-add-client.sh wg-remove-client.sh show-clash-remote-url.sh lib/common.sh lib/config.sh lib/state.sh config/vps.example.yaml config/wireguard-client.example.conf scripts/preflight.sh scripts/base.sh scripts/firewall.sh scripts/ssh-hardening.sh scripts/wireguard.sh scripts/wg-add-client.sh scripts/wg-remove-client.sh scripts/sing-box-repository.sh scripts/sing-box.sh scripts/generate-clash-profile.sh scripts/check-clash-runtime.ps1 scripts/clash-remote.sh scripts/clash-remote-server.py; do [[ -f "$ROOT/$file" ]]; done
grep -Fqx 'vps.local.yaml' "$ROOT/.gitignore"
grep -Fqx 'config/*.conf' "$ROOT/.gitignore"
grep -Fqx '!config/*.example.conf' "$ROOT/.gitignore"
grep -Fqx 'output/' "$ROOT/.gitignore"
printf 'vps-init layout test passed\n'
