#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="$(bash "$ROOT/bin/tu" doctor)"
[[ "$output" == *"Tu DevKit Doctor"* ]]
[[ "$output" == *"系统"* ]]
[[ "$output" == *"lite"* ]]
[[ "$output" == *"必需"* ]]
output="$(bash "$ROOT/bin/tu" doctor ultimate)"
[[ "$output" == *"ultimate"* ]]
if bash "$ROOT/bin/tu" doctor unknown >/dev/null 2>&1; then
  printf 'doctor accepted an unknown profile\n' >&2
  exit 1
fi
source "$ROOT/lib/utils.sh"
parse_flags --strict
[[ "$STRICT" == 1 ]]
safe_source "$ROOT/tests/does-not-exist.sh"
printf 'doctor test passed\n'
