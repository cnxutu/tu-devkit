# WireGuard 与 sing-box 软件指南

## 范围

本专栏帮助读者理解 WireGuard、sing-box 各自解决什么问题，如何在 Ubuntu 和 Windows 上从官方来源安装、使用和排错，以及它们如何与 Clash Verge 组成当前 VPS 代理链路。

这里不保存具体服务器 IP、端口、密钥、密码、订阅 URL、实时版本或一次性 PID。当前部署参数以受控配置和实机命令为准，P0 自动化行为以 [`vps-init/`](../../../vps-init/README.md) 的脚本与测试为准。

## 阅读导航

| 目标 | 页面 |
| --- | --- |
| 理解 VPN 隧道、Peer、`AllowedIPs`、分流和全隧道 | [WireGuard 指南](wireguard.md) |
| 理解代理内核、Inbound/Outbound、路由、服务管理 | [sing-box 指南](sing-box.md) |
| 核对 VPS 安装路径、进程、配置、日志和组合链路 | [联合架构与运维手册](combined-stack-operations.md) |
| 直接部署本仓库方案 | [VPS 初始化教程](../initialization-guide.md) |
| 查看当前 P0 网络拓扑 | [VPS 网络架构](../architecture.md) |
| 查看密钥、端口与日志边界 | [VPS 安全说明](../security.md) |

## 两者的边界

| 软件 | 工作层次 | 主要职责 | 不负责 |
| --- | --- | --- | --- |
| WireGuard | 三层 IP 隧道 | 在 Peer 之间建立加密私网、安装路由、承载任意 IP 流量 | 按域名选择代理、Shadowsocks 认证、业务级 fallback |
| sing-box | 代理与路由内核 | 接受代理协议、执行 DNS/路由规则、连接目标站点 | 分发 WireGuard Peer 密钥、替代操作系统路由管理 |
| Clash Verge / Mihomo | 桌面代理客户端 | 接管应用流量、按规则选择节点、健康检查与 fallback | 建立本项目的 WireGuard Peer 身份 |

在本项目中，WireGuard 提供 VPS 私网可达性，sing-box 提供 Shadowsocks 2022 服务，Clash Verge 决定哪些应用流量使用私网节点以及何时回退公网节点。三者是互补关系，不是互相替代。

## 证据状态

- 软件概念、安装入口和命令语义来自各自官方文档，页面底部保留官方链接。
- P0 路径、配置默认值和数据流来自当前仓库脚本、模板与测试。
- 软件版本、Windows/Linux UI 和发行渠道可能变化；安装前应重新核对官方页面，不以本文硬编码版本为准。

## 官方入口

- [WireGuard 官网](https://www.wireguard.com/)
- [WireGuard 官方安装页](https://www.wireguard.com/install/)
- [WireGuard 官方 Quick Start](https://www.wireguard.com/quickstart/)
- [WireGuard for Windows 服务说明](https://git.zx2c4.com/wireguard-windows/about/docs/enterprise.md)
- [sing-box 官方文档](https://sing-box.sagernet.org/)
- [sing-box 官方安装页](https://sing-box.sagernet.org/installation/package-manager/)
- [sing-box 官方桌面客户端](https://sing-box.sagernet.org/clients/desktop/)
- [sing-box 官方配置索引](https://sing-box.sagernet.org/configuration/)
