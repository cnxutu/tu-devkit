#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/logging.sh"
source "$ROOT/lib/platform.sh"
source "$ROOT/lib/utils.sh"
source "$ROOT/scripts/bootstrap.sh"
for profile in minimal standard java frontend python-ai rust devops hardware; do
  [[ "$(profile_modules "$profile")" == *base* ]]
done
printf 'profile test passed\n'
