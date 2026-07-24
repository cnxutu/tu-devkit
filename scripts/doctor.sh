#!/usr/bin/env bash
doctor_main() {
  parse_flags "$@"; detect_platform
  printf 'Tu DevKit Doctor\n\n系统\n'; platform_summary | sed 's/^/  /'
  printf '\n工具\n'; local item cmd; for item in 'Git:git' 'Curl:curl' 'Zsh:zsh' 'GitHub CLI:gh' 'Lazygit:lazygit' 'Java:java' 'Maven:mvn' 'NVM:nvm' 'Node:node' 'npm:npm' 'pnpm:pnpm' 'Python:python3' 'pip:pip3' 'uv:uv' 'Docker:docker' 'VS Code:code' 'Codex CLI:codex' 'OpenCode:opencode'; do cmd="${item#*:}"; if [[ "$cmd" == nvm ]]; then safe_source "${NVM_DIR:-$HOME/.nvm}/nvm.sh"; fi; if has "$cmd" || ( [[ "$cmd" == nvm ]] && declare -F nvm >/dev/null 2>&1 ); then printf '  ✓ %-16s %s\n' "${item%%:*}" "$(version_of "$cmd")"; else printf '  ✗ %-16s 缺失\n' "${item%%:*}"; fi; done
  if has docker && docker compose version >/dev/null 2>&1; then printf '  ✓ Docker Compose   %s\n' "$(docker compose version 2>/dev/null | head -n 1)";
  elif has docker-compose; then printf '  ✓ Docker Compose   %s\n' "$(version_of docker-compose)";
  else printf '  ✗ Docker Compose   缺失\n'; fi
  if has docker && ! docker info >/dev/null 2>&1; then
    if [[ "$IS_WSL" == 1 ]]; then printf '  ! Docker daemon     不可用（检查 Docker Desktop WSL integration 或原生 daemon）\n';
    else printf '  ! Docker daemon     不可用（启动 Docker Desktop 或 Docker daemon）\n'; fi
  fi
  has git && { [[ -z "$(git config --global user.email 2>/dev/null || true)" ]] && printf '  ! Git user.email     未配置\n' || true; }
}
