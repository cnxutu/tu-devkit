#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cp "$ROOT/config/vps.example.yaml" "$tmp/vps.local.yaml"
if bash "$ROOT/install.sh" --config "$tmp/vps.local.yaml" --phase unknown --dry-run >/dev/null 2>&1; then echo 'unknown phase accepted' >&2; exit 1; fi
bash "$ROOT/install.sh" --config "$tmp/vps.local.yaml" --phase base,firewall,ssh-hardening,wireguard,sing-box,clash --dry-run >/dev/null
grep -Fq 'VPS_INIT_DRY_RUN=1' "$ROOT/install.sh"
printf 'vps-init dry-run contract test passed\n'
