#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_home="$(mktemp -d)"
test_path="$(mktemp -d)"
printf '%s\n' '#!/usr/bin/env bash' 'TU_ROOT=/stale/path' 'source "$TU_ROOT/lib/logging.sh"' > "$test_path/tu"
chmod +x "$test_path/tu"
HOME="$test_home" PATH="$test_path:/usr/bin:/bin" SHELL=/bin/zsh bash "$ROOT/install.sh" >/dev/null
[[ -x "$test_home/.local/bin/tu" ]]
[[ -x "$test_path/tu" ]]
[[ -x "$test_home/.local/share/tu-devkit/bin/tu" ]]
version_output="$(HOME="$test_home" PATH="$test_path:/usr/bin:/bin" "$test_path/tu" version)"
[[ "$version_output" == "tu-devkit 0.1.0" ]]
list_output="$(HOME="$test_home" PATH="$test_path:/usr/bin:/bin" "$test_path/tu" list)"
[[ "$list_output" == *standard* ]]
HOME="$test_home" PATH="$test_path:/usr/bin:/bin" bash -c 'source "'$ROOT'/lib/logging.sh"; source "'$ROOT'/lib/platform.sh"; source "'$ROOT'/lib/utils.sh"; source "'$ROOT'/scripts/bootstrap.sh"; PACKAGE_MANAGER=none; ensure_packages git:git'
HOME="$test_home" PATH="$test_path:/usr/bin:/bin" bash -c 'set -Eeuo pipefail; dry_home="$(mktemp -d)"; export HOME="$dry_home"; source "'$ROOT'/lib/logging.sh"; source "'$ROOT'/lib/platform.sh"; source "'$ROOT'/lib/utils.sh"; source "'$ROOT'/scripts/bootstrap.sh"; zsh() { :; }; DRY_RUN=1; YES=1; install_shell; configure_maven_mirrors; install_node; [[ ! -e "$HOME/.zshrc" && ! -e "$HOME/.m2/settings.xml" && ! -e "$HOME/.nvm" ]]'
printf 'install bundle test passed\n'
