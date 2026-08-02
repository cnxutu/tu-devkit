#!/usr/bin/env bash

doctor_profile_requires() {
  local profile="$1" key="$2"
  case "$profile" in
    lite)
      case "$key" in git|curl|zsh|java|maven|nvm|node|npm|pnpm|docker|vscode|codex) return 0;; esac
      ;;
    standard)
      case "$key" in git|curl|zsh|java|maven|nvm|node|npm|pnpm|docker|vscode|codex|python|pip|uv|opencode) return 0;; esac
      ;;
    ultimate)
      case "$key" in git|curl|zsh|java|maven|nvm|node|npm|pnpm|docker|vscode|codex|python|pip|uv|opencode|rustc|cargo|rustfmt|clippy|kubectl) return 0;; esac
      ;;
  esac
  return 1
}

doctor_target_profile() {
  local arg target="lite"
  for arg in "$@"; do
    [[ "$arg" == --* || "$arg" == -v ]] || target="$arg"
  done
  case "$target" in lite|standard|ultimate) printf '%s\n' "$target";; *) return 1;; esac
}

doctor_main() {
  local profile
  profile="$(doctor_target_profile "$@")" || {
    log_error '检查档位只能是：lite、standard、ultimate'
    return 2
  }
  parse_flags "$@"; detect_platform
  local issues=0 item key label cmd required marker
  printf 'Tu DevKit Doctor（%s）\n' "$profile"
  printf '说明：[必需] 属于所选档位的完成条件；[可选] 仅供参考。\n\n'
  printf '系统\n'; platform_summary | sed 's/^/  /'
  printf '\n工具\n'
  for item in \
    'git:Git:git' 'curl:Curl:curl' 'zsh:Zsh:zsh' 'gh:GitHub CLI:gh' 'lazygit:Lazygit:lazygit' \
    'java:Java:java' 'maven:Maven:mvn' 'nvm:NVM:nvm' 'node:Node:node' 'npm:npm:npm' 'pnpm:pnpm:pnpm' \
    'python:Python:python3' 'pip:pip:pip3' 'uv:uv:uv' 'docker:Docker CLI:docker' 'vscode:VS Code:code' \
    'codex:Codex CLI:codex' 'opencode:OpenCode:opencode' 'rustc:Rust:rustc' 'cargo:Cargo:cargo' \
    'rustfmt:rustfmt:rustfmt' 'clippy:Clippy:clippy-driver' 'kubectl:Kubernetes CLI:kubectl'; do
    IFS=: read -r key label cmd <<<"$item"
    if doctor_profile_requires "$profile" "$key"; then required=1; marker='必需'; else required=0; marker='可选'; fi
    if [[ "$cmd" == nvm ]]; then safe_source "${NVM_DIR:-$HOME/.nvm}/nvm.sh"; fi
    if has "$cmd" || { [[ "$cmd" == nvm ]] && declare -F nvm >/dev/null 2>&1; }; then
      printf '  ✓ %-18s %-9s %s\n' "$label" "[$marker]" "$(version_of "$cmd")"
    else
      printf '  ✗ %-18s %-9s 缺失\n' "$label" "[$marker]"
      [[ "$required" == 1 ]] && issues=$((issues + 1))
    fi
  done
  if has docker && docker compose version >/dev/null 2>&1; then
    printf '  ✓ %-18s %-9s %s\n' 'Docker Compose' '[必需]' "$(docker compose version 2>/dev/null | head -n 1)"
  elif has docker-compose; then
    printf '  ✓ %-18s %-9s %s\n' 'Docker Compose' '[必需]' "$(version_of docker-compose)"
  else
    printf '  ✗ %-18s %-9s 缺失\n' 'Docker Compose' '[必需]'
    issues=$((issues + 1))
  fi
  if has docker && ! docker info >/dev/null 2>&1; then
    if [[ "$IS_WSL" == 1 ]]; then printf '  ! Docker daemon              不可用（检查 Docker Desktop WSL integration）\n'
    else printf '  ! Docker daemon              不可用（启动 Docker Desktop 或 Docker daemon）\n'; fi
  fi
  if has git; then
    [[ -n "$(git config --global user.name 2>/dev/null || true)" ]] || printf '  ! Git user.name              未配置\n'
    [[ -n "$(git config --global user.email 2>/dev/null || true)" ]] || printf '  ! Git user.email             未配置\n'
    if [[ -f "$HOME/.ssh/id_ed25519" || -f "$HOME/.ssh/id_rsa" ]]; then printf '  ✓ Git SSH key                found\n'
    else printf '  - Git SSH key                未配置（仅 GitHub SSH remote 需要）\n'; fi
  fi
  if [[ "$profile" == ultimate ]]; then
    printf '  - OpenRouter provider           需手动运行：tu ai openrouter（在官方界面输入 API Key）\n'
  fi
  if (( issues > 0 )); then
    printf '\n所选档位 %s：缺少 %s 项必需 CLI。补救：tu install %s --yes\n' "$profile" "$issues" "$profile"
  else
    printf '\n所选档位 %s：必需 CLI 已就绪。\n' "$profile"
  fi
  if [[ "$STRICT" == 1 && "$issues" -gt 0 ]]; then return 1; fi
}
