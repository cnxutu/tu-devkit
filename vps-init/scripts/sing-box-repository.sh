#!/usr/bin/env bash
# shellcheck disable=SC1091 # Module paths are resolved from this script at runtime.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"

SAGER_FINGERPRINT=2C317FBD5D886B4E89BAE8DA6D9152172A2B2F0C
SAGER_KEY_URL=https://sing-box.app/gpg.key
SAGER_REPO_URL=https://deb.sagernet.org/

configure_sing_box_repository() {
  if [[ "$VPS_INIT_DRY_RUN" == 1 ]]; then
    info "[DRY-RUN] configure official sing-box stable APT repository and verify GPG fingerprint ${SAGER_FINGERPRINT}"
    return
  fi
  require_root; require_command curl; require_command gpg
  local key_tmp fingerprint source_tmp
  key_tmp="$(mktemp)"; source_tmp="$(mktemp)"
  if ! curl --fail --silent --show-error --location "$SAGER_KEY_URL" --output "$key_tmp"; then
    rm -f "$key_tmp" "$source_tmp"
    die 'Failed to download the official sing-box repository key.'
  fi
  fingerprint="$(gpg --batch --show-keys --with-colons "$key_tmp" | awk -F: '$1=="fpr" {print $10; exit}')"
  [[ "$fingerprint" == "$SAGER_FINGERPRINT" ]] || { rm -f "$key_tmp" "$source_tmp"; die "Refusing sing-box repository key: unexpected fingerprint ${fingerprint:-missing}."; }
  install -d -m 755 /etc/apt/keyrings
  install -m 644 "$key_tmp" /etc/apt/keyrings/sagernet.asc
  cat > "$source_tmp" <<EOF
Types: deb
URIs: ${SAGER_REPO_URL}
Suites: *
Components: *
Enabled: yes
Signed-By: /etc/apt/keyrings/sagernet.asc
EOF
  install -m 644 "$source_tmp" /etc/apt/sources.list.d/sagernet.sources
  rm -f "$key_tmp" "$source_tmp"
}

install_sing_box_stable() {
  configure_sing_box_repository
  [[ "$VPS_INIT_DRY_RUN" == 1 ]] && return
  run env DEBIAN_FRONTEND=noninteractive apt-get update
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y sing-box
  local version tmp
  version="$(sing-box version | awk 'NR==1 {print $3}')"
  ensure_private_dir "$VPS_INIT_STATE_DIR"
  tmp="$(mktemp "${VPS_INIT_STATE_DIR}/.sing-box-version.XXXXXX")"
  printf '%s\n' "$version" > "$tmp"; chmod 600 "$tmp"; mv -f "$tmp" "${VPS_INIT_STATE_DIR}/sing-box-version"
}
