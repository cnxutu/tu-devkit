# Clash Remote Profile 教程

Remote Profile 让 Clash Verge 通过 WireGuard 私网读取 VPS 生成的完整 Clash YAML。它只解决“配置交付与更新”，不会远程控制 Clash，也不会改变 Shadowsocks TCP 业务链路。

## 1. 配置服务器

Quick 必须同时开启 WG 与 Remote；Secure 固定启用 WG：

```yaml
wireguard:
  enabled: true
  client_mode: management
clash_remote:
  enabled: true
  port: 18080
  update_interval_hours: 24
```

`management` 是 Remote 客户端的推荐模式，只把 WG 私网 CIDR 路由进隧道。若需要旧的全隧道行为，改为 `full`。

执行对应 Profile 安装并检查：

```bash
./install.sh --profile quick --config config/vps.local.yaml --dry-run
./install.sh --profile quick --config config/vps.local.yaml --yes
./doctor.sh --config config/vps.local.yaml
```

## 2. 生成并连接 WG 客户端

```bash
sudo ./scripts/wg-add-client.sh laptop
```

安全取回生成的客户端配置，在 Windows WireGuard 客户端导入并连接。`management` 配置中的 `AllowedIPs` 应等于 `wireguard.address` 的私网 CIDR，而不是 `0.0.0.0/0`。

## 3. 获取并导入订阅

只有这条显式命令会显示敏感 URL：

```bash
sudo ./show-clash-remote-url.sh
```

保持 WG 已连接，在 Clash Verge 的配置/订阅页面新增 Remote Profile，粘贴 URL 并立即刷新。服务响应会携带 `Profile-Update-Interval`，值来自 `update_interval_hours`；也可以随时手动刷新。

不要把 URL 放入命令历史之外的脚本参数、工单、截图、群聊或可集中采集的日志。怀疑泄漏时应视为凭据泄漏并重新部署 token，而不是仅隐藏旧消息。

## 4. 验收

```bash
./doctor.sh --config config/vps.local.yaml
```

同时确认：

- Clash Verge 能首次下载并手动刷新。
- 配置中的 `chatgpt.com`、`cdn.openai.com` 命中 VPS 节点。
- VPS 公网接口没有 Remote 端口规则；仅有带模块注释的 `wg0` 规则。
- 断开 WG 后刷新失败，重新连接后恢复；这是正确的私网隔离行为。

## 5. 排错顺序

1. 确认 Windows WireGuard 隧道已连接且能访问 WG 服务端私网地址。
2. 运行 `doctor.sh`，检查 `wg-quick@wg0`、Remote systemd 服务、私网监听、UFW 与文件权限。
3. 确认 Clash Verge 保存的是最新的完整 URL，未遗漏 token 或文件名。
4. 检查配置端口是否与 SSH、sing-box 或其他私网服务冲突。
5. 不要为排错开放公网 HTTP、Controller 或管理 UI。

已有本地导入配置不会自动转换为 Remote；需要在 Clash Verge 中新增订阅。关闭 `clash_remote.enabled` 也不会自动卸载已运行服务，以免配置切换造成意外中断。
