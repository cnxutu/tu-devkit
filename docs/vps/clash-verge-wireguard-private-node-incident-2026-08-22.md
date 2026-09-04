# 2026-08-22 Clash Verge 经 WireGuard 私网节点故障复盘

## 1. 结论

本次故障发生在 WireGuard 基础隧道修复之后。Windows WireGuard 已有近期握手、双向传输和正确私网路由，私网 sing-box TCP 入口可达；但 Clash Verge Rev 主 Mihomo 在开启 TUN 时仍把 `VPS-WireGuard` 判定为不可用，`fallback` 因而选择公网节点。

最终根因是主 Mihomo 的私网 Shadowsocks 节点没有显式指定 Windows WireGuard 出口适配器。在 TUN 运行态下，自动接口选择没有把该节点连接送到操作系统 WireGuard 路径。给标准版 Profile 的 `VPS-WireGuard` 节点添加设备级 `interface-name: <WG_ADAPTER>`，语法检查并热加载后，主实例报告该节点 `alive=true`、产生有效延迟，`fallback` 的活动节点切回私网节点，P0-1 WireGuard + TUN 运行态检查通过。

本次不需要把节点迁移为 Mihomo 原生 `type: wireguard`，也不需要修改 WireGuard Peer、sing-box 服务端、认证信息或极简备用 Profile。

## 2. 影响与现象

- WireGuard `management` 分流隧道已连接，私网路由存在。
- Clash Verge 系统代理和 TUN 开启后，GUI 中 `VPS-WireGuard` 显示 Timeout。
- AI `fallback` 组虽然把私网节点排在第一位，实际 `now` 仍为公网节点。
- 公网节点可继续支撑日常开发，因此不是整个 Clash 配置失效；影响主要是私网优先链路未被使用。
- 之前为验证基础 WireGuard 曾激活全隧道配置并造成网络中断；该做法与本次 Clash 集成根因无关，不应重复。

## 3. 证据链

| 证据 | 当次观察 | 支持的结论 |
| --- | --- | --- |
| Windows WireGuard | Tunnel Service 与适配器 Up，有近期握手和双向计数 | 基础隧道已建立 |
| Windows 路由 | `<WG_PRIVATE_CIDR>` 指向 WireGuard 适配器 | 私网目标具备操作系统路由 |
| 私网 TCP 探测 | `<WG_SERVER_PRIVATE_IP>:<PRIVATE_SS_PORT>` 可建连 | VPS 私网 sing-box 入口可达 |
| P0-1 基线检查 | `-RequireWireGuard -RequireTun` 的基础检查通过 | 当前标准运行要素存在，但仍需节点级证据 |
| 主 Mihomo `/proxies` | 私网节点 `alive=false`、无有效延迟、`interface` 为空；组 `now` 为公网节点 | 故障位于主 Mihomo 节点连接/接口选择层 |
| 私网节点隔离测试 | 同一节点在禁用 TUN 的最小临时 Mihomo 中多次完成实际 HTTP/TLS 请求 | 节点协议、认证、VPS 私网入口和服务端出站有效 |
| 标准 Profile 隔离测试 | 禁用隔离实例自身 TUN 后，`fallback` 选择私网节点并完成实际请求 | 规则组顺序与配置逻辑有效 |
| 添加接口绑定后 | 主实例节点 `interface=<WG_ADAPTER>`、`alive=true`、有有效延迟，组 `now` 切到私网节点 | 修复与故障形成因果闭环 |
| 最终运行态检查 | WireGuard + TUN 检查通过 | 修复后链路的核心运行门禁通过 |

## 4. 排查过程与尝试评价

### 4.1 有效尝试

1. 先验证 WireGuard 的握手、双向计数、适配器和私网路由，确认不再是前一阶段的 UDP 回程问题。
2. 直接探测私网 sing-box TCP 入口，把“隧道不通”和“Clash 节点不通”分开。
3. 通过 Mihomo API 读取主实例节点的 `alive`、延迟历史、`interface` 和 `fallback now/all`，确认 GUI Timeout 对应真实运行态。
4. 从标准 `company-vps.yaml` 隔离同一私网 Shadowsocks 节点，使用禁用 TUN、独立端口的临时 Mihomo 做实际 HTTP/TLS 请求。
5. 隔离完整标准 Profile 并禁用临时实例自身 TUN，证明 `fallback` 成员顺序和节点配置本身可用。
6. 将主实例和隔离实例唯一的关键差异收敛到 TUN 下的出口接口选择。
7. 依据 Mihomo 官方通用代理字段说明，在私网节点添加 `interface-name: <WG_ADAPTER>`。
8. 对受控源、当前存储 Profile 和合并配置分别备份并用当前 Mihomo 校验，随后经 Controller 热加载。
9. 复验主实例节点健康、接口、代理组选择和 P0-1 运行态检查。

### 4.2 没有解决根因或容易误导的尝试

| 尝试 | 结果 | 经验 |
| --- | --- | --- |
| 只看 Clash GUI 的 Timeout | 只能确认失败 | 必须同时读取节点 `alive/interface/history` 和组 `now` |
| 因节点名含 WireGuard 就怀疑 Peer | 与当时握手和私网 TCP 证据冲突 | 当前节点是 `ss`，WireGuard 只是其底层私网路径 |
| 继续修改 WireGuard、sing-box 或认证 | 没有必要且会扩大变量 | 隔离节点成功已证明这些层可用 |
| 把私网节点放在 `fallback` 第一位 | 主实例仍选公网 | `fallback` 只会选择第一个“可用”节点，顺序不能修复不可用状态 |
| 依赖一次 PowerShell HTTPS 失败 | 出现本机 Schannel 凭据包错误 | 客户端 TLS 栈错误不能直接归因于代理，应换独立请求实现复验 |
| 辅助脚本把延迟解析为 `0` | 与原始 API 响应不符 | 先保留并解析原始 HTTP/IPC 响应，工具错误不能当运行态证据 |
| 直接迁移到 Mihomo 原生 WireGuard | 未实施，也无必要 | 现有“OS WireGuard + 私网 SS”已被证明可用，迁移会引入新身份与路由变量 |

## 5. 为什么本次定位耗时

- 前一阶段确实存在 WireGuard UDP 回程故障，使两个连续问题的现象都表现为 Clash 私网节点 Timeout，容易误把它们当作同一根因。
- 一开始没有明确区分“操作系统 WireGuard 隧道”“私网 sing-box TCP”“隔离 Mihomo 节点”和“主 Mihomo TUN 集成”四层门禁。
- 只看 GUI 节点卡片，没有尽早读取主 Mihomo 的节点接口和代理组活动成员。
- 一些测试受到 Windows TLS/Schannel 和辅助脚本响应解析问题干扰，产生了与实际节点状态无关的失败或延迟 `0`。
- `interface-name` 是节点通用字段而非 WireGuard 专属字段，且属于设备适配项，未在共享配置设计阶段显式考虑。

以后应在 WireGuard C1/C2 通过后，直接执行“主实例运行态 → 节点隔离 → TUN 差异 → 出口接口”路径，预计十分钟内完成初步定性。

## 6. 最终修复与回滚

### 修复

在标准版 Profile 的私网 Shadowsocks 节点增加：

```yaml
interface-name: <WG_ADAPTER>
```

当次变更同步到了受控标准源、Clash Verge 当前存储 Profile 和合并运行配置；每个文件变更前均创建了本地时间戳备份，全部使用当前 Mihomo 内核通过语法检查，再通过本地 Controller 热加载。文档不记录实际路径中的 Profile ID、真实接口以外的敏感内容或备份文件名。

### 回滚

如果绑定后该设备节点不可用：

1. 恢复三处对应的变更前备份，或仅删除本次新增的 `interface-name`；
2. 使用当前 Mihomo 内核重新执行语法检查；
3. 热加载或由用户在 Clash Verge GUI 中重载 Profile；
4. 确认公网 fallback 恢复，再重新核对该设备实际 WireGuard 适配器名称。

不得用切换全隧道、删除默认路由或重建 Peer 作为回滚手段。

## 7. 多电脑配置决策

本次修复中的 `interface-name` 是设备级适配器名称。它解决了当前电脑的 TUN 出口选择，不代表相同字符串适用于其他电脑。

后续落地优先级：

1. 多台电脑统一 WireGuard 隧道/适配器命名；或
2. 共享 `company-vps.yaml` 保持通用，通过每设备覆写注入 `interface-name`；或
3. 为每台设备从模板生成并单独验证 Profile。

在没有统一命名之前，不应把当前电脑名称直接发布到公共订阅。每台电脑至少验证：实际适配器名、私网路由、节点 `interface`、`alive` 和代理组 `now`。

## 8. 最终状态与剩余边界

- `verified`：操作系统 WireGuard、私网路由和私网 sing-box 入口正常。
- `verified`：私网 Shadowsocks 节点和标准 `fallback` 配置在隔离 Mihomo 中正常。
- `verified`：增加正确的设备级接口绑定后，主 Mihomo 私网节点转为健康，代理组选择私网节点，P0-1 运行态检查通过。
- `verified`：公网节点仍可作为 fallback，标准版配置可以继续支撑日常开发。
- `observed`：最终实际目标请求并非零错误，曾出现少量目标级超时；这不能推翻节点健康和选路修复，但说明跨境网络与目标站稳定性仍需单独观察。
- `unknown`：TUN 自动接口选择在当前版本内部为何未命中操作系统私网路由，端点证据不足以进一步归因；当前采用官方支持的显式接口字段规避。

## 9. 后续快速清单

1. WireGuard：近期握手、双向计数、私网路由。
2. 私网服务：TCP 入口可达。
3. 主 Mihomo：`alive/history/interface` 与组 `now/all`。
4. 隔离节点：禁用 TUN、独立端口、实际 HTTP/TLS 多次请求。
5. 仅当隔离成功而主 TUN 失败时，核对或添加 `interface-name`。
6. 语法检查、备份、热加载、节点健康、组选择、P0-1 检查、实际请求依次验收。
7. 记录成功率和错误类型，不把目标站波动、TLS 客户端错误或解析脚本错误混为代理失败。

完整命令、门禁和 AI 交接格式见 [Clash Verge 经 WireGuard 私网节点快速排查手册](software-guides/clash-verge-wireguard-private-node-troubleshooting.md)。

## 10. 官方依据与关联资料

- [Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev)
- [Mihomo 通用代理字段](https://wiki.metacubex.one/en/config/proxies/)
- [Mihomo fallback 代理组](https://wiki.metacubex.one/en/config/proxy-groups/fallback/)
- [Mihomo API](https://wiki.metacubex.one/en/api/)
- [WireGuard 连接故障复盘](wireguard-connectivity-incident-2026-08-22.md)
- [联合架构与运维手册](software-guides/combined-stack-operations.md)
