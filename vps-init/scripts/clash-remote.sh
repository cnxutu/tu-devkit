#!/usr/bin/env bash
# shellcheck disable=SC1091 # Module paths are resolved from this script at runtime.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"; source "$ROOT/lib/config.sh"

setup_clash_remote() {
  feature_enabled clash_remote || { info 'Clash Remote Profile is disabled; skipping.'; return 0; }
  local bind port interval service_user=tu-clash-remote service_group=tu-clash-remote
  local secret_dir publish_dir token_file url_file profile_source profile_target
  local runtime_dir=/usr/local/lib/tu-devkit-vps-init config_dir=/etc/tu-devkit-vps-init
  local server_target="$runtime_dir/clash-remote-server.py" env_target="$config_dir/clash-remote.env"
  local unit_target=/etc/systemd/system/tu-devkit-clash-remote.service token tmp url
  bind="$(wireguard_server_ip)"; port="$(config_value_or clash_remote port 18080)"; interval="$(config_value_or clash_remote update_interval_hours 24)"
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then
    info "[DRY-RUN] publish Clash Remote Profile on WireGuard ${bind}:${port} without a public UFW rule"
    return 0
  fi
  require_root; require_command ip; require_command systemctl
  ip -4 address show dev wg0 | grep -Fq "inet ${bind}/" || die "Clash Remote requires wg0 with address ${bind}."
  profile_source="${VPS_INIT_OUTPUT_DIR:-$ROOT/output}/vps-clash.yaml"
  [[ -s "$profile_source" ]] || die 'Generated Clash profile is missing; run the clash phase first.'
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y python3-minimal openssl
  getent group "$service_group" >/dev/null 2>&1 || groupadd --system "$service_group"
  id -u "$service_user" >/dev/null 2>&1 || useradd --system --gid "$service_group" --home-dir /nonexistent --shell /usr/sbin/nologin "$service_user"
  secret_dir="${VPS_INIT_STATE_DIR}/secrets"; publish_dir="${VPS_INIT_STATE_DIR}/subscriptions"
  token_file="$secret_dir/clash-remote-token"; url_file="$secret_dir/clash-remote-url"; profile_target="$publish_dir/vps-clash.yaml"
  install -d -m 700 "$secret_dir" "$config_dir"
  install -d -m 750 -o root -g "$service_group" "$publish_dir"
  install -d -m 755 "$runtime_dir"
  if [[ ! -s "$token_file" ]]; then
    tmp="$(mktemp "$secret_dir/.clash-remote-token.XXXXXX")"; openssl rand -hex 24 > "$tmp"; chmod 600 "$tmp"; mv -f "$tmp" "$token_file"
  fi
  token="$(< "$token_file")"; [[ "$token" =~ ^[0-9a-f]{48}$ ]] || die 'Existing Clash Remote token is invalid; refusing to replace it silently.'
  install -m 755 "$ROOT/scripts/clash-remote-server.py" "$server_target"
  tmp="$(mktemp "$publish_dir/.vps-clash.XXXXXX")"; install -m 640 -o root -g "$service_group" "$profile_source" "$tmp"
  mv -f "$tmp" "$profile_target"
  tmp="$(mktemp "$config_dir/.clash-remote-env.XXXXXX")"
  cat > "$tmp" <<EOF
CLASH_REMOTE_BIND=${bind}
CLASH_REMOTE_PORT=${port}
CLASH_REMOTE_TOKEN=${token}
CLASH_REMOTE_PROFILE=${profile_target}
CLASH_REMOTE_UPDATE_INTERVAL=${interval}
EOF
  install -m 600 "$tmp" "$env_target"; rm -f "$tmp"
  tmp="$(mktemp /etc/systemd/system/.tu-devkit-clash-remote.XXXXXX)"
  cat > "$tmp" <<EOF
[Unit]
Description=tu-devkit Clash Remote Profile
Requires=wg-quick@wg0.service
After=network-online.target wg-quick@wg0.service

[Service]
Type=simple
User=${service_user}
Group=${service_group}
EnvironmentFile=${env_target}
ExecStart=/usr/bin/python3 ${server_target}
Restart=on-failure
NoNewPrivileges=true
PrivateDevices=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
CapabilityBoundingSet=
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictAddressFamilies=AF_INET AF_INET6
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target
EOF
  install -m 644 "$tmp" "$unit_target"; rm -f "$tmp"
  CLASH_REMOTE_BIND="$bind" \
    CLASH_REMOTE_PORT="$port" \
    CLASH_REMOTE_TOKEN="$token" \
    CLASH_REMOTE_PROFILE="$profile_target" \
    CLASH_REMOTE_UPDATE_INTERVAL="$interval" \
    python3 "$server_target" --check-config
  systemctl daemon-reload
  systemctl enable --now tu-devkit-clash-remote.service
  systemctl restart tu-devkit-clash-remote.service
  url="http://${bind}:${port}/subscription/${token}/vps-clash.yaml"
  tmp="$(mktemp "$secret_dir/.clash-remote-url.XXXXXX")"; printf '%s\n' "$url" > "$tmp"; chmod 600 "$tmp"; mv -f "$tmp" "$url_file"
  printf 'url = "%s"\n' "$url" | curl --fail --silent --show-error --output /dev/null --config - || die 'Clash Remote health check failed.'
  info "Clash Remote Profile is ready; retrieve its sensitive URL with $ROOT/show-clash-remote-url.sh."
}
