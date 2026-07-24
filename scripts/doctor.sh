#!/usr/bin/env bash
doctor_main() {
  parse_flags "$@"; detect_platform
  printf 'Tu DevKit Doctor\n\nSystem\n'; platform_summary | sed 's/^/  /'
  printf '\nTools\n'; local item cmd; for item in 'Git:git' 'Curl:curl' 'Zsh:zsh' 'GitHub CLI:gh' 'Lazygit:lazygit' 'Java:java' 'Maven:mvn' 'NVM:nvm' 'Node:node' 'npm:npm' 'pnpm:pnpm' 'Python:python3' 'pip:pip3' 'uv:uv' 'Docker:docker' 'Docker Compose:docker-compose' 'VS Code:code' 'Codex CLI:codex' 'OpenCode:opencode'; do cmd="${item#*:}"; if [[ "$cmd" == nvm ]]; then safe_source "${NVM_DIR:-$HOME/.nvm}/nvm.sh"; fi; if has "$cmd" || ( [[ "$cmd" == nvm ]] && declare -F nvm >/dev/null 2>&1 ); then printf '  ✓ %-16s %s\n' "${item%%:*}" "$(version_of "$cmd")"; else printf '  ✗ %-16s missing\n' "${item%%:*}"; fi; done
  if has docker && ! docker info >/dev/null 2>&1; then
    if [[ "$IS_WSL" == 1 ]]; then printf '  ! Docker daemon     unavailable (check Docker Desktop WSL integration or native daemon)\n';
    else printf '  ! Docker daemon     unavailable (start Docker Desktop or the Docker daemon)\n'; fi
  fi
  has git && { [[ -z "$(git config --global user.email 2>/dev/null || true)" ]] && printf '  ! Git user.email     not configured\n' || true; }
}
