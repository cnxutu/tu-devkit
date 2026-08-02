# 开发工具前置环境

本指南说明在运行 `./install.sh`、`tu setup ...` 或 `tu install ...` 前后，需要由开发者亲自完成的工具、账号和宿主机设置。

它不讲 WSL2 的安装、发行版迁移或 `/data` 权限；Windows + Ubuntu WSL2 使用者请先完成 [WSL2 与 Ubuntu 环境](windows-wsl2-setup.md)。

## 1. Git 与 GitHub SSH

如果要通过 `git@github.com:...` 克隆或推送，先在开发环境中安装 Git 和 OpenSSH client：

~~~bash
# Ubuntu WSL2
sudo apt update
sudo apt install -y git openssh-client

# macOS：二选一
xcode-select --install
# 或 brew install git
~~~

设置提交身份。这里填写的是提交元数据，和 SSH 密钥无关：

~~~bash
git config --global user.name "你的姓名"
git config --global user.email "你的 GitHub 邮箱"
git config --global init.defaultBranch main
~~~

生成 Ed25519 密钥并展示公钥：

~~~bash
ssh-keygen -t ed25519 -C "你的 GitHub 邮箱"
cat ~/.ssh/id_ed25519.pub
~~~

复制以 `ssh-ed25519` 开头的整行内容，打开 [GitHub SSH key 设置页](https://github.com/settings/ssh/new)，选择 **Authentication Key** 并粘贴保存。私钥 `~/.ssh/id_ed25519` 绝不能复制、上传或提交。

然后验证 SSH 认证并克隆：

~~~bash
ssh -T git@github.com
git clone git@github.com:cnxutu/tu-devkit.git
~~~

首次连接 GitHub 时，SSH 会询问主机真实性。这是在登记 GitHub 服务器公钥，不是上传你的个人密钥。先对照 [GitHub 官方 SSH 主机指纹](https://docs.github.com/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)，确认无误后输入 `yes`；该确认会保存到 `~/.ssh/known_hosts`。

> [!IMPORTANT]
> 请逐行执行上面的命令。不要在 `git clone` 仍在运行、尤其是出现 `Are you sure you want to continue connecting (yes/no/[fingerprint])?` 时粘贴后续命令；它们可能被 SSH 误读为确认答案。先输入 `yes` 并等待 `git clone` 完成，再进入下一节。

克隆默认会检出仓库的默认分支 `main`。本仓库提供 `origin/dev` 作为日常开发分支；进入仓库后切换并同步：

~~~bash
cd tu-devkit
git branch --all
git switch dev
git branch --set-upstream-to=origin/dev dev
git pull --ff-only
~~~

`git switch dev` 在本地已存在 `dev` 时会直接切换；首次克隆但只有 `origin/dev` 时，Git 会创建对应的本地分支。紧随其后的 `git branch --set-upstream-to=origin/dev dev` 会显式建立或确认本地 `dev` 与远端 `origin/dev` 的跟踪关系，可重复执行。不要对已存在的本地分支执行 `git switch --track origin/dev`，否则会报 `a branch named 'dev' already exists`。

如果任务或 PR 明确指定了其他分支，再按实际分支名切换：

~~~bash
# 目标分支已在本地：
git switch <目标分支>

# 目标分支仅存在于 origin：
git switch --track origin/<目标分支>
~~~

将 `<目标分支>` 替换为项目负责人、任务或 PR 指定的真实分支名。需要新建个人开发分支时，以当前 `dev` 为基准并使用 `codex/` 前缀：`git switch -c codex/<任务名>`。

安装 `tu` 后，也可使用以下命令完成“生成并展示”部分；该命令不上传密钥、不打开浏览器，也不会覆盖已有 `id_ed25519`：

~~~bash
tu setup git --email "你的 GitHub 邮箱"
tu setup git --test
~~~

`tu setup git --test` 成功时会显示 GitHub 的认证欢迎信息；GitHub 不提供交互 shell，因此底层 `ssh -T` 自身可能返回非零，命令会按认证结果判定。

## 2. 获取并安装 tu

在第 1 节完成分支确认或切换后，进入模块并安装：

~~~bash
cd ai-dev-env-init
chmod +x install.sh
./install.sh
export PATH="$HOME/.local/bin:$PATH"
~~~

随后选择一种环境安装方式：

~~~bash
# Java + Node + Codex（推荐起步）
tu install lite --dry-run
tu install lite --yes
tu check lite

# 需要 Python/uv 或 OpenCode 时，改用标准版
tu install standard --yes
tu check standard

# 需要 Rust、Kubernetes CLI 与 OpenRouter 登录入口时，使用最终版
tu install ultimate --yes
tu check ultimate
# 然后在 OpenCode 官方登录界面完成 OpenRouter provider 登录
tu ai openrouter
~~~

`lite` 提供 Java、Maven、Node 和 Codex；`standard` 在此基础上加入 Python/uv 与 OpenCode；`ultimate` 再加入 Rust、Cargo、rustfmt、Clippy、Kubernetes CLI 和 OpenRouter 登录入口。OpenRouter 的 API Key 必须由用户在 `tu ai openrouter` 打开的官方界面中输入，脚本不会保存该凭据。下载 NVM 或 AI 官方安装器时会显示当前阶段、进度、60 秒连接超时、300 秒总超时和最多 3 次重试。`standard` 与 `ultimate` 中的 uv 默认通过 `pipx` 安装并显示 pip 下载进度，设置 60 秒请求超时和 3 次重试；仅在 `pipx` 不可用时回退到官方安装器。若网络仍不可用或误按 `Ctrl+C` 中断，可直接重新执行同一档位的 `tu install <profile> --yes`：已完成的包、Maven 配置和 NVM/Node 安装会被识别并跳过或补全，无需删除 `~/.m2`、`~/.nvm` 或其他用户目录。

或者只准备 AI 项目基础环境：

~~~bash
tu setup ai --dry-run
tu setup ai --yes
tu ai codex
~~~

只想开始 Codex 开发时，`tu ai codex` 即可启动登录；`tu ai login` 会额外要求 OpenCode 也已安装，适合同时使用两种 AI CLI 的场景。

## 3. Windows 宿主机集成（仅 WSL2）

以下项目不由 Ubuntu 内的 `tu` 自动完成：

- 安装 Docker Desktop，在 **Settings → Resources → WSL Integration** 中启用当前 Ubuntu 发行版；不要同时运行 WSL 内的第二套 Docker daemon。
- 安装 Windows 版 VS Code 和 **Remote - WSL** 扩展；在 WSL 项目目录执行 `code .` 验证连接。
- 如果 Docker CLI 存在但 `tu doctor` 显示 daemon 不可用，先确认 Docker Desktop 正在运行且 WSL Integration 已启用。

## 4. 登录与密钥边界

GitHub SSH、GitHub CLI 和 AI CLI 是相互独立的授权路径：

~~~bash
gh auth login
gh auth status
tu ai login
~~~

`tu` 可以安装 CLI、启动各自的官方登录流程并进行诊断，但不会保存 API Key、代替浏览器授权，或上传 SSH 私钥。
