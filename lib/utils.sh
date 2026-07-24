#!/usr/bin/env bash
CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/tu-devkit"
BACKUP_DIR="${CONFIG_DIR}/backups"
YES=0; VERBOSE=0; STRICT=0; DRY_RUN=0
parse_flags() { YES=0; VERBOSE=0; STRICT=0; DRY_RUN=0; for arg in "$@"; do case "$arg" in --yes|-y) YES=1;; --verbose|-v) VERBOSE=1;; --strict) STRICT=1;; --dry-run) DRY_RUN=1;; esac; done; }
confirm() { [[ "$YES" == 1 ]] && return 0; local answer; read -r -p "$1 [y/N] " answer || true; [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]; }
run() { if [[ "$DRY_RUN" == 1 ]]; then log_info "[DRY-RUN] $*"; return 0; fi; [[ "$VERBOSE" == 1 ]] && log_info "+ $*"; "$@"; }
has() { command -v "$1" >/dev/null 2>&1; }
version_of() {
  if has "$1"; then "$1" --version 2>/dev/null | head -n 1
  elif [[ "$1" == nvm ]] && declare -F nvm >/dev/null 2>&1; then nvm --version 2>/dev/null | head -n 1
  else true; fi
}
backup_file() {
  local file="$1"; [[ -e "$file" ]] || return 0
  mkdir -p "$BACKUP_DIR"; local dest="${BACKUP_DIR}/$(basename "$file").$(date +%Y%m%d%H%M%S).bak"
  cp -p "$file" "$dest"; log_info "Backed up $file to $dest"
}
append_once() { local file="$1" marker="$2"; grep -Fqx "$marker" "$file" 2>/dev/null || { backup_file "$file"; printf '%s\n' "$marker" >> "$file"; }; }
safe_source() { [[ -f "$1" ]] && source "$1"; }
