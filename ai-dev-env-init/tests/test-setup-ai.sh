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
  opencode() { printf "%s\\n" "$*" > "$HOME/opencode-args"; }
  ai_main openrouter
  [[ "$(cat "$HOME/opencode-args")" == "auth login" ]]
  unset -f opencode
  if ai_main openrouter >/dev/null 2>&1; then
    exit 1
  fi
'

printf 'setup-ai test passed\n'
