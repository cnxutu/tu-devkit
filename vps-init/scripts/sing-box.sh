#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/config.sh"

setup_sing_box() {
  [[ "$(config_bool sing_box enabled)" == true ]] || { info 'sing-box is disabled; skipping.'; return 0; }
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info "[DRY-RUN] install and configure sing-box on TCP $(config_value sing_box port)"; return 0; fi
  require_root
  local password_file password port listen method
  password_file="${SING_BOX_PASSWORD_FILE:-${VPS_INIT_STATE_DIR}/secrets/sing-box-password}"
  port="$(config_value sing_box port)"; listen="$(config_value sing_box listen)"; method="$(config_value sing_box method)"
  [[ "$listen" != 0.0.0.0 ]] || confirm "Expose sing-box on ${listen}:${port}?" || die 'sing-box setup cancelled.'
  apt-cache show sing-box >/dev/null 2>&1 || die 'sing-box is not available from configured apt sources. Configure an approved repository first.'
  run env DEBIAN_FRONTEND=noninteractive apt-get update
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y sing-box
  ensure_private_dir "$(dirname "$password_file")"
  if [[ ! -s "$password_file" ]]; then umask 077; openssl rand -base64 24 > "$password_file"; chmod 600 "$password_file"; fi
  password="$(< "$password_file")"; install -d -m 750 /etc/sing-box
  cat > /etc/sing-box/config.json <<EOF
{"inbounds":[{"type":"shadowsocks","listen":"${listen}","listen_port":${port},"method":"${method}","password":"${password}"}]}
EOF
  chmod 600 /etc/sing-box/config.json
  sing-box check -c /etc/sing-box/config.json
  systemctl enable --now sing-box
  info 'sing-box is configured; its password is stored only in the protected local secret file.'
}
