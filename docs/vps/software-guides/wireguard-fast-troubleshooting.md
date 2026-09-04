# WireGuard 快速排查手册

## 1. 目标与边界

本手册处理以下典型故障：Windows WireGuard 显示隧道已激活，但没有近期握手、接收流量始终为零、VPS 私网地址或私网 sing-box 入口不可达。

排查时先只证明 WireGuard 本身，不同时修改 Clash Profile、sing-box 认证、Peer 密钥和默认路由。默认使用 `management` 分流配置；`AllowedIPs = 0.0.0.0/0` 的全隧道配置可能接管默认路由并触发 Windows kill switch，不得作为基础连通性测试。

本手册中的地址、端口、密钥和接口名均为占位符。真实参数只从受控配置和两端运行态读取，不写入 Git、聊天或普通日志。

## 2. 成功门禁

WireGuard GUI 的“已连接”只证明本地 Tunnel Service 和虚拟网卡已启动，不证明远端已收到或响应。基础隧道必须同时满足以下四项才算通过：

| 门禁 | 证据 | 不能替代它的证据 |
| --- | --- | --- |
| G1 本地接口已启动 | Windows Tunnel Service 为 Running，WireGuard 适配器为 Up | GUI 只有绿色状态 |
| G2 已完成握手 | 两端 `latest-handshakes` 为近期时间 | 只有发送字节、服务端 `active (exited)` |
| G3 双向传输 | 两端 RX、TX 均大于零并在探测时变化 | 客户端 TX 增长但 RX 为零 |
| G4 私网业务可达 | 私网 Peer 地址或指定 TCP 服务探测成功 | 公网代理节点可用 |

只有 G1-G4 全部通过，才进入 Clash 或全隧道验证。P0-1 的联合运行态检查见 [`check-clash-runtime.ps1`](../../../vps-init/scripts/check-clash-runtime.ps1)，但它不能代替无握手阶段的 UDP 抓包。

## 3. 十分钟判定路径

| 时间 | 检查 | 判断与动作 |
| --- | --- | --- |
| 0-2 分钟 | 配置静态核对 | `Endpoint` 必须是 `<VPS_IP>:<WG_PORT>`；客户端 Address 唯一；两端公钥互指；PresharedKey 两端同时存在且一致，或两端都省略；`AllowedIPs` 不冲突 |
| 2-4 分钟 | 两端运行态 | Windows 读取服务、适配器、握手和收发；VPS 读取 `wg show`、UDP 监听和 systemd 状态 |
| 4-6 分钟 | 服务端短抓包 | 没有客户端 UDP：查 Endpoint、云防火墙、家庭出口；有入站但无响应：查 Peer/密钥/PSK/服务端运行配置；有入站和响应：转查回程 |
| 6-8 分钟 | Windows 物理网卡抓包 | 看客户端是否发出握手，以及服务端响应是否抵达物理网卡；不要只抓 WireGuard 虚拟网卡 |
| 8-10 分钟 | 同端口 UDP 对照 | 在维护窗口内用同一 UDP 端口做受控回显；若请求到 VPS、响应离开 VPS但客户端仍收不到，判定为端口/路径回程问题，测试其他已批准端口 |

最短决策树：

```text
GUI 已激活
  └─ 有近期握手？
      ├─ 是 → 有双向计数？
      │       ├─ 是 → 验证私网路由和业务 TCP，再验证 Clash
      │       └─ 否 → 查 AllowedIPs、路由、转发和防火墙
      └─ 否 → VPS 能看到客户端握手发起包？
              ├─ 否 → 查 Endpoint、监听端口、云防火墙和客户端出口
              └─ 是 → VPS 发出了握手响应？
                      ├─ 否 → 查 Peer 公钥、PSK、运行态配置和时间
                      └─ 是 → Windows 物理网卡收到响应？
                              ├─ 是 → 查 Windows 防火墙/驱动/隧道服务
                              └─ 否 → 同端口 UDP 对照并评估迁移端口
```

## 4. 分层检查命令

### 4.1 Windows：只读核对

需要读取受保护 Tunnel Service 运行态的命令应在管理员 PowerShell 中执行。权限不足时记录为“证据不可得”，不能推断为密钥不匹配。

```powershell
Get-Service WireGuardManager, 'WireGuardTunnel$*'
Get-NetAdapter | Where-Object InterfaceDescription -Match 'WireGuard|Wintun'
& 'C:\Program Files\WireGuard\wg.exe' show <TUNNEL_NAME>
Get-NetRoute -AddressFamily IPv4 | Where-Object DestinationPrefix -EQ '<WG_CIDR>'
Test-NetConnection <WG_SERVER_PRIVATE_IP> -Port <PRIVATE_TCP_PORT>
```

重点读取：

- `latest handshake` 是否存在且足够新；
- `transfer` 是否同时有 received 和 sent；
- `endpoint` 是否带正确 UDP 端口；
- 私网路由是否绑定到预期 WireGuard 接口。

Windows 导入配置后会使用受保护的 `.conf.dpapi`。修改原始 `.conf` 不会自动更新已经安装的 Tunnel Service；必须通过 GUI 重新导入，或按官方服务流程替换隧道。

### 4.2 VPS：只读核对

```bash
sudo systemctl status wg-quick@wg0 --no-pager
sudo wg show wg0
sudo wg show wg0 latest-handshakes
sudo wg show wg0 transfer
sudo ss -lunp | grep ":<WG_PORT>"
ip -br address show wg0
sudo sysctl net.ipv4.ip_forward
```

`wg-quick@wg0` 显示 `active (exited)` 可以是正常状态，因为接口和数据面由内核维持。真正的活性证据是近期握手和双向计数。

只有“已握手但私网或互联网转发失败”时，才继续检查：

```bash
ip route
sudo nft list ruleset
sudo iptables -t nat -S POSTROUTING
```

无握手时先不要把时间耗在 NAT、DNS、sing-box 或 Clash 上。

### 4.3 VPS：短时 UDP 抓包

以下抓包可能包含公网 Endpoint，只在 VPS 本地查看并及时删除，不把原始输出提交到仓库：

```bash
sudo timeout 20 tcpdump -ni any "udp port <WG_PORT>" -vv
```

激活客户端并观察同一轮请求。标准 WireGuard 握手中，客户端发起包的 UDP payload 通常为 148 字节，服务端响应通常为 92 字节；包长只能辅助识别方向，最终仍以 `wg show` 和端到端结果为准。

| VPS 抓包 | 高概率结论 | 下一步 |
| --- | --- | --- |
| 完全没有入站 | 客户端没发到该 Endpoint，或上游入站被丢弃 | 查客户端 Endpoint、当前物理出口、云安全组和 VPS UDP 监听 |
| 有 148 字节入站，没有 92 字节响应 | WireGuard 没接受该握手 | 查运行态 Peer 公钥、PSK、服务端私钥、两端时间和加载的配置 |
| 有 148 字节入站，也有 92 字节出站，客户端仍 RX=0 | VPS 已处理并响应，问题转向 UDP 回程或 Windows 入站路径 | 立即在 Windows 物理网卡抓包；不要继续重建密钥 |

### 4.4 Windows：物理网卡 PktMon

PktMon 是 Windows 内置的跨网络栈诊断工具。管理员 PowerShell 中限制为目标 UDP 端口并短时抓取：

```powershell
pktmon filter remove WG-UDP
pktmon filter add WG-UDP -t UDP -p <WG_PORT>
pktmon start -c --file-name "$env:TEMP\wg-pktmon.etl"
# 激活隧道并等待一轮握手
pktmon counters
pktmon stop
pktmon filter remove WG-UDP
Remove-Item -LiteralPath "$env:TEMP\wg-pktmon.etl"
```

首次执行时若不存在名为 `WG-UDP` 的旧过滤器，第一条删除命令报“未找到”可忽略；不要无条件删除其他诊断任务的过滤器。如需详细包内容，先不要执行最后的 `Remove-Item`，按本机 `pktmon /?` 支持的格式导出 ETL/PCAP；文件中可能包含 Endpoint，分析后再删除。判定重点是物理网卡是否看到了服务端的 UDP 响应：

- 看到了客户端发出、也看到响应进入物理网卡：继续查 Windows 防火墙、驱动、Tunnel Service 和本机网络栈；
- 看到了客户端发出，但物理网卡没有任何响应，而 VPS 已抓到响应发出：回程在到达 Windows 之前被丢弃。

## 5. 同端口 UDP 对照与端口迁移

同端口 UDP 回显用于区分“WireGuard 认证问题”和“该 UDP 五元组的通用回程问题”。它需要临时占用端口，必须在维护窗口内先停止 WireGuard 监听、保留 SSH/供应商控制台恢复入口，并准备立即恢复；不要在仍需该隧道维持管理连接时执行。

判定规则：

1. 客户端 UDP 请求到达 VPS；
2. VPS 回显响应确实从公网接口发出；
3. 客户端超时且物理网卡没有响应；
4. 换用另一个已批准 UDP 端口后，同一测试可双向收发。

四项同时成立时，可以把根因收敛到“原 UDP 端口的回程路径被网络设备或策略丢弃”。无法仅凭端点抓包确定具体是家庭路由器、运营商、VPS 上游还是中间网络，必须保留这个不确定边界。

迁移时一次只改端口：

1. 备份 VPS 声明式配置与客户端配置；
2. 在云防火墙和主机防火墙允许候选 UDP 端口；
3. 修改 VPS `ListenPort`，同步修改客户端 `Endpoint`；
4. 重载接口并确认新端口监听；
5. 先验证近期握手和双向计数，再验证私网 TCP 服务；
6. 验收后删除旧端口放行；失败则恢复两端旧端口和防火墙规则。

不要只用一次 UDP 扫描结果永久选端口；家庭网络、运营商和云网络策略可能变化。优先选择双方网络长期允许、用途明确且纳入防火墙管理的端口。

## 6. 握手之后的分层验证

| 阶段 | 只验证什么 | 通过条件 |
| --- | --- | --- |
| A 基础隧道 | `management` 配置，不启用 Clash | 近期握手、双向计数、私网地址/端口可达 |
| B 私网 sing-box | 直接探测 VPS 私网 TCP 入站 | TCP 建连成功，服务端监听地址正确 |
| C Clash 集成 | 当前活动 Profile 中的私网 Shadowsocks 节点 | Mihomo 实际连接私网地址，健康检查通过，公网 fallback 独立可用 |
| D 全隧道 | 用户明确选择的独立配置 | DNS、公网出口、IPv4/IPv6、局域网、断开恢复全部通过 |

这些阶段不能倒序。Clash 中名为 `VPS-WireGuard` 的节点在本项目里是“经操作系统 WireGuard 私网访问的 Shadowsocks 节点”，不是 Mihomo 原生 `type: wireguard` 节点；它超时不能直接证明 WireGuard 密钥错误。

若阶段 A、B 已通过而阶段 C 失败，不再修改 WireGuard，转入 [Clash Verge 私网节点快速排查手册](clash-verge-wireguard-private-node-troubleshooting.md)，对比隔离节点与主 Mihomo TUN 下的出口接口。

## 7. 禁止的低效或高风险做法

- 不以绿色 GUI、Tunnel Service Running、适配器 Up 作为“已经连上”的结论。
- 不在无握手时先改 Clash、sing-box 密码、DNS、NAT 或应用路由。
- 不同时更换密钥、PSK、端口和 `AllowedIPs`；一次只改变一个变量。
- 不把非管理员 `wg.exe` 的 `Permission denied` 当作密钥不匹配。
- 不直接比较含 CRLF/LF 差异的密钥文件长度或文本哈希；应规范化换行，并只在本机安全地派生/比较公钥。
- 不在基础排错中激活 `0.0.0.0/0` 的全隧道配置；它可能立刻中断当前网络和远程协作。
- 不在用户正在使用的活动 Clash Profile 上做故障注入。
- 不在未保留 SSH/Console 和回滚配置时停止 WireGuard、修改防火墙或占用监听端口。

## 8. AI 排查交接模板

后续 AI 每完成一层就记录结论，不得把“未获权限”写成“已验证”：

```text
现象：<GUI 状态、握手、RX/TX、私网探测>
静态配置：<Endpoint 格式、公钥配对、PSK 状态、AllowedIPs；不粘贴密钥>
Windows 运行态：<服务/适配器/握手/收发/物理网卡抓包>
VPS 运行态：<接口/监听/握手/收发/短抓包>
已证实：<能够由命令或抓包直接支持的事实>
未证实：<具体中间丢包设备、不可读的受保护配置等>
本次只改：<单一变量>
回滚：<恢复对象与验证命令>
下一门禁：<G1-G4 中尚未通过的一项>
```

## 9. 证据与关联页面

- 本手册的单向 UDP 判定链来自 [2026-08-22 WireGuard 连接故障复盘](../wireguard-connectivity-incident-2026-08-22.md)。该复盘证明的是当次环境，不代表所有无握手故障都由端口过滤导致。
- WireGuard 配置字段、`wg show`、握手和 Keepalive 语义见 [WireGuard 官方 Quick Start](https://www.wireguard.com/quickstart/) 与 [`wg(8)` 官方手册](https://git.zx2c4.com/wireguard-tools/about/src/man/wg.8)。
- Windows Tunnel Service、DPAPI 配置和管理员权限见 [WireGuard for Windows Enterprise Usage](https://git.zx2c4.com/wireguard-windows/about/docs/enterprise.md)。
- Windows 物理路径抓包见 [Microsoft Packet Monitor](https://learn.microsoft.com/en-us/windows-server/networking/technologies/pktmon/pktmon) 和 [`pktmon filter add`](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/pktmon-filter-add)。
- 基础概念和安装见 [WireGuard 使用指南](wireguard.md)，组合链路见 [联合架构与运维手册](combined-stack-operations.md)。
- WireGuard 已通但 Clash 私网节点失败时，见 [Clash Verge 私网节点快速排查手册](clash-verge-wireguard-private-node-troubleshooting.md) 与 [2026-08-22 Clash Verge 私网节点故障复盘](../clash-verge-wireguard-private-node-incident-2026-08-22.md)。
