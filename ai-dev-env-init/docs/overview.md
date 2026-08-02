# ai-dev-env-init 整体导览

本文用来回答三个问题：

1. 第一次接触这个模块，应该先看什么？
2. 从安装 `tu` 到开发环境可用，完整流程是什么？
3. Profile、模块、脚本和诊断之间是什么关系？

如果只想使用工具，先看本文的“使用主流程”，再回到 [README](../README.md#快速开始) 按命令操作即可。

## 一图认识这个模块

`ai-dev-env-init` 分为两层：

- `./install.sh` 安装的是 **`tu` 命令本身**；
- `tu init` 或 `tu install <profile>` 才会按照 Profile 安装或检查 **开发工具链**。

```mermaid
flowchart LR
    U["使用者"]

    subgraph CLI["第一层：安装 tu 命令"]
        I["./install.sh"]
        P["~/.local/bin/tu"]
        R["~/.local/share/tu-devkit"]
        I --> P
        I --> R
    end

    subgraph ENV["第二层：准备开发环境"]
        C["tu init<br/>或 tu install &lt;profile&gt;"]
        F["profiles/*.conf<br/>选择模块组合"]
        M["安装或检查模块<br/>base / git / java / node / python ..."]
        D["tu check &lt;profile&gt;<br/>按档位诊断"]
        C --> F --> M --> D
    end

    X["需要人工完成<br/>账号登录 / SSH 公钥登记<br/>Docker Desktop / VS Code WSL 集成"]

    U --> I
    P --> C
    M --> X
    X --> D
```

工具会尽量跳过已经存在的命令，并在修改用户配置前进行提示或备份。账号授权、密钥上传和宿主机集成仍由使用者完成。

## 推荐阅读顺序

根据你的目标选择一条路径，不需要从头读完所有文件。

```mermaid
flowchart TD
    S["从这里开始：整体导览"]
    Q{"你要做什么？"}

    S --> Q

    Q -->|"直接使用"| R1["1. README：快速开始"]
    R1 --> R2{"当前平台？"}
    R2 -->|"macOS"| R3["README：macOS"]
    R2 -->|"Windows + Ubuntu WSL2"| W1["WSL2 与 Ubuntu 环境"]
    W1 --> W2["开发工具前置环境"]
    W2 --> W3["README：Windows + Ubuntu WSL2"]
    R3 --> R4["README：命令 / 安全与故障排查"]
    W3 --> R4

    Q -->|"选择安装内容"| P1["README：配置档案"]
    P1 --> P2["profiles/*.conf：查看精确模块清单"]

    Q -->|"维护或扩展工具"| M1["README：开发 / 目录结构"]
    M1 --> M2["bin/tu：命令路由"]
    M2 --> M3["scripts/bootstrap.sh：安装主流程"]
    M3 --> M4["对应 scripts/*.sh 与 tests/*.sh"]
```

### 最短阅读路径

| 读者 | 建议顺序 | 读完能解决什么 |
| --- | --- | --- |
| 首次使用者 | 本文 → [README 快速开始](../README.md#快速开始) → [命令](../README.md#命令) | 安装 `tu`、选择 Profile、完成诊断 |
| WSL2 使用者 | 本文 → [WSL2 与 Ubuntu 环境](windows-wsl2-setup.md) → [开发工具前置环境](development-tools-prerequisites.md) → [README WSL2 部分](../README.md#windows-1110--ubuntu-wsl2) | 完成 WSL 本体、目录权限、Git/SSH、宿主机集成与 `tu` 初始化 |
| Profile 选择者 | [README 配置档案](../README.md#配置档案) → `profiles/*.conf` | 理解各 Profile 的用途和实际模块组合 |
| 模块维护者 | [README 开发](../README.md#开发) → `bin/tu` → `scripts/bootstrap.sh` → 对应测试 | 理解命令分发、Profile 展开、模块安装和验证入口 |

## 使用主流程

下面是一次完整的首次使用流程。虚线步骤表示需要按平台或个人状态决定是否执行。

```mermaid
flowchart TD
    A["准备操作系统环境"]
    W["WSL2 使用者：完成 WSL 本体和 /data/workspace"]
    S["完成 Git/SSH 与宿主机集成前置步骤"]
    B["获取 tu-devkit 仓库"]
    C["进入 ai-dev-env-init"]
    D["执行 ./install.sh"]
    E["tu 命令是否已在 PATH？"]
    F["执行 export PATH=...<br/>或重新加载 Shell 配置"]
    G["预览：tu install lite --dry-run"]
    H["选择安装方式"]
    I["交互式：tu init"]
    J["非交互式：tu install &lt;profile&gt; --yes"]
    K["按 Profile 逐个安装或检查模块"]
    L["人工完成剩余账号授权"]
    N["执行 tu check &lt;profile&gt;"]
    O{"诊断是否满足需求？"}
    P["按提示修复后重新诊断"]
    Z["环境可用"]

    A -.-> W
    A --> S --> B --> C --> D --> E
    W --> S
    E -->|"否"| F --> G
    E -->|"是"| G
    G --> H
    H --> I
    H --> J
    I --> K
    J --> K
    K -.-> L
    K --> N
    L --> N
    N --> O
    O -->|"否"| P --> N
    O -->|"是"| Z
```

推荐先执行 `--dry-run` 查看计划。日常 Java + Node + Codex 使用 `lite`；需要 Python/uv 与 OpenCode 时使用 `standard`；需要 Rust、DevOps 和 OpenRouter 登录入口时使用 `ultimate`。OpenRouter 的 API Key 仍由用户在 `tu ai openrouter` 启动的官方界面中输入。只准备 AI 项目基础环境时，可以使用 `tu setup ai --dry-run` 和 `tu setup ai --yes`。

## 首次开始 Codex 开发

不需要等待所有可选工具都安装完。首次安装被网络或 `Ctrl+C` 中断时，直接重复同一条所选档位命令即可；已完成的步骤会跳过或补全。

```mermaid
flowchart TD
    A["tu install lite --yes"] --> B["tu check lite"]
    B --> C{"Codex CLI 是否为 ✓？"}
    C -->|"否"| A
    C -->|"是"| D["tu ai codex"]
    D --> E["首次选择 Sign in with ChatGPT"]
    E --> F["进入项目目录并运行 codex"]
```

| 项目 | 对 Codex 首次开发是否阻塞 |
| --- | --- |
| Git、Node/npm/pnpm、Codex CLI | 阻塞：缺失时重跑 `tu install lite --yes`。 |
| Python/pip/uv、Java/Maven/Gradle | 仅相应语言项目需要。 |
| Docker daemon、VS Code Remote - WSL | 仅容器或 VS Code 图形工作流需要。 |
| GitHub CLI、lazygit、OpenCode | 可选；不阻塞 Codex。 |

`tu ai login` 会同时要求 Codex 与 OpenCode，因此只使用 Codex 时直接运行 `tu ai codex`。

### 缺失项的最小补救

安装中断后优先重跑当前所选 profile，例如 `tu install lite --yes`，然后重新执行对应的 `tu check lite`。`tu check lite`、`tu check standard`、`tu check ultimate` 分别按三档环境标出必需项；具体缺失补救命令统一在 [README](../README.md) 的“安装中断或 tu check 缺失时怎么办”部分维护。

## 命令内部流向

从维护者视角看，命令执行链路如下：

```mermaid
flowchart LR
    T["bin/tu<br/>解析命令"]
    A{"命令类型"}
    P["Profile 安装<br/>init / install"]
    S["专项设置<br/>setup ai / git / wsl"]
    D["诊断<br/>check / doctor"]
    O["其他<br/>ai / update / list"]

    PF["读取 profiles/&lt;name&gt;.conf"]
    IM["scripts/bootstrap.sh<br/>install_profile"]
    MM["install_module"]
    MOD["模块安装函数<br/>base / shell / git / java / node / python<br/>docker / vscode / codex / opencode / rust / devops"]
    TEST["tests/run.sh<br/>及 tests/test-*.sh"]

    T --> A
    A --> P --> PF --> IM --> MM --> MOD
    A --> S
    A --> D
    A --> O
    MOD -.-> TEST
    S -.-> TEST
    D -.-> TEST
```

主要目录职责：

| 路径 | 职责 | 什么时候看 |
| --- | --- | --- |
| `install.sh` | 将运行包复制到用户目录并安装 `tu` wrapper | 修改工具自身安装方式时 |
| `bin/tu` | CLI 入口与子命令路由 | 新增或调整命令时 |
| `profiles/*.conf` | 声明一个 Profile 包含哪些模块 | 调整工具组合时 |
| `scripts/bootstrap.sh` | Profile 展开和各模块安装/检查逻辑 | 修改安装行为时 |
| `scripts/setup-*.sh` | AI、Git、WSL2 等专项初始化流程 | 修改专项设置时 |
| `scripts/doctor.sh` | 环境诊断 | 新增检查项或排障提示时 |
| `lib/*.sh` | 日志、平台识别和公共函数 | 修改跨脚本公共能力时 |
| `tests/*.sh` | 布局、命令、Profile、安装和诊断测试 | 每次行为变更后验证 |
| `modules/` | 模块化扩展的预留结构 | 规划后续模块拆分时 |

## 如何选择入口命令

```mermaid
flowchart TD
    A{"你的目标"}
    B["不知道选什么<br/>tu init"]
    C["按层级安装<br/>lite / standard / ultimate"]
    D["只准备 AI 项目基础环境<br/>tu setup ai --yes"]
    E["只处理一个模块<br/>tu install &lt;module&gt;"]
    F["按档位检查当前环境<br/>tu check &lt;profile&gt;"]
    G["用于自动化验收<br/>tu check &lt;profile&gt; --strict"]

    A -->|"交互选择"| B
    A -->|"按 Java+Node、Python/AI、Rust/DevOps 选择层级"| C
    A -->|"Git + Node + Python + AI + VS Code"| D
    A -->|"例如 git / docker / java"| E
    A -->|"人工排障"| F
    A -->|"CI 或脚本"| G
```

无论选择哪种安装入口，都建议以 `tu check <profile>` 收尾；需要在所选档位必需 CLI 缺失时返回非零退出码，则使用 `tu check <profile> --strict`。
