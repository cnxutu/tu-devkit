#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/config.sh"

wg_server_address() { local cidr; cidr="$(config_value wireguard ipv4_cidr)"; printf '%s.1/%s\n' "${cidr%.*}" "${cidr#*/}"; }
wg_outbound_interface() {
  local value; value="$(config_value wireguard outbound_interface)"
  [[ -n "$value" ]] && { printf '%s\n' "$value"; return; }
  ip route show default | awk '/default/ {print $5; exit}'
}
setup_wireguard() {
  [[ "$(config_bool wireguard enabled)" == true ]] || { info 'WireGuard is disabled; skipping.'; return 0; }
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info "[DRY-RUN] install and configure WireGuard on UDP $(config_value wireguard port)"; return 0; fi
  require_root
  local port addr outbound private public
  port="$(config_value wireguard port)"; addr="$(wg_server_address)"; outbound="$(wg_outbound_interface)"
  [[ -n "$outbound" ]] || die 'Cannot determine default outbound interface; set wireguard.outbound_interface.'
  run env DEBIAN_FRONTEND=noninteractive apt-get update
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard
  ensure_private_dir /etc/wireguard
  if [[ ! -f /etc/wireguard/server_private.key ]]; then
    umask 077; wg genkey > /etc/wireguard/server_private.key
  fi
  private="$(< /etc/wireguard/server_private.key)"; public="$(printf '%s' "$private" | wg pubkey)"
  printf '%s\n' "$public" > /etc/wireguard/server_public.key; chmod 600 /etc/wireguard/server_{private,public}.key
  cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = ${addr}
ListenPort = ${port}
PrivateKey = ${private}
PostUp = sysctl -w net.ipv4.ip_forward=1; iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${outbound} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${outbound} -j MASQUERADE
EOF
  chmod 600 /etc/wireguard/wg0.conf
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/99-tu-devkit-vps-init.conf
  systemctl enable wg-quick@wg0
  systemctl restart wg-quick@wg0
  info "WireGuard wg0 is active on UDP ${port}."
}
