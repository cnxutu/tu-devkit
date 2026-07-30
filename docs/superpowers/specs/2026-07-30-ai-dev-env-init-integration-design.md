# ai-dev-env-init 集成与验收设计

## 目标

以 `ai-dev-env-init/` 作为 `tu-devkit` 中唯一的开发环境初始化工具目录，保留已从 `main` 继承的安装、profile、诊断和 WSL 初始化能力，并使迁移后的 AI 初始化增强能够在 Linux/macOS CI 中被完整验收。

## 边界

- 不重命名 `ai-dev-env-init/`，不恢复旧的仓库根目录工具布局。
- 不重复 cherry-pick 或 merge `main`：`main` 已是 `dev` 的祖先。
- 不改变安装器的用户可见功能范围；本次只修复迁移造成的入口、执行权限和验收链路缺口。

## 方案

`ai-dev-env-init/` 持有全部 Bash 工具文件：`install.sh`、`bin/`、`lib/`、`profiles/`、`scripts/` 与 `tests/`。根目录 CI 仅编排该目录下的测试、Bash 语法检查和 ShellCheck。

迁移时丢失的 Git 可执行位将恢复到所有可直接执行的 Bash 入口和测试脚本，使 README 中的 `./install.sh` 与布局测试中的可执行性约束在 Linux/macOS checkout 后保持一致。

## 验收

1. `ai-dev-env-init/tests/run.sh` 可作为模块唯一的测试入口，所有 `test-*.sh` 可在 Bash 中运行。
2. 布局测试确认安装入口、`bin/tu` 与必需子目录均存在且命令入口可执行。
3. CI 从仓库根目录调用模块路径下的测试、语法检查和 ShellCheck。
4. `tu` 保留主分支既有的 `init`、`install`、`doctor`、`update`、`setup wsl` 等能力，并包含 dev 新增的 `setup ai` 与 `ai-dev-environment` profile。

## 风险与约束

Windows 工作区不一定能本地启动 WSL Bash；功能性 Bash 验收以 CI 的 Ubuntu/macOS 环境为准。本地将执行无需 Bash 的 Git 路径与模式核验，并在可用时执行 Bash 测试。
