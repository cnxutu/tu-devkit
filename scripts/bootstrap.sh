#!/usr/bin/env bash
install_packages() {
  local packages=("$@"); ((${#packages[@]})) || return 0
  case "$PACKAGE_MANAGER" in
    brew) log_info "Homebrew packages: ${packages[*]}"; confirm "Install missing packages?" && run brew install "${packages[@]}" || log_warn "Skipped package installation" ;;
    apt) log_info "APT packages: ${packages[*]}"; confirm "Install missing packages (sudo may be required)?" && run sudo apt-get update && run sudo apt-get install -y "${packages[@]}" || log_warn "Skipped package installation" ;;
    *) log_warn "No supported package manager detected";;
  esac
}
package_present() {
  case "$PACKAGE_MANAGER" in
    apt) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed' ;;
    brew) brew list --formula "$1" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}
ensure_packages() {
  local pkg command package; local missing=()
  for pkg in "$@"; do
    command="${pkg%%:*}"; package="${pkg#*:}"
    has "$command" || package_present "$package" || missing+=("$package")
  done
  if ((${#missing[@]})); then install_packages "${missing[@]}"; fi
}
install_base() {
  if [[ "$PACKAGE_MANAGER" == apt ]]; then
    ensure_packages git:git curl:curl wget:wget unzip:unzip zip:zip jq:jq tree:tree make:make ca-certificates:ca-certificates gpg:gnupg ssh:openssh-client zsh:zsh
  elif [[ "$PACKAGE_MANAGER" == brew ]]; then
    ensure_packages git:git curl:curl wget:wget unzip:unzip zip:zip jq:jq tree:tree make:make ca-certificates:ca-certificates gpg:gnupg ssh:openssh zsh:zsh
  fi
  ensure_packages gh:gh lazygit:lazygit
}
install_shell() {
  has zsh || { log_warn "zsh is missing"; return 0; }
  local rc="${HOME}/.zshrc"; touch "$rc"
  if ! grep -q 'tu-devkit shell configuration' "$rc" 2>/dev/null; then backup_file "$rc"; cat >> "$rc" <<'EOF'

# tu-devkit shell configuration
export PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/.nvm" ]] && export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
alias ll='ls -alF'
EOF
  fi
  if [[ ! -d "${HOME}/.oh-my-zsh" ]] && confirm "Install Oh My Zsh from the official installer?"; then
    local tmp; tmp="$(mktemp)"; curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$tmp"; RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$tmp"; rm -f "$tmp"
  else has oh-my-zsh || [[ -d "${HOME}/.oh-my-zsh" ]] || log_skip "Oh My Zsh"; fi
}
install_git() {
  if ! has git; then ensure_packages git:git; fi
  has git || { log_error 'Git is not installed'; return 1; }
  git config --global init.defaultBranch main 2>/dev/null || true
  [[ -n "$(git config --global user.name 2>/dev/null || true)" ]] || log_warn 'Git user.name is not configured'
  [[ -n "$(git config --global user.email 2>/dev/null || true)" ]] || log_warn 'Git user.email is not configured'
  if [[ ! -f "$HOME/.ssh/id_ed25519" && ! -f "$HOME/.ssh/id_rsa" ]]; then
    log_warn 'No SSH key found; generate one manually if you use GitHub SSH remotes'
    log_info 'Example: ssh-keygen -t ed25519 -C "your-email@example.com"'
  fi
  has gh && gh auth status >/dev/null 2>&1 || log_warn 'GitHub CLI is not authenticated; run: gh auth login'
}
install_java() {
  if [[ "$PACKAGE_MANAGER" == apt ]]; then install_packages openjdk-17-jdk maven gradle
  elif [[ "$PACKAGE_MANAGER" == brew ]]; then install_packages openjdk@17 maven gradle
  fi
}
install_node() {
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"; mkdir -p "$nvm_dir"
  if [[ ! -s "$nvm_dir/nvm.sh" ]]; then
    confirm "Install NVM from the official GitHub release?" || return 0
    local tmp; tmp="$(mktemp)"; curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh -o "$tmp"; PROFILE=/dev/null NVM_DIR="$nvm_dir" bash "$tmp"; rm -f "$tmp"
  fi
  safe_source "$nvm_dir/nvm.sh"
  if declare -F nvm >/dev/null 2>&1; then nvm install --lts; nvm alias default 'lts/*'; corepack enable 2>/dev/null || true; has pnpm || npm install --global pnpm; fi
}
install_python() {
  if [[ "$PACKAGE_MANAGER" == apt ]]; then ensure_packages python3:python3 python3-pip:python3-pip pipx:pipx
  elif [[ "$PACKAGE_MANAGER" == brew ]]; then ensure_packages python3:python pipx:pipx
  fi
  if ! has uv && confirm 'Install uv using the official installer?'; then
    local tmp; tmp="$(mktemp)"; curl -LsSf https://astral.sh/uv/install.sh -o "$tmp"; sh "$tmp"; rm -f "$tmp"
  fi
}
install_docker() {
  if has docker; then log_skip "Docker CLI already installed"
  elif [[ "$OS" == macos && "$PACKAGE_MANAGER" == brew ]]; then
    log_info 'macOS Docker support uses Docker Desktop; the daemon runs outside the shell.'
    confirm 'Install Docker Desktop with Homebrew Cask?' && run brew install --cask docker || log_warn 'Skipped Docker Desktop installation'
  else log_warn '请安装 Docker Desktop（macOS/WSL2）或 Docker Engine（Linux），然后重新运行 tu doctor'; fi
}
install_vscode() { has code && log_skip 'VS Code code command' || log_warn 'VS Code code command unavailable; install VS Code and enable Shell Command: Install code command in PATH'; }
install_official_script() {
  local url="$1" label="$2" tmp
  confirm "从官方地址安装 ${label}？" || return 0
  tmp="$(mktemp)"
  if curl -fsSL "$url" -o "$tmp" && grep -Eiq '(codex|opencode)' "$tmp"; then
    bash "$tmp"
  else
    log_error "无法验证 ${label} 官方安装脚本，已停止执行"
  fi
  rm -f "$tmp"
}
install_ai() {
  if ! has codex; then
    if has npm && confirm '通过 @openai/codex npm 包安装 Codex CLI？'; then run npm install --global @openai/codex
    elif [[ "$OS" == macos ]] && has brew && confirm '通过 Homebrew Cask 安装 Codex CLI？'; then run brew install --cask codex
    else install_official_script 'https://chatgpt.com/codex/install.sh' 'Codex CLI'; fi
  else log_skip 'Codex CLI'; fi
  if ! has opencode; then
    if has npm && confirm '通过 opencode-ai npm 包安装 OpenCode？'; then run npm install --global opencode-ai
    elif [[ "$OS" == macos ]] && has brew && confirm '通过 Homebrew 安装 OpenCode？'; then run brew install anomalyco/tap/opencode
    else install_official_script 'https://opencode.ai/install' 'OpenCode'; fi
  else log_skip 'OpenCode'; fi
}
ai_main() {
  local action="${1:-help}"
  case "$action" in
    help) cat <<'EOF'
AI 工具命令：
  tu ai login       依次启动 Codex 和 OpenCode 登录流程
  tu ai codex       打开 Codex CLI
  tu ai opencode    打开 OpenCode TUI
  tu ai status      检查 AI CLI 是否已安装
EOF
      ;;
    status) doctor_main ;;
    login)
      has codex || { log_error 'Codex CLI 未安装，请先运行: tu install standard --yes'; return 1; }
      has opencode || { log_error 'OpenCode 未安装，请先运行: tu install standard --yes'; return 1; }
      log_info '即将启动 Codex。首次运行时选择 Sign in with ChatGPT。'; codex
      log_info '即将启动 OpenCode provider 登录。'; opencode auth login
      ;;
    codex) has codex && exec codex || { log_error 'Codex CLI 未安装'; return 1; } ;;
    opencode) has opencode && exec opencode || { log_error 'OpenCode 未安装'; return 1; } ;;
    *) log_error "未知 AI 操作: $action"; ai_main help; return 2 ;;
  esac
}
install_module() { case "$1" in base|minimal) install_base;; shell) install_shell;; git) install_git;; java) install_java;; node|frontend) install_node;; python|python-ai) install_python;; docker) install_docker;; vscode) install_vscode;; ai|standard) install_ai;; rust|devops|hardware) log_warn "$1 profile is scaffolded; no automatic installer yet";; *) log_error "Unknown module/profile: $1"; return 2;; esac; }
profile_modules() { case "$1" in minimal) printf '%s\n' base shell git vscode;; standard) printf '%s\n' base shell git java node python docker vscode ai;; java) printf '%s\n' base shell git java docker vscode;; frontend) printf '%s\n' base shell git node vscode;; python-ai) printf '%s\n' base shell git python ai vscode;; rust|devops|hardware) printf '%s\n' base shell git "$1" vscode;; *) return 2;; esac; }
install_profile() { local profile="$1"; parse_flags "${@:2}"; detect_platform; [[ "$OS" != unsupported ]] || { log_error 'Unsupported operating system'; return 1; }; log_info "Installing profile: $profile"; while read -r module; do install_module "$module"; done < <(profile_modules "$profile"); }
install_target() { local target="$1"; shift; parse_flags "$@"; detect_platform; case "$target" in minimal|standard|java|frontend|python-ai|rust|devops|hardware) install_profile "$target" "$@";; *) install_module "$target";; esac; }
select_profile() { cat <<'EOF'
Tu DevKit
1. 标准 AI 全栈环境
2. 最小基础环境
3. Java 后端
4. 前端开发
5. Python 与 AI
6. Rust 开发
7. DevOps
8. 硬件与 IoT
9. 自定义选择
10. 仅运行诊断
EOF
  local choice; read -r -p '请选择安装模式 [1-10]: ' choice
  case "$choice" in 1) SELECTED_PROFILE=standard;;2) SELECTED_PROFILE=minimal;;3) SELECTED_PROFILE=java;;4) SELECTED_PROFILE=frontend;;5) SELECTED_PROFILE=python-ai;;6) SELECTED_PROFILE=rust;;7) SELECTED_PROFILE=devops;;8) SELECTED_PROFILE=hardware;;10) SELECTED_PROFILE=doctor;;9) SELECTED_PROFILE=custom;;*) log_error '选择无效'; return 2;; esac
  [[ "$SELECTED_PROFILE" == custom ]] && { read -r -p '请输入以空格分隔的模块（如 base node python）: ' CUSTOM_MODULES; for m in $CUSTOM_MODULES; do install_module "$m"; done; return 0; }
  [[ "$SELECTED_PROFILE" == doctor ]] && { doctor_main; return 0; }
}
list_profiles() { cat <<'EOF'
配置档案: minimal, standard, java, frontend, python-ai, rust, devops, hardware
模块: base, shell, git, java, node, python, docker, vscode, ai
EOF
}
