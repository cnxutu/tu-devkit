# VPS 初始化教程

## 共同准备

在全新 Ubuntu 上执行：

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates git
git clone <your-tu-devkit-remote>
cd tu-devkit/vps-init
cp config/vps.example.yaml config/vps.local.yaml
```

编辑 `config/vps.local.yaml`，填写 `server.public_endpoint`、当前/目标 SSH 端口、管理员公钥路径与 sing-box 参数。先执行 `--dry-run`，确认阶段和端口符合预期后再执行 `--yes`。

## 路径 1：Quick + 本地 YAML

配置：

```yaml
wireguard:
  enabled: false
clash_remote:
  enabled: false
```

命令：

```bash
./install.sh --profile quick --config config/vps.local.yaml --dry-run
./install.sh --profile quick --config config/vps.local.yaml --yes
./doctor.sh --config config/vps.local.yaml
```

安全复制 `output/vps-clash.yaml` 到 Windows，在 Clash Verge 中以本地配置导入。

## 路径 2：Quick + WG + 本地 YAML

设置 `wireguard.enabled: true`，Remote 保持关闭，执行路径 1 的三条命令。然后生成 WG 客户端：

```bash
sudo ./scripts/wg-add-client.sh laptop
```

`client_mode: full` 会生成 `AllowedIPs = 0.0.0.0/0`；`management` 只生成配置的 WG 私网 CIDR。Clash YAML 仍按本地文件导入。

## 路径 3：Quick + WG + Remote

配置：

```yaml
wireguard:
  enabled: true
  client_mode: management
clash_remote:
  enabled: true
  port: 18080
  update_interval_hours: 24
```

执行路径 1 的安装与 doctor 命令，再生成客户端并连接 WG：

```bash
sudo ./scripts/wg-add-client.sh laptop
sudo ./show-clash-remote-url.sh
```

将最后一条命令显示的 URL 新增为 Clash Verge Remote Profile。URL 是凭据，不要粘贴到工单、群聊、截图或日志。详细导入和排错见 [Remote Profile 教程](clash-remote-profile.md)。

## 路径 4：Secure + Remote

Secure 固定安装 WireGuard，`wireguard.enabled: false` 不会关闭它。设置 `clash_remote.enabled: true`，确认供应商控制台/恢复入口和非 root 管理员公钥可用，并保持当前 SSH 会话：

```bash
./install.sh --profile secure --config config/vps.local.yaml --dry-run
./install.sh --profile secure --config config/vps.local.yaml --yes
./doctor.sh --config config/vps.local.yaml
```

在第二终端通过目标 SSH 端口完成一次密钥登录，然后：

```bash
./install.sh --profile secure --finalize --verified-ssh --config config/vps.local.yaml --yes
./doctor.sh --config config/vps.local.yaml
sudo ./scripts/wg-add-client.sh laptop
sudo ./show-clash-remote-url.sh
```

## 升级与恢复

Quick 可随时按 Secure 命令原地升级。能力状态采用并集记录；关闭配置开关不会自动卸载已安装的 WG 或 Remote 服务。若 SSH 加固异常，保留现有会话并从供应商控制台恢复，不要继续叠加网络改动。若 Remote 异常，先确认 WG 已连接，再运行 `doctor.sh`，不要为排错临时开放公网订阅端口。
