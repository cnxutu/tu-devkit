# P0：tu-devkit

`tu-devkit` 是 P0，负责维护开发工具与 AI 工程上下文能力；它不是 P1–P4 的运行时服务。

## 入口

- [AI Engineering Context Platform](./ai-guidance/README.md)：P1–P4 的系统知识、AI 使用说明、角色、规则、Skill 与 Template。
- [AI 开发环境初始化](./ai-dev-env-init/README.md)：`tu` 命令和开发环境安装说明。
- [VPS 网络环境初始化](./vps-init/README.md)：Ubuntu VPS 的安全基线、WireGuard 与可选 sing-box 初始化。

根目录只提供导航。各模块的安装、使用和设计说明均在对应二级目录内维护。

本目录的 [AGENTS.md](AGENTS.md) 是唯一的 AI 协作入口，它会直接将 Codex 引导至 `ai-guidance/`；公共 AI 约束与产品知识均在该模块统一维护。
