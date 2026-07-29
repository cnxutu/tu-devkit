# tu-devkit

`tu-devkit` 是开发工具集仓库。每个工具以仓库根目录下的独立文件包交付，包内包含自己的安装器、实现、配置和测试，便于后续继续增加 Java、前端、DevOps 等工具集。

## 当前工具集

| 工具集 | 目录 | 用途 | 安装入口 |
| --- | --- | --- | --- |
| AI 开发环境初始化 | [`ai-dev-env-init/`](./ai-dev-env-init/) | 为 macOS 和 Ubuntu WSL2 初始化 AI 项目开发环境，并提供 `tu` 命令 | `ai-dev-env-init/install.sh` |

## 使用 AI 开发环境初始化工具

```bash
git clone https://github.com/<username>/tu-devkit.git
cd tu-devkit/ai-dev-env-init
chmod +x install.sh
./install.sh
export PATH="$HOME/.local/bin:$PATH"
tu setup ai --yes
```

完整的 profile、平台要求、AI CLI 登录、WSL2 配置、诊断与测试说明见 [AI 开发环境初始化 README](./ai-dev-env-init/README.md)。

## 仓库结构

```text
ai-dev-env-init/        AI 开发环境初始化工具集
  install.sh            模块安装入口
  bin/                  tu 命令入口
  lib/                  共享 Shell 工具
  scripts/              初始化、诊断和更新流程
  profiles/             环境配置档案
  modules/              工具模块预留目录
  tests/                模块测试
```

新工具集应以与 `ai-dev-env-init/` 相同的方式在仓库根目录创建自包含文件包，不共享或依赖其他工具集的安装入口。
