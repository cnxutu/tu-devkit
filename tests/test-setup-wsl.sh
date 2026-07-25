#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_home="$(mktemp -d)"
workspace="$(mktemp -d)/workspace"
HOME="$test_home" TU_WSL_WORKSPACE="$workspace" bash -c '
  set -Eeuo pipefail
  source "'$ROOT'/lib/logging.sh"
  source "'$ROOT'/lib/platform.sh"
  source "'$ROOT'/lib/utils.sh"
  source "'$ROOT'/scripts/setup-wsl.sh"
  detect_platform() { OS=linux; IS_WSL=1; PACKAGE_MANAGER=apt; }
  YES=1
  setup_wsl_main --yes
  [[ -d "$TU_WSL_WORKSPACE" ]]
  test_file="$TU_WSL_WORKSPACE/.tu-devkit-write-test.$$"
  printf ok > "$test_file"
  rm -f "$test_file"
'
printf 'setup-wsl test passed\n'
