# VPS 初始化

`vps-init` 用同一套底层脚本提供两条安装路线：`quick` 用于从 0 到 1 快速验证代理，`secure` 在安装过程中完成常规安全加固。它独立于 `dev-env-init`，不会被 `tu init` 自动调用。

## 从全新 Ubuntu 开始

仅需先手动安装 Git 和 CA 证书，然后克隆仓库：

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates git
git clone <your-tu-devkit-remote>
cd tu-devkit/vps-init
cp config/vps.example.yaml config/vps.local.yaml
```

编辑 `vps.local.yaml`，至少设置：

- `server.public_endpoint`：VPS 公网 IP 或域名，供 WireGuard 和 Clash 共用；
- `ssh.current_port`：供应商当前实际监听的 SSH 端口，通常为 `22`；
- `ssh.port`：secure 路线最终使用的 SSH 端口；
- `ssh.admin_authorized_keys_path`：secure 路线使用的非 root 管理员公钥文件；默认安全策略会禁用 root 登录。

真实端点、密码、私钥、`vps.local.yaml` 和 `output/` 均不得提交到 Git。

## 路线一：Quick

```bash
./install.sh --profile quick --config config/vps.local.yaml --dry-run
./install.sh --profile quick --config config/vps.local.yaml --yes
./doctor.sh --config config/vps.local.yaml
```

执行顺序为 `base → firewall → sing-box → clash`。它会启用默认拒绝入站的 UFW，只放行当前 SSH TCP 端口和 sing-box TCP 端口，并用 Fail2ban 保护当前 SSH 端口。

Quick 不修改 sshd 配置、不迁移 SSH 端口、不禁用密码认证、不安装 WireGuard。后续可直接执行 secure 路线升级。

## 路线二：Secure

开始前确认供应商 Web/Serial Console 或恢复入口可用，且管理员公钥已经安装。保留当前 SSH 会话不要关闭。

```bash
./install.sh --profile secure --config config/vps.local.yaml --dry-run
./install.sh --profile secure --config config/vps.local.yaml --yes
./doctor.sh --config config/vps.local.yaml
```

Prepare 阶段会：

- 同时放行并监听当前/目标 SSH 端口，禁用密码认证和 root 登录；
- 用 Fail2ban 同时保护两个 SSH 端口；
- 安装 WireGuard、sing-box，生成 Clash 配置；
- 写入 `secure-transition` 状态，保留旧 SSH 防火墙规则。

使用第二个终端通过目标端口完成一次密钥登录。确认成功后才能收口：

```bash
./install.sh --profile secure --finalize --verified-ssh --config config/vps.local.yaml --yes
./doctor.sh --config config/vps.local.yaml
```

`--yes` 不能替代 `--verified-ssh`。Finalize 只保留目标 SSH 配置，Fail2ban 切到目标端口，并且只删除状态中记录、由本模块创建的旧端口过渡规则。用户已有 UFW 规则不会被删除。若当前端口与目标端口相同，prepare 会直接形成 `secure` 状态，无需 finalize。

## 状态与诊断

状态、模块拥有的 UFW 规则、备份和已安装 sing-box 版本保存在 `/var/lib/tu-devkit-vps-init/`，采用原子写入。日志位于 `/var/log/tu-devkit-vps-init/`，分享前需脱敏。

`doctor.sh` 默认读取状态，也可显式检查：

```bash
./doctor.sh --profile quick --config config/vps.local.yaml
./doctor.sh --profile secure-transition --config config/vps.local.yaml
./doctor.sh --profile secure --config config/vps.local.yaml
```

过渡状态会输出下一条 finalize 命令。SSH、Fail2ban 和 sing-box 配置均先备份、再校验；校验失败会恢复模块管理的上一版本。SSH 异常时优先使用仍保持连接的会话或供应商控制台恢复，不要继续叠加网络变更。

## 安装源与兼容入口

脚本从 sing-box 官方 SagerNet APT stable 仓库安装，固定校验官方 GPG 指纹 `2C317FBD5D886B4E89BAE8DA6D9152172A2B2F0C`，不执行 pipe-to-shell 安装器。

高级用户仍可使用 `--phase`。该模式继续遵循 `wireguard.enabled` 和 `sing_box.enabled`；Profile 模式的能力由 Profile 固定，不依赖这两个旧开关。`SING_BOX_ENDPOINT` 和旧 `wireguard.endpoint` 仍是兼容回退，新配置统一使用 `server.public_endpoint`。`--profile` 与 `--phase` 互斥；不指定其中任何一个时只显示帮助，不修改服务器。

## Clash TCP-only 说明

当前 Shadowsocks 2022 节点只提供 TCP，节点配置保持 `udp: false`，服务端和 UFW 不开放 sing-box UDP。Clash 模板在业务规则之前拒绝 UDP/443，使浏览器的 QUIC 尝试立即失败并快速回落到 HTTP/2/TCP。

生成文件位于 `output/vps-clash.yaml`，权限为 `600`。仓库模板更新不会自动覆盖 Clash Verge 已导入的配置，必须重新运行安装/生成脚本并在 Clash Verge 中重新导入或重载。

## 开发验证

```bash
bash vps-init/tests/run.sh
bash -n vps-init/*.sh vps-init/lib/*.sh vps-init/scripts/*.sh vps-init/tests/*.sh
shellcheck vps-init/*.sh vps-init/lib/*.sh vps-init/scripts/*.sh vps-init/tests/*.sh
```

真实 VPS 仍需分别验证 quick、secure、quick→secure，云厂商安全组、DNS、TLS 证书和 VPS 采购不由脚本修改。
