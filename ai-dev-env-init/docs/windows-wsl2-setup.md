# Windows 上的 WSL2 与 Ubuntu 前置环境

所有 Windows 命令在管理员 PowerShell 执行；Linux 命令在 Ubuntu 终端执行。本指南不自动卸载或删除任何发行版。

> [!WARNING]
> wsl --unregister Ubuntu 会永久删除该发行版的文件。请先导出备份，并确认发行版名称。

## 推荐目录

- WSL Ubuntu 虚拟磁盘：D:\WSL\Ubuntu
- Ubuntu 内代码目录：/data/workspace
- Windows 访问路径：\\wsl$\Ubuntu\data\workspace

D 盘保存 WSL 虚拟磁盘；代码仍应放在 Ubuntu 内的 /data/workspace，而不是 /mnt/c 或 /mnt/d，以避免 Windows ACL、chmod 和性能问题。

## 1. 备份和清理旧 Ubuntu

~~~powershell
wsl --list --verbose
wsl --status
New-Item -ItemType Directory -Force D:\WSL\backup
wsl --shutdown
wsl --export Ubuntu D:\WSL\backup\ubuntu-before-reinstall.tar
~~~

确认备份存在且不再需要旧环境后，才执行：

~~~powershell
wsl --unregister Ubuntu
~~~

如发行版名称不是 Ubuntu，替换为列表显示的实际名称。不要对 Docker Desktop 或业务发行版执行 unregister。

## 2. 安装 WSL2

~~~powershell
wsl --install --no-distribution
wsl --update
wsl --set-default-version 2
wsl --status
~~~

首次安装可能需要重启。默认版本必须是 2；若失败，检查 BIOS/UEFI 虚拟化和 Windows Virtual Machine Platform。

## 3. 将 Ubuntu 直接导入 D 盘

从 Ubuntu 官方 WSL rootfs 下载页下载当前 LTS 的 AMD64 rootfs tar，保存为 D:\WSL\downloads\ubuntu.rootfs.tar。不要使用来源不明的镜像。

~~~powershell
New-Item -ItemType Directory -Force D:\WSL\downloads
New-Item -ItemType Directory -Force D:\WSL
wsl --import Ubuntu D:\WSL\Ubuntu D:\WSL\downloads\ubuntu.rootfs.tar --version 2
wsl --set-default Ubuntu
wsl --list --verbose
~~~

Ubuntu 应显示 Version 2。D:\WSL\Ubuntu 中是发行版 VHDX，勿手工移动、删除或同步。若公司策略只能通过 Store 安装，可先 export、unregister，再 import 到 D 盘；这会暂时占用 C 盘空间。

## 4. 首次启动

~~~powershell
wsl -d Ubuntu
~~~

rootfs 导入通常先以 root 启动。将 devuser 替换为自己的用户名：

~~~bash
adduser devuser
usermod -aG sudo devuser
printf '[user]\ndefault=devuser\n' > /etc/wsl.conf
exit
~~~

~~~powershell
wsl --shutdown
wsl -d Ubuntu
~~~

在 Ubuntu 验证并安装基础工具：

~~~bash
whoami
df -h /
sudo apt update
sudo apt upgrade -y
sudo apt install -y git curl ca-certificates unzip zip jq tree build-essential
~~~

## 5. 创建代码目录

`/data` 位于 Linux 根目录下。普通用户直接执行 `mkdir /data/workspace` 或先进入 `/data` 再执行 `mkdir workspace`，通常会收到 `Permission denied`，这是正常的 Linux 权限保护，不是 WSL2 安装失败。

~~~bash
sudo install -d -o "$(id -u)" -g "$(id -g)" -m 0755 /data/workspace
cd /data/workspace
pwd
touch .write-test && rm .write-test
~~~

`pwd` 预期为 `/data/workspace`，写入测试应无报错。`install -d` 会用管理员权限创建目录，但直接把新目录的所有者设置为当前用户；后续的 `git clone`、构建和包管理命令不再使用 `sudo`。

如果目录已经存在但当前用户不能写入，先检查归属，再只修复这个开发目录：

~~~bash
ls -ld /data /data/workspace
sudo chown -R "$(id -u):$(id -g)" /data/workspace
touch /data/workspace/.write-test && rm /data/workspace/.write-test
~~~

不要执行 `chmod 777`。不要在不清楚内容归属时递归修改整个 `/data`；其中可能存在其他用户或服务的数据。Windows 可通过 `\\wsl$\Ubuntu\data\workspace` 访问；不要以管理员身份在该路径创建代码文件。

## 6. VS Code、Docker 与 ai-dev-env-init

安装 Windows VS Code 和 Remote - WSL 扩展，在 Ubuntu 项目目录执行 code .。Docker Desktop 中启用 Ubuntu 的 WSL Integration，并将 Disk image location 改到 D 盘；不要同时启动 Ubuntu 内第二个 Docker daemon。

克隆仓库前，先按 [README 的 GitHub SSH 前置步骤](../README.md#前置安装-git-与-github-ssh) 生成公钥、在 GitHub 网页添加 **Authentication Key**，并通过 `ssh -T git@github.com` 验证。这个网页授权步骤需要用户亲自完成。

~~~bash
cd /data/workspace
git clone git@github.com:cnxutu/tu-devkit.git
cd tu-devkit/ai-dev-env-init
chmod +x install.sh
./install.sh
export PATH="$HOME/.local/bin:$PATH"
tu setup git --email "你的 GitHub 邮箱"  # 仅在还没有 SSH key 时执行
tu setup wsl --dry-run
tu setup ai --dry-run
tu doctor
~~~

确认后执行 tu setup wsl --yes、tu setup ai --yes。OpenCode + OpenRouter 使用 tu ai openrouter；该命令不保存 API Key。

## 排障

- C 盘仍增长：确认 Ubuntu 使用 import 放在 D:\WSL\Ubuntu，并检查 Docker Desktop 磁盘镜像位置。
- WSL 不能启动：执行 wsl --update、重启，并检查虚拟化设置。
- 在 `/data` 下 `mkdir workspace` 报 `Permission denied`：执行第 5 节的 `sudo install -d ... /data/workspace`，再以普通用户验证写入。
- 已有目录权限错误：只对 `/data/workspace` 等明确开发目录执行 `chown`，绝不递归修改 `/`、整个 `/home`、`/mnt` 或用途不明的 `/data`。

