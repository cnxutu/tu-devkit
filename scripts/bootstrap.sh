#!/usr/bin/env bash
install_packages() {
  local packages=("$@"); ((${#packages[@]})) || return 0
  case "$PACKAGE_MANAGER" in
    brew) log_info "Homebrew packages: ${packages[*]}"; confirm "Install missing packages?" && run brew install "${packages[@]}" || log_warn "Skipped package installation" ;;
    apt) log_info "APT packages: ${packages[*]}"; confirm "Install missing packages (sudo may be required)?" && run sudo apt-get update && run sudo apt-get install -y "${packages[@]}" || log_warn "Skipped package installation" ;;
    *) log_warn "No supported package manager detected";;
  esac
}
ensure_packages() {
  local pkg; local missing=()
  for pkg in "$@"; do has "${pkg%%:*}" || missing+=("${pkg#*:}"); done
  install_packages "${missing[@]}"
}
install_base() { [[ "$PACKAGE_MANAGER" == apt ]] && ensure_packages git:git curl:curl wget:wget unzip:unzip zip:zip jq:jq tree:tree make:make ca-certificates:ca-certificates gnupg:gnupg openssh-client:openssh-client zsh:zsh || [[ "$PACKAGE_MANAGER" == brew ]] && ensure_packages git:git curl:curl wget:wget unzip:unzip zip:zip jq:jq tree:tree make:make ca-certificates:ca-certificates gnupg:gnupg openssh-client:openssh-client zsh:zsh; ensure_packages gh:gh lazygit:lazygit; }
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
  git config --global init.defaultBranch main 2>/dev/null || true
  has git || return 0
  [[ -n "$(git config --global user.name 2>/dev/null || true)" ]] || log_warn 'Git user.name is not configured'
  [[ -n "$(git config --global user.email 2>/dev/null || true)" ]] || log_warn 'Git user.email is not configured'
  has gh && gh auth status >/dev/null 2>&1 || log_warn 'GitHub CLI is not authenticated; run: gh auth login'
}
install_java() { [[ "$PACKAGE_MANAGER" == apt ]] && install_packages openjdk-17-jdk maven gradle || [[ "$PACKAGE_MANAGER" == brew ]] && install_packages openjdk@17 maven gradle; }
install_node() {
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"; mkdir -p "$nvm_dir"
  if [[ ! -s "$nvm_dir/nvm.sh" ]]; then
    confirm "Install NVM from the official GitHub release?" || return 0
    local tmp; tmp="$(mktemp)"; curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh -o "$tmp"; PROFILE=/dev/null NVM_DIR="$nvm_dir" bash "$tmp"; rm -f "$tmp"
  fi
  safe_source "$nvm_dir/nvm.sh"
  if declare -F nvm >/dev/null 2>&1; then nvm install --lts; nvm alias default 'lts/*'; corepack enable 2>/dev/null || true; has pnpm || npm install --global pnpm; fi
}
install_python() { [[ "$PACKAGE_MANAGER" == apt ]] && install_packages python3 python3-pip pipx || [[ "$PACKAGE_MANAGER" == brew ]] && install_packages python pipx; if ! has uv && confirm 'Install uv using the official installer?'; then local tmp; tmp="$(mktemp)"; curl -LsSf https://astral.sh/uv/install.sh -o "$tmp"; sh "$tmp"; rm -f "$tmp"; fi; }
install_docker() { if has docker; then log_skip "Docker CLI already installed"; else [[ "$PACKAGE_MANAGER" == brew ]] && ensure_packages docker:docker docker-compose:docker-compose || log_warn 'Install Docker Desktop/Engine according to your platform'; fi; }
install_vscode() { has code && log_skip 'VS Code code command' || log_warn 'VS Code code command unavailable; install VS Code and enable Shell Command: Install code command in PATH'; }
install_ai() {
  if ! has codex; then
    if has npm && confirm 'Install Codex CLI from the @openai/codex npm package?'; then run npm install --global @openai/codex; else log_warn 'Codex CLI missing; install it from the official OpenAI Codex repository'; fi
  else log_skip 'Codex CLI'; fi
  if ! has opencode; then
    if has npm && confirm 'Install OpenCode from the opencode-ai npm package?'; then run npm install --global opencode-ai; else log_warn 'OpenCode missing; install it from the official OpenCode documentation'; fi
  else log_skip 'OpenCode'; fi
}
install_module() { case "$1" in base|minimal) install_base;; shell) install_shell;; git) install_git;; java) install_java;; node|frontend) install_node;; python|python-ai) install_python;; docker) install_docker;; vscode) install_vscode;; ai|standard) install_ai;; rust|devops|hardware) log_warn "$1 profile is scaffolded; no automatic installer yet";; *) log_error "Unknown module/profile: $1"; return 2;; esac; }
profile_modules() { case "$1" in minimal) printf '%s\n' base shell git vscode;; standard) printf '%s\n' base shell git java node python docker vscode ai;; java) printf '%s\n' base shell git java docker vscode;; frontend) printf '%s\n' base shell git node vscode;; python-ai) printf '%s\n' base shell git python ai vscode;; rust|devops|hardware) printf '%s\n' base shell git "$1" vscode;; *) return 2;; esac; }
install_profile() { local profile="$1"; parse_flags "${@:2}"; detect_platform; [[ "$OS" != unsupported ]] || { log_error 'Unsupported operating system'; return 1; }; log_info "Installing profile: $profile"; while read -r module; do install_module "$module"; done < <(profile_modules "$profile"); }
install_target() { local target="$1"; shift; case "$target" in minimal|standard|java|frontend|python-ai|rust|devops|hardware) install_profile "$target" "$@";; *) install_module "$target";; esac; }
select_profile() { cat <<'EOF'
Tu DevKit
1. Standard AI Full-Stack
2. Minimal Base Environment
3. Java Backend
4. Frontend
5. Python & AI
6. Rust Development
7. DevOps
8. Hardware & IoT
9. Custom Selection
10. Doctor Only
EOF
  local choice; read -r -p 'Select installation mode [1-10]: ' choice
  case "$choice" in 1) SELECTED_PROFILE=standard;;2) SELECTED_PROFILE=minimal;;3) SELECTED_PROFILE=java;;4) SELECTED_PROFILE=frontend;;5) SELECTED_PROFILE=python-ai;;6) SELECTED_PROFILE=rust;;7) SELECTED_PROFILE=devops;;8) SELECTED_PROFILE=hardware;;10) SELECTED_PROFILE=doctor;;9) read -r -p 'Enter modules separated by spaces: ' CUSTOM_MODULES; SELECTED_PROFILE=custom;;*) log_error 'Invalid selection'; return 2;; esac
  [[ "$SELECTED_PROFILE" == custom ]] && { for m in $CUSTOM_MODULES; do install_module "$m"; done; return 0; }
  [[ "$SELECTED_PROFILE" == doctor ]] && { doctor_main; return 0; }
}
list_profiles() { cat <<'EOF'
Profiles: minimal, standard, java, frontend, python-ai, rust, devops, hardware
Modules: base, shell, git, java, node, python, docker, vscode, ai
EOF
}
