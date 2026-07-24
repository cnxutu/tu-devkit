# tu-devkit

`tu-devkit` is a Bash toolkit for initializing and maintaining a reusable AI full-stack development environment on macOS and Ubuntu WSL2.

## Quick start

```bash
git clone https://github.com/<username>/tu-devkit.git
cd tu-devkit
chmod +x install.sh
./install.sh
tu init
tu doctor
```

The installer places `tu` in `~/.local/bin`. The tool detects Homebrew or apt, skips commands already available, and asks before installing packages or running official installers.

## Profiles

`standard` is the recommended profile and combines base tools, shell setup, Git checks, Java 17/Maven/Gradle, NVM with Node LTS, Python tooling, Docker checks, VS Code checks, and AI CLI checks. Other profiles are `minimal`, `java`, `frontend`, `python-ai`, `rust`, `devops`, and `hardware`. Rust, DevOps, and hardware currently provide a safe scaffold and diagnostics rather than heavy automatic installation.

## Commands

```text
tu init                         interactive profile selection
tu install standard --yes       install a profile non-interactively
tu install docker               install/check one module
tu check                        fast diagnostic report
tu doctor --verbose             detailed diagnostic report
tu update                       review and confirm safe updates
tu list                        list profiles and modules
tu version                     show version
```

`tu install` accepts `--yes` for package and installer confirmations. It never creates SSH keys, uploads credentials, configures API keys, or prints secrets. GitHub authentication remains manual via `gh auth login`.

## Safety and troubleshooting

Before changing an existing `.zshrc`, tu creates a timestamped copy under `~/.config/tu-devkit/backups/`. Shell additions are marked and appended only once. NVM is loaded explicitly in non-interactive execution. On WSL2, an installed Docker CLI with an unavailable daemon usually means Docker Desktop WSL integration is disabled or the native daemon is stopped; enable one integration path rather than installing a second Docker environment.

If `code` is missing after installing VS Code, use VS Code's Command Palette and run **Shell Command: Install 'code' command in PATH** on macOS, or install the VS Code WSL integration on Ubuntu WSL2.

## Development

Run the basic tests with `bash tests/run.sh`. If ShellCheck is installed, run `shellcheck install.sh bin/tu lib/*.sh scripts/*.sh tests/*.sh`. All installers are intended to be idempotent and suitable for review before use.

## Directory structure

```text
bin/tu       command entry point
lib/         logging, platform detection, and shared utilities
scripts/     bootstrap, doctor, and update workflows
modules/     reserved for future per-module expansion
profiles/    human-readable profile manifests
tests/       basic shell tests
```

## Roadmap

Add package-manager adapters, richer custom module selection, profile-specific VS Code extensions, native Rust/DevOps/hardware installers, CI matrix tests for macOS and WSL2, and a persisted user configuration file.
