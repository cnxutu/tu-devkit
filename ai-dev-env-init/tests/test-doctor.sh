#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="$(bash "$ROOT/bin/tu" doctor)"
[[ "$output" == *"Tu DevKit Doctor"* ]]
[[ "$output" == *"系统"* ]]
source "$ROOT/lib/utils.sh"
parse_flags --strict
[[ "$STRICT" == 1 ]]
printf 'doctor test passed\n'
