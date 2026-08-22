# 2026-08-22 WireGuard 连接故障复盘

## 1. 结论

本次故障包含两个连续问题：

1. 首份 Windows 配置的 `Endpoint` 缺少 UDP 端口，客户端拒绝导入；补全为 `<VPS_IP>:<WG_PORT>` 后解决语法问题。
2. 配置可导入并显示“已连接”后，原 UDP 端口存在单向回程不可达：Windows 的握手发起包到达 VPS，VPS 生成并发出了握手响应，但响应没有到达 Windows 物理网卡。相同端口的普通 UDP 回显也复现了“请求到达、响应发出、客户端收不到”。迁移到已验证双向可达的 UDP 端口后，WireGuard 立即出现近期握手和双向流量，私网服务随之可达。

因此，最终根因不是 WireGuard 服务未启动、Peer 密钥错误、PresharedKey、UFW、NAT 或 Clash 规则，而是原 UDP 端口在 VPS 到家庭 Windows 的回程路径中被丢弃。端点证据无法定位到具体中间设备，具体丢弃点保持 `unknown`。

## 2. 影响与现象

- Windows WireGuard GUI 显示隧道已激活，Tunnel Service 和适配器存在。
- 客户端持续发送少量流量，但接收始终为零，没有 `latest handshake`。
- VPS 私网地址和私网 sing-box TCP 入口不可达。
- Clash 中通过 WireGuard 私网访问的 Shadowsocks 节点健康检查超时。
- 一度使用全隧道配置做验证，导致本机默认网络被接管并中断正常访问；该动作没有帮助定位无握手问题。

## 3. 根因证据链

| 证据 | 观察 | 排除或证明 |
| --- | --- | --- |
| Windows 服务和适配器 | Tunnel Service Running，适配器 Up | 只证明本地接口启动，不能证明远端连通 |
| WireGuard 运行态 | 客户端 TX 增长、RX=0、无近期握手 | 隧道没有真正建立 |
| VPS `tcpdump` | 收到 UDP payload 148 字节的握手发起包 | Endpoint、客户端出站、VPS 入站和监听端口基本成立 |
| VPS `tcpdump` | 随后看到 UDP payload 92 字节的握手响应离开 VPS | 服务端收到并处理了握手，密钥/Peer 路径具备生成响应的条件 |
| Windows PktMon | 物理网卡看到发出的发起包，没有看到服务端响应 | 响应在到达 Windows 物理网卡前丢失，不是 WireGuard 虚拟网卡路由问题 |
| 同端口 UDP 回显 | 请求到 VPS、回显离开 VPS、客户端 0 次收到 | 问题不依赖 WireGuard 加密或 Peer 配置，是原 UDP 端口的通用回程问题 |
| 候选端口双向测试 | 多个候选 UDP 端口可以双向收发 | 家庭到 VPS 的 UDP 并非整体不可用 |
| 迁移后验收 | 立即有近期握手、双向计数和私网 TCP 可达 | 端口迁移修复了实际故障，完成因果闭环 |

## 4. 排查过程与尝试评价

### 4.1 有效尝试

1. 修正 `Endpoint` 格式，使配置能够导入。
2. 把 GUI 状态拆成服务、适配器、握手和 RX/TX 四类证据，识别出“本地已启动、隧道未建立”。
3. 核对两端静态配置和运行态 Peer，确认 Address、`AllowedIPs`、公钥方向和 PSK 状态。
4. 核对 VPS `wg0`、UDP 监听、systemd、主机防火墙、转发与 NAT，排除服务未加载和明显的 VPS 主机阻断。
5. 在 VPS 短抓包，看到标准握手发起和响应的两个方向。
6. 在 Windows 物理网卡使用 PktMon，确认响应没有进入客户端主机。
7. 在相同端口做普通 UDP 回显，排除 WireGuard 认证协议本身。
8. 对少量已批准候选 UDP 端口做双向测试，只迁移 `ListenPort`/`Endpoint` 这一项。
9. 迁移后按“握手 → 双向计数 → 私网 TCP”顺序复验，并持久化服务端和客户端配置。

### 4.2 做过但没有解决根因的尝试

| 尝试 | 结果 | 为什么没有帮助 |
| --- | --- | --- |
| 重复查看 GUI 是否绿色 | 无进展 | 绿色只说明本地 Tunnel Service 已启动 |
| 反复检查或重建密钥 | 新身份仍在原端口失败 | 网络回程丢包与客户端身份无关；在 VPS 已发响应后不应继续围绕密钥打转 |
| 移除 PresharedKey 再测试 | 原端口仍失败 | PSK 不是根因，但该测试帮助排除了额外认证变量 |
| 优先检查 NAT、DNS、Clash 和 sing-box | 消耗时间 | 无握手时这些上层或转发层还没有进入数据路径 |
| 用 Clash 私网节点健康检查推断隧道状态 | 只能得到 Timeout | Timeout 同时可能来自 WireGuard、TCP 服务或 Clash，本身不能定位层次 |
| 激活全隧道配置验证 | 本机网络中断 | `/0` 改变默认路由和 Windows 防火墙行为，却不能解释为何没有握手 |
| 非管理员读取 `wg.exe` 后比较配置 | 出现 Access Denied | 权限不足是证据缺失，不是配置不匹配 |
| 用原始文本长度/哈希比较密钥 | 曾出现假差异 | CRLF/LF 和结尾换行会改变文本长度/哈希，应在本机规范化后派生并比较公钥 |

## 5. 为什么本次耗时过长

核心问题不是 WireGuard Peer 难以创建，而是排查顺序没有尽早以“近期握手和双向收发”为第一门禁：

- 把“接口 Up”过早当成“隧道已连接”；
- WireGuard、Clash、sing-box 和全隧道路由同时进入排查范围，变量过多；
- 看到客户端 RX=0 后，没有立即在两端对同一轮 UDP 包做方向对照；
- VPS 已发出响应后，仍花时间检查密钥、NAT 和应用代理；
- 没有先做同端口普通 UDP 回显来快速区分协议问题与网络路径问题；
- 在基础隧道未通过时测试全隧道，造成额外故障和恢复工作。

以后应在 10 分钟内完成以下收敛：GUI Up 但无握手 → VPS 同端口抓包 → Windows 物理网卡抓包 → 同端口 UDP 回显 → 必要时受控测试候选端口。

## 6. 后续标准处理清单

### 阶段 A：冻结变量

- 关闭 Clash 的系统代理/TUN 对本次基础验证的影响，但不修改活动 Profile。
- 只激活 `management` 分流配置；保持全隧道配置未激活。
- 记录当前端口和配置备份，保持 VPS SSH 与供应商控制台恢复入口。

### 阶段 B：两分钟静态核对

- `Endpoint` 含主机和端口；
- 客户端地址唯一；
- 两端公钥互指；
- PSK 两端一致或同时省略；
- 服务端 Peer `AllowedIPs` 是该客户端地址，客户端路由是预期私网 CIDR；
- Windows 正在运行的是重新导入后的受保护配置，不是假定原 `.conf` 已自动生效。

### 阶段 C：四分钟握手判定

- Windows：服务、适配器、`latest handshake`、RX/TX；
- VPS：接口、监听、`latest-handshakes`、transfer；
- 没有握手时立刻短抓 UDP，不进入 Clash 或 sing-box 排查。

### 阶段 D：四分钟方向定位

- VPS 无入站：查客户端/Endpoint/上游入站；
- VPS 有发起、无响应：查 Peer/密钥/PSK/运行态加载；
- VPS 有发起和响应、Windows 物理网卡无响应：同端口 UDP 对照并评估端口迁移；
- Windows 收到响应但仍无握手：查本机防火墙、驱动和 Tunnel Service。

### 阶段 E：逐层验收

1. 近期握手；
2. 双向计数；
3. 私网 Peer 或私网 TCP 服务；
4. Clash 私网 Shadowsocks 节点；
5. 用户明确需要时，单独验证全隧道、DNS、IPv6、局域网和断开恢复。

完整命令、变更门禁和 AI 交接模板见 [WireGuard 快速排查手册](software-guides/wireguard-fast-troubleshooting.md)。

## 7. 证据状态与安全边界

- `verified`：当次抓包证明原端口请求到 VPS、响应离开 VPS但未抵达 Windows；同端口 UDP 回显复现；迁移端口后握手和私网 TCP 恢复。
- `verified`：新客户端身份和移除 PSK 后，原端口故障不变，因此旧密钥/PSK不是最终根因。
- `unknown`：回程中具体由家庭路由器、运营商、VPS 上游还是其他中间设备丢弃，端点证据无法进一步归属。
- 复盘已移除真实公网 IP、端口、密钥、订阅地址、临时文件名和原始抓包；完整敏感运行记录不得补入本文。

## 8. 关联资料

- [WireGuard 快速排查手册](software-guides/wireguard-fast-troubleshooting.md)
- [WireGuard 使用指南](software-guides/wireguard.md)
- [WireGuard、sing-box 与 Clash Verge 联合架构与运维手册](software-guides/combined-stack-operations.md)
- [VPS 安全说明](security.md)
