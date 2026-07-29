#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/platform.sh"
detect_platform
[[ -n "$OS" && -n "$ARCH" && -n "$PACKAGE_MANAGER" ]]
uname() { printf 'Linux\n'; }
WSL_DISTRO_NAME=Ubuntu
detect_platform
[[ "$OS" == linux && "$IS_WSL" == 1 ]]
printf 'platform test passed\n'
