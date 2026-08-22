# VPS 文档

先从 [`vps-init/README.md`](../../vps-init/README.md) 的路线决策表选择 Quick/Secure、是否启用 WireGuard，以及本地 YAML/Remote Profile。

- [初始化教程](initialization-guide.md)：四条可直接执行的完整路径。
- [Remote Profile 教程](clash-remote-profile.md)：通过 WireGuard 私网订阅 Clash 配置。
- [极简 sing-box 本地 Profile](clash-verge-minimal-sing-box-profile.md)：单一公网 sing-box 节点、系统代理模式，不启用 TUN 或 WireGuard。
- [架构说明](architecture.md)：安装状态迁移与客户端数据流。
- [安全说明](security.md)：SSH、防火墙、密钥、订阅秘密与日志边界。
- [WireGuard 与 sing-box 软件指南](software-guides/README.md)：软件原理、Ubuntu/Windows 安装、常用命令、适用场景及联合运维核对。
- [WireGuard 快速排查](software-guides/wireguard-fast-troubleshooting.md)：处理 GUI 已激活但无握手、RX=0、单向 UDP 回程和私网不可达。
- [2026-08-22 WireGuard 连接故障复盘](wireguard-connectivity-incident-2026-08-22.md)：记录本次原端口回程不可达的证据链、无效尝试和改进后的排查顺序。
- [Clash Verge 私网节点快速排查](software-guides/clash-verge-wireguard-private-node-troubleshooting.md)：处理 WireGuard 已通但主 Mihomo 在 TUN 下仍判定私网 Shadowsocks 节点不可用。
- [2026-08-22 Clash Verge 私网节点故障复盘](clash-verge-wireguard-private-node-incident-2026-08-22.md)：记录隔离节点验证、TUN 出口接口定因、设备级 `interface-name` 修复和多电脑注意事项。

本文档不提供特定 VPS 供应商的实时价格、库存或节点推荐；购买时应从供应商官方页面核实。
