#!/usr/bin/env bash

setup_git_main() {
  parse_flags "$@"
  local email="" arg key_file="${HOME}/.ssh/id_ed25519" public_key
  while (($#)); do
    case "$1" in
      --email) [[ -n "${2:-}" ]] || { log_error '--email 需要邮箱参数'; return 2; }; email="$2"; shift 2;;
      --test) export TU_GIT_SSH_TEST=1; shift;;
      *) shift;;
    esac
  done

  has ssh-keygen || { log_error '缺少 ssh-keygen；请先安装 OpenSSH client'; return 1; }
  if [[ ! -f "$key_file" ]]; then
    email="${email:-$(git config --global user.email 2>/dev/null || true)}"
    if [[ -z "$email" && "$YES" != 1 ]]; then
      read -r -p '用于 SSH key 注释的 GitHub 邮箱: ' email
    fi
    [[ -n "$email" ]] || { log_error '请通过 --email 或 git config --global user.email 提供邮箱'; return 2; }
    if [[ "$DRY_RUN" == 1 ]]; then
      log_info "[DRY-RUN] generate $key_file with comment: $email"
      return 0
    fi
    mkdir -p -m 700 "${HOME}/.ssh"
    log_info '将生成新的 Ed25519 私钥；请按提示设置并妥善保管 passphrase'
    ssh-keygen -t ed25519 -C "$email" -f "$key_file"
  else
    log_ok "Using existing SSH key: $key_file"
  fi

  public_key="${key_file}.pub"
  [[ -f "$public_key" ]] || { log_error "公钥不存在：$public_key；不会从私钥推导或显示私钥"; return 1; }
  printf '\n请复制以下公钥（只复制这一行，不要复制私钥）：\n\n'
  cat "$public_key"
  printf '\n\n然后在浏览器打开并添加为 Authentication Key：\n  https://github.com/settings/ssh/new\n'
  printf '添加后运行：\n  ssh -T git@github.com\n'
  printf '首次连接的主机指纹提示是正常的；请先与 GitHub 官方公布的指纹核对，再输入 yes。\n'
  if [[ "${TU_GIT_SSH_TEST:-0}" == 1 ]]; then
    local test_output
    if test_output="$(ssh -T git@github.com 2>&1)"; then :; fi
    printf '\n%s\n' "$test_output"
    if [[ "$test_output" == *"successfully authenticated"* ]]; then
      log_ok 'GitHub SSH authentication succeeded'
    else
      log_error 'GitHub SSH authentication was not confirmed'
      return 1
    fi
  fi
}
