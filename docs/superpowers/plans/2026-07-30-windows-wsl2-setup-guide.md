# Windows WSL2 前置环境指南 Implementation Plan

**Goal:** 提供可安全执行的 Windows WSL2 + Ubuntu + ai-dev-env-init 前置环境指南。

### Task 1: 编写独立指南
- Create: ai-dev-env-init/docs/windows-wsl2-setup.md
- [ ] 说明旧发行版备份、注销风险、WSL2 安装和状态检查。
- [ ] 提供使用 wsl --import 将 Ubuntu 放到 D:\WSL\Ubuntu 的步骤。
- [ ] 说明 /data/workspace、VS Code、Docker Desktop 和 ai-dev-env-init 验收。

### Task 2: 添加模块入口
- Modify: ai-dev-env-init/README.md
- [ ] 在 Windows WSL2 章节加入独立指南链接。

### Task 3: 文档核验
- [ ] 运行 rg 检查 import、D:\WSL\Ubuntu、/data/workspace 和 ai-dev-env-init 命令。
- [ ] 运行 git diff --check。

