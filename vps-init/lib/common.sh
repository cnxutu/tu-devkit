#!/usr/bin/env bash
set -Eeuo pipefail

VPS_INIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VPS_INIT_STATE_DIR="${VPS_INIT_STATE_DIR:-/var/lib/tu-devkit-vps-init}"
VPS_INIT_LOG_DIR="${VPS_INIT_LOG_DIR:-/var/log/tu-devkit-vps-init}"
VPS_INIT_DRY_RUN="${VPS_INIT_DRY_RUN:-0}"
VPS_INIT_YES="${VPS_INIT_YES:-0}"

log() { printf '[%s] [%s] %s\n' "$(date -u +%FT%TZ)" "$1" "$2"; }
info() { log INFO "$1"; }
warn() { log WARN "$1" >&2; }
die() { log ERROR "$1" >&2; exit 1; }

run() {
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then info "[DRY-RUN] $*"; return 0; fi
  "$@"
}

require_root() {
  [[ "${EUID}" -eq 0 ]] && return 0
  [[ "$VPS_INIT_DRY_RUN" == 1 ]] && { warn 'Dry-run is not root; privileged actions are shown but not performed.'; return 0; }
  die 'Run as root or with sudo.'
}
require_command() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
confirm() {
  [[ "$VPS_INIT_YES" == 1 ]] && return 0
  local answer
  read -r -p "$1 [y/N] " answer || true
  [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

ensure_private_dir() { run install -d -m 700 "$1"; }
backup_file() {
  local file="$1" backup_dir="$2"
  [[ -e "$file" ]] || return 0
  ensure_private_dir "$backup_dir"
  run cp -a "$file" "$backup_dir/$(basename "$file").$(date +%Y%m%d%H%M%S).bak"
}

service_active() { systemctl is-active --quiet "$1"; }
