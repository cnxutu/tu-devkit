#!/usr/bin/env bash
set -Eeuo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install -d "${HOME}/.local/bin"
install -m 0755 "${root_dir}/bin/tu" "${HOME}/.local/bin/tu"
printf '%s\n' "Installed tu to ${HOME}/.local/bin/tu"
case ":${PATH}:" in *":${HOME}/.local/bin:"*) ;; *) printf '%s\n' "Add ${HOME}/.local/bin to PATH, then run: tu init" ;; esac
