#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"; source "$ROOT/lib/config.sh"
CONFIG_FILE="${CONFIG_FILE:-$ROOT/config/vps.local.yaml}"; validate_config
if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info '[DRY-RUN] create protected Clash profile'; exit 0; fi
endpoint="${SING_BOX_ENDPOINT:-}"; [[ -n "$endpoint" ]] || die 'Set SING_BOX_ENDPOINT to the server hostname or public IP.'
password_file="${SING_BOX_PASSWORD_FILE:-${VPS_INIT_STATE_DIR}/secrets/sing-box-password}"; [[ -s "$password_file" ]] || die 'sing-box password file is missing.'
output_dir="${VPS_INIT_OUTPUT_DIR:-$ROOT/output}"; ensure_private_dir "$output_dir"; output="$output_dir/vps-clash.yaml"
cat > "$output" <<EOF
proxies:
  - name: VPS
    type: ss
    server: ${endpoint}
    port: $(config_value sing_box port)
    cipher: $(config_value sing_box method)
    password: $(< "$password_file")
proxy-groups:
  - name: Proxy
    type: select
    proxies: [VPS]
rules: [MATCH,Proxy]
EOF
chmod 600 "$output"; info "Created protected Clash profile at $output"
