#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="$(bash "$ROOT/bin/tu" doctor)"
[[ "$output" == *"Tu DevKit Doctor"* ]]
[[ "$output" == *"System"* ]]
printf 'doctor test passed\n'
