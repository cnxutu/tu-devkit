#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for test in "$ROOT"/tests/test-*.sh; do bash "$test"; done
