#!/usr/bin/env bash
set -Eeuo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install -d "${HOME}/.local/bin"
install -m 0755 "${root_dir}/bin/tu" "${HOME}/.local/bin/tu"
printf '%s\n' "Installed tu to ${HOME}/.local/bin/tu"
path_install_dir=""
old_ifs="$IFS"
IFS=:
for path_dir in $PATH; do
  [[ -n "$path_dir" && -d "$path_dir" && -w "$path_dir" ]] || continue
  [[ "$path_dir" == "$HOME/.local/bin" ]] && continue
  if [[ -e "$path_dir/tu" && ! -L "$path_dir/tu" ]]; then
    continue
  fi
  path_install_dir="$path_dir"
  break
done
IFS="$old_ifs"
if [[ -n "$path_install_dir" ]]; then
  install -m 0755 "${root_dir}/bin/tu" "$path_install_dir/tu"
  printf '%s\n' "Installed tu to PATH directory: $path_install_dir/tu"
fi
if [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
  shell_rc="${HOME}/.zshrc"
  [[ "${SHELL:-}" == */bash ]] && shell_rc="${HOME}/.bashrc"
  marker='# tu-devkit PATH'
  if [[ ! -f "$shell_rc" ]] || ! grep -Fqx "$marker" "$shell_rc" 2>/dev/null; then
    if [[ -f "$shell_rc" ]]; then
      backup_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/tu-devkit/backups"
      mkdir -p "$backup_dir"
      backup_file="${backup_dir}/$(basename "$shell_rc").$(date +%Y%m%d%H%M%S).bak"
      cp -p "$shell_rc" "$backup_file"
      printf '%s\n' "Backed up $shell_rc to $backup_file"
    fi
    {
      printf '\n%s\n' "$marker"
      printf 'export PATH="$HOME/.local/bin:$PATH"\n'
    } >> "$shell_rc"
    printf '%s\n' "Added ~/.local/bin to $shell_rc"
  fi
  printf '%s\n' "当前终端请先执行: export PATH=\"$HOME/.local/bin:\$PATH\""
fi
if [[ -z "$path_install_dir" ]]; then
  printf '%s\n' '当前终端请执行: source ~/.zshrc（或 source ~/.bashrc）'
fi
printf '%s\n' '然后运行: tu doctor'
