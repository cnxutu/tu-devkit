# Clash Verge 经 WireGuard 私网节点快速排查手册

## 1. 适用范围

本手册处理以下链路：Windows 操作系统先建立 WireGuard 分流隧道，Clash Verge Rev 使用 Mihomo 运行一个以 VPS WireGuard 私网地址为 `server` 的 Shadowsocks 节点，再由规则组或 `fallback` 选择该节点。

这里的 `VPS-WireGuard` 只是节点名称。它在当前 P0 标准配置中是 `type: ss`，不是 Mihomo 原生 `type: wireguard`。WireGuard 身份、握手和私网路由由 Windows WireGuard 客户端负责；Mihomo 只经该私网路由连接 sing-box。

所有示例均使用占位符，不记录真实 IP、端口、密钥、密码、订阅 URL、Profile ID 或 Controller 地址。当前标准配置只关注受控的 `company-vps.yaml`；极简备用 Profile 不在本流程中修改。

## 2. 成功门禁

必须按顺序通过四层门禁，不能用上层 Timeout 反推下层原因：

| 门禁 | 通过证据 | 失败时停止在哪一层 |
| --- | --- | --- |
| C1 WireGuard | 近期握手、双向计数、预期私网路由存在 | 转 [WireGuard 快速排查手册](wireguard-fast-troubleshooting.md) |
| C2 私网服务 | 从 Windows 到 `<WG_SERVER_PRIVATE_IP>:<PRIVATE_SS_PORT>` 的 TCP 建连成功 | 查 sing-box 监听、VPS 防火墙和私网地址 |
| C3 节点隔离 | 同一 Shadowsocks 节点在隔离的 Mihomo 临时实例中能完成目标 HTTP/TLS 请求 | 查节点协议、认证和服务端出站 |
| C4 主实例集成 | Clash Verge 主 Mihomo 中节点 `alive=true`，有有效延迟，代理组 `now` 选择私网节点 | 查 TUN 路由、实际运行配置和出口接口绑定 |

只有 C1、C2 已通过而 C3/C4 失败时，才进入 Clash 配置排查。若 C3 通过但 C4 失败，优先怀疑主 Mihomo 的 TUN/出口接口选择，而不是重建 WireGuard Peer 或修改 sing-box 凭据。

## 3. 十分钟判定路径

```text
Clash 私网节点 Timeout
  └─ WireGuard 有近期握手、双向流量和私网路由？
      ├─ 否 → 排查 WireGuard，不改 Clash
      └─ 是 → 私网 Shadowsocks TCP 端口可达？
              ├─ 否 → 排查 sing-box 监听、防火墙和私网地址
              └─ 是 → 隔离节点能通过实际 HTTP/TLS 请求？
                      ├─ 否 → 排查 SS 协议、认证、服务端和目标出口
                      └─ 是 → 主 Mihomo 的该节点 alive/interface/group now？
                              ├─ 正常 → 区分目标站波动、DNS 和健康检查 URL
                              └─ 异常且 TUN 开启 → 核对 interface-name 与 WG 适配器
```

建议时间盒：

1. 0-2 分钟：确认当前 WireGuard Tunnel Service、适配器、握手、双向计数和私网路由。
2. 2-4 分钟：直接探测私网 sing-box TCP 入口。
3. 4-7 分钟：从 Mihomo API 读取主实例的 `alive`、`history`、`interface`、代理组 `now/all`；不要只看 GUI 卡片。
4. 7-10 分钟：用最小临时配置隔离同一个私网 Shadowsocks 节点。隔离实例不得启用 TUN、不得占用活动端口，也不得改写当前 Profile。

## 4. 只读核对

### 4.1 WireGuard 与私网入口

管理员 PowerShell：

```powershell
Get-Service 'WireGuardTunnel$*'
Get-NetAdapter | Where-Object InterfaceDescription -Match 'WireGuard|Wintun'
& 'C:\Program Files\WireGuard\wg.exe' show <WG_TUNNEL_NAME>
Get-NetRoute -AddressFamily IPv4 | Where-Object DestinationPrefix -EQ '<WG_PRIVATE_CIDR>'
Test-NetConnection <WG_SERVER_PRIVATE_IP> -Port <PRIVATE_SS_PORT>
```

判定重点：WireGuard GUI 的绿色状态不能替代近期握手；TCP 成功只能证明私网入口可达，不能证明主 Mihomo 选对了出口接口。

### 4.2 Clash Verge / Mihomo 实际运行态

优先从 Clash Verge 当前 Controller 读取，而不是只审阅磁盘上的源 YAML：

- `GET /proxies`：查看节点 `alive`、`history`、`interface`，以及代理组的 `now`、`all`、`fixed`；
- `GET /proxies/{name}/delay`：单独探测节点；
- `GET /group/{name}/delay`：核对组成员健康状态；
- 核对当前 Profile、合并配置和主实例的节点字段一致，避免“源文件已改、运行态未加载”。

Controller 不对 TCP 开放时，Clash Verge Rev 可能通过本机受保护的 IPC 提供访问。没有权限或未能正确解析 IPC 响应时，应记录为“证据不可得”，不能把延迟 `0` 或空结果直接当成节点失败。

对 `fallback` 组同时检查成员顺序和 `now`。Mihomo 的 `fallback` 会按配置顺序选择第一个可用节点；私网节点放在第一位但 `now` 仍为公网节点，通常说明主实例判定私网节点不可用。

## 5. TUN 下的出口接口绑定

### 5.1 何时考虑 `interface-name`

只有以下证据同时成立时，才给私网 Shadowsocks 节点显式绑定 WireGuard 适配器：

1. WireGuard 有近期握手、双向流量和正确的 `<WG_PRIVATE_CIDR>` 路由；
2. 私网 Shadowsocks TCP 入口可达；
3. 同一节点在不启用 TUN 的隔离 Mihomo 中工作正常；
4. Clash Verge 主 Mihomo 开启 TUN 后，该节点失败且运行态 `interface` 为空或不是 WireGuard 适配器。

该证据形态说明节点、认证和服务端均已通过，剩余差异集中在主实例 TUN 下的出口选择。Mihomo 官方将 `interface-name` 定义为节点发起连接时使用的网络接口，因此可以把私网节点固定到操作系统 WireGuard 适配器：

```yaml
proxies:
  - name: VPS-WireGuard
    type: ss
    server: <WG_SERVER_PRIVATE_IP>
    port: <PRIVATE_SS_PORT>
    cipher: <SS_CIPHER>
    password: <SS_PASSWORD>
    interface-name: <WG_ADAPTER>
```

只在私网节点上添加该字段，不给公网 fallback 绑定 WireGuard。变更前先确认 `<WG_ADAPTER>` 是 Windows 当前实际适配器名称，并对源配置、Clash Verge 存储 Profile 和合并运行配置分别备份、语法校验和核对加载结果。

### 5.2 多电脑注意事项

`interface-name` 是设备级名称，不是可跨设备假定一致的服务器属性。共享订阅或共享 YAML 中硬编码某台电脑的 `home-pc`，可能使其他电脑的节点直接失败。

优先采用以下任一方案：

- 所有电脑统一 WireGuard 隧道/适配器名称；
- 保持共享 Profile 无设备字段，通过 Clash Verge 的每设备覆写添加 `interface-name`；
- 从受控模板为每台设备生成 Profile，并在导入前验证适配器名称。

若设备名称变化，应先恢复或更新绑定再重载；不要通过切换全隧道、删除系统默认路由来“验证”。

## 6. 安全变更与验收

### 6.1 变更门禁

1. 只改标准 `company-vps.yaml` 对应的私网节点；不改极简备用配置。
2. 记录当前活动 Profile，创建带时间戳的本地备份；备份不得提交 Git。
3. 使用 Clash Verge 当前实际 Mihomo 内核执行配置语法检查。
4. 先更新受控源配置，再更新当前存储 Profile；必要时才处理合并运行配置。
5. 优先使用 Controller 热加载；失败时再由用户在 GUI 中重载，避免无计划重启和网络中断。
6. 任一步失败立即恢复备份，并复验公网 fallback。

### 6.2 通过条件

- 主实例 `/proxies` 中私网节点 `interface=<WG_ADAPTER>`；
- 私网节点 `alive=true` 且出现有效延迟历史；
- 目标 `fallback` 组的 `now=VPS-WireGuard`；
- P0 运行态检查通过：

```powershell
powershell -ExecutionPolicy Bypass -File .\vps-init\scripts\check-clash-runtime.ps1 -RequireWireGuard -RequireTun
```

- 用多个实际 HTTP/TLS 请求验证链路，记录成功率和错误类型；目标站超时或地区网络波动要与“节点已健康并被选中”分开陈述。

单次 HTTP 成功、GUI 上的一个延迟数字或 `Test-NetConnection` 成功，都不能单独代表端到端稳定性。PowerShell/Schannel 若报告本机凭据包错误，也不能直接归因于代理节点，应换用不依赖同一 TLS 栈的客户端复验。

## 7. 常见误判与禁止事项

- 不把名为 `VPS-WireGuard` 的 `ss` 节点误认为 Mihomo 原生 WireGuard 节点，不为修复当前链路迁移到 `type: wireguard`。
- 不在 C1/C2 未通过时修改 Clash 规则、健康检查、认证或接口绑定。
- 不因主实例 Timeout 就重建 Peer、轮换 Shadowsocks 密码或修改 VPS 服务。
- 不只修改磁盘源 YAML而不验证 Clash Verge 实际运行态。
- 不把 `fallback` 仍选公网解释为规则错误；先看私网节点是否被判定为可用。
- 不用活动的全隧道 WireGuard 配置做基础验证，它可能接管默认网络并中断排查会话。
- 不公开 Mihomo Controller、IPC、完整 Profile 或任何凭据。

## 8. AI 快速交接模板

```text
当前 Profile：<标准版/其他；不记录本地 ID>
WireGuard：<服务、适配器、近期握手、RX/TX、私网路由>
私网入口：<TCP 成功/失败>
隔离节点：<实际 HTTP/TLS 成功率、错误类型；是否禁用 TUN>
主 Mihomo：<节点 alive/history/interface；组 now/all>
已证实：<直接证据支持的结论>
未证实：<目标站波动、中间网络、不可读运行态等>
本次单一变更：<字段和对象，不粘贴凭据>
回滚：<备份位置和恢复验证>
最终验收：<运行态检查、节点健康、组选择、实际请求>
```

## 9. 官方依据与关联页面

- [Clash Verge Rev 项目](https://github.com/clash-verge-rev/clash-verge-rev)：确认其使用 Mihomo 内核。
- [Mihomo 通用代理字段](https://wiki.metacubex.one/en/config/proxies/)：`server` 可为域名或 IP，`interface-name` 指定节点连接使用的接口。
- [Mihomo fallback 代理组](https://wiki.metacubex.one/en/config/proxy-groups/fallback/)：按配置顺序使用第一个可用节点。
- [Mihomo API](https://wiki.metacubex.one/en/api/)：代理运行态和节点/代理组延迟接口。
- [Mihomo 原生 WireGuard 节点](https://wiki.metacubex.one/en/config/proxies/wg/)：仅用于辨别架构边界，当前 P0 链路未采用该节点类型。
- [联合架构与运维手册](combined-stack-operations.md)
- [2026-08-22 Clash Verge 私网节点故障复盘](../clash-verge-wireguard-private-node-incident-2026-08-22.md)
