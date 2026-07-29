# AI Engineering Context Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `ai-guidance` 从通用提示词仓库迁移为可供多仓库 AI Agent 按需加载的产品上下文平台。

**Architecture:** 公共工作方式、角色、规范和任务模板收敛到 `ai-guidance/core`；产品事实收敛到 `ai-guidance/products/<scope>/<product>`。真实代码仓库通过最小 `AGENTS.md` 模板和仓库清单绑定产品，而不复制系统知识。

**Tech Stack:** Markdown、YAML、Mermaid；无需运行时依赖。

---

### Task 1: 建立平台入口和公共能力层

**Files:**
- Create: `ai-guidance/README.md`
- Create: `ai-guidance/platform.yaml`
- Create: `ai-guidance/core/index.md`
- Move: `ai-guidance/agents/` → `ai-guidance/core/agents/`
- Move: `ai-guidance/rules/` → `ai-guidance/core/rules/`
- Move: `ai-guidance/skills/` → `ai-guidance/core/skills/`
- Move: `ai-guidance/templates/` → `ai-guidance/core/templates/`

- [ ] 创建平台入口，定义 Core 与 Product 的职责边界、加载优先级与产品注册。
- [ ] 迁移既有公共能力，并更新 Skill 中的相对引用至 `../agents`、`../rules` 与 `../templates`。
- [ ] 创建缺失的 `system-designer`、`spring-cloud`、`refactor-analysis` 和 `cross-service-change` 公共资产。

### Task 2: 创建无人机巡检产品知识包

**Files:**
- Create: `ai-guidance/products/company/device-inspection-platform/product.yaml`
- Create: `ai-guidance/products/company/device-inspection-platform/index.md`
- Create: `ai-guidance/products/company/device-inspection-platform/context/*.md`
- Create: `ai-guidance/products/company/device-inspection-platform/architecture/*.md`
- Create: `ai-guidance/products/company/device-inspection-platform/flows/*.md`
- Create: `ai-guidance/products/company/device-inspection-platform/repositories/*.yaml`
- Create: `ai-guidance/products/company/device-inspection-platform/tasks/active/.gitkeep`
- Create: `ai-guidance/products/company/device-inspection-platform/tasks/archive/.gitkeep`
- Move: `ai-guidance/examples/device-inspection-platform/` → `ai-guidance/products/company/device-inspection-platform/examples/minimal-demo/`

- [ ] 创建索引优先的产品入口，明确每类任务需要继续读取的文档。
- [ ] 将示例事实迁入 `examples/minimal-demo`，避免与真实产品事实混淆。
- [ ] 为四个仓库定义职责、领域所有权与已知集成边，不虚构主题、接口或部署事实。

### Task 3: 建立接入、治理和未来扩展契约

**Files:**
- Create: `ai-guidance/bootstrap/AGENTS.md.template`
- Create: `ai-guidance/bootstrap/repository-manifest.template.yaml`
- Create: `ai-guidance/core/contracts/*.yaml`
- Create: `ai-guidance/docs/governance.md`
- Create: `ai-guidance/docs/authoring-guide.md`
- Create: `ai-guidance/docs/integration-guide.md`
- Create: `ai-guidance/products/personal/knowledge-hub/.gitkeep`

- [ ] 定义仓库级加载顺序和覆盖优先级：局部约束 > 产品事实 > Core 规则。
- [ ] 定义产品、仓库、任务元数据的最小机器可读契约，为 `init`、图谱和 MCP 检索保留稳定入口。
- [ ] 定义知识更新、来源标注、敏感信息和归档治理规则。

### Task 4: 验证与收尾

**Files:**
- Modify: `.gitignore`
- Delete: `.superpowers/`（本次视觉辅助产生的未跟踪临时文件）

- [ ] 检查所有 Markdown 链接、目录迁移和 YAML 基础语法。
- [ ] 确认不再存在旧公共目录或已失效的 `examples` 路径引用。
- [ ] 确认用户已有的 `drone-inspection-platform` → `device-inspection-platform` 重命名已被吸收，而非覆盖。
