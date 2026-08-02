#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/logging.sh"
source "$ROOT/lib/platform.sh"
source "$ROOT/lib/utils.sh"
source "$ROOT/scripts/bootstrap.sh"
for profile in lite standard ultimate minimal java frontend python-ai rust devops hardware; do
  [[ "$(profile_modules "$profile")" == *base* ]]
done
[[ "$(profile_modules lite)" == *codex* && "$(profile_modules lite)" != *python* && "$(profile_modules lite)" != *opencode* ]]
[[ "$(profile_modules standard)" == *python* && "$(profile_modules standard)" == *codex* && "$(profile_modules standard)" == *opencode* ]]
[[ "$(profile_modules ultimate)" == *python* && "$(profile_modules ultimate)" == *codex* && "$(profile_modules ultimate)" == *opencode* && "$(profile_modules ultimate)" == *openrouter* && "$(profile_modules ultimate)" == *rust* && "$(profile_modules ultimate)" == *devops* ]]
printf 'profile test passed\n'
