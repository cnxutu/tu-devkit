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
  mkdir -p "$HOME/.nvm" "$HOME/fake-bin"
  printf "export PATH=\"$HOME/fake-bin:\$PATH\"\n" > "$HOME/.nvm/nvm.sh"
  printf "#!/usr/bin/env bash\nprintf codex-from-nvm\\n" > "$HOME/fake-bin/codex"
  printf "#!/usr/bin/env bash\nprintf 'opencode-from-nvm: %s\\n' \"\$*\"\n" > "$HOME/fake-bin/opencode"
  chmod +x "$HOME/fake-bin/codex"
  chmod +x "$HOME/fake-bin/opencode"
  [[ "$(ai_main codex)" == "codex-from-nvm" ]]
  [[ "$(ai_main opencode run "explain this repository")" == "opencode-from-nvm: run explain this repository" ]]
'

printf 'setup-ai test passed\n'
