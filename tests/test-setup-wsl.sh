#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_home="$(mktemp -d)"
data_root="$(mktemp -d)/data"
HOME="$test_home" TU_WSL_DATA_ROOT="$data_root" bash -c '
  set -Eeuo pipefail
  source "'$ROOT'/lib/logging.sh"
  source "'$ROOT'/lib/platform.sh"
  source "'$ROOT'/lib/utils.sh"
  source "'$ROOT'/scripts/setup-wsl.sh"
  detect_platform() { OS=linux; IS_WSL=1; PACKAGE_MANAGER=apt; }
  YES=1
  setup_wsl_main --yes
  [[ -d "$TU_WSL_DATA_ROOT" && -d "$TU_WSL_DATA_ROOT/workspace" ]]
  test_file="$TU_WSL_DATA_ROOT/workspace/.tu-devkit-write-test.$$"
  printf ok > "$test_file"
  rm -f "$test_file"
'
printf 'setup-wsl test passed\n'

dry_home="$(mktemp -d)"
dry_root="$(mktemp -d)/data"
HOME="$dry_home" TU_WSL_DATA_ROOT="$dry_root" bash -c '
  set -Eeuo pipefail
  source "'$ROOT'/lib/logging.sh"
  source "'$ROOT'/lib/platform.sh"
  source "'$ROOT'/lib/utils.sh"
  source "'$ROOT'/scripts/setup-wsl.sh"
  detect_platform() { OS=linux; IS_WSL=1; PACKAGE_MANAGER=apt; }
  setup_wsl_main --dry-run
  [[ ! -e "$TU_WSL_DATA_ROOT" ]]
'
printf 'setup-wsl dry-run test passed\n'
