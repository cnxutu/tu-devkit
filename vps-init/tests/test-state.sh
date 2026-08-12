#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034 # Dynamic sources consume test variables.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
source "$ROOT/lib/common.sh"
VPS_INIT_STATE_DIR="$tmp/state"; VPS_INIT_DRY_RUN=0
source "$ROOT/lib/state.sh"
write_profile_state quick; [[ "$(read_profile_state)" == quick ]]
write_profile_state secure-transition; [[ "$(read_profile_state)" == secure-transition ]]
write_capabilities sing-box wireguard clash-remote
capability_recorded sing-box; capability_recorded wireguard; capability_recorded clash-remote
write_capabilities sing-box; capability_recorded wireguard
[[ "$(stat -c %a "$CAPABILITIES_STATE_FILE")" == 600 ]]
record_managed_ufw_rule 'tu-devkit-vps-init test'; managed_ufw_rule_recorded 'tu-devkit-vps-init test'
forget_managed_ufw_rule 'tu-devkit-vps-init test'; if managed_ufw_rule_recorded 'tu-devkit-vps-init test'; then exit 1; fi
[[ "$(stat -c %a "$PROFILE_STATE_FILE")" == 600 ]]
printf 'vps-init state test passed\n'
