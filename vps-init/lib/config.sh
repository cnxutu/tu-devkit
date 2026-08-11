#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="${CONFIG_FILE:-}"
config_value() {
  local section="$1" key="$2"
  awk -v section="$section" -v key="$key" '
    $0 ~ "^" section ":" { in_section=1; next }
    in_section && /^[^[:space:]][^:]*:/ { exit }
    in_section && $0 ~ "^[[:space:]]+" key ":[[:space:]]*" {
      sub("^[[:space:]]+" key ":[[:space:]]*", ""); sub(/[[:space:]]+#.*/, ""); print; exit
    }' "$CONFIG_FILE" | tr -d '"' | tr -d "'"
}
config_bool() {
  local value; value="$(config_value "$1" "$2")"
  [[ "$value" == true ]] && printf 'true\n' || printf 'false\n'
}
config_value_or() {
  local value
  value="$(config_value "$1" "$2")"
  printf '%s\n' "${value:-$3}"
}
feature_enabled() {
  local feature="$1"
  case "${VPS_INIT_PROFILE:-}" in
    quick) [[ "$feature" == sing_box ]];;
    secure|secure-transition) [[ "$feature" == wireguard || "$feature" == sing_box ]];;
    *) [[ "$(config_bool "$feature" enabled)" == true ]];;
  esac
}
public_endpoint() {
  local value="${SING_BOX_ENDPOINT:-}"
  [[ -n "$value" ]] || value="$(config_value server public_endpoint)"
  [[ -n "$value" ]] || value="$(config_value wireguard endpoint)"
  printf '%s\n' "$value"
}
validate_bool() { [[ "$1" == true || "$1" == false ]] || die "$2 must be true or false."; }
is_port() { [[ "$1" =~ ^[1-9][0-9]{0,4}$ ]] && (( "$1" <= 65535 )); }
is_cidr_v4() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]] || return 1
  local address="${1%/*}" octet
  for octet in ${address//./ }; do (( 10#$octet <= 255 )) || return 1; done
}
shadowsocks_key_length() {
  case "$1" in
    2022-blake3-aes-128-gcm) printf '16\n';;
    2022-blake3-aes-256-gcm) printf '32\n';;
    *) return 1;;
  esac
}
is_base64_key_length() {
  local value="$1" expected="$2" decoded_length
  [[ "$value" =~ ^[a-zA-Z0-9+/]+={0,2}$ ]] || return 1
  decoded_length="$(printf '%s' "$value" | base64 -d 2>/dev/null | wc -c)" || return 1
  decoded_length="${decoded_length//[[:space:]]/}"
  [[ "$decoded_length" == "$expected" ]]
}
validate_config() {
  [[ -f "$CONFIG_FILE" ]] || die "Config file not found: $CONFIG_FILE"
  local current_ssh_port ssh_port wg_port sb_port cidr listen outbound method maxretry endpoint
  current_ssh_port="$(config_value_or ssh current_port 22)"; ssh_port="$(config_value ssh port)"; wg_port="$(config_value wireguard port)"; sb_port="$(config_value sing_box port)"; cidr="$(config_value wireguard ipv4_cidr)"
  is_port "$current_ssh_port" || die 'ssh.current_port must be a valid TCP port.'
  is_port "$ssh_port" || die 'ssh.port must be a valid TCP port.'
  is_port "$wg_port" || die 'wireguard.port must be a valid UDP port.'
  is_port "$sb_port" || die 'sing_box.port must be a valid TCP port.'
  is_cidr_v4 "$cidr" || die 'wireguard.ipv4_cidr must be an IPv4 CIDR.'
  [[ "$ssh_port" != "$sb_port" ]] || die 'ssh.port and sing_box.port must differ.'
  validate_bool "$(config_value ssh disable_root_login)" 'ssh.disable_root_login'
  validate_bool "$(config_value wireguard enabled)" 'wireguard.enabled'
  validate_bool "$(config_value wireguard ipv6_enabled)" 'wireguard.ipv6_enabled'
  validate_bool "$(config_value sing_box enabled)" 'sing_box.enabled'
  listen="$(config_value sing_box listen)"; [[ "$listen" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die 'sing_box.listen must be an IPv4 address.'
  outbound="$(config_value wireguard outbound_interface)"; [[ -z "$outbound" || "$outbound" =~ ^[a-zA-Z0-9_.:-]+$ ]] || die 'wireguard.outbound_interface contains invalid characters.'
  method="$(config_value sing_box method)"; [[ "$method" == 2022-blake3-aes-128-gcm || "$method" == 2022-blake3-aes-256-gcm ]] || die 'sing_box.method is not an approved Shadowsocks 2022 method.'
  maxretry="$(config_value_or fail2ban maxretry 5)"; [[ "$maxretry" =~ ^[1-9][0-9]*$ ]] || die 'fail2ban.maxretry must be a positive integer.'
  [[ "$(config_value_or fail2ban bantime 1h)" =~ ^[1-9][0-9]*[smhdw]?$ ]] || die 'fail2ban.bantime must be a positive fail2ban duration.'
  [[ "$(config_value_or fail2ban findtime 10m)" =~ ^[1-9][0-9]*[smhdw]?$ ]] || die 'fail2ban.findtime must be a positive fail2ban duration.'
  endpoint="$(public_endpoint)"
  [[ -z "$endpoint" || "$endpoint" =~ ^[a-zA-Z0-9._:-]+$ ]] || die 'server.public_endpoint contains unsupported characters.'
}
