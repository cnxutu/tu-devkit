# ai-dev-env-init OpenRouter 引导接入设计

## 目标

为首次使用者提供 OpenCode + OpenRouter 的安全上手路径，同时保留 Codex 和 OpenCode 的独立使用方式。

## 命令边界

- `tu ai codex`：独立启动 Codex，使用 ChatGPT 交互式登录；不需要 OpenRouter。
- `tu ai opencode`：独立启动已安装的 OpenCode。
- `tu ai openrouter`：确认 OpenCode 已安装后，说明该命令会进入 OpenCode 官方 provider 登录流程，并执行 `opencode auth login`。用户在该流程中选择 OpenRouter、阅读授权提示并自行粘贴 API Key。

## 安全边界

脚本不得接收、回显、写入、导出或提交 OpenRouter API Key。认证配置完全由 OpenCode 的官方交互流程处理，避免脚本依赖可能变化的配置文件格式或在仓库中保留密钥。

## 首次使用说明

README 将说明三种选择：

1. 只使用 Codex：适合有 ChatGPT 订阅且希望直接使用 OpenAI 代码代理的场景。
2. OpenCode + OpenRouter：适合希望在 OpenCode 中选择多家模型的场景；需要用户自行注册 OpenRouter、了解模型计费并在官方登录流程中授权。
3. 只启动已配置的 OpenCode：适合已完成任意 provider 配置的用户。

文档会强调 API Key 属于敏感凭据，不应写入项目、Git 配置或 Shell 历史。

## 验收

1. 新命令出现在 `tu ai` 帮助中。
2. OpenCode 缺失时命令返回明确的安装提示，且不尝试认证。
3. OpenCode 存在时命令执行一次官方 `opencode auth login`，不传递或记录任何密钥。
4. 单元测试以替代的 `opencode` 函数验证命令参数，而不触发真实认证。

