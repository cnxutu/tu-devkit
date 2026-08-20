#!/usr/bin/env bash
# shellcheck disable=SC2016 # Literal shell snippets are intentional grep patterns.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
has_exact_line() { tr -d '\r' < "$2" | grep -Fqx "$1"; }
grep -Fq 'vps.local.yaml' "$ROOT/.gitignore"
grep -Fq 'output/' "$ROOT/.gitignore"
grep -Fq 'Refusing SSH hardening' "$ROOT/scripts/ssh-hardening.sh"
grep -Fq 'sshd -t' "$ROOT/scripts/ssh-hardening.sh"
grep -Fq 'VPS_INIT_VERIFIED_SSH' "$ROOT/scripts/ssh-hardening.sh"
grep -Fq 'managed_ufw_rule_recorded' "$ROOT/scripts/firewall.sh"
grep -Fq 'forget_managed_ufw_rule' "$ROOT/scripts/firewall.sh"
grep -Fq 'fail2ban-client -t' "$ROOT/scripts/firewall.sh"
grep -Fq 'install -m 600 "$config_tmp" "$candidate"' "$ROOT/scripts/wireguard.sh"
grep -Fq "awk '(/^# tu-devkit client:/" "$ROOT/scripts/wireguard.sh"
grep -Fq 'Secure profile would disable root login' "$ROOT/install.sh"
grep -Fq '# tu-devkit client:' "$ROOT/scripts/wg-add-client.sh"
grep -Fq '/etc/wireguard/wg0.conf' "$ROOT/scripts/wg-remove-client.sh"
grep -Fq 'install -m 600 "$config_tmp" "$candidate"' "$ROOT/scripts/sing-box.sh"
grep -Fq 'sing-box generate rand --base64 "$key_length"' "$ROOT/scripts/sing-box.sh"
grep -Fq '"network":"tcp"' "$ROOT/scripts/sing-box.sh"
grep -Fq '"multiplex":{"enabled":true,"padding":false}' "$ROOT/scripts/sing-box.sh"
grep -Fq '"strategy":"ipv4_only"' "$ROOT/scripts/sing-box.sh"
grep -Fq 'is_base64_key_length' "$ROOT/scripts/sing-box.sh"
grep -Fq 'sing-box configuration valid' "$ROOT/doctor.sh"
grep -Fq 'sing-box multiplex padding and IPv4 resolver stable' "$ROOT/doctor.sh"
grep -Fq 'sing-box ${key_length}-byte key valid' "$ROOT/doctor.sh"
grep -Fq 'SING_BOX_PASSWORD_FILE' "$ROOT/scripts/generate-clash-profile.sh"
grep -Fq 'clash-verge-profile.template.yaml' "$ROOT/scripts/generate-clash-profile.sh"
grep -Fq 'mktemp "$output_dir/.vps-clash.XXXXXX"' "$ROOT/scripts/generate-clash-profile.sh"
grep -Fq '2C317FBD5D886B4E89BAE8DA6D9152172A2B2F0C' "$ROOT/scripts/sing-box-repository.sh"
grep -Fq 'https://deb.sagernet.org/' "$ROOT/scripts/sing-box-repository.sh"
grep -Fq 'Enabled: yes' "$ROOT/scripts/sing-box-repository.sh"
grep -Fq 'Requires=wg-quick@wg0.service' "$ROOT/scripts/clash-remote.sh"
grep -Fq 'ProtectSystem=strict' "$ROOT/scripts/clash-remote.sh"
grep -Fq 'ufw allow in on wg0' "$ROOT/scripts/firewall.sh"
grep -Fq 'log_message' "$ROOT/scripts/clash-remote-server.py"
if grep -Eq '0\.0\.0\.0.*CLASH_REMOTE|CLASH_REMOTE.*0\.0\.0\.0' "$ROOT/scripts/clash-remote.sh"; then echo 'public Clash Remote bind found' >&2; exit 1; fi
if grep -Eq 'curl[^\n]*\|[[:space:]]*(sh|bash)' "$ROOT/scripts/sing-box-repository.sh"; then echo 'curl pipe-to-shell found' >&2; exit 1; fi
grep -Fq '    udp: false' "$ROOT/config/clash-verge-profile.template.yaml"
grep -Fq 'disable-keep-alive: false' "$ROOT/config/clash-verge-profile.template.yaml"
if grep -Eq '^[[:space:]]*smux:|protocol:[[:space:]]*h2mux' "$ROOT/config/clash-verge-profile.template.yaml"; then echo 'Codex profile must not enable smux' >&2; exit 1; fi
grep -Fq "For safety, this checker only connects to a loopback Mihomo controller." "$ROOT/scripts/check-clash-runtime.ps1"
grep -Fq "Read-Host 'Mihomo controller secret' -AsSecureString" "$ROOT/scripts/check-clash-runtime.ps1"
grep -Fq "contains DIRECT and can bypass the VPS" "$ROOT/scripts/check-clash-runtime.ps1"
grep -Fq "[switch]\$RequireWireGuard" "$ROOT/scripts/check-clash-runtime.ps1"
grep -Fq "WireGuard private proxy endpoint" "$ROOT/scripts/check-clash-runtime.ps1"
grep -Fq "does not use private server" "$ROOT/scripts/check-clash-runtime.ps1"
grep -Fq "Runtime TUN route exclusions are missing" "$ROOT/scripts/check-clash-runtime.ps1"
grep -Fq '  route-exclude-address:' "$ROOT/config/clash-verge-profile.template.yaml"
wireguard_template="$ROOT/config/wireguard-client.example.conf"
has_exact_line 'PrivateKey = <CLIENT_PRIVATE_KEY>' "$wireguard_template"
has_exact_line 'PublicKey = <SERVER_PUBLIC_KEY>' "$wireguard_template"
has_exact_line 'PresharedKey = <PRESHARED_KEY>' "$wireguard_template"
has_exact_line 'Endpoint = <VPS_PUBLIC_HOST>:<WIREGUARD_UDP_PORT>' "$wireguard_template"
has_exact_line 'AllowedIPs = 10.66.66.0/24' "$wireguard_template"
if grep -Fq 'AllowedIPs = 0.0.0.0/0' "$wireguard_template"; then
  echo 'WireGuard example must not enable a full-tunnel route' >&2
  exit 1
fi
grep -Fq "  - 'AND,((NETWORK,UDP),(DST-PORT,443)),REJECT'" "$ROOT/config/clash-verge-profile.template.yaml"
grep -Fq '  - DOMAIN-SUFFIX,steamstatic.com,🎮 Steam CDN' "$ROOT/config/clash-verge-profile.template.yaml"
steam_cdn_line="$(grep -nF '  - DOMAIN-SUFFIX,steamstatic.com,🎮 Steam CDN' "$ROOT/config/clash-verge-profile.template.yaml" | cut -d: -f1)"
steam_web_line="$(grep -nF '  - DOMAIN-SUFFIX,steamcommunity.com,🎬 Entertainment' "$ROOT/config/clash-verge-profile.template.yaml" | cut -d: -f1)"
(( steam_cdn_line < steam_web_line )) || { echo 'Steam CDN rule must precede Steam web proxy rules' >&2; exit 1; }
if grep -Fq 'disable-quic:' "$ROOT/config/clash-verge-profile.template.yaml"; then
  echo 'unsupported disable-quic setting found in Clash configuration' >&2
  exit 1
fi
private_line="$(grep -nF '  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve' "$ROOT/config/clash-verge-profile.template.yaml" | cut -d: -f1)"
reject_line="$(grep -nF "  - 'AND,((NETWORK,UDP),(DST-PORT,443)),REJECT'" "$ROOT/config/clash-verge-profile.template.yaml" | cut -d: -f1)"
first_business_rule_line="$(grep -nF '  - DOMAIN-SUFFIX,dingtalk.com,' "$ROOT/config/clash-verge-profile.template.yaml" | cut -d: -f1)"
(( private_line < reject_line && reject_line < first_business_rule_line )) || { echo 'Clash safety rule order is invalid' >&2; exit 1; }
printf 'vps-init security contract test passed\n'
