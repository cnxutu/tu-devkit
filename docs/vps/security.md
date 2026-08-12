# VPS 安全说明

## 路线边界

- Quick 保留供应商现有 SSH 端口和认证方式，但仍启用 UFW 最小入站与当前 SSH 端口的 Fail2ban。
- Secure 在修改 SSH 前检查管理员公钥、当前监听端口、公网端点和恢复入口；Prepare 保留当前/目标端口，Finalize 必须显式传入 `--verified-ssh`。
- UFW 规则带模块注释并记录所有权；Finalize 只删除模块创建的旧 SSH 过渡规则，不清空或删除用户规则。
- SSH、Fail2ban 与 sing-box 配置先备份和校验，失败时恢复模块管理的上一版本。

## Remote Profile 的秘密边界

- Remote 必须依赖 WireGuard，只绑定 WG 服务端私网地址。
- 防火墙只添加 `in on wg0` 规则，禁止为公网接口开放 Remote TCP 端口。
- 禁止以公网明文 HTTP 提供订阅；公网 HTTPS 是后续独立能力，不在第一版范围内。
- 禁止暴露 Clash Controller、External UI 或管理 API。
- URL 中的随机 token 等同凭据。URL/token 只写入权限 `600` 的状态文件，不进入安装日志；仅通过 `sudo ./show-clash-remote-url.sh` 显式查看。
- HTTP 服务只响应精确 token 路径，关闭请求日志和目录浏览。错误路径统一返回 404。
- Remote 发布的 YAML 与本地 `output/vps-clash.yaml` 来自同一模板，不额外生成弱化安全选项的配置。

## 密钥、来源与运维

- WireGuard 私钥、sing-box 密码、客户端配置、Clash YAML 与 Remote URL/token 只保存在受限目录，不写入 Git、聊天或日志。
- sing-box 使用官方 SagerNet APT stable 源并固定校验 GPG 指纹，不执行 `curl | sh`。
- 云厂商安全组、DNS、TLS 和控制台权限由管理员在脚本外维护。
- 排错时优先运行 `doctor.sh`。WG 断开导致 Remote 刷新失败是预期隔离效果，不应通过临时开放公网端口绕过。
