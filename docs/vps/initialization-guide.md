# VPS 初始化教程

在 Ubuntu 22.04+ 的一次性测试 VPS 中，使用 root 或可无交互 sudo 的账号执行。先确认供应商控制台可用，并保留当前 SSH 会话。

```bash
git clone <your-tu-devkit-remote>
cd tu-devkit/vps-init
cp config/vps.example.yaml config/vps.local.yaml
./install.sh --config config/vps.local.yaml --phase base,firewall --dry-run
./install.sh --config config/vps.local.yaml --phase base,firewall --yes
./doctor.sh --config config/vps.local.yaml
```

编辑 `vps.local.yaml` 后，再分别执行 SSH、WireGuard 和 sing-box 阶段。每次 SSH 变更前，先在第二个终端验证目标端口与管理员公钥；任何失败都应保留当前会话并通过控制台或备份恢复。客户端配置仅从受限输出目录导入，不能提交或通过聊天工具发送。
