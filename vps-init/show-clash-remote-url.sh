#!/usr/bin/env bash
# shellcheck disable=SC1091 # Module path is resolved from this script at runtime.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/common.sh"
require_root
url_file="${VPS_INIT_STATE_DIR}/secrets/clash-remote-url"
[[ -s "$url_file" ]] || die 'Clash Remote URL is not available; enable clash_remote and run a Profile install.'
cat "$url_file"
