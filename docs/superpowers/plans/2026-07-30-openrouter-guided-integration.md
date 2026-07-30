# OpenRouter 引导接入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为已安装的 OpenCode 提供安全的 OpenRouter provider 登录入口和首次使用说明。

**Architecture:** ai_main 新增一个仅编排官方 OpenCode 认证流程的子命令；不写入配置文件或密钥。Shell 测试通过同名函数替代 opencode，只验证调用参数和缺失依赖行为。

**Tech Stack:** Bash、OpenCode CLI、Shell 测试。

---

### Task 1: 先添加 OpenRouter 命令的失败测试

**Files:**
- Modify: ai-dev-env-init/tests/test-setup-ai.sh

- [ ] 在现有 bash -c 测试脚本末尾加入：

~~~bash
  opencode() { printf '%s\n' "$*" > "$HOME/opencode-args"; }
  ai_main openrouter
  [[ "$(cat "$HOME/opencode-args")" == 'auth login' ]]
  unset -f opencode
  if ai_main openrouter >/dev/null 2>&1; then
    exit 1
  fi
~~~

- [ ] 运行 bash ai-dev-env-init/tests/test-setup-ai.sh，确认在 openrouter 未实现时失败。

### Task 2: 实现不保存密钥的 OpenRouter 引导命令

**Files:**
- Modify: ai-dev-env-init/scripts/bootstrap.sh

- [ ] 在 ai_main 帮助文本中加入：

~~~text
  tu ai openrouter  启动 OpenCode 登录并选择 OpenRouter provider
~~~

- [ ] 在 ai_main 的 case 中加入：

~~~bash
    openrouter)
      has opencode || { log_error 'OpenCode 未安装，请先运行: tu install standard --yes'; return 1; }
      log_info '即将启动 OpenCode provider 登录；请选择 OpenRouter，并在官方界面中自行输入 API Key。'
      opencode auth login
      ;;
~~~

- [ ] 运行 bash ai-dev-env-init/tests/test-setup-ai.sh，预期输出 setup-ai test passed。

实现不得读取环境变量、接收命令行 Key、写入配置文件或回显认证信息。

### Task 3: 增加首次使用与选择说明

**Files:**
- Modify: ai-dev-env-init/README.md

- [ ] 在命令列表中加入：

~~~text
tu ai openrouter                在 OpenCode 官方登录流程中配置 OpenRouter
~~~

- [ ] 在“一键准备 AI 开发环境”章节添加：只使用 Codex、OpenCode + OpenRouter、只使用已配置的 OpenCode 三种选择；说明 OpenRouter 需要用户自行注册、授权和承担模型费用。

- [ ] 添加安全提示：不将 API Key 写入项目文件、Git 配置、Shell 历史或仓库。

- [ ] 运行 rg -n 'tu ai openrouter|OpenCode \+ OpenRouter|API Key' ai-dev-env-init/README.md ai-dev-env-init/scripts/bootstrap.sh。

### Task 4: 完整验证

**Files:**
- Verify: ai-dev-env-init/tests/test-setup-ai.sh
- Verify: ai-dev-env-init/tests/run.sh

- [ ] 运行：

~~~bash
bash ai-dev-env-init/tests/test-setup-ai.sh
bash -n ai-dev-env-init/scripts/bootstrap.sh ai-dev-env-init/tests/test-setup-ai.sh
bash ai-dev-env-init/tests/run.sh
git diff --check
~~~

预期：定向测试和语法检查通过；macOS/Ubuntu 环境中全量测试通过。Windows Git Bash 的 doctor 和 WSL 权限测试若因非目标平台失败，记录为环境限制，不改变工具逻辑。

