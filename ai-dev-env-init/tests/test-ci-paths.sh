#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CI_FILE="${ROOT}/.github/workflows/ci.yml"

grep -Fq 'bash ai-dev-env-init/tests/run.sh' "$CI_FILE"
grep -Fq 'bash -n ai-dev-env-init/install.sh ai-dev-env-init/bin/tu ai-dev-env-init/bin/tu-wrapper ai-dev-env-init/lib/*.sh ai-dev-env-init/scripts/*.sh ai-dev-env-init/tests/*.sh' "$CI_FILE"
grep -Fq 'shellcheck ai-dev-env-init/install.sh ai-dev-env-init/bin/tu ai-dev-env-init/bin/tu-wrapper ai-dev-env-init/lib/*.sh ai-dev-env-init/scripts/*.sh ai-dev-env-init/tests/*.sh' "$CI_FILE"

printf 'ci paths test passed\n'
