#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034 # Dynamic sources consume test variables.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
source "$ROOT/lib/common.sh"; source "$ROOT/lib/config.sh"; source "$ROOT/lib/state.sh"
source "$ROOT/scripts/firewall.sh"
VPS_INIT_DRY_RUN=0; marker_file="$tmp/owned"; actions="$tmp/actions"
recorded=''
record_managed_ufw_rule() { recorded="$1"; }
ufw() {
  if [[ "$1" == status && "${2:-}" != numbered ]]; then printf '22/tcp ALLOW Anywhere\n'; return; fi
  if [[ "$1" == status && "${2:-}" == numbered ]]; then
    [[ -f "$marker_file" ]] && printf '[ 3] 22/tcp ALLOW IN Anywhere # tu-devkit-vps-init owned\n'
    return
  fi
  printf '%s\n' "$*" >> "$actions"
  [[ "$1" == --force && "$2" == delete ]] && rm -f "$marker_file"
}
run() { "$@"; }
ufw_allow_managed '22/tcp' 'tu-devkit-vps-init must-not-own'
[[ -z "$recorded" ]] || { echo 'existing user UFW rule was claimed' >&2; exit 1; }
touch "$marker_file"
managed_ufw_rule_recorded() { [[ "$1" == 'tu-devkit-vps-init owned' ]]; }
forget_managed_ufw_rule() { printf 'forgot %s\n' "$1" >> "$actions"; }
delete_managed_ufw_comment 'tu-devkit-vps-init owned'
grep -Fq -- '--force delete 3' "$actions"
grep -Fq 'forgot tu-devkit-vps-init owned' "$actions"
printf 'vps-init firewall ownership test passed\n'
