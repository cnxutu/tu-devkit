#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cp "$ROOT/config/vps.example.yaml" "$tmp/vps.local.yaml"
sed -i 's/public_endpoint: ""/public_endpoint: "203.0.113.10"/' "$tmp/vps.local.yaml"
if bash "$ROOT/install.sh" >/dev/null 2>&1; then echo 'missing profile/phase accepted' >&2; exit 1; fi
if bash "$ROOT/install.sh" --config "$tmp/vps.local.yaml" --profile unknown --dry-run >/dev/null 2>&1; then echo 'unknown profile accepted' >&2; exit 1; fi
if bash "$ROOT/install.sh" --config "$tmp/vps.local.yaml" --profile quick --phase base --dry-run >/dev/null 2>&1; then echo 'profile/phase conflict accepted' >&2; exit 1; fi
if bash "$ROOT/install.sh" --config "$tmp/vps.local.yaml" --profile secure --finalize --yes --dry-run >/dev/null 2>&1; then echo 'secure finalize accepted without verified SSH' >&2; exit 1; fi
sed 's#/home/admin/.ssh/authorized_keys#/root/.ssh/authorized_keys#' "$tmp/vps.local.yaml" > "$tmp/root-key.yaml"
if bash "$ROOT/install.sh" --config "$tmp/root-key.yaml" --profile secure --dry-run >/dev/null 2>&1; then echo 'secure profile accepted a root-only key while disabling root login' >&2; exit 1; fi
if bash "$ROOT/install.sh" --config "$tmp/vps.local.yaml" --phase unknown --dry-run >/dev/null 2>&1; then echo 'unknown phase accepted' >&2; exit 1; fi
bash "$ROOT/install.sh" --config "$tmp/vps.local.yaml" --phase base,firewall,ssh-hardening,wireguard,sing-box,clash --dry-run >/dev/null
quick_output="$(bash "$ROOT/install.sh" --config "$tmp/vps.local.yaml" --profile quick --dry-run)"
grep -Fq 'configure quick UFW' <<< "$quick_output"
grep -Fq 'install and configure sing-box' <<< "$quick_output"
if grep -Fq 'install and configure WireGuard' <<< "$quick_output"; then echo 'quick profile invoked WireGuard' >&2; exit 1; fi
if grep -Fq 'SSH transition policy' <<< "$quick_output"; then echo 'quick profile invoked SSH hardening' >&2; exit 1; fi
sed '/^wireguard:/,/^sing_box:/ s/  enabled: false/  enabled: true/' "$tmp/vps.local.yaml" > "$tmp/quick-wg.yaml"
quick_wg_output="$(bash "$ROOT/install.sh" --config "$tmp/quick-wg.yaml" --profile quick --dry-run)"
grep -Fq 'install and configure WireGuard' <<< "$quick_wg_output"
sed '/^clash_remote:/,$ s/  enabled: false/  enabled: true/' "$tmp/vps.local.yaml" > "$tmp/remote-without-wg.yaml"
if bash "$ROOT/install.sh" --config "$tmp/remote-without-wg.yaml" --profile quick --dry-run >/dev/null 2>&1; then echo 'Quick Remote accepted without WireGuard' >&2; exit 1; fi
sed '/^clash_remote:/,$ s/  enabled: false/  enabled: true/' "$tmp/quick-wg.yaml" > "$tmp/quick-remote.yaml"
quick_remote_output="$(bash "$ROOT/install.sh" --config "$tmp/quick-remote.yaml" --profile quick --dry-run)"
grep -Fq 'publish Clash Remote Profile on WireGuard' <<< "$quick_remote_output"
secure_output="$(bash "$ROOT/install.sh" --config "$tmp/vps.local.yaml" --profile secure --dry-run)"
grep -Fq 'SSH transition policy' <<< "$secure_output"
grep -Fq 'install and configure WireGuard' <<< "$secure_output"
secure_remote_output="$(bash "$ROOT/install.sh" --config "$tmp/remote-without-wg.yaml" --profile secure --dry-run)"
grep -Fq 'publish Clash Remote Profile on WireGuard' <<< "$secure_remote_output"
mkdir -p "$tmp/state"; printf 'secure-transition\n' > "$tmp/state/profile"
finalize_output="$(VPS_INIT_STATE_DIR="$tmp/state" bash "$ROOT/install.sh" --config "$tmp/vps.local.yaml" --profile secure --finalize --verified-ssh --dry-run)"
grep -Fq 'keep only hardened SSH port' <<< "$finalize_output"
sed 's/current_port: 22/current_port: 22222/' "$tmp/vps.local.yaml" > "$tmp/same-port.yaml"
same_port_output="$(bash "$ROOT/install.sh" --config "$tmp/same-port.yaml" --profile secure --dry-run)"
grep -Fq 'record profile state: secure' <<< "$same_port_output"
grep -Fq 'VPS_INIT_DRY_RUN=1' "$ROOT/install.sh"
printf 'vps-init dry-run contract test passed\n'
