#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/common.sh"; source "$ROOT/lib/config.sh"
CONFIG_FILE="$ROOT/config/vps.local.yaml"; phases='base,firewall'; noninteractive=0
while [[ $# -gt 0 ]]; do case "$1" in --config) CONFIG_FILE="$2"; shift 2;; --phase) phases="$2"; shift 2;; --dry-run) VPS_INIT_DRY_RUN=1; shift;; --yes) VPS_INIT_YES=1; noninteractive=1; shift;; *) die "Unknown argument: $1";; esac; done
validate_config
[[ "$VPS_INIT_DRY_RUN" == 1 || "$noninteractive" == 1 ]] || confirm "Apply VPS phases: $phases?" || die 'Installation cancelled.'
if [[ "$VPS_INIT_DRY_RUN" == 0 ]]; then
  install -d -m 700 "$VPS_INIT_LOG_DIR"
  exec > >(tee -a "$VPS_INIT_LOG_DIR/vps-init.$(date +%Y%m%d%H%M%S).log") 2>&1
fi
export CONFIG_FILE VPS_INIT_DRY_RUN VPS_INIT_YES VPS_INIT_STATE_DIR VPS_INIT_LOG_DIR
source "$ROOT/scripts/preflight.sh"; preflight
IFS=, read -r -a requested <<< "$phases"
for phase in "${requested[@]}"; do
  case "$phase" in base) source "$ROOT/scripts/base.sh"; install_base;; firewall) source "$ROOT/scripts/firewall.sh"; configure_firewall;; ssh-hardening) source "$ROOT/scripts/ssh-hardening.sh"; harden_ssh;; wireguard) source "$ROOT/scripts/wireguard.sh"; setup_wireguard;; sing-box) source "$ROOT/scripts/sing-box.sh"; setup_sing_box;; clash) "$ROOT/scripts/generate-clash-profile.sh";; *) die "Unknown phase: $phase";; esac
done
