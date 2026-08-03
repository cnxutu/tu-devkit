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
printf 'vps-init config test passed\n'
