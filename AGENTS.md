# P0 AI 协作入口

本仓库的公共 AI 协作约束、产品上下文、角色、规则、Skill、Template 与维护要求，统一在 `ai-guidance/` 模块维护。

开始任何任务前，必须先读取并遵循：[ai-guidance/AGENTS.md](ai-guidance/AGENTS.md)。

`dev-env-init/` 等其余目录是工具或脚本实现；除非当前任务直接涉及它们，否则不要将其作为默认 AI 知识上下文加载。

如目标目录存在更具体的 `AGENTS.md`，也必须读取并与本入口及 `ai-guidance/` 中的公共约束一并遵循；仅在约束冲突时，以目标目录的局部约束为准。

本入口只定义仓库级公共约束，不能覆盖 Codex 平台、系统或开发者施加的约束；指令优先级与事实可信度的具体规则以 `ai-guidance/AGENTS.md` 为准。
