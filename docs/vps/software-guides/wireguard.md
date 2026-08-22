# WireGuard 使用指南

## 1. 它是什么

WireGuard 是基于 UDP 的三层加密隧道。它创建一个虚拟网络接口，把匹配路由的 IP 包加密后发送给 Peer。它的核心模型接近“接口 + 密钥 + 路由”，不提供用户名密码登录、域名分流、订阅管理或应用代理规则。

Linux 上的 WireGuard 通常运行在内核中，因此不会出现一个长期驻留的 `wireguard` 用户态进程。`wg-quick@wg0.service` 执行完接口、地址和路由配置后显示 `active (exited)` 是正常状态；真正的数据面由内核接口 `wg0` 承担。

### 核心名词

| 名词 | 含义 |
| --- | --- |
| Interface | 本机 WireGuard 虚拟网卡，持有本机私钥和隧道地址 |
| Peer | 允许通信的对端，使用对端公钥标识 |
| Endpoint | 从本机访问对端时使用的公网主机与 UDP 端口 |
| `AllowedIPs` | 同时承担出站路由选择和入站源地址许可的 CIDR 列表 |
| Handshake | Peer 之间的密钥协商；近期握手是链路活性的关键证据 |
| `PersistentKeepalive` | 周期性小包，用于维持 NAT/状态防火墙映射；不是链路重试器 |

WireGuard 不负责自动分发密钥和配置。私钥永远只留在所属设备；两端交换公钥，必要时再配置独立 PresharedKey。

## 2. 分流与全隧道

`AllowedIPs` 决定哪些目标进入隧道：

```ini
# 只访问 VPS 私网：分流
AllowedIPs = 10.66.66.0/24

# 所有 IPv4 默认流量进入隧道：全隧道
AllowedIPs = 0.0.0.0/0
```

启动 WireGuard 不等于自动接管所有流量。只有 `AllowedIPs` 覆盖默认路由，或者系统存在其他显式默认路由时，普通互联网流量才会全量进入隧道。

本项目默认采用 `management` 分流模式：Windows 只把 VPS 私网 CIDR 路由到 WireGuard；Clash Verge 再把选中的 AI 流量发送给该私网里的 Shadowsocks 入口。这样公网 Shadowsocks fallback 不依赖 WireGuard 本身，容灾边界更清晰。

## 3. 推荐使用场景

| 场景 | 推荐程度 | 说明 |
| --- | --- | --- |
| 远程访问 VPS 私网管理端口 | 推荐 | 无需把管理 API、订阅服务暴露公网 |
| 个人设备到 VPS 的稳定私网 | 推荐 | 配置少、性能好、密钥模型清晰 |
| 两个固定网络之间 Site-to-Site | 推荐 | 配合路由和转发规则使用 |
| 全机流量统一从 VPS 出口 | 条件推荐 | 使用 `0.0.0.0/0`，必须额外设计 DNS、IPv6、kill switch 和恢复入口 |
| 按域名选择不同代理节点 | 不适合单独完成 | 交给 Clash、sing-box 等代理路由层 |
| 大规模员工身份、审批和自动撤权 | 不适合单独完成 | WireGuard 本身没有控制平面，需要额外的密钥与设备管理系统 |

## 4. Ubuntu 安装与使用

### 官方安装

Ubuntu 使用发行版包：

```bash
sudo apt-get update
sudo apt-get install -y wireguard
```

官方入口：

- [WireGuard Installation](https://www.wireguard.com/install/)
- [WireGuard Quick Start](https://www.wireguard.com/quickstart/)
- [`wg(8)` 官方手册](https://git.zx2c4.com/wireguard-tools/about/src/man/wg.8)
- [`wg-quick(8)` 官方手册](https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8)

### 常见安装布局

| 内容 | Ubuntu 路径 |
| --- | --- |
| `wg` | `/usr/bin/wg` |
| `wg-quick` | `/usr/bin/wg-quick` |
| 接口配置 | `/etc/wireguard/<interface>.conf` |
| 本项目服务端配置 | `/etc/wireguard/wg0.conf` |
| systemd 模板 | `/lib/systemd/system/wg-quick@.service` 或发行版等价路径 |

可用以下命令从实机确认，不要只依赖表格：

```bash
command -v wg wg-quick
readlink -f "$(command -v wg)"
dpkg-query -W wireguard wireguard-tools
dpkg -L wireguard-tools
systemctl show wg-quick@wg0 -p FragmentPath -p ExecStart
```

### 最小配置结构

服务端 `/etc/wireguard/wg0.conf` 的结构示例：

```ini
[Interface]
Address = 10.66.66.1/24
ListenPort = <UDP_PORT>
PrivateKey = <SERVER_PRIVATE_KEY>

[Peer]
PublicKey = <CLIENT_PUBLIC_KEY>
PresharedKey = <OPTIONAL_PRESHARED_KEY>
AllowedIPs = 10.66.66.2/32
```

客户端结构示例：

```ini
[Interface]
Address = 10.66.66.2/32
PrivateKey = <CLIENT_PRIVATE_KEY>

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
PresharedKey = <OPTIONAL_PRESHARED_KEY>
Endpoint = <VPS_PUBLIC_HOST>:<UDP_PORT>
AllowedIPs = 10.66.66.0/24
PersistentKeepalive = 25
```

`PersistentKeepalive = 25` 适合客户端位于 NAT 或状态防火墙后的场景。官方 Quick Start 将 25 秒作为广泛兼容的合理值；不是所有 Peer 都必须配置，通常配置在需要维持映射的一侧。

### 服务管理

```bash
sudo systemctl enable --now wg-quick@wg0
sudo systemctl restart wg-quick@wg0
sudo systemctl status wg-quick@wg0 --no-pager
sudo systemctl is-enabled wg-quick@wg0
sudo systemctl is-active wg-quick@wg0
```

`wg-quick` 会根据 `/etc/wireguard/wg0.conf` 创建或删除接口、设置地址和路由，并执行配置中的 `PostUp/PostDown`。它不是常驻 VPN 守护进程。

### 安全核对

```bash
sudo stat -c '%a %U:%G %n' /etc/wireguard /etc/wireguard/wg0.conf
ip -br link show wg0
sudo wg show wg0
sudo wg show wg0 latest-handshakes
sudo wg show wg0 transfer
sudo journalctl -u wg-quick@wg0 --no-pager -n 100
```

期望配置目录与私钥配置只允许 root 读取，通常目录为 `0700`、配置为 `0600`。`wg show` 默认隐藏私钥和 PresharedKey，但仍会显示公钥、Endpoint、流量和握手信息；不要把完整输出粘贴到公开工单或聊天。

查看原始配置应在 VPS 终端本地进行：

```bash
sudo less /etc/wireguard/wg0.conf
# 或编辑
sudoedit /etc/wireguard/wg0.conf
```

修改前先备份并保持现有 SSH 会话。修改后先检查语法，再在具备控制台恢复能力时重启隧道。不要使用 `SaveConfig = true` 与自动生成配置混用，否则停止接口时可能覆盖声明式配置。

## 5. Windows 安装与使用

### 官方下载

从 [WireGuard 官方安装页](https://www.wireguard.com/install/) 下载 Windows Installer。普通用户使用自动选择架构、校验签名的安装器；批量部署可使用官方 MSI。不要从软件聚合站下载驱动和安装包。

官方 Windows 客户端支持 Windows 10/11 和相应 Windows Server 版本。企业部署、服务模式和 ACL 见 [WireGuard for Windows Enterprise Usage](https://git.zx2c4.com/wireguard-windows/about/docs/enterprise.md)。

### 默认安装与服务

| 内容 | Windows 默认位置或名称 |
| --- | --- |
| GUI/服务程序 | `C:\Program Files\WireGuard\wireguard.exe` |
| CLI | `C:\Program Files\WireGuard\wg.exe` |
| Manager 服务 | `WireGuardManager` |
| 单隧道服务 | `WireGuardTunnel$<tunnel-name>` |
| 受保护配置库 | `%ProgramFiles%\WireGuard\Data\Configurations\*.conf.dpapi` |

Manager 服务负责托盘 UI 与隧道管理；每个已安装隧道有独立 Tunnel Service，启动时创建网络适配器，停止时删除适配器。受保护配置使用 Windows DPAPI；读取详细运行状态通常需要管理员权限。

### GUI 使用

1. 安装并启动 WireGuard。
2. 可从 [`vps-init/config/wireguard-client.example.conf`](../../../vps-init/config/wireguard-client.example.conf) 复制脱敏模板到仓库外，只替换其中五个占位符；或使用受控传输得到的 `.conf`。
3. 选择“从文件导入隧道”，导入完成后的 `.conf`。
4. 核对隧道名称、Address、Endpoint 和 `AllowedIPs`，不要在截图中显示密钥。
5. 激活隧道，确认“最新握手”和收发字节持续更新。
6. 分流场景验证私网地址；全隧道场景额外验证公网出口、DNS 和 IPv6 行为。

### PowerShell 核对

以管理员 PowerShell 运行需要高权限的命令：

```powershell
Get-Service WireGuardManager, 'WireGuardTunnel$*'
Get-NetAdapter | Where-Object InterfaceDescription -Match 'WireGuard|Wintun'
& 'C:\Program Files\WireGuard\wg.exe' show interfaces
& 'C:\Program Files\WireGuard\wg.exe' show <tunnel-name>
Test-NetConnection <WIREGUARD_PRIVATE_SERVER> -Port <PRIVATE_SERVICE_PORT>
```

官方服务安装命令：

```powershell
& 'C:\Program Files\WireGuard\wireguard.exe' /installtunnelservice 'C:\secure\client.conf'
& 'C:\Program Files\WireGuard\wireguard.exe' /uninstalltunnelservice '<tunnel-name>'
```

卸载 Tunnel Service 会使该隧道暂时不可用；执行前必须确认配置备份和替代管理路径。不要把明文 `.conf` 长期放在下载目录、同步盘或 Git 仓库。

## 6. 排错顺序

遇到“Windows GUI 已连接但没有近期握手、接收为零”时，直接使用 [WireGuard 快速排查手册](wireguard-fast-troubleshooting.md)。它给出两端抓包、单向 UDP 回程判定、端口迁移门禁和 AI 交接模板。

1. 确认两端时间正确、UDP 端口已被云安全组和主机防火墙允许。
2. 确认服务端 `wg0` 接口存在，Windows Tunnel Service 与适配器均正常。
3. 检查 Endpoint 是否可解析和可达，Peer 公钥是否配对。
4. 查看 `latest-handshakes`；无握手先排 UDP、防火墙、Endpoint 和密钥，不先排应用代理。
5. 有握手但私网不通时，检查 Address、`AllowedIPs`、路由、IP forwarding 和防火墙转发。
6. 私网可达但应用端口不通时，再检查 sing-box 的监听地址、端口和服务状态。
7. NAT 后长时间空闲才失效时，再评估 `PersistentKeepalive = 25`。

### 常见误区

- `AllowedIPs = 10.66.66.0/24` 是分流，不会让所有互联网流量进入隧道。
- `AllowedIPs = 0.0.0.0/0` 只覆盖 IPv4；若系统仍有 IPv6，必须单独设计 IPv6 路由和泄漏边界。
- WireGuard for Windows 在单 Peer 配置包含 `/0` 时会启用阻止隧道外流量的 kill switch；即使本机仍有更具体的局域网路由，防火墙也可能阻止访问局域网。只需要 VPS 私网和 AI 私网入口时使用 `AllowedIPs = 10.66.66.0/24`。
- Windows 导入 `.conf` 后会把配置保存到受保护的 DPAPI 配置库。之后修改原始 `.conf` 不会自动更新正在运行的 Tunnel Service；需要在确认备份后删除旧隧道并重新导入，或使用官方 `/uninstalltunnelservice`、`/installtunnelservice` 命令替换服务。
- WireGuard 没有“登录密码”。不要把 WireGuard 私钥或 PresharedKey 填入 Clash 的 Shadowsocks `password`。
- 能 ping 通 Peer 不代表 sing-box 端口正常；反过来，公网代理正常也不代表 WireGuard 已握手。

## 7. 本项目入口

- 安装实现：[`vps-init/scripts/wireguard.sh`](../../../vps-init/scripts/wireguard.sh)
- 添加客户端：[`vps-init/scripts/wg-add-client.sh`](../../../vps-init/scripts/wg-add-client.sh)
- 配置默认值：[`vps-init/config/vps.example.yaml`](../../../vps-init/config/vps.example.yaml)
- Windows 客户端脱敏模板：[`vps-init/config/wireguard-client.example.conf`](../../../vps-init/config/wireguard-client.example.conf)
- 当前数据流：[VPS 网络架构](../architecture.md)
- 联合验收：[联合架构与运维手册](combined-stack-operations.md)
- 无握手快速定位：[WireGuard 快速排查手册](wireguard-fast-troubleshooting.md)
- 实际故障证据：[2026-08-22 WireGuard 连接故障复盘](../wireguard-connectivity-incident-2026-08-22.md)
