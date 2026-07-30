# ai-dev-env-init 集成验收 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 使 `ai-dev-env-init/` 成为可独立安装、可在 CI 验收的开发环境初始化模块。

**Architecture:** 工具的实现维持在 `ai-dev-env-init/`；根目录 GitHub Actions 仅以该模块为工作路径执行测试和静态检查。布局测试约束实际用户入口和 CI 编排路径，Git 可执行模式确保 Linux/macOS checkout 可直接运行入口脚本。

**Tech Stack:** Bash、Git file mode、GitHub Actions、ShellCheck。

---

### Task 1: 先定义迁移后的可执行入口与 CI 路径验收

**Files:**
- Modify: `ai-dev-env-init/tests/test-layout.sh`
- Create: `ai-dev-env-init/tests/test-ci-paths.sh`

- [ ] **Step 1: 扩展布局测试，要求两个用户入口可执行**

在 `test-layout.sh` 的现有 `bin/tu` 断言后加入：

```bash
[[ -x "${PACKAGE_ROOT}/install.sh" ]]
[[ -x "${PACKAGE_ROOT}/tests/run.sh" ]]
```

- [ ] **Step 2: 新建 CI 路径测试**

创建 `ai-dev-env-init/tests/test-ci-paths.sh`：

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CI_FILE="${ROOT}/.github/workflows/ci.yml"

grep -Fq 'bash ai-dev-env-init/tests/run.sh' "$CI_FILE"
grep -Fq 'bash -n ai-dev-env-init/install.sh ai-dev-env-init/bin/tu ai-dev-env-init/bin/tu-wrapper ai-dev-env-init/lib/*.sh ai-dev-env-init/scripts/*.sh ai-dev-env-init/tests/*.sh' "$CI_FILE"
grep -Fq 'shellcheck ai-dev-env-init/install.sh ai-dev-env-init/bin/tu ai-dev-env-init/bin/tu-wrapper ai-dev-env-init/lib/*.sh ai-dev-env-init/scripts/*.sh ai-dev-env-init/tests/*.sh' "$CI_FILE"

printf 'ci paths test passed\n'
```

- [ ] **Step 3: 在 Linux/macOS Bash 环境运行新测试，确认 RED**

运行：

```bash
bash ai-dev-env-init/tests/test-layout.sh
bash ai-dev-env-init/tests/test-ci-paths.sh
```

预期：布局测试因 `install.sh` 或 `tests/run.sh` 没有可执行位失败；CI 路径测试因 workflow 仍指向旧根目录失败。Windows 本地 WSL Bash 无法启动时，记录 `E_ACCESSDENIED`，由 Git 模式和 CI 运行验证替代。

### Task 2: 修复模块入口权限与 CI 编排

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify mode: `ai-dev-env-init/install.sh`
- Modify mode: `ai-dev-env-init/bin/tu`
- Modify mode: `ai-dev-env-init/bin/tu-wrapper`
- Modify mode: `ai-dev-env-init/tests/run.sh`
- Modify mode: `ai-dev-env-init/tests/test-*.sh`
- Modify mode: `ai-dev-env-init/lib/*.sh`
- Modify mode: `ai-dev-env-init/scripts/*.sh`

- [ ] **Step 1: 将 CI 的三个命令改为模块路径**

替换三处 `run` 内容：

```yaml
run: bash ai-dev-env-init/tests/run.sh
```

```yaml
run: bash -n ai-dev-env-init/install.sh ai-dev-env-init/bin/tu ai-dev-env-init/bin/tu-wrapper ai-dev-env-init/lib/*.sh ai-dev-env-init/scripts/*.sh ai-dev-env-init/tests/*.sh
```

```yaml
run: shellcheck ai-dev-env-init/install.sh ai-dev-env-init/bin/tu ai-dev-env-init/bin/tu-wrapper ai-dev-env-init/lib/*.sh ai-dev-env-init/scripts/*.sh ai-dev-env-init/tests/*.sh
```

- [ ] **Step 2: 恢复迁移前所有 Bash 文件的 Git 可执行模式**

运行：

```bash
git update-index --chmod=+x ai-dev-env-init/install.sh ai-dev-env-init/bin/tu ai-dev-env-init/bin/tu-wrapper ai-dev-env-init/lib/*.sh ai-dev-env-init/scripts/*.sh ai-dev-env-init/tests/*.sh
```

不修改脚本内容；这使主分支原有的可执行行为在新目录中保持一致。

- [ ] **Step 3: 核验 GREEN**

运行：

```bash
bash ai-dev-env-init/tests/test-layout.sh
bash ai-dev-env-init/tests/test-ci-paths.sh
git ls-files -s ai-dev-env-init
```

预期：两个测试均输出 `... test passed`；所有模块 Bash 文件的 Git 模式为 `100755`。

### Task 3: 对齐模块文档的验收命令

**Files:**
- Modify: `ai-dev-env-init/README.md`

- [ ] **Step 1: 将开发验收命令限定为从仓库根目录执行**

把“运行基础测试”代码块改为：

```bash
bash ai-dev-env-init/tests/run.sh
```

把 ShellCheck 代码块改为：

```bash
shellcheck ai-dev-env-init/install.sh ai-dev-env-init/bin/tu ai-dev-env-init/bin/tu-wrapper ai-dev-env-init/lib/*.sh ai-dev-env-init/scripts/*.sh ai-dev-env-init/tests/*.sh
```

- [ ] **Step 2: 验证文档中的命令和 CI 命令一致**

运行：

```bash
rg -n 'bash ai-dev-env-init/tests/run.sh|shellcheck ai-dev-env-init/' ai-dev-env-init/README.md .github/workflows/ci.yml
```

预期：README 与 CI 均引用 `ai-dev-env-init/`，没有旧根目录的测试或静态检查命令。

### Task 4: 完整功能验收与提交

**Files:**
- Verify: `ai-dev-env-init/tests/run.sh`
- Verify: `.github/workflows/ci.yml`

- [ ] **Step 1: 执行全部模块测试和语法检查**

运行：

```bash
bash ai-dev-env-init/tests/run.sh
bash -n ai-dev-env-init/install.sh ai-dev-env-init/bin/tu ai-dev-env-init/bin/tu-wrapper ai-dev-env-init/lib/*.sh ai-dev-env-init/scripts/*.sh ai-dev-env-init/tests/*.sh
```

预期：每个测试输出 `... test passed`，且语法检查无输出、退出码为 0。

- [ ] **Step 2: 执行 ShellCheck**

运行：

```bash
shellcheck ai-dev-env-init/install.sh ai-dev-env-init/bin/tu ai-dev-env-init/bin/tu-wrapper ai-dev-env-init/lib/*.sh ai-dev-env-init/scripts/*.sh ai-dev-env-init/tests/*.sh
```

预期：无输出、退出码为 0。

- [ ] **Step 3: 审查最终变更并提交**

运行：

```bash
git diff --check
git diff -- .github/workflows/ci.yml ai-dev-env-init
git status --short
git add .github/workflows/ci.yml ai-dev-env-init
git commit -m "fix: validate ai-dev-env-init module layout"
```

预期：diff 无空白错误；提交只包含模块测试、文档、CI 路径和 Git 模式修复。

