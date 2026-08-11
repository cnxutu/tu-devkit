# VPS 初始化模块功能需求（目标设计）

## 1. 目标与状态

为 `tu-devkit` 新增顶层 `vps-init/` 模块，面向新购的 Ubuntu VPS 提供可审查、可重复执行的个人基础设施初始化能力：系统基础工具、安全基线、防火墙、WireGuard、可选的 sing-box 代理与客户端导入文件。

本文记录已实现的目标契约；具体操作仍以模块 README、实现与测试为准。

## 2. 范围、前提与非目标

### 2.1 目标环境

| 项目 | 要求 |
| --- | --- |
| 操作系统 | Ubuntu 22.04 LTS 或更高版本；安装前必须检测并拒绝不支持的发行版或版本。 |
| 执行身份 | root，或可无交互 `sudo` 的普通用户；脚本不得假定当前 SSH 会话可安全恢复。 |
| 网络 | 必须能解析 DNS 并访问初始化所需的软件源；公网 IPv4/IPv6 信息仅用于显示与生成端点，获取失败不得泄露内部网络信息。 |
| 使用场景 | 单台个人 VPS；不承诺多机编排、高可用、企业 IAM 或多租户隔离。 |

### 2.2 非目标

- 不自动购买 VPS、修改域名 DNS、申请 TLS 证书或配置 CDN。
- 不创建、上传、打印或提交 SSH 私钥、WireGuard 私钥、代理密码、Token。
- 不把服务器变成通用控制面、面板或用户管理系统；客户端与密钥生命周期仅限本机管理员操作。
- 不默认暴露 HTTP/HTTPS、管理面板或代理端口；所有额外入站端口均需显式配置和确认。

## 3. 模块边界与入口

建议目录如下。各脚本应只负责一个阶段，通过共享库读取配置、写日志、执行预检和统一报错。

```text
vps-init/
├── README.md
├── install.sh                 # quick/secure Profile 与高级 phase 编排入口
├── doctor.sh                  # 只读健康检查
├── config/vps.example.yaml    # 可提交的脱敏示例
├── scripts/
│   ├── preflight.sh
│   ├── base.sh
│   ├── ssh-hardening.sh
│   ├── firewall.sh
│   ├── wireguard.sh
│   ├── wg-add-client.sh
│   ├── wg-remove-client.sh
│   ├── sing-box.sh
│   └── generate-clash-profile.sh
├── templates/
└── tests/
```

`vps-init/` 与 `ai-dev-env-init/` 是并列、独立的安装单元：前者管理远端公网 VPS，后者只管理开发者本机的 macOS/WSL2 开发工具链。两者可以复用仓库级 Bash 规范、CI 写法和文档约定，但不得共享安装器、Profile、默认执行流程、运行配置或秘密输出目录。

本期不修改 `tu init`、`tu install <profile>` 或现有 `tu` 命令路由。VPS 初始化唯一入口为模块内脚本；任何未来统一命令必须以显式的 `tu vps ...` 子命令引入，并经过独立的设计与兼容性评审，绝不能由开发环境初始化流程自动触发。

推荐命令契约：

```bash
# 快速验证：不改变 SSH 行为、不安装 WireGuard
./install.sh --profile quick --config ./config/vps.local.yaml

# 安装并进入双 SSH 端口的安全过渡状态
./install.sh --profile secure --config ./config/vps.local.yaml

# 仅在新端口密钥登录已验证后收口
./install.sh --profile secure --finalize --verified-ssh --config ./config/vps.local.yaml

# 高级兼容入口
./install.sh --phase base,firewall --config ./config/vps.local.yaml
./doctor.sh --config ./config/vps.local.yaml
```

`--profile` 与 `--phase` 互斥，均未指定时只显示帮助且不得修改服务器。Profile 固定能力集合；旧 `wireguard.enabled`、`sing_box.enabled` 仅控制高级 phase 模式。

`vps.example.yaml` 只能包含端口、开关、网段、客户端别名等非敏感参数。实际配置 `vps.local.yaml`、`.env`、生成的客户端配置、日志与备份目录必须被 `.gitignore` 覆盖。

## 4. 通用功能要求

| 编号 | 要求 | 验收要点 |
| --- | --- | --- |
| FR-01 | 所有变更脚本幂等；重复执行不得重复追加规则、重复创建 systemd 单元或替换已有密钥。 | 同一配置连续执行两次，第二次仅报告复核/跳过项，关键配置摘要不变。 |
| FR-02 | 每次执行必须先完成预检，再输出计划；`--dry-run` 不得产生写操作。 | 对临时测试根目录运行 dry-run 后，文件树和服务状态不变。 |
| FR-03 | 每个写操作必须记录时间、阶段、命令结果和脱敏后的原因到可配置日志；不得记录秘密值。 | 日志可定位失败阶段，且扫描不出现私钥、代理密码或完整客户端配置。 |
| FR-04 | 配置校验必须在变更前完成，拒绝非法端口、重复端口、无效 CIDR、未知阶段和不支持的协议组合。 | 无效配置返回非零并指出配置键与修复方式。 |
| FR-05 | 每个阶段提供明确的成功、跳过、失败和人工操作提示；失败返回非零且不继续依赖它的后续阶段。 | 故意使软件源不可用时，显示失败原因与重试/修复建议。 |
| FR-06 | 所有下载源、软件包和外部安装器必须在文档中声明；外部脚本不得以无版本、无校验的方式直接以 root 执行。 | 依赖版本/来源可审查；测试覆盖下载失败与校验失败。 |
| FR-07 | 支持 `--yes` 非交互确认；secure finalize 还必须显式传入 `--verified-ssh`，两者不可互相替代。 | 缺少 SSH 验证标志时拒绝收口。 |
| FR-08 | 原子记录 `quick`、`secure-transition`、`secure` 状态及模块创建的 UFW 规则。 | doctor 默认按状态验收，且 finalize 只删除被记录的模块规则。 |

## 5. 分阶段功能需求

### 5.1 基础初始化

- 检查 Ubuntu 版本、权限、DNS/软件源连通性、默认路由和可用公网地址；公网地址仅作为诊断输出，无法获取时允许继续执行不依赖它的阶段。
- 全新主机由管理员先手动安装 `git` 与 CA 证书并克隆仓库；脚本安装或确认 `curl`、`gnupg`、`wget`、`vim`、`git`、`htop`、`net-tools`、`unzip`、`ufw`、`fail2ban`、`jq`。
- 使用 apt 的非交互安全更新策略；不得无提示进行发行版升级或重启服务器。
- 输出已安装/已存在/失败包清单，以及需要人工处理的重启提示。

### 5.2 SSH 安全加固（防锁定优先）

执行前必须同时满足：当前 SSH 服务配置语法可验证、至少一个指定管理员公钥已存在、目标 SSH 端口已在防火墙放行、用户确认可使用第二个终端建立新连接。任一条件不满足必须拒绝执行。

- 备份受影响 SSH 配置到受限权限目录，文件名包含时间戳；不得固定覆盖 `/etc/ssh/sshd_config.backup`。
- 使用 `sshd -t` 校验候选配置后才重载服务；校验或重载失败时恢复备份并报告恢复结果。
- 默认禁用 root 密码登录、空密码登录和密码认证；是否完全禁用 root 的公钥登录应为显式配置项，默认采取更安全的禁用策略。
- 支持配置 SSH 端口；迁移端口时先放行新端口、验证新会话，再由管理员确认关闭旧端口。脚本不得在当前会话中自动关闭唯一管理入口。

### 5.3 防火墙与 Fail2ban

- UFW 默认策略为拒绝入站、允许出站；启用前必须放行经确认的 SSH 管理端口。
- Quick 固定放行当前 SSH TCP 与 sing-box TCP；Secure 固定增加 WireGuard UDP，并在过渡期同时放行当前/目标 SSH。高级 phase 模式继续按旧功能开关处理。
- 防火墙规则必须带可识别注释或可追踪清单，重复执行不产生重复规则；不得清空用户已有的无关规则。
- 配置并启用 fail2ban 的 SSH 防护；保留管理员可配置的 `bantime`、`findtime` 与 `maxretry`，且变更前备份现有本地配置。
- `doctor.sh` 必须报告 UFW 状态、预期端口、实际规则与 fail2ban 服务状态，不展示来源 IP 的完整敏感日志。

### 5.4 WireGuard 服务与客户端

- 仅在 `wireguard.enabled: true` 时安装并配置；IPv4 地址池、监听端口、出口网卡、DNS 与客户端允许路由均从本地配置读取并校验冲突。
- 初始服务器地址可采用 `10.66.66.1/24`，但必须是可覆盖示例，不得假定与用户已有私网不冲突。
- IPv6 默认关闭：不生成 IPv6 地址、路由或 `fd42:42:42::/64` 配置；只有显式启用且通过前置检查时才生成 IPv6 配置。
- 生成服务器和客户端密钥时设置最小文件权限；私钥和预共享密钥不得写入仓库、日志、标准输出或 Clash 文件。
- `wg-add-client.sh <alias>` 为每台设备生成独立密钥和唯一地址；别名必须校验并防止路径穿越。生成的配置仅保存到受限本地输出目录，可选择生成二维码但不得默认打印秘密内容。
- `wg-remove-client.sh <alias>` 在删除前显示将撤销的 peer，并要求确认；撤销后保留脱敏审计记录，不保留可用私钥。
- 配置转发、NAT 和持久化规则时必须识别实际出口网卡，不能硬编码 `eth0`；失败时报告内核转发、NAT 或权限问题的具体检查项。

### 5.5 sing-box 与 Clash 导出

- Profile 路线固定安装 sing-box；高级 phase 模式仍可通过旧开关关闭。仅支持经过明确审查的 Shadowsocks 2022 TCP 入站。
- 使用官方 SagerNet APT stable 仓库，下载公钥后固定核对官方指纹，禁止执行未经校验的 pipe-to-shell 安装器，并记录实际安装版本。
- 监听 `0.0.0.0` 或公网端口需要显式确认，并与 UFW 放行规则原子协调；服务配置通过 sing-box 自身校验后才能重启。
- 密码必须由安全随机源生成或由受控本地秘密文件提供；只写入权限受限的运行配置和本地客户端输出，不回显、不提交。
- 生成兼容 Clash Verge Rev 的单一 YAML 配置，其中节点名称来自非敏感配置，例如 `VPS-SantaClara`。生成前检查端点地址、端口、方法和密码来源；输出文件权限为仅所有者可读。
- 不承诺 Shadowrocket、Clash Verge Rev 等客户端的版本兼容性；README 必须列出已验证客户端/版本与导入方式，未验证组合标为 `pending_verification`。

## 6. 配置与秘密管理

```yaml
# config/vps.example.yaml：仅示例，不含密码、私钥或真实主机地址
server:
  public_endpoint: ""
ssh:
  current_port: 22
  port: 22222
  disable_root_login: true
fail2ban:
  bantime: 1h
  findtime: 10m
  maxretry: 5
wireguard:
  enabled: false
  port: 60273
  ipv4_cidr: 10.66.66.0/24
  ipv6_enabled: false
sing_box:
  enabled: false
  port: 8080
  listen: 0.0.0.0
  method: 2022-blake3-aes-128-gcm
```

- 秘密文件路径必须通过配置引用，且只接受本机绝对路径或模块受控的受限目录；不得从 Git、URL 或命令行参数读取秘密。
- 所有生成目录默认权限为 `0700`，私钥与客户端配置为 `0600`；README 必须说明备份和迁移时的人工安全责任。
- `git status --ignored` 的验证说明应确认本地配置和输出未被跟踪，但命令输出不得展示秘密文件内容。

## 7. 健康检查与验收

`doctor.sh` 必须只读，检查并以人类可读输出和非零退出码区分以下状态：

| 检查项 | 成功条件 |
| --- | --- |
| 基础环境 | 支持的 Ubuntu、所需命令可用、日志目录可写。 |
| SSH | 配置语法通过；显示脱敏后的认证策略与监听端口。 |
| 防火墙 | UFW 已启用，预期服务端口与配置一致，未发现脚本管理规则冲突。 |
| Fail2ban | 服务 active，SSH jail 已加载或明确报告未配置。 |
| WireGuard | `wg-quick@wg0` active、接口存在、监听端口与配置一致；不输出私钥或完整 peer 配置。 |
| sing-box | 服务 active、配置校验通过、监听地址/端口与配置一致。 |
| 外网连通性 | 可选执行公开 IP 查询；服务不可用时显示 `unknown`，不把第三方位置数据库结果视为部署成功依据。 |

最低验收应覆盖：Shell 静态检查、配置校验、dry-run 无副作用、幂等性、SSH 加固拒绝不安全前提、防火墙规则不重复、WireGuard 客户端新增/撤销、sing-box 配置校验与秘密不泄露。涉及真实 VPS 的端到端验收必须在一次性测试主机完成，并记录脱敏结果。

## 8. 文档交付与分期

模块 README 必须提供：前置条件、备份与恢复、逐阶段执行方式、端口暴露说明、配置参考、秘密边界、失败排查和验收命令。`docs/vps/` 可在实现后增加购买指南、初始化教程、架构说明与安全说明；供应商、价格、节点库存和客户端版本均属易变事实，不能在无来源与日期的情况下固化为推荐。

建议按以下可独立验收的里程碑实现，避免一个脚本同时改变 SSH、网络和代理配置：

1. 基础预检、配置校验、日志、基础软件、UFW/Fail2ban 与只读 doctor。
2. 带防锁定门槛和回滚的 SSH 加固。
3. IPv4 WireGuard 服务、独立客户端生命周期和 doctor 检查。
4. sing-box、Clash 导出与端到端测试。

## 9. 待核实项

- `vps-init/install.sh` 是本期唯一入口；是否在未来引入显式 `tu vps ...` 子命令：`pending_decision`。
- sing-box 使用官方 SagerNet APT stable 仓库，并校验固定官方 GPG 指纹；真实 VPS 软件源可用性仍需端到端验证。
- WireGuard IPv6 支持、DNS 策略、全隧道/分流默认值和客户端兼容矩阵：`pending_decision`。
- 真实 VPS 供应商选择、区域和资源规格属于采购决策，不构成本模块功能需求或默认配置。
