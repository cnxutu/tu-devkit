#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_home="$(mktemp -d)"

HOME="$test_home" bash -c '
  set -Eeuo pipefail
  source "'$ROOT'/lib/logging.sh"
  source "'$ROOT'/lib/platform.sh"
  source "'$ROOT'/lib/utils.sh"
  source "'$ROOT'/scripts/bootstrap.sh"
  source "'$ROOT'/scripts/setup-ai.sh"
  detect_platform() { OS=linux; IS_WSL=0; PACKAGE_MANAGER=none; }
  setup_ai_main --dry-run
  [[ "$(profile_modules ai-dev-environment)" == $'"'"'base\nshell\ngit\nnode\npython\nai\nvscode'"'"' ]]
  [[ ! -e "$HOME/.zshrc" && ! -e "$HOME/.nvm" ]]
'

printf 'setup-ai test passed\n'
