#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_home="$(mktemp -d)"
HOME="$test_home" bash -c '
  set -Eeuo pipefail
  source "'$ROOT'/lib/logging.sh"
  source "'$ROOT'/lib/utils.sh"
  source "'$ROOT'/scripts/setup-git.sh"
  ssh-keygen() {
    local path=""
    while (($#)); do
      [[ "$1" == -f ]] && { path="$2"; shift 2; continue; }
      shift
    done
    mkdir -p "$(dirname "$path")"
    printf private > "$path"
    printf "ssh-ed25519 public-key user@example.com\\n" > "${path}.pub"
  }
  output="$(setup_git_main --yes --email user@example.com)"
  [[ -f "$HOME/.ssh/id_ed25519" && -f "$HOME/.ssh/id_ed25519.pub" ]]
  [[ "$output" == *"ssh-ed25519 public-key user@example.com"* ]]
  [[ "$output" != *"private"* ]]
  [[ "$output" == *"https://github.com/settings/ssh/new"* ]]
'

printf 'setup-git test passed\n'
