# Windows WSL2 前置环境指南设计

## 目标

为 Windows 用户提供从旧 Ubuntu 清理到新的 D 盘 WSL2 Ubuntu 环境，再到 ai-dev-env-init 验收的完整操作说明。

## 文档位置

新建 ai-dev-env-init/docs/windows-wsl2-setup.md，并从 ai-dev-env-init/README.md 链接。

## 安全边界

文档不自动卸载发行版、不删除用户数据、不导入镜像。所有可能删除数据的命令都标注备份、确认和停止条件。

## 技术路线

使用 wsl --import 将官方 Ubuntu rootfs 导入 D:\WSL\Ubuntu；代码仍放在 WSL Linux 文件系统的 /data/workspace，而非 /mnt/d 或 /mnt/c，以保障 Linux 工具链性能和权限语义。

## 验收

指南包括 WSL 版本检查、发行版路径核验、Ubuntu 首次启动、/data/workspace 创建、VS Code/Docker 集成和 ai-dev-env-init 的 install、doctor、setup ai 实测步骤。

