#!/usr/bin/env bash
detect_platform() {
  OS="unsupported"; IS_WSL=0
  case "$(uname -s)" in
    Darwin) OS="macos";;
    Linux) OS="linux"; grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1 || true;;
  esac
  ARCH="$(uname -m)"
  if [[ "$OS" == macos ]] && command -v brew >/dev/null 2>&1; then PACKAGE_MANAGER=brew
  elif [[ "$OS" == linux ]] && command -v apt-get >/dev/null 2>&1; then PACKAGE_MANAGER=apt
  else PACKAGE_MANAGER=none; fi
}
platform_summary() {
  detect_platform
  local label="$OS"; [[ "$IS_WSL" == 1 ]] && label="Ubuntu WSL2"
  printf 'OS: %s\nArchitecture: %s\nPackage manager: %s\n' "$label" "$ARCH" "$PACKAGE_MANAGER"
}
