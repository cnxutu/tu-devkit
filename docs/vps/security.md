# VPS 安全说明

- SSH 加固前必须已有管理员公钥、目标端口的 UFW 放行和备用登录会话；候选配置通过 `sshd -t` 才会重载。
- UFW 默认拒绝入站。WireGuard 与 sing-box 端口只在对应功能启用时放行。
- WireGuard 私钥、sing-box 密码、生成的客户端 `.conf` 与 Clash YAML 只保存在受限权限目录，不能进入 Git、日志或终端输出。
- 执行日志默认在 `/var/log/tu-devkit-vps-init/`；分享前必须人工脱敏。
- 删除客户端会撤销相应 peer；服务器密钥轮换和 VPS 失陷后的处置仍需管理员按事件流程手动完成。
