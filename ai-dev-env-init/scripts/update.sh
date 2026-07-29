#!/usr/bin/env bash
update_main() {
  parse_flags "$@"; detect_platform; log_info 'Planned safe updates: package metadata, pnpm, uv, and Rust toolchain where installed.'
  confirm 'Proceed with updates?' || { log_skip 'Updates'; return 0; }
  [[ "$PACKAGE_MANAGER" == brew ]] && run brew update && run brew upgrade || true
  [[ "$PACKAGE_MANAGER" == apt ]] && run sudo apt-get update || true
  has pnpm && run pnpm add --global pnpm || true
  has uv && run uv self update || true
  has rustup && run rustup update || true
}
