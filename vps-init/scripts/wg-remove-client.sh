#!/usr/bin/env bash
# shellcheck disable=SC1091 # Module paths are resolved from this script at runtime.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
alias_name="${1:-}"; [[ "$alias_name" =~ ^[a-zA-Z0-9_-]{1,32}$ ]] || die 'Invalid client alias.'
client_dir="${VPS_INIT_STATE_DIR}/clients"; file="$client_dir/$alias_name.conf"; [[ -f "$file" ]] || die "Client not found: $alias_name"
confirm "Revoke WireGuard client $alias_name?" || die 'Client removal cancelled.'
if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info "[DRY-RUN] revoke $alias_name"; exit 0; fi
private="$(awk -F' = ' '/^PrivateKey/ {print $2; exit}' "$file")"; public="$(printf '%s' "$private" | wg pubkey)"
wg set wg0 peer "$public" remove
tmp="$(mktemp)"
awk -v marker="# tu-devkit client: ${alias_name}" '
  $0 == marker { drop=1; next }
  drop && /^\[Peer\]$/ { next }
  drop && /^PublicKey = / { next }
  drop && /^AllowedIPs = / { drop=0; next }
  { print }
' /etc/wireguard/wg0.conf > "$tmp"
install -m 600 "$tmp" /etc/wireguard/wg0.conf; rm -f "$tmp"
rm -f -- "$file"
info "Revoked client $alias_name."
