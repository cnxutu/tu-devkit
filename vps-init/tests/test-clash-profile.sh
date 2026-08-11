#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cp "$ROOT/config/vps.example.yaml" "$tmp/vps.local.yaml"
printf '%s\n' 'test-only-password' > "$tmp/sing-box-password"

CONFIG_FILE="$tmp/vps.local.yaml" \
SING_BOX_ENDPOINT='192.0.2.1' \
SING_BOX_PASSWORD_FILE="$tmp/sing-box-password" \
VPS_INIT_OUTPUT_DIR="$tmp/output" \
VPS_INIT_STATE_DIR="$tmp/state" \
bash "$ROOT/scripts/generate-clash-profile.sh" >/dev/null

profile="$tmp/output/vps-clash.yaml"
[[ -f "$profile" ]] || { echo 'Clash profile was not generated' >&2; exit 1; }
grep -Fq '    udp: false' "$profile"
grep -Fq "  - 'AND,((NETWORK,UDP),(DST-PORT,443)),REJECT'" "$profile"
if grep -Fq 'disable-quic:' "$profile"; then
  echo 'unsupported disable-quic setting found in generated profile' >&2
  exit 1
fi

reject_line="$(grep -nF "  - 'AND,((NETWORK,UDP),(DST-PORT,443)),REJECT'" "$profile" | cut -d: -f1)"
match_line="$(grep -nF '  - MATCH,Proxy' "$profile" | cut -d: -f1)"
(( reject_line < match_line )) || { echo 'UDP/443 rejection must precede MATCH' >&2; exit 1; }
[[ "$(stat -c '%a' "$profile")" == 600 ]] || { echo 'Clash profile permissions must be 600' >&2; exit 1; }
printf 'vps-init Clash profile test passed\n'
