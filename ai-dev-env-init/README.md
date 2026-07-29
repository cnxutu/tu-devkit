# AI 开发环境初始化

`ai-dev-env-init` 是 `tu-devkit` 中的 AI 开发环境初始化工具集，基于 Bash，面向 macOS 和 Ubuntu WSL2，帮助快速搭建可复用的 AI 全栈开发环境。

仓库级工具索引见 [tu-devkit README](../README.md)。

## 快速开始

### 前置安装 Git

如果使用 `git clone`，请先安装 Git：

macOS：

```bash
xcode-select --install
```

如果已经安装 Homebrew，也可以执行：

```bash
brew install git
```

Ubuntu WSL2：

```bash
sudo apt update
sudo apt install -y git
```

如果不想预先安装 Git，也可以从 GitHub 下载 ZIP；运行 AI 初始化模块的 `./install.sh` 后，标准 profile 会尝试安装 Git。

### 安装 AI 开发环境初始化模块

```bash
git clone https://github.com/<username>/tu-devkit.git
cd tu-devkit/ai-dev-env-init
chmod +x install.sh
./install.sh
export PATH="$HOME/.local/bin:$PATH"
tu init
tu doctor
```

安装脚本会把完整运行包放到 `~/.local/share/tu-devkit`，并把 `tu` wrapper 放到 `~/.local/bin`；当前 PATH 中存在可写目录时还会同步放置 wrapper，因此 macOS Homebrew 环境通常无需重新打开终端即可执行。工具会自动识别 Homebrew 或 apt，已安装的命令会跳过；安装系统包或运行官方安装器前会请求确认。如果当前没有可写的 PATH 目录，安装器会提示执行 `source ~/.zshrc` 或 `source ~/.bashrc`。

支持的目标环境是 macOS，以及 Windows 11/10 中的 Ubuntu WSL2。Windows 原生 PowerShell 不在本项目范围内；请在 WSL2 Ubuntu 终端中运行本工具。

## 配置档案

推荐使用 `standard`，它包含基础工具、Shell 配置、Git 检查、Java 17/Maven/Gradle、NVM 与 Node LTS、Python 工具、Docker 检查、VS Code 检查和 AI CLI 检查。

其他配置档案：`minimal`、`java`、`frontend`、`python-ai`、`ai-dev-environment`、`rust`、`devops`、`hardware`。`ai-dev-environment` 专注于 AI 项目初始化；Rust、DevOps 和硬件 profile 当前提供安全的结构和诊断能力，暂不执行重量级自动安装。

### 标准版工具总览

执行 `tu install standard --yes` 后，工具会按下表安装或检查。已存在的工具会跳过，账号登录和宿主机集成不会由脚本代替。

| 分类 | 工具/组件 | 标准版 | 处理方式 | 用途 |
| --- | --- | :---: | --- | --- |
| 基础系统 | Git | ✓ | 安装/检查 | 版本控制、项目协作 |
| 基础系统 | curl、wget | ✓ | 安装/检查 | 下载和网络请求 |
| 基础系统 | unzip、zip、jq、tree | ✓ | 安装/检查 | 文件、JSON 和目录操作 |
| 基础系统 | make、build 工具、ca-certificates、gnupg | ✓ | 安装/检查 | 编译、证书和软件源 |
| 基础系统 | OpenSSH client | ✓ | 安装/检查 | SSH 连接 GitHub/服务器 |
| GitHub | GitHub CLI (`gh`) | ✓ | 安装/检查 | GitHub 登录和仓库操作 |
| GitHub | lazygit | ✓ | 安装/检查 | 终端 Git 工作流 |
| Shell | zsh、Oh My Zsh | ✓ | 安装/安全追加配置 | Shell 环境、别名和 PATH |
| Git | user.name、user.email、默认分支 | ✓ | 检查/提示手动配置 | 提交身份和分支规范 |
| Git/SSH | SSH key、GitHub SSH 连通性 | ✓ | 检查，密钥需手动生成 | 安全拉取和推送代码 |
| Java | OpenJDK 17 | ✓ | 安装/检查 | Java 后端开发 |
| Java | Maven、Gradle | ✓ | 安装/检查 | Java 构建和依赖管理 |
| Node.js | NVM | ✓ | 官方安装器 | Node.js 版本管理 |
| Node.js | Node.js LTS、npm | ✓ | NVM 安装/检查 | 前端和 CLI 工具 |
| Node.js | Corepack、pnpm | ✓ | 启用/安装 | 当前项目常用的包管理器 |
| Python | Python 3、pip、pipx | ✓ | 安装/检查 | Python 开发和 CLI 工具 |
| Python | uv | ✓ | 官方安装器/检查 | Python 环境和依赖管理 |
| 容器 | Docker CLI、Docker Compose | ✓ | 检查；按平台处理 daemon | 容器开发和服务编排 |
| 编辑器 | VS Code `code` 命令 | ✓ | 检查/提示手动启用 | 编辑器和 `code .` |
| AI Agent | Codex CLI | ✓ | npm、Homebrew 或官方安装器 | OpenAI 代码代理 |
| AI Agent | OpenCode | ✓ | npm、Homebrew 或官方安装器 | 多 provider AI 代码代理 |

### Maven 镜像仓库

安装 Java profile 或标准版时，如果 Maven 可用，工具会自动配置用户级文件：

```text
~/.m2/settings.xml
```

默认启用阿里云公共代理：

```text
https://maven.aliyun.com/repository/public
```

配置文件同时保留华为云备用镜像：

```text
https://repo.huaweicloud.com/repository/maven/
```

由于 Maven 对同一个仓库只使用第一个匹配的 mirror，脚本默认启用阿里云，并将华为云作为可切换的备用配置写入注释。需要切换时编辑 `~/.m2/settings.xml`，注释阿里云 mirror、取消华为云 mirror 的注释即可。

已有 `settings.xml` 时，工具会先创建备份，并只在不存在 `tu-devkit maven mirrors` 标记时写入；不会覆盖现有账号、私服或其他 Maven 配置。可以用下面的命令确认最终生效配置：

```bash
mvn help:effective-settings
```

### Profile 包含关系

| Profile | 包含模块 | 适用场景 | 当前状态 |
| --- | --- | --- | --- |
| `minimal` | 基础、Shell、Git、VS Code 检查 | 轻量通用环境 | 已实现 |
| `standard` | 基础、Shell、Git、Java、Node、Python、Docker、VS Code、AI | 推荐的 AI 全栈环境 | 已实现 |
| `java` | 基础、Shell、Git、Java、Docker、VS Code | Java 后端 | 已实现 |
| `frontend` | 基础、Shell、Git、Node、VS Code | Node.js 前端 | 已实现 |
| `python-ai` | 基础、Shell、Git、Python、AI、VS Code | Python 和 AI | 已实现 |
| `ai-dev-environment` | 基础、Shell、Git、Node、Python、AI、VS Code | AI 项目初始化 | 已实现 |
| `rust` | 基础、Shell、Git、Rust、VS Code | Rust 开发 | 结构已提供，安装器待完善 |
| `devops` | 基础、Shell、Git、Docker、DevOps、VS Code | DevOps 工具链 | 结构已提供，安装器待完善 |
| `hardware` | 基础、Shell、Git、Hardware、VS Code | 硬件与 IoT | 结构已提供，安装器待完善 |

### 不会自动处理的事项

| 事项 | 原因 | 需要执行的操作 |
| --- | --- | --- |
| GitHub 账号登录 | 涉及用户授权 | `gh auth login` |
| Codex 登录 | 需要浏览器/交互式账号授权 | `tu ai login`，选择 `Sign in with ChatGPT` |
| OpenCode provider/API key | provider 由用户选择 | `opencode auth login` 或 `tu ai login` |
| SSH 私钥生成和上传 | 私钥属于敏感凭据 | 手动运行 `ssh-keygen` 并只上传 `.pub` 公钥 |
| Docker Desktop WSL Integration | 属于 Windows 宿主机设置 | 在 Docker Desktop 设置中启用 Ubuntu 发行版 |
| VS Code Remote - WSL | 属于编辑器宿主机集成 | Windows VS Code 安装 Remote - WSL 扩展 |

## 命令

```text
tu init                         交互式选择配置档案
tu install standard --yes       非交互式安装配置档案
tu install docker               安装或检查单个模块
tu check                        快速诊断
tu doctor --verbose             详细诊断
tu doctor --strict              严格诊断，问题时返回非零退出码
tu install standard --dry-run  只展示安装/修改计划，不写入环境
tu update                       查看并确认安全更新
tu list                         列出配置档案和模块
tu setup ai --yes               初始化 AI 开发环境
tu ai login                     依次配置 Codex 和 OpenCode 账号
tu ai codex                     打开 Codex CLI
tu ai opencode                  打开 OpenCode
tu version                      显示版本
```

`tu install` 支持 `--yes`，用于自动确认软件包和安装器操作。工具不会创建 SSH 密钥、上传凭据、配置 API key 或打印 secrets。GitHub 登录需手动执行 `gh auth login`。

`--dry-run` 适合第一次执行或 CI 预览：会展示包管理器、NVM/pnpm、Maven、Shell 和 AI CLI 的计划，不修改 `.zshrc`、`~/.m2/settings.xml` 或其他用户配置。`tu doctor --strict` 适合自动化验收，发现缺少工具、Docker daemon 不可用或 Git 身份未配置时返回非零退出码。

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

### AI 项目初始化

当前文件包 `ai-dev-env-init/` 包含命令入口、配置档案、安装流程和测试。使用以下命令初始化适合 AI 项目的基础环境：

```bash
tu setup ai --dry-run
tu setup ai --yes
tu ai login
```

该环境安装或检查 Git、Node.js、Python、uv、Codex CLI、OpenCode 与 VS Code；不包含 Java 和 Docker。需要完整 AI 全栈环境时，仍使用 `tu install standard --yes`。

### macOS

```bash
cd ai-dev-env-init
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
cd ai-dev-env-init
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

#### WSL2 一次性权限初始化

如果当前账户无法在项目目录创建文件，先预览再执行：

```bash
tu setup wsl --dry-run
tu setup wsl --yes
# 如果要修复已有项目目录：
tu setup wsl --yes --path /data/workspace/your-project
```

如果连仓库目录本身都无法读取或执行安装脚本，先只修复这个明确的仓库目录，再重新运行安装器：

```bash
sudo chown -R "$(id -un):$(id -gn)" /path/to/tu-devkit
```

该命令只处理开发相关目录：

```text
/data
/data/workspace
~/.local
~/.config/tu-devkit
~/.cache
~/.m2
~/.npm
~/.nvm
```

目录不存在时创建；`/data` 存在时会询问是否将 `/data` 及其全部内容递归归当前用户所有，具体项目目录也会按需修复。脚本保留现有权限模式，不执行 `chmod 777`，也不会递归修改 `/`、整个 `/home` 或 `/mnt`。如果 `/data` 中存放其他用户或系统服务数据，请先备份并确认归属影响。

建议把代码放在 `/data/workspace`，而不是 `/mnt/c/...`。[Microsoft WSL 文档](https://learn.microsoft.com/zh-cn/windows/wsl/filesystems) 建议 Linux 工具链的项目放在 WSL 自己的文件系统中，以获得更好的性能。WSL 在 Windows 挂载盘上受到 Windows ACL 和 DrvFs 权限规则影响，Linux 中执行 `chmod` 或 `chown` 不一定能获得 Windows 侧没有的权限，具体规则见 [WSL 文件权限说明](https://learn.microsoft.com/en-us/windows/wsl/file-permissions)。可以在 Windows 文件管理器中通过 `\\wsl$\Ubuntu\data\workspace` 访问该目录。

如果手动把用户加入原生 Docker Engine 的 `docker` 组，需要重新打开 WSL：

```bash
sudo usermod -aG docker "$USER"
exit
# 在 PowerShell 中：wsl --shutdown
```

Docker Desktop WSL Integration 模式通常不需要加入 `docker` 组，脚本只提醒，不会默认修改该组。

### 安装完成的判断

`tu doctor` 中 Codex CLI、OpenCode、Node、Git、Java、Python 和 Docker CLI 应显示 `✓`。Docker daemon 和 VS Code Remote - WSL 属于宿主机/集成状态，可能需要按上面的说明手动处理。账号登录成功后，`tu ai login` 才算完成。

### macOS 一次性权限建议

macOS 不需要对整个用户目录执行递归授权。建议统一使用用户目录下的开发目录：

```bash
mkdir -p ~/workspace
ls -ld ~/workspace
```

如果历史上曾用 `sudo` 创建项目文件，只修复明确的开发目录：

```bash
sudo chown -R "$(id -un):$(id -gn)" ~/workspace
```

不要使用 `sudo npm install`、`sudo pnpm install` 或 `sudo mvn`；Node 使用 NVM，项目和缓存放在用户目录。若项目放在 Desktop/Documents，macOS 可能触发隐私访问授权，推荐迁移到 `~/workspace`，或在系统设置中只给终端/VS Code 必要的访问权限。

## 开发

运行基础测试：

```bash
bash tests/run.sh
```

如果已安装 ShellCheck，可执行：

```bash
shellcheck install.sh bin/tu lib/*.sh scripts/*.sh tests/*.sh
```

仓库 CI 会在 Ubuntu 和 macOS 上运行基础测试、Bash 语法检查和 ShellCheck。

所有安装模块都应具备幂等性，适合重复执行和人工审查。

Profile 的模块清单位于 `profiles/*.conf`，`tu list` 和 `tu install` 会直接读取这些文件。新增一个 profile 时，先添加对应的 `.conf` 文件；如果使用现有模块即可生效，若新增工具类别，再在 `scripts/bootstrap.sh` 的 `install_module` 中补充安装逻辑和测试。

## Git、SSH 与 GitHub 配置

安装完成后，先检查 Git：

```bash
tu install git
tu doctor
```

如果尚未配置提交身份，请使用自己的信息：

```bash
git config --global user.name "你的姓名"
git config --global user.email "你的邮箱"
git config --global init.defaultBranch main
```

推荐使用 SSH 连接 GitHub。工具不会自动生成或上传私钥；需要时手动执行：

```bash
ssh-keygen -t ed25519 -C "你的邮箱"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub          # macOS
clip.exe < ~/.ssh/id_ed25519.pub        # WSL2 Ubuntu，可复制到 Windows 剪贴板
```

然后将公钥添加到 GitHub 的 SSH keys 页面，并测试：

```bash
ssh -T git@github.com
```

GitHub CLI 登录是另一条独立的认证路径：

```bash
gh auth login
gh auth status
```

不要把 `~/.ssh` 私钥、GitHub token 或 API key 提交到项目中。`tu doctor` 会检查 Git 用户信息、GitHub CLI 登录状态，并在缺少 SSH key 时给出提醒。

## 目录结构

```text
install.sh                                    模块安装入口
bin/tu                                        命令入口
lib/                                          日志、平台检测和共享工具
scripts/                                      初始化、doctor 和 update 流程
profiles/                                     配置档案清单
modules/                                      AI 工具模块预留目录
tests/                                        模块 Shell 测试
```

## 后续计划

增加更多包管理器适配、安装事务和回滚、结构化 JSON 诊断输出、按 profile 安装 VS Code 扩展、Rust/DevOps/硬件原生安装器、macOS 与 WSL2 CI 矩阵测试，以及持久化用户配置文件。
