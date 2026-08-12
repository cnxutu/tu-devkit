# VPS 初始化

`vps-init` 用同一套脚本提供两条安装路线，并支持两种 Clash 配置交付方式：

| 选择 | 适用场景 | SSH | WireGuard | Clash 配置 |
| --- | --- | --- | --- | --- |
| Quick | 先从 0 到 1 验证代理 | 保持供应商现状 | 默认关闭，可选 | 本地 YAML；开启 WG 后可选 Remote |
| Secure | 安装时完成常规安全加固 | 两阶段迁移到密钥认证 | 始终安装 | 本地 YAML；可选 Remote |

Remote Profile 是“经 WireGuard 私网拉取 Clash YAML”，不是 Clash 远程控制。第一版不会开放公网订阅端口、Clash Controller 或管理 UI。

```mermaid
flowchart TD
  A["全新 Ubuntu"] --> B{"选择路线"}
  B -->|"快速验证"| Q{"Quick 是否启用 WireGuard"}
  B -->|"安装即加固"| S["Secure：固定启用 WireGuard"]
  Q -->|"否"| QL["Quick + 本地 YAML"]
  Q -->|"是"| QC{"配置交付方式"}
  S --> SC{"配置交付方式"}
  QC -->|"本地导入"| QWL["Quick + WG + 本地 YAML"]
  QC -->|"私网订阅"| QWR["Quick + WG + Remote"]
  SC -->|"本地导入"| SL["Secure + 本地 YAML"]
  SC -->|"私网订阅"| SR["Secure + Remote"]
```

## 1. 从全新 Ubuntu 开始

服务器上只需先手动安装 Git 与 CA 证书：

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates git
git clone <your-tu-devkit-remote>
cd tu-devkit/vps-init
cp config/vps.example.yaml config/vps.local.yaml
```

编辑 `config/vps.local.yaml`。至少确认：

- `server.public_endpoint`：VPS 公网 IP 或域名，供 WireGuard 与 Clash 共用。
- `ssh.current_port`：供应商当前 SSH 监听端口，默认 `22`。
- `ssh.port`：Secure 完成后的 SSH 端口。
- `ssh.admin_authorized_keys_path`：Secure 使用的非 root 管理员公钥文件。
- `wireguard.enabled`：只控制 Quick 是否安装 WG；Secure 会忽略 `false` 并固定安装。
- `wireguard.client_mode`：`full` 生成 `AllowedIPs = 0.0.0.0/0`；`management` 只路由 WG 私网 CIDR。
- `clash_remote.enabled`：是否启用 WG 私网 Remote Profile。

旧配置无需迁移：新增字段均有兼容默认值。

```yaml
wireguard:
  enabled: false
  client_mode: full # full | management

clash_remote:
  enabled: false
  port: 18080
  update_interval_hours: 24
```

真实端点、密码、私钥、`vps.local.yaml`、`output/` 和 Remote URL/token 都不得提交到 Git 或复制到日志。

## 2. 四条常用路径

### A. Quick：本地 Clash YAML，不安装 WG

保持默认的 `wireguard.enabled: false`、`clash_remote.enabled: false`：

```bash
./install.sh --profile quick --config config/vps.local.yaml --dry-run
./install.sh --profile quick --config config/vps.local.yaml --yes
./doctor.sh --config config/vps.local.yaml
```

顺序：`base → firewall → sing-box → clash`。Quick 只放行当前 SSH TCP 与 sing-box TCP，并启用当前 SSH 端口的 Fail2ban；不修改 sshd、不迁移端口、不禁用密码认证。

将权限为 `600` 的 `output/vps-clash.yaml` 安全复制到本机，再导入 Clash Verge。

### B. Quick + WG：仍使用本地 Clash YAML

设置 `wireguard.enabled: true`、`clash_remote.enabled: false`，然后执行与路径 A 相同的 Quick 命令。顺序变为：

`base → firewall → wireguard → sing-box → clash`

生成客户端：

```bash
sudo ./scripts/wg-add-client.sh laptop
```

`client_mode: full` 适合希望客户端全量流量进入 WG 的情况；只为了访问私网订阅时建议使用 `management`。

### C. Quick + WG + Remote

```yaml
wireguard:
  enabled: true
  client_mode: management
clash_remote:
  enabled: true
```

执行 Quick 命令后，顺序为：

`base → firewall → wireguard → sing-box → clash → clash-remote`

连接 WireGuard 后，显式查看敏感订阅 URL：

```bash
sudo ./show-clash-remote-url.sh
```

在 Clash Verge 中新增 Remote Profile。URL 形如：

```text
http://10.66.66.1:18080/subscription/<random-token>/vps-clash.yaml
```

服务仅绑定 WG 服务端地址；UFW 只允许 `in on wg0`，不会为公网网卡开放 `18080/tcp`。完整操作见[Remote Profile 教程](../docs/vps/clash-remote-profile.md)。

### D. Secure + Remote

Secure 固定安装 WG，因此 `wireguard.enabled` 可保持旧值；只需开启 `clash_remote.enabled: true`。开始前确认供应商 Web/Serial Console 可用，并保留当前 SSH 会话：

```bash
./install.sh --profile secure --config config/vps.local.yaml --dry-run
./install.sh --profile secure --config config/vps.local.yaml --yes
./doctor.sh --config config/vps.local.yaml
```

Prepare 会保留旧/新 SSH 端口、切换到非 root 密钥认证、安装 WG/sing-box/Remote，并写入 `secure-transition`。在第二终端通过目标端口成功登录后才能收口：

```bash
./install.sh --profile secure --finalize --verified-ssh --config config/vps.local.yaml --yes
./doctor.sh --config config/vps.local.yaml
```

`--yes` 不能替代 `--verified-ssh`。Finalize 只删除状态中记录、由本模块创建的旧 SSH 过渡规则，不删除用户已有 UFW 规则。若当前端口等于目标端口，Prepare 会直接形成 `secure`。

## 3. 状态与诊断

安装状态位于 `/var/lib/tu-devkit-vps-init/`：

- `profile`：`quick`、`secure-transition` 或 `secure`。
- `capabilities`：已安装的 `sing-box`、`wireguard`、`clash-remote`；重复执行采用并集，不会把仍运行的能力误标为已卸载。
- `managed-ufw-rules`：脚本拥有的防火墙规则。
- `secrets/`：密码、Remote token/URL 等敏感状态，权限为 `600`。

`doctor.sh` 优先按 capability 验收；旧状态没有 capability 文件时会按原 Quick/Secure 行为兼容推断：

```bash
./doctor.sh --config config/vps.local.yaml
./doctor.sh --profile quick --config config/vps.local.yaml
```

Remote 检查包括 systemd 服务、私网监听、`wg0` UFW 规则、发布文件权限和脱敏 HTTP 健康检查。过渡状态会明确输出下一条 Finalize 命令。

## 4. 安全与兼容边界

- Shadowsocks 2022 保持 TCP-only，节点为 `udp: false`；Clash 在业务规则之前拒绝 UDP/443，使 QUIC 快速回落 HTTP/2/TCP。
- Steam 商店/社区主页面继续走 `🎬 Entertainment`；`steamstatic.com` 等图片与前端 CDN 默认走 `🎮 Steam CDN → DIRECT`，可在 Clash Verge 中手动回退 VPS，避免大量小资源绕行美国节点。
- Remote 复用同一份完整 Clash 模板；本地 YAML 导入仍受支持，且不会被自动转换或覆盖。
- 只有显式运行 `show-clash-remote-url.sh` 才显示敏感 URL；安装日志不记录 URL/token。
- sing-box 从官方 SagerNet APT stable 仓库安装，并固定校验 GPG 指纹 `2C317FBD5D886B4E89BAE8DA6D9152172A2B2F0C`，不执行 `curl | sh`。
- `--phase` 仍作为高级兼容入口；`--profile` 与 `--phase` 互斥。未指定入口时只显示帮助，不修改服务器。
- 云厂商安全组、DNS、TLS 证书与 VPS 购买不由脚本修改。

## 5. 开发验证

```bash
bash vps-init/tests/run.sh
bash -n vps-init/*.sh vps-init/lib/*.sh vps-init/scripts/*.sh vps-init/tests/*.sh
shellcheck vps-init/*.sh vps-init/lib/*.sh vps-init/scripts/*.sh vps-init/tests/*.sh
```

真实 VPS 仍需分别验收 Quick、Quick+WG、Quick+WG+Remote 与 Secure+Remote。
