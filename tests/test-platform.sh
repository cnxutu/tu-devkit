#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/platform.sh"
detect_platform
[[ -n "$OS" && -n "$ARCH" && -n "$PACKAGE_MANAGER" ]]
printf 'platform test passed\n'
