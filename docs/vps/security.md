# VPS 安全说明

- Quick 是快速验证路线，但仍启用 UFW 最小入站和当前 SSH 端口的 Fail2ban；它不会改变现有 SSH 认证方式。
- Secure 在修改 SSH 前检查管理员公钥、当前监听端口、公网端点，并要求确认供应商恢复入口可用。
- SSH prepare 同时保留当前/目标端口，候选配置通过 `sshd -t` 才重载；finalize 必须显式传入 `--verified-ssh`。
- UFW 规则带模块注释并记录所有权；finalize 只删除模块创建的旧 SSH 过渡规则，不清空或删除用户规则。
- Fail2ban、SSH、sing-box 配置变更前备份，校验失败恢复模块上一版本。
- WireGuard 私钥、sing-box 密码、客户端配置和 Clash YAML 只保存在受限目录，不写入 Git 或日志。
- sing-box 使用官方 APT stable 源并固定核对 GPG 指纹，不执行 `curl | sh`。
- 云厂商安全组、DNS、TLS 和控制台权限由管理员在脚本外维护。
