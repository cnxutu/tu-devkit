#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKAGE_ROOT="${ROOT}/ai-dev-env-init"

for required in bin lib profiles scripts tests; do
  [[ -d "${PACKAGE_ROOT}/${required}" ]]
done

[[ -x "${PACKAGE_ROOT}/bin/tu" ]]
[[ -x "${PACKAGE_ROOT}/install.sh" ]]
[[ -x "${PACKAGE_ROOT}/tests/run.sh" ]]
[[ -f "${PACKAGE_ROOT}/install.sh" ]]
[[ -f "${PACKAGE_ROOT}/scripts/bootstrap.sh" ]]
grep -Fq 'ai-dev-env-init' "${ROOT}/README.md"

printf 'layout test passed\n'
