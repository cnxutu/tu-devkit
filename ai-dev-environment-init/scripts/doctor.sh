#!/usr/bin/env bash
doctor_main() {
  parse_flags "$@"; detect_platform; local issues=0
  printf 'Tu DevKit Doctor\n\n系统\n'; platform_summary | sed 's/^/  /'
  printf '\n工具\n'; local item cmd; for item in 'Git:git' 'Curl:curl' 'Zsh:zsh' 'GitHub CLI:gh' 'Lazygit:lazygit' 'Java:java' 'Maven:mvn' 'NVM:nvm' 'Node:node' 'npm:npm' 'pnpm:pnpm' 'Python:python3' 'pip:pip3' 'uv:uv' 'Docker:docker' 'VS Code:code' 'Codex CLI:codex' 'OpenCode:opencode'; do cmd="${item#*:}"; if [[ "$cmd" == nvm ]]; then safe_source "${NVM_DIR:-$HOME/.nvm}/nvm.sh"; fi; if has "$cmd" || ( [[ "$cmd" == nvm ]] && declare -F nvm >/dev/null 2>&1 ); then printf '  ✓ %-16s %s\n' "${item%%:*}" "$(version_of "$cmd")"; else printf '  ✗ %-16s 缺失\n' "${item%%:*}"; issues=$((issues + 1)); fi; done
  if has docker && docker compose version >/dev/null 2>&1; then printf '  ✓ Docker Compose   %s\n' "$(docker compose version 2>/dev/null | head -n 1)";
  elif has docker-compose; then printf '  ✓ Docker Compose   %s\n' "$(version_of docker-compose)";
  else printf '  ✗ Docker Compose   缺失\n'; issues=$((issues + 1)); fi
  if has docker && ! docker info >/dev/null 2>&1; then
    if [[ "$IS_WSL" == 1 ]]; then printf '  ! Docker daemon     不可用（检查 Docker Desktop WSL integration 或原生 daemon）\n';
    else printf '  ! Docker daemon     不可用（启动 Docker Desktop 或 Docker daemon）\n'; fi
    issues=$((issues + 1))
  fi
  if has git; then
    if [[ -z "$(git config --global user.name 2>/dev/null || true)" ]]; then printf '  ! Git user.name     未配置\n'; issues=$((issues + 1)); fi
    if [[ -z "$(git config --global user.email 2>/dev/null || true)" ]]; then printf '  ! Git user.email    未配置\n'; issues=$((issues + 1)); fi
    if [[ -f "$HOME/.ssh/id_ed25519" || -f "$HOME/.ssh/id_rsa" ]]; then printf '  ✓ Git SSH key       found\n';
    else printf '  - Git SSH key       未配置（如使用 GitHub SSH，请手动生成）\n'; fi
  fi
  if [[ "$STRICT" == 1 && "$issues" -gt 0 ]]; then
    printf '\n严格检查失败：%s 项需要处理。\n' "$issues"
    return 1
  fi
}
