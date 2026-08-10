#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CI_FILE="${ROOT}/.github/workflows/ci.yml"

grep -Fq 'bash dev-env-init/tests/run.sh' "$CI_FILE"
grep -Fq 'bash -n dev-env-init/install.sh dev-env-init/bin/tu dev-env-init/bin/tu-wrapper dev-env-init/lib/*.sh dev-env-init/scripts/*.sh dev-env-init/tests/*.sh' "$CI_FILE"
grep -Fq 'shellcheck dev-env-init/install.sh dev-env-init/bin/tu dev-env-init/bin/tu-wrapper dev-env-init/lib/*.sh dev-env-init/scripts/*.sh dev-env-init/tests/*.sh' "$CI_FILE"

printf 'ci paths test passed\n'
