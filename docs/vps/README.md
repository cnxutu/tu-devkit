# VPS 总入口：学习、部署与排障

本页是 P0-1 VPS 相关知识的总入口。它负责告诉你**先学什么、遇到什么问题读哪一页、哪些内容可以当作当前事实**；具体命令、配置和故障证据仍以链接到的专题文档、脚本、测试和受控运行态为准。

本目录不保存真实公网地址、端口组合、密钥、密码、订阅 URL、Token、PID 或完整日志。文档中的配置只表达结构和目标状态，不代表当前 VPS 已加载该配置。

## 先看哪一页

| 你的目标 | 首先阅读 | 然后阅读 |
| --- | --- | --- |
| 第一次理解这套 VPS | [网络架构](architecture.md) | [WireGuard 与 sing-box 软件指南](software-guides/README.md) |
| 从零部署 | [`vps-init/README.md`](../../vps-init/README.md) 的路线决策表 | [初始化教程](initialization-guide.md)、[安全说明](security.md) |
| 学 WireGuard | [WireGuard 指南](software-guides/wireguard.md) | [WireGuard 快速排查](software-guides/wireguard-fast-troubleshooting.md) |
| 学 sing-box | [sing-box 指南](software-guides/sing-box.md) | [联合架构与运维手册](software-guides/combined-stack-operations.md) |
| 配置 Clash Verge / Remote Profile | [Remote Profile 教程](clash-remote-profile.md) | [极简 sing-box 本地 Profile](clash-verge-minimal-sing-box-profile.md) |
| WireGuard 已通但 Clash 私网节点失败 | [Clash Verge 私网节点快速排查](software-guides/clash-verge-wireguard-private-node-troubleshooting.md) | [对应故障复盘](clash-verge-wireguard-private-node-incident-2026-08-22.md) |
| SSH、代理、VPN 突然不可用 | 先读本页的[排障入口](#排障入口)，再读 [WireGuard 快速排查](software-guides/wireguard-fast-troubleshooting.md) | 按症状选择历史复盘 |
| 复盘一次真实网络事故 | [WireGuard 连接故障复盘](wireguard-connectivity-incident-2026-08-22.md) | [WireGuard / sing-box / SSH 脱敏复盘](vps-network-troubleshooting-wireguard-singbox-ssh-anonymized.md) |

## 推荐学习路线

按下面顺序阅读，可以先建立模型，再执行变更，最后学习如何用证据定位故障。

### 1. 先建立组件边界

先读[网络架构](architecture.md)和[软件指南入口](software-guides/README.md)，理解三层职责：

- WireGuard：三层加密 IP 隧道，负责 Peer、握手和路由；
- sing-box：代理协议、入站/出站、DNS 和代理路由；
- Clash Verge / Mihomo：桌面端流量接管、规则选择、TUN 和节点编排。

重点理解 `management` 分流与 `full` 全隧道的区别，以及“配置存在、服务运行、握手成功、业务流量通过”是四个不同结论。

### 2. 再学习部署路径

阅读 [`vps-init/README.md`](../../vps-init/README.md) 的路线表，再看[初始化教程](initialization-guide.md)：

1. Quick + 本地 YAML：先验证 sing-box 和基础代理；
2. Quick + WireGuard + 本地 YAML：增加管理私网；
3. Quick + WireGuard + Remote：通过私网分发 Clash 配置；
4. Secure + Remote：在恢复入口和第二 SSH 会话已准备好后再加固。

部署前同时阅读[安全说明](security.md)，特别是 SSH 迁移、UFW、Remote Profile 凭据和回滚入口。

### 3. 学会日常运维

使用[联合架构与运维手册](software-guides/combined-stack-operations.md)把配置校验、systemd、监听、WireGuard 计数、sing-box 日志、Clash 运行态和端到端请求串起来。仓库实现和自动化入口以 [`vps-init/README.md`](../../vps-init/README.md)、`vps-init/doctor.sh`、脚本和测试为准；不要在远端长期维护一套未纳入仓库的临时命令。

### 4. 最后学习排障

排障顺序是：现象与成功标准 → 实际入口 → 客户端路由 → 中间层运行态 → 隧道/传输 → VPS 入站 → 服务出站 → 原始业务负载。先读 [`AGENTS.md`](AGENTS.md) 的证据和变更门禁，再按最早未通过的一层取证。

页面快、视频慢时，必须测媒体清单和分片；SSH、sing-box、WireGuard 同时异常时，优先验证公网 IP、TCP 三次握手、VPS Console 和双端抓包，不要直接重装服务、切换全隧道或清空防火墙。

## 排障入口

明确指定 `P0-1` 并涉及 VPS 部署、网络、代理、VPN、DNS、路由、防火墙、性能或稳定性时：

1. 先读取 [`AGENTS.md`](AGENTS.md)，它是本目录的工作方法、证据标准、风险门禁和交接格式；
2. 写出期望路径，并记录当前有效配置、监听、路由、握手、流量计数和恢复入口；
3. 用与症状匹配的最小探针建立基线；一轮实验只改变一个变量；
4. 只有在原失败探针经最小变更转为成功、相邻替代原因已排除且持久性已验证时，才称为“根因”或“已解决”；
5. 历史复盘只用于提出检查方向，不能替代当前运行态核实。

专题排查页面：

- [WireGuard 快速排查](software-guides/wireguard-fast-troubleshooting.md)：无握手、RX=0、单向 UDP 回程、私网不可达；
- [Clash Verge 私网节点快速排查](software-guides/clash-verge-wireguard-private-node-troubleshooting.md)：WireGuard 已通但 TUN 下节点不可用；
- [WireGuard 连接故障复盘](wireguard-connectivity-incident-2026-08-22.md)：单向 UDP 回程故障的证据链和改进顺序；
- [Clash Verge 私网节点故障复盘](clash-verge-wireguard-private-node-incident-2026-08-22.md)：隔离实例、TUN 出口接口和多电脑配置边界；
- [WireGuard / sing-box / SSH 脱敏复盘](vps-network-troubleshooting-wireguard-singbox-ssh-anonymized.md)：多协议同时不可用时，从 VPS 健康、监听、防火墙、`tcpdump` 到地域可达性的完整示例。

## 证据与文档边界

- `AGENTS.md`、指南和架构页：长期可复用的方法、边界和目标结构；
- `vps-init/` 脚本、配置模板、测试和 `doctor.sh`：当前仓库实现与静态验证依据；
- 事故复盘：带时间窗口的历史证据，只用于学习和提出当前检查方向；
- 当前 SSH、systemd、`ss`、`wg show`、防火墙、Controller 和真实业务探针：判断“现在是否正常”的最高优先级证据。

软件的官方安装入口、配置索引和版本核对链接集中在[软件指南入口](software-guides/README.md)。版本、供应商策略、云安全组、DNS 和公网可达性等易变事实，使用前必须重新核实。

本文档不提供特定 VPS 供应商的实时价格、库存或节点推荐；购买和供应商侧变更应从供应商官方页面与控制台核实。
