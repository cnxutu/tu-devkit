#!/usr/bin/env bash
# shellcheck disable=SC1091 # Module paths are resolved from this script at runtime.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"; source "$ROOT/lib/config.sh"
CONFIG_FILE="${CONFIG_FILE:-$ROOT/config/vps.local.yaml}"; validate_config
if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info '[DRY-RUN] create protected Clash profile'; exit 0; fi
endpoint="$(public_endpoint)"; [[ -n "$endpoint" ]] || die 'Set server.public_endpoint (or SING_BOX_ENDPOINT) to the server hostname or public IP.'
[[ "$endpoint" =~ ^[a-zA-Z0-9._:-]+$ ]] || die 'The public endpoint contains unsupported characters.'
password_file="${SING_BOX_PASSWORD_FILE:-${VPS_INIT_STATE_DIR}/secrets/sing-box-password}"; [[ -s "$password_file" ]] || die 'sing-box password file is missing.'
password="$(< "$password_file")"
template="$ROOT/config/clash-verge-profile.template.yaml"; [[ -f "$template" ]] || die 'Clash profile template is missing.'
port="$(config_value sing_box port)"; method="$(config_value sing_box method)"; key_length="$(shadowsocks_key_length "$method")"
is_base64_key_length "$password" "$key_length" || die "sing-box password is not a valid ${key_length}-byte key for ${method}."
output_dir="${VPS_INIT_OUTPUT_DIR:-$ROOT/output}"; ensure_private_dir "$output_dir"; output="$output_dir/vps-clash.yaml"
output_tmp="$(mktemp "$output_dir/.vps-clash.XXXXXX")"; trap 'rm -f "$output_tmp"' EXIT
replacements=0
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    '    server: "your.server.example"') printf '    server: "%s"\n' "$endpoint"; (( replacements += 1 ));;
    '    port: 8080') printf '    port: %s\n' "$port"; (( replacements += 1 ));;
    '    cipher: 2022-blake3-aes-128-gcm') printf '    cipher: %s\n' "$method"; (( replacements += 1 ));;
    '    password: "CHANGE_ME"') printf '    password: "%s"\n' "$password"; (( replacements += 1 ));;
    *) printf '%s\n' "$line";;
  esac
done < "$template" > "$output_tmp"
[[ "$replacements" == 4 ]] || die 'Clash profile template placeholders are incomplete.'
chmod 600 "$output_tmp"; mv -f "$output_tmp" "$output"; trap - EXIT
info "Created protected Clash profile at $output"
