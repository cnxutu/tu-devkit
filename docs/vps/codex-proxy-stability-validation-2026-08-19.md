# Codex 代理稳定性修复与 WireGuard 验证报告

验证时间：2026-08-18 23:49 至 2026-08-19 01:50（Asia/Shanghai）

## 最终结论

本轮已将 Windows WireGuard 私网入口正式接入 Clash Verge 的 AI fallback 组，并完成私网优先、公网回退、恢复私网三段实测。当前架构不是“所有流量都走 WireGuard”，而是有意采用分流：

1. WireGuard 的 `AllowedIPs` 为 `10.66.66.0/24`，只承载 VPS 私网段。
2. Clash 根据域名规则接管 AI 流量，再把 Shadowsocks 连接发往 `10.66.66.1:8080`。
3. 私网入口异常时，Clash 自动改走同一 sing-box 服务的公网 Shadowsocks 入口。
4. 其余 Windows 流量不因 WireGuard 启动而自动进入隧道；是否经过 Clash 由系统代理和应用代理行为决定。

因此，Clash 中的 `VPS-WireGuard` 仍然是 Shadowsocks 节点。它使用的是 Shadowsocks 2022 密码，不是 WireGuard 私钥、Peer 公钥或 PresharedKey。它与 `VPS-SantaClara` 密码相同是正确设计，因为两者连接同一个 sing-box 入站；两者的 `server` 必须不同：前者是 `10.66.66.1`，后者是 VPS 公网入口。

本次综合评分：**8.7 / 10**。以中低价海外 VPS 作为个人 AI 开发代理的定位看，当前可用性和容灾已经达到较好水平；主要扣分来自跨境 TTFB、UFW 未启用，以及 Clash Verge 2.5.2 的 REST Controller 不可用导致观测能力有限。

## 根因与处理

| 根因或偏差 | 影响 | 处理结果 |
| --- | --- | --- |
| `company-vps.yaml` 与 Clash 活动 Profile 不一致 | 修改未真正生效 | 已部署到活动 Profile；最终 SHA-256 一致 |
| WireGuard 隧道服务曾运行但适配器消失 | 私网节点不可达，表现为偶发超时 | 重装单条隧道服务；服务 Running、适配器 Up、私网 8080 可达 |
| Windows 客户端源配置缺少 Keepalive | NAT 空闲后可能断握手 | 加入 `PersistentKeepalive = 25` 并通过服务重装加载 |
| P0 默认 `client_mode: full` 与 AI 管理分流目标矛盾 | 可能误把全机流量导入 WireGuard，破坏公网 fallback 独立性 | 默认改为 `management`，只生成 `10.66.66.0/24`；`full` 仍可显式选择 |
| P0 运行时检查器只看 Clash，未要求 WG 服务/适配器/私网端口 | 配置正确但隧道假活无法被发现 | 新增 `-RequireWireGuard`，联合检查节点地址、服务、适配器和 TCP 入口 |
| Clash Verge 重启后 Windows 注册表系统代理漂移为关闭 | Codex 自身可用，但浏览器/ChatGPT 可能绕过代理 | 已核对代理地址并恢复 `ProxyEnable=1`，目标为 `127.0.0.1:7897` |
| 旧方案 h2mux 对长流连接产生硬错误 | 模型刷新、WebSocket、流式响应不稳定 | 继续使用普通 Shadowsocks TCP，客户端禁止 `smux/h2mux` |
| VPS 无可用 IPv6 出口但旧配置会尝试 IPv6 | `cannot assign requested address` | 保持服务端解析与路由 IPv4-only，客户端 `ipv6: false` |

## 当前有效配置

### Windows WireGuard

| 项目 | 实际状态 |
| --- | --- |
| Manager 服务 | Running / Automatic |
| `WireGuardTunnel$tu-company-win` | Running / Automatic |
| 隧道适配器 | `tu-company-win` / Up |
| 客户端地址 | `10.66.66.2/32`，另保留配置中的 IPv6 地址 |
| `AllowedIPs` | `10.66.66.0/24`，管理分流模式 |
| `PersistentKeepalive` | 配置源为 25 秒，已通过隧道服务重装加载 |
| VPS 私网代理入口 | `10.66.66.1:8080` 可达 |

`wg.exe show` 的详细运行态在当前 Windows 会话中返回 Access Denied，因此没有把“内核读回 Keepalive”伪报为已验证；已验证的是配置值、官方服务重装流程和重装后的端到端可达性。

### Clash Verge Rev 2.5.2

| 项目 | 实际状态 |
| --- | --- |
| mixed port | 7897，监听正常 |
| 模式 | Rule |
| IPv6 | false |
| TUN | 关闭 |
| Windows 系统代理 | 已启用，`127.0.0.1:7897` |
| 客户端 `smux` | 未启用 |
| AI 组 | fallback；`VPS-WireGuard` 在前，`VPS-SantaClara` 在后 |
| AI 组 `DIRECT` | 不存在 |
| 健康检查 | 60 秒、超时 8 秒、最多失败 2 次、接受 HTTP 200-499 |
| 源文件与活动 Profile | SHA-256 一致 |

当前 Codex 进程存在到 7897 的 Established 连接；私网正常时，Mihomo 存在到 `10.66.66.1:8080` 的 Established 连接。这两项共同证明业务流量实际经过 Clash 和 WireGuard 私网入口。

### VPS

| 项目 | 实际状态 |
| --- | --- |
| sing-box | active；`sing-box check` 通过 |
| `wg-quick@wg0` | active |
| WireGuard 最近握手 | 检查时约 76 秒前 |
| TCP 8080 | 正在监听 |
| sing-box 模式 | Shadowsocks 2022、TCP-only、普通 TCP 优先 |
| 最近 30 分钟日志聚合 | 2 行命中 error/timeout；期间执行过故障注入 |
| UFW | inactive |

没有导出具体 sing-box 日志原文，因为连接日志可能携带端点信息。现有聚合无法证明两行一定属于故障注入，因此把它保留为观察项，而不是宣称为零错误。

## 端到端测试

### WireGuard 私网路径

| 目标 | 成功率 | 预期探测状态 | 平均 | P95 | 最大 |
| --- | ---: | --- | ---: | ---: | ---: |
| ChatGPT favicon | 30/30 | 403 | 553 ms | 569 ms | 569 ms |
| Codex backend 路由 | 10/10 | 405 | 600 ms | 640 ms | 640 ms |
| OpenAI API | 10/10 | 401 | 726 ms | 1848 ms | 1848 ms |

这些 401/403/405 是无业务认证或探测方法不匹配时的预期应用状态；它们证明 DNS、TCP、Shadowsocks、TLS 和目标路由已建立，不是业务请求失败。50 次测试均未发生连接级失败。

### 公网 fallback 与恢复

为避免依赖受 Windows ACL 限制的服务停止操作，本次只对活动 Clash Profile 做了可回滚故障注入：临时将 WireGuard 节点指向不可达的同网段地址，P0 源文件和 WireGuard 服务不变。

| 检查 | 结果 |
| --- | --- |
| 私网节点故障后自动切公网 | 通过 |
| 切换耗时 | 11.8 秒 |
| fallback 期间 ChatGPT | 可达，HTTP 403 |
| Mihomo 公网 Shadowsocks 连接 | 26 条 Established |
| 恢复原配置和重启 | 通过 |
| 恢复后私网 Shadowsocks 连接 | 5 条 Established |
| 临时故障配置 | 已删除，不可恢复但原配置已从备份恢复 |

该结果验证的是 Clash 节点故障的自动回退能力。由于当前会话无法停止 WireGuard 隧道服务，没有声称完成“真实卸载网卡”的破坏性演练；从 Clash 视角，两种故障都表现为私网 Shadowsocks 入口不可达。

## P0 代码调整

- `vps-init/config/vps.example.yaml`：WireGuard 默认模式改为 `management`。
- `vps-init/lib/config.sh`：默认 AllowedIPs 改为 VPS 私网段；保留显式 `full` 模式。
- `vps-init/README.md`：说明分流与公网 fallback 的关系。
- `vps-init/scripts/check-clash-runtime.ps1`：新增 `-RequireWireGuard` 及服务、适配器、私网 TCP 入口检查。
- `vps-init/tests/test-config.sh`：覆盖默认 management、显式 full 和非法模式。
- `vps-init/tests/test-security-contract.sh`：锁定 WireGuard 强制检查契约。

## 自动化验证

- `vps-init/tests/run.sh`：8/8 通过。
- 修改脚本 `bash -n`：通过。
- ShellCheck：通过。
- PowerShell 运行时检查器语法解析：通过。
- `check-clash-runtime.ps1 -RequireWireGuard`：通过。
- Mihomo 对 `D:\vps\company-vps.yaml` 的配置检查：通过。
- `git diff --check`：通过。

## 评分

| 维度 | 权重 | 得分 | 说明 |
| --- | ---: | ---: | --- |
| 可用性与容灾 | 30% | 9.2 | 私网优先、公网回退和恢复均有实测证据 |
| 长连接稳定性 | 20% | 8.9 | 普通 SS TCP、TCP-only、Keepalive 25、无 smux |
| 延迟与抖动 | 20% | 8.1 | ChatGPT/Codex P95 约 0.57/0.64 秒；OpenAI API 有一次 1.85 秒长尾 |
| 配置一致性 | 15% | 9.4 | 源、活动 Profile、运行时和 P0 防回归已对齐 |
| 安全性 | 10% | 7.0 | 密钥边界正确，但 UFW inactive，公网 8080 为 fallback 保持开放 |
| 可观测性 | 5% | 7.6 | 自动检查已增强，但 REST Controller 不可用且详细 WG 状态受 ACL 限制 |
| **加权总分** | **100%** | **8.7** | 适合作为个人 AI 开发代理的稳定主链路 |

## 剩余风险与后续建议

1. 为 VPS 制定防锁死规则后启用 UFW：至少先确认 SSH、WireGuard UDP 端口和公网 Shadowsocks fallback TCP 端口均被允许，再启用防火墙。
2. 保持 WireGuard `management` 模式。只有明确要让全机默认流量走隧道、并另外设计公网 fallback 时，才切换 `full`。
3. TUN 当前不必开启：Codex 已实测跟随 7897，系统代理也已恢复。若某个具体应用绕过系统代理，再针对该应用评估 TUN。
4. 继续观察 sing-box 的 error/timeout 聚合趋势；若在没有故障演练时持续增加，再在 VPS 本地脱敏归类。
5. 不要在 Clash 的 `VPS-WireGuard` 节点中填写 WireGuard 密钥。该字段始终是 sing-box Shadowsocks 2022 密码。

## 参考

- WireGuard for Windows enterprise/service lifecycle：<https://git.zx2c4.com/wireguard-windows/about/docs/enterprise.md>
- sing-box multiplex：<https://sing-box.sagernet.org/configuration/shared/multiplex/>
- sing-box Shadowsocks inbound：<https://sing-box.sagernet.org/configuration/inbound/shadowsocks/>
