#!/usr/bin/env bash

setup_wsl_main() {
  parse_flags "$@"
  detect_platform
  if [[ "$OS" != linux || "$IS_WSL" != 1 ]]; then
    log_error 'tu setup wsl 只能在 Ubuntu WSL2 中运行'
    return 1
  fi

  local data_root="${TU_WSL_DATA_ROOT:-/data}"
  local workspace="${TU_WSL_WORKSPACE:-${data_root}/workspace}" arg
  while (($#)); do
    case "$1" in
      --path) [[ -n "${2:-}" ]] || { log_error '--path 需要目录参数'; return 2; }; workspace="$2"; shift 2;;
      *) shift;;
    esac
  done
  local user_name="${USER:-$(id -un)}" group_name uid gid path test_file
  group_name="$(id -gn)"; uid="$(id -u)"; gid="$(id -g)"
  if [[ "$DRY_RUN" == 1 ]]; then
    log_info "[DRY-RUN] prepare WSL data root and workspace: $data_root, $workspace"
    log_info "[DRY-RUN] repair the targeted workspace and user directories; do not recursively change unrelated data"
    return 0
  fi
  if [[ "$workspace" == /mnt/* ]]; then
    log_warn "当前工作区位于 Windows 挂载盘：$workspace"
    log_warn 'Linux 工具链建议使用 /data/workspace，避免 node_modules、Git 和文件权限/性能问题'
  fi

  if [[ ! -e "$data_root" ]]; then
    if mkdir -p "$data_root" 2>/dev/null; then log_ok "Created $data_root"
    elif confirm "使用 sudo 创建并将 $data_root 目录归当前用户所有？"; then
      run sudo install -d -o "$uid" -g "$gid" -m 0755 "$data_root"
    else log_warn "无法创建 $data_root"; fi
  fi
  local paths=(
    "$workspace"
    "${HOME}/.local"
    "${HOME}/.config/tu-devkit"
    "${HOME}/.cache"
    "${HOME}/.m2"
    "${HOME}/.npm"
    "${HOME}/.nvm"
  )
  for path in "${paths[@]}"; do
    if [[ ! -e "$path" ]]; then
      if mkdir -p "$path" 2>/dev/null; then
        log_ok "Created $path"
      elif confirm "使用 sudo 创建并将 $path 归当前用户所有？"; then
        run sudo install -d -o "$uid" -g "$gid" -m 0755 "$path"
      else
        log_warn "无法创建 $path"
      fi
    fi
    [[ -e "$path" ]] || continue
    if [[ ! -w "$path" ]]; then
      log_warn "当前用户没有写权限：$path"
      if confirm "使用 sudo 将 $path 及其内容归 ${user_name}:${group_name}？"; then
        run sudo chown -R "${uid}:${gid}" "$path"
      fi
    fi
  done

  test_file="${workspace}/.tu-devkit-write-test.$$"
  if printf 'tu-devkit\n' > "$test_file" 2>/dev/null; then
    rm -f "$test_file"
    log_ok "Workspace writable: $workspace"
  else
    log_error "Workspace is not writable: $workspace"
    log_info "建议执行：sudo chown -R ${user_name}:${group_name} '$workspace'"
    return 1
  fi

  if has docker && ! id -nG | tr ' ' '\n' | grep -qx docker; then
    log_warn '当前用户不在 docker group；Docker Desktop WSL integration 通常不需要该组'
    log_info '仅使用 WSL 内原生 Docker Engine 时，才考虑：sudo usermod -aG docker "$USER"'
  fi
  log_info 'WSL 权限初始化完成；项目建议放在 /data/workspace，而不是 /mnt/c/...'
}
