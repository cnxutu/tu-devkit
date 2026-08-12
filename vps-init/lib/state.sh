#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE_STATE_FILE="${VPS_INIT_STATE_DIR}/profile"
MANAGED_UFW_FILE="${VPS_INIT_STATE_DIR}/managed-ufw-rules"
CAPABILITIES_STATE_FILE="${VPS_INIT_STATE_DIR}/capabilities"

read_profile_state() {
  if [[ -s "$PROFILE_STATE_FILE" ]]; then tr -d '[:space:]' < "$PROFILE_STATE_FILE"; fi
}

write_profile_state() {
  local state="$1" tmp
  [[ "$state" == quick || "$state" == secure-transition || "$state" == secure ]] || die "Invalid profile state: $state"
  [[ "$VPS_INIT_DRY_RUN" == 1 ]] && { info "[DRY-RUN] record profile state: $state"; return; }
  ensure_private_dir "$VPS_INIT_STATE_DIR"
  tmp="$(mktemp "${VPS_INIT_STATE_DIR}/.profile.XXXXXX")"
  printf '%s\n' "$state" > "$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$PROFILE_STATE_FILE"
}

write_capabilities() {
  local tmp capability
  [[ "$VPS_INIT_DRY_RUN" == 1 ]] && { info "[DRY-RUN] record capabilities: $*"; return; }
  for capability in "$@"; do
    [[ "$capability" == sing-box || "$capability" == wireguard || "$capability" == clash-remote ]] || die "Invalid capability: $capability"
  done
  ensure_private_dir "$VPS_INIT_STATE_DIR"
  tmp="$(mktemp "${VPS_INIT_STATE_DIR}/.capabilities.XXXXXX")"
  [[ -f "$CAPABILITIES_STATE_FILE" ]] && cp "$CAPABILITIES_STATE_FILE" "$tmp"
  for capability in "$@"; do printf '%s\n' "$capability" >> "$tmp"; done
  sort -u -o "$tmp" "$tmp"
  chmod 600 "$tmp"; mv -f "$tmp" "$CAPABILITIES_STATE_FILE"
}

capability_recorded() {
  [[ -f "$CAPABILITIES_STATE_FILE" ]] && grep -Fqx "$1" "$CAPABILITIES_STATE_FILE"
}

record_managed_ufw_rule() {
  local comment="$1"
  [[ "$VPS_INIT_DRY_RUN" == 1 ]] && return
  ensure_private_dir "$VPS_INIT_STATE_DIR"
  touch "$MANAGED_UFW_FILE"; chmod 600 "$MANAGED_UFW_FILE"
  grep -Fqx "$comment" "$MANAGED_UFW_FILE" || printf '%s\n' "$comment" >> "$MANAGED_UFW_FILE"
}

managed_ufw_rule_recorded() {
  [[ -f "$MANAGED_UFW_FILE" ]] && grep -Fqx "$1" "$MANAGED_UFW_FILE"
}

forget_managed_ufw_rule() {
  local comment="$1" tmp
  [[ -f "$MANAGED_UFW_FILE" ]] || return 0
  [[ "$VPS_INIT_DRY_RUN" == 1 ]] && return
  tmp="$(mktemp "${VPS_INIT_STATE_DIR}/.managed-ufw.XXXXXX")"
  grep -Fvx "$comment" "$MANAGED_UFW_FILE" > "$tmp" || true
  chmod 600 "$tmp"; mv -f "$tmp" "$MANAGED_UFW_FILE"
}
