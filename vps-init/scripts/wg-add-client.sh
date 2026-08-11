#!/usr/bin/env bash
# shellcheck disable=SC1091 # Module paths are resolved from this script at runtime.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"; source "$ROOT/lib/config.sh"
alias_name="${1:-}"; [[ "$alias_name" =~ ^[a-zA-Z0-9_-]{1,32}$ ]] || die 'Client alias must contain only letters, numbers, _, or -.'
CONFIG_FILE="${CONFIG_FILE:-$ROOT/config/vps.local.yaml}"; validate_config; require_root; require_command wg
client_dir="${VPS_INIT_STATE_DIR}/clients"; ensure_private_dir "$client_dir"; [[ ! -e "$client_dir/$alias_name.conf" ]] || die "Client already exists: $alias_name"
if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info "[DRY-RUN] create WireGuard client $alias_name"; exit 0; fi
umask 077; private="$(wg genkey)"; public="$(printf '%s' "$private" | wg pubkey)"; server_public="$(< /etc/wireguard/server_public.key)"
cidr="$(config_value wireguard ipv4_cidr)"; prefix="${cidr%.*}"; index=$(( $(find "$client_dir" -name '*.conf' -type f | wc -l) + 2 )); address="${prefix}.${index}/${cidr#*/}"
endpoint="$(public_endpoint)"; [[ -n "$endpoint" ]] || die 'server.public_endpoint must be set before creating a client.'
cat > "$client_dir/$alias_name.conf" <<EOF
[Interface]
PrivateKey = ${private}
Address = ${address}
[Peer]
PublicKey = ${server_public}
Endpoint = ${endpoint}:$(config_value wireguard port)
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
chmod 600 "$client_dir/$alias_name.conf"
wg set wg0 peer "$public" allowed-ips "${address%/*}/32"
cat >> /etc/wireguard/wg0.conf <<EOF

# tu-devkit client: ${alias_name}
[Peer]
PublicKey = ${public}
AllowedIPs = ${address%/*}/32
EOF
chmod 600 /etc/wireguard/wg0.conf
info "Created client configuration at $client_dir/$alias_name.conf"
