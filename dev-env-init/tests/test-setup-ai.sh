#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034 # Dynamic sources and test doubles are exercised indirectly.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_home="$(mktemp -d)"

(
  set -Eeuo pipefail
  export HOME="$test_home"
  export NVM_DIR="$HOME/.nvm"
  source "$ROOT/lib/logging.sh"
  source "$ROOT/lib/platform.sh"
  source "$ROOT/lib/utils.sh"
  source "$ROOT/scripts/bootstrap.sh"
  source "$ROOT/scripts/setup-ai.sh"
  detect_platform() { OS=linux; IS_WSL=0; PACKAGE_MANAGER=none; }
  setup_ai_main --dry-run
  [[ "$(profile_modules ai-dev-environment)" == $'base\nshell\ngit\nnode\npython\nai\nvscode' ]]
  [[ ! -e "$HOME/.zshrc" && ! -e "$HOME/.nvm" ]]
  opencode() { printf "%s\\n" "$*" > "$HOME/opencode-args"; }
  ai_main openrouter
  [[ "$(cat "$HOME/opencode-args")" == "auth login" ]]
  unset -f opencode
  PATH=/usr/bin:/bin
  if ai_main openrouter >/dev/null 2>&1; then
    exit 1
  fi
  mkdir -p "$HOME/.nvm" "$HOME/fake-bin"
  printf "export PATH=\"$HOME/fake-bin:\$PATH\"\n" > "$HOME/.nvm/nvm.sh"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "codex-from-nvm\n"' > "$HOME/fake-bin/codex"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "opencode-from-nvm: %s\n" "$*"' > "$HOME/fake-bin/opencode"
  chmod +x "$HOME/fake-bin/codex"
  chmod +x "$HOME/fake-bin/opencode"
  [[ "$(ai_main codex)" == "codex-from-nvm" ]]
  [[ "$(ai_main opencode run "explain this repository")" == "opencode-from-nvm: run explain this repository" ]]
)

printf 'setup-ai test passed\n'
