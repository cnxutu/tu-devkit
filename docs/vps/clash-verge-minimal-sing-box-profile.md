# Clash Verge 极简 sing-box 本地 Profile

## 目标与边界

此 Profile 只解决一件事：让**遵循 Windows 系统代理**的应用通过一个公网 sing-box Shadowsocks 2022 节点访问外网。它不包含 TUN、WireGuard、Remote Profile、DNS 接管、分流域名表、节点测速或 fallback，目的是减少当前链路的变量。

它是应用/系统代理配置，**不是三层 VPN**：不遵循系统代理的应用不会被接管。需要 TUN 前，应先单独验证本机路由、WireGuard 私网排除和应用兼容性，而不是在此最小 Profile 上继续叠加设置。

## 文件与准备

模板位于 [`vps-init/config/clash-verge-sing-box-minimal.template.yaml`](../../vps-init/config/clash-verge-sing-box-minimal.template.yaml)。复制到仓库外的受限目录，例如：

```powershell
Copy-Item `
  D:\workspace\github\tu-devkit\vps-init\config\clash-verge-sing-box-minimal.template.yaml `
  C:\vps\clash-sing-box-minimal.yaml
```

只替换以下四项：

| 字段 | 来源 |
| --- | --- |
| `server` | VPS 公网 IP 或域名 |
| `port` | VPS sing-box TCP 监听端口 |
| `cipher` | 与 sing-box `method` 一致的 Shadowsocks 2022 方法 |
| `password` | VPS 受保护状态目录中的 sing-box 密码 |

完整 YAML 含 Shadowsocks 密码，属于凭据。不要保存到仓库、同步盘、截图、聊天记录或公开日志。

## Clash Verge 使用方式

1. 在 Clash Verge 的 Profiles 中“从文件导入” `C:\vps\clash-sing-box-minimal.yaml`，然后启用它。
2. 保持模式为 `Rule`，策略组 `🚀 VPS` 只选择 `VPS-sing-box`。
3. 在 Clash Verge 设置中启用“系统代理”。不要手工写 WinINET 注册表；应用设置才是持久来源。
4. 关闭 TUN / 虚拟网卡和“自动设置全局路由”。此模板未为 TUN 提供运行态保障。
5. 重载内核或完全退出 Clash Verge（含托盘）后重新启动，再访问需要代理的网站验证。

模板将局域网、私网、localhost 和 Windows 连通性检查直连，其他进入系统代理的流量都匹配 `MATCH,🚀 VPS`。它不含 `DIRECT` 代理选项，避免策略组被误切为直连。

## 最小验收

在 PowerShell 中确认系统代理与本地端口：

```powershell
$proxy = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$proxy.ProxyEnable
$proxy.ProxyServer
Test-NetConnection 127.0.0.1 -Port 7897
```

预期是 `ProxyEnable` 为 `1`、`ProxyServer` 指向 `127.0.0.1:7897`，且端口可达。若端口可达但浏览器仍直连，回到 Clash Verge 重新保存“系统代理”并重启应用。

服务端仅需确认 sing-box 正常；不要为了本 Profile 再启动 WireGuard 或 Remote：

```bash
sudo systemctl status sing-box --no-pager
sudo sing-box check -c /etc/sing-box/config.json
```

## 排错与回退

| 现象 | 处理 |
| --- | --- |
| 导入后没有网络 | 先关闭系统代理，切回上一个 Profile；检查 `server`、`port`、`cipher` 和 `password` 是否与 sing-box 完全一致 |
| 外网仍直连或很慢 | 确认 Clash Verge 的系统代理已经启用；该模板不启用 TUN，因此不接管绕过系统代理的应用 |
| 页面尝试 QUIC 后超时 | 保持模板的 UDP/443 拒绝和节点 `udp: false`，让 HTTPS 回落 TCP |
| 需要局域网资源 | 保持私网 `DIRECT` 规则；不要用 TUN 全局路由来解决系统代理配置问题 |

该 Profile 的回退方式是：在 Clash Verge 停用它并恢复之前的 Profile，然后关闭系统代理。它不会修改 VPS、WireGuard 或服务器防火墙。
