#!/usr/bin/env bash
# shellcheck disable=SC1091 # Module paths are resolved from this script at runtime.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/common.sh"; source "$ROOT/lib/config.sh"; source "$ROOT/lib/state.sh"
CONFIG_FILE="$ROOT/config/vps.local.yaml"; phases=''; profile=''; finalize=0; verified_ssh=0; noninteractive=0
usage() {
  cat <<'EOF'
Usage:
  ./install.sh --profile quick --config FILE [--dry-run] [--yes]
  ./install.sh --profile secure --config FILE [--dry-run] [--yes]
  ./install.sh --profile secure --finalize --verified-ssh --config FILE [--dry-run] [--yes]
  ./install.sh --phase PHASE[,PHASE...] --config FILE [--dry-run] [--yes]

Profiles are the recommended interface. --phase is retained for advanced compatibility.
EOF
}
[[ $# -gt 0 ]] || { usage; exit 2; }
while [[ $# -gt 0 ]]; do case "$1" in
  --config) [[ $# -ge 2 ]] || die '--config requires a file.'; CONFIG_FILE="$2"; shift 2;;
  --profile) [[ $# -ge 2 ]] || die '--profile requires quick or secure.'; profile="$2"; shift 2;;
  --phase) [[ $# -ge 2 ]] || die '--phase requires a phase list.'; phases="$2"; shift 2;;
  --finalize) finalize=1; shift;;
  --verified-ssh) verified_ssh=1; shift;;
  --dry-run) VPS_INIT_DRY_RUN=1; shift;;
  --yes) VPS_INIT_YES=1; noninteractive=1; shift;;
  -h|--help) usage; exit 0;;
  *) die "Unknown argument: $1";;
esac; done
[[ -z "$profile" || -z "$phases" ]] || die '--profile and --phase are mutually exclusive.'
[[ -n "$profile" || -n "$phases" ]] || { usage; die 'Specify --profile or --phase.'; }
if [[ -n "$profile" ]]; then
  [[ "$profile" == quick || "$profile" == secure ]] || die "Unknown profile: $profile"
  [[ "$finalize" == 0 || "$profile" == secure ]] || die '--finalize is valid only with --profile secure.'
  [[ "$verified_ssh" == 0 || "$finalize" == 1 ]] || die '--verified-ssh requires --finalize.'
  if [[ "$profile" == quick ]]; then
    [[ "$finalize" == 0 ]] || die 'The quick profile has no finalize step.'
    phases='base,firewall'
    feature_enabled wireguard && phases="${phases},wireguard"
    phases="${phases},sing-box,clash"
    feature_enabled clash_remote && phases="${phases},clash-remote"
  elif [[ "$finalize" == 1 ]]; then
    [[ "$verified_ssh" == 1 ]] || die 'Secure finalize requires --verified-ssh; --yes cannot replace this confirmation.'
    phases='ssh-finalize,firewall-finalize'
  else
    phases='base,firewall,ssh-hardening,wireguard,sing-box,clash'
    feature_enabled clash_remote && phases="${phases},clash-remote"
  fi
  VPS_INIT_PROFILE="$profile"
else
  [[ "$finalize" == 0 && "$verified_ssh" == 0 ]] || die '--finalize and --verified-ssh require --profile secure.'
  VPS_INIT_PROFILE='legacy'
fi
validate_config
if [[ "$profile" == quick && "$(config_value_or clash_remote enabled false)" == true && "$(config_value wireguard enabled)" != true ]]; then
  die 'Quick clash_remote requires wireguard.enabled: true.'
fi
if [[ -n "$profile" ]]; then
  endpoint="$(public_endpoint)"; [[ -n "$endpoint" ]] || die 'server.public_endpoint is required for Profile installs.'
fi
if [[ "$profile" == secure ]]; then
  if [[ "$finalize" == 1 ]]; then
    state="$(read_profile_state)"
    [[ "$state" == secure-transition || "$state" == secure ]] || die 'Secure finalize requires an existing secure-transition state.'
  fi
fi
if [[ "$profile" == secure && "$finalize" == 0 && "$VPS_INIT_DRY_RUN" == 0 && "$noninteractive" == 0 ]]; then
  confirm 'Confirm the VPS provider console or recovery access is available before SSH hardening?' || die 'Secure installation cancelled: recovery access was not confirmed.'
fi
[[ "$VPS_INIT_DRY_RUN" == 1 || "$noninteractive" == 1 ]] || confirm "Apply VPS phases: $phases?" || die 'Installation cancelled.'
if [[ "$VPS_INIT_DRY_RUN" == 0 ]]; then
  install -d -m 700 "$VPS_INIT_LOG_DIR"
  exec > >(tee -a "$VPS_INIT_LOG_DIR/vps-init.$(date +%Y%m%d%H%M%S).log") 2>&1
fi
export CONFIG_FILE VPS_INIT_DRY_RUN VPS_INIT_YES VPS_INIT_STATE_DIR VPS_INIT_LOG_DIR VPS_INIT_PROFILE
export VPS_INIT_VERIFIED_SSH="$verified_ssh"
source "$ROOT/scripts/preflight.sh"; preflight
if [[ "$profile" == secure && "$finalize" == 0 ]]; then
  key_file="$(config_value ssh admin_authorized_keys_path)"
  if [[ "$(config_bool ssh disable_root_login)" == true && "$key_file" == /root/* ]]; then
    die 'Secure profile would disable root login, but ssh.admin_authorized_keys_path belongs to root. Configure a non-root administrator key.'
  fi
  if [[ "$VPS_INIT_DRY_RUN" == 0 ]]; then
    [[ -s "$key_file" ]] || die "Secure preflight requires a non-empty administrator key file: $key_file"
    require_command ss
    current_port="$(config_value_or ssh current_port 22)"
    ss -H -ltn | awk '{print $4}' | grep -Eq ":${current_port}$" || die "Secure preflight: ssh.current_port ${current_port} is not listening."
  fi
fi
IFS=, read -r -a requested <<< "$phases"
for phase in "${requested[@]}"; do
  case "$phase" in
    base) source "$ROOT/scripts/base.sh"; install_base;;
    firewall) source "$ROOT/scripts/firewall.sh"; configure_firewall;;
    firewall-finalize) source "$ROOT/scripts/firewall.sh"; finalize_firewall;;
    ssh-hardening) source "$ROOT/scripts/ssh-hardening.sh"; prepare_ssh_hardening;;
    ssh-finalize) source "$ROOT/scripts/ssh-hardening.sh"; finalize_ssh_hardening;;
    wireguard) source "$ROOT/scripts/wireguard.sh"; setup_wireguard;;
    sing-box) source "$ROOT/scripts/sing-box.sh"; setup_sing_box;;
    clash) "$ROOT/scripts/generate-clash-profile.sh";;
    clash-remote) source "$ROOT/scripts/clash-remote.sh"; setup_clash_remote;;
    *) die "Unknown phase: $phase";;
  esac
done
if [[ -n "$profile" ]]; then
  if [[ "$profile" == quick ]]; then
    write_profile_state quick
    capabilities=(sing-box)
    feature_enabled wireguard && capabilities+=(wireguard)
    feature_enabled clash_remote && capabilities+=(clash-remote)
    write_capabilities "${capabilities[@]}"
  elif [[ "$finalize" == 1 || "$(config_value_or ssh current_port 22)" == "$(config_value ssh port)" ]]; then
    write_profile_state secure
  else
    write_profile_state secure-transition
    info "Secure transition is ready. Verify a new SSH session on port $(config_value ssh port), then run: ./install.sh --profile secure --finalize --verified-ssh --config '$CONFIG_FILE'"
  fi
  if [[ "$profile" == secure && "$finalize" == 0 ]]; then
    capabilities=(sing-box wireguard)
    feature_enabled clash_remote && capabilities+=(clash-remote)
    write_capabilities "${capabilities[@]}"
  fi
fi
