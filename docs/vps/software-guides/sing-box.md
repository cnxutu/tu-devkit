# sing-box 使用指南

## 1. 它是什么

sing-box 是一个以 JSON 配置描述入站、出站、DNS 和路由的代理平台。本项目把它作为 VPS 上的服务端代理内核：接受 Shadowsocks 2022 的 TCP 连接，再从 VPS 访问目标站点。它不负责建立 Windows 与 VPS 的私网，也不负责桌面端的规则选择；前者由 WireGuard 完成，后者由 Clash Verge / Mihomo 完成。

| 组件 | 本项目职责 |
| --- | --- |
| sing-box | Shadowsocks 2022 入站、VPS 出站访问、服务配置校验 |
| WireGuard | Windows 到 VPS 私网的加密三层连接 |
| Clash Verge / Mihomo | Windows 应用代理、域名规则、私网优先和公网 fallback |

sing-box 的完整配置由 `dns`、`inbounds`、`outbounds`、`route` 等顶级字段组成。实际可用字段与行为以当前官方配置索引为准；升级前不要从旧文章复制已弃用字段。

## 2. 推荐使用场景

| 场景 | 推荐程度 | 原因 |
| --- | --- | --- |
| 个人 VPS 上提供 Shadowsocks 2022 服务 | 推荐 | 配置与 systemd 运维路径清晰，适合与 Clash 客户端配合 |
| 通过 WireGuard 私网访问同一代理入站 | 推荐 | 不必额外开放私网管理服务到公网 |
| 根据域名、应用或网络条件选择节点 | 交给客户端 | 应由 Clash Verge / Mihomo 规则和代理组完成 |
| 在 VPS 上开放公开管理 API 或面板 | 不推荐 | 本项目不开放 Controller、External UI 或管理 API |
| 一次性执行不透明的一键安装脚本 | 不推荐 | 无法审计软件来源、密钥和 systemd 配置 |

## 3. Ubuntu 安装

### 官方 APT 仓库

sing-box 官方文档提供 Debian / APT 仓库安装方式。当前命令和仓库地址可能变化，安装前先查看 [官方 Package Manager 页面](https://sing-box.sagernet.org/installation/package-manager/)。典型流程如下：

```bash
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
sudo chmod a+r /etc/apt/keyrings/sagernet.asc
sudo tee /etc/apt/sources.list.d/sagernet.sources >/dev/null <<'EOF'
Types: deb
URIs: https://deb.sagernet.org/
Suites: *
Components: *
Enabled: yes
Signed-By: /etc/apt/keyrings/sagernet.asc
EOF
sudo apt-get update
sudo apt-get install -y sing-box
```

本项目**不建议**在生产 VPS 手工执行上面的整段命令后再让脚本接管。对本项目部署，应使用 [`vps-init`](../../../vps-init/README.md)；其中 [`sing-box-repository.sh`](../../../vps-init/scripts/sing-box-repository.sh) 会先下载官方密钥、核验固定指纹，再写入 APT source，且不会执行 `curl | sh`。

首次安装或升级前先做 dry-run：

```bash
cd tu-devkit/vps-init
./install.sh --profile quick --config config/vps.local.yaml --dry-run
./install.sh --profile quick --config config/vps.local.yaml --yes
./doctor.sh --config config/vps.local.yaml
```

Secure 路线、WireGuard 和 Remote Profile 的选择见 [VPS 初始化教程](../initialization-guide.md)。不要把 `vps.local.yaml`、生成的 Clash YAML 或任何密钥提交到 Git。

### 安装位置与服务

发行包安装位置随版本和发行版可能不同，因此以命令输出为准：

```bash
command -v sing-box
sing-box version
dpkg-query -W sing-box
dpkg -L sing-box
systemctl show sing-box -p FragmentPath -p ExecStart
```

当前 P0-1 脚本管理的服务端配置是 `/etc/sing-box/config.json`，权限为 `0600`；生成的 Shadowsocks 密码存于受限状态目录，不写入安装日志。不要将这些位置当作跨发行版的 sing-box 固定默认值。

## 4. 配置模型与项目映射

### 最小结构

下面只是解释结构的脱敏示例，不能直接用于生产：

```json
{
  "dns": {
    "servers": [{ "type": "local", "tag": "local" }],
    "strategy": "ipv4_only"
  },
  "route": {
    "default_domain_resolver": { "server": "local", "strategy": "ipv4_only" }
  },
  "inbounds": [
    {
      "type": "shadowsocks",
      "listen": "<LISTEN_ADDRESS>",
      "listen_port": <TCP_PORT>,
      "network": "tcp",
      "method": "2022-blake3-aes-128-gcm",
      "password": "<BASE64_SECRET>"
    }
  ]
}
```

| 配置项 | P0-1 当前策略 | 原因 |
| --- | --- | --- |
| Shadowsocks 方法 | `2022-blake3-aes-128-gcm`（默认） | 脚本会按方法生成并校验对应长度的随机 Base64 密钥 |
| 网络 | TCP-only | Clash 模板禁用节点 UDP，并拒绝 UDP/443，使 QUIC 回落到 HTTP/2/TCP |
| DNS / 默认域名解析 | `ipv4_only` | 适用于尚未验证 IPv6 默认路由的 VPS；启用 IPv6 前应先做实机验证 |
| multiplex | 服务端兼容开启、`padding: false` | 客户端不启用 `smux` / `h2mux`，避免长流式连接共享底层连接的稳定性风险 |
| 监听 | 由 `sing_box.listen` 和 `sing_box.port` 配置 | 暴露公网地址时，脚本会要求显式确认 |

配置来源是 [`vps-init/config/vps.example.yaml`](../../../vps-init/config/vps.example.yaml)，生成逻辑在 [`vps-init/scripts/sing-box.sh`](../../../vps-init/scripts/sing-box.sh)。不要手工编辑 `/etc/sing-box/config.json` 后又直接重复执行安装脚本；脚本会重新生成它。需要改变行为时，先修改受控 YAML 与脚本/模板，再走校验和部署流程。

### 配置校验

每次改动后，必须先校验再重启：

```bash
sudo sing-box check -c /etc/sing-box/config.json
sudo systemctl restart sing-box
sudo systemctl status sing-box --no-pager
```

`sing-box check` 是官方配置检查入口；也可用 `sing-box format` 格式化**副本**，不要把格式化命令直接作用于含秘密的未知文件。P0-1 脚本在写入配置后已自动执行 `sing-box check`；校验失败会恢复脚本管理的上一版配置。

## 5. 日常运维与验证

### 服务生命周期

```bash
sudo systemctl enable sing-box
sudo systemctl start sing-box
sudo systemctl restart sing-box
sudo systemctl status sing-box --no-pager
sudo journalctl -u sing-box --output cat -n 100
sudo journalctl -u sing-box --output cat -f
```

停止服务会中断所有经此 VPS 的代理连接；仅在已确认公网 fallback、维护窗口或可回滚路径时执行。日志可能包含目标端点或连接元数据，不要整体复制到公开工单。

### 服务端验收

在 VPS 上执行：

```bash
sudo systemctl is-active --quiet sing-box
sudo sing-box check -c /etc/sing-box/config.json
sudo ss -ltnp
sudo ./doctor.sh --config config/vps.local.yaml
```

验收时应确认：sing-box 已运行、配置通过、预期 TCP 端口监听、UFW 仅放行设计中的入站，以及 `doctor.sh` 中的密钥长度/IPv4/multiplex 健康项通过。`ss` 与 `journalctl` 输出可能包含公网端点；在共享记录中只保留聚合结论。

### Windows 客户端验收

从服务器**受控地**取回权限为 `0600` 的 `output/vps-clash.yaml`，或在 WireGuard 已连接时导入私网 Remote Profile。不要在聊天、截图或同步目录暴露 YAML；其中包含 Shadowsocks 密码。

在 Clash Verge 中确认：Rule 模式、AI 组含私网优先节点和公网 fallback 节点、且 AI 组没有 `DIRECT`。再从仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\vps-init\scripts\check-clash-runtime.ps1 -RequireWireGuard
```

该检查器会优先读取 loopback Mihomo Controller；控制器不可用时回退核对合并运行配置。它不应用配置、也不会输出节点密码。完整组合验收见 [联合架构与运维手册](combined-stack-operations.md)。

## 6. 排错与恢复顺序

1. 先运行 `sing-box check`；语法或字段不兼容时不要重启服务。
2. 检查 `systemctl status sing-box` 和受限范围内的 journal 聚合，确认是启动失败、端口冲突还是连接问题。
3. 查看监听地址和 UFW 规则；确认公网 Shadowsocks 端口、WireGuard UDP 端口和 SSH 端口符合设计，避免以临时全开放排错。
4. 服务端健康但私网节点不可达时，转查 WireGuard 的握手、Windows 隧道服务与 `AllowedIPs`。
5. 公网节点可用、私网节点不可用时，保持 Clash fallback 可用，修复 WireGuard 后再恢复私网优先。
6. 修改后的 `sing-box check` 或 restart 失败时，恢复脚本保存的上一版配置；不要在故障状态继续叠加手工更改。

## 7. 官方资料与项目入口

- [sing-box 官方文档](https://sing-box.sagernet.org/)
- [官方 Package Manager](https://sing-box.sagernet.org/installation/package-manager/)
- [官方配置索引](https://sing-box.sagernet.org/configuration/)
- [官方 Shadowsocks 入站说明](https://sing-box.sagernet.org/configuration/inbound/shadowsocks/)
- [官方 multiplex 配置说明](https://sing-box.sagernet.org/configuration/shared/multiplex/)
- [P0-1 sing-box 安装实现](../../../vps-init/scripts/sing-box.sh)
- [P0-1 sing-box APT 仓库校验](../../../vps-init/scripts/sing-box-repository.sh)
- [P0-1 服务端诊断](../../../vps-init/doctor.sh)
- [VPS 安全说明](../security.md)
