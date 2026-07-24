# tu-devkit

`tu-devkit` 是一个基于 Bash 的开发环境初始化与维护工具，面向 macOS 和 Ubuntu WSL2，帮助快速搭建可复用的 AI 全栈开发环境。

## 快速开始

```bash
git clone https://github.com/<username>/tu-devkit.git
cd tu-devkit
chmod +x install.sh
./install.sh
export PATH="$HOME/.local/bin:$PATH"
tu init
tu doctor
```

安装脚本会把 `tu` 放到 `~/.local/bin`，并在当前 PATH 中存在可写目录时同步放置一份，因此 macOS Homebrew 环境通常无需重新打开终端即可执行。工具会自动识别 Homebrew 或 apt，已安装的命令会跳过；安装系统包或运行官方安装器前会请求确认。如果当前没有可写的 PATH 目录，安装器会提示执行 `source ~/.zshrc` 或 `source ~/.bashrc`。

支持的目标环境是 macOS，以及 Windows 11/10 中的 Ubuntu WSL2。Windows 原生 PowerShell 不在本项目范围内；请在 WSL2 Ubuntu 终端中运行本工具。

## 配置档案

推荐使用 `standard`，它包含基础工具、Shell 配置、Git 检查、Java 17/Maven/Gradle、NVM 与 Node LTS、Python 工具、Docker 检查、VS Code 检查和 AI CLI 检查。

其他配置档案：`minimal`、`java`、`frontend`、`python-ai`、`rust`、`devops`、`hardware`。Rust、DevOps 和硬件 profile 当前提供安全的结构和诊断能力，暂不执行重量级自动安装。

## 命令

```text
tu init                         交互式选择配置档案
tu install standard --yes       非交互式安装配置档案
tu install docker               安装或检查单个模块
tu check                        快速诊断
tu doctor --verbose             详细诊断
tu update                       查看并确认安全更新
tu list                         列出配置档案和模块
tu ai login                     依次配置 Codex 和 OpenCode 账号
tu ai codex                     打开 Codex CLI
tu ai opencode                  打开 OpenCode
tu version                      显示版本
```

`tu install` 支持 `--yes`，用于自动确认软件包和安装器操作。工具不会创建 SSH 密钥、上传凭据、配置 API key 或打印 secrets。GitHub 登录需手动执行 `gh auth login`。

## 安全与故障排查

修改已有 `.zshrc` 前，工具会在 `~/.config/tu-devkit/backups/` 创建带时间戳的备份。Shell 配置带有标记，只会追加一次。NVM 会在非交互式执行中显式加载。

在 WSL2 中，如果 Docker CLI 已安装但 daemon 不可用，通常是 Docker Desktop 的 WSL integration 未启用，或 WSL 内的原生 daemon 未启动。请只选择一种 Docker 环境，避免重复安装。

如果安装 VS Code 后找不到 `code` 命令，请在 macOS 的 VS Code Command Palette 中执行 **Shell Command: Install 'code' command in PATH**；Ubuntu WSL2 用户请安装并启用 VS Code WSL integration。

## 一键准备 AI 开发环境

标准版会安装或检查 Codex CLI 和 OpenCode。安装完成后执行：

```bash
tu doctor
tu ai login
```

首次运行 `tu ai login` 时：

1. Codex 会打开交互式登录流程，请选择 `Sign in with ChatGPT`。
2. Codex 退出后，OpenCode 会运行 `opencode auth login`，按提示选择 provider 并完成登录。
3. 登录完成后，可在任意项目目录执行 `tu ai codex` 或 `tu ai opencode`。

脚本只负责安装 CLI 和启动官方登录流程，不会代填 API key、保存密钥到项目文件、生成 SSH key 或上传任何凭据。

### macOS

```bash
./install.sh
export PATH="$HOME/.local/bin:$PATH"
tu install standard --yes
tu doctor
tu ai login
```

标准版优先使用 NVM 管理 Node.js；OpenCode 和 Codex 在 npm 可用时使用 npm 安装，缺少 npm 时分别回退到官方安装方式或 Homebrew。

### Windows 11/10 + Ubuntu WSL2

在 Ubuntu WSL2 终端中执行：

```bash
./install.sh
export PATH="$HOME/.local/bin:$PATH"
tu install standard --yes
tu doctor
tu ai login
```

WSL2 还需要在 Windows 侧完成以下一次性设置：

- 安装 Docker Desktop，并在 Settings → Resources → WSL Integration 中启用当前 Ubuntu 发行版。
- 安装 Windows 版 VS Code 和 Remote - WSL 扩展。
- 从 WSL 项目目录执行 `code .`，确认 VS Code 能通过 WSL 打开项目。
- 如果 Docker CLI 存在但 `tu doctor` 显示 daemon 不可用，优先检查 Docker Desktop 是否运行及 WSL integration 是否启用，不要再安装第二套 Docker。

### 安装完成的判断

`tu doctor` 中 Codex CLI、OpenCode、Node、Git、Java、Python 和 Docker CLI 应显示 `✓`。Docker daemon 和 VS Code Remote - WSL 属于宿主机/集成状态，可能需要按上面的说明手动处理。账号登录成功后，`tu ai login` 才算完成。

## 开发

运行基础测试：

```bash
bash tests/run.sh
```

如果已安装 ShellCheck，可执行：

```bash
shellcheck install.sh bin/tu lib/*.sh scripts/*.sh tests/*.sh
```

所有安装模块都应具备幂等性，适合重复执行和人工审查。

## 目录结构

```text
bin/tu       命令入口
lib/         日志、平台检测和共享工具
scripts/     初始化、doctor 和 update 流程
modules/     预留的模块目录
profiles/    配置档案清单
tests/       基础 Shell 测试
```

## 后续计划

增加更多包管理器适配、更丰富的自定义模块选择、按 profile 安装 VS Code 扩展、Rust/DevOps/硬件原生安装器、macOS 与 WSL2 CI 矩阵测试，以及持久化用户配置文件。
