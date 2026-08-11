# VPS 初始化教程

全新 Ubuntu 只需先安装 `ca-certificates` 和 `git`，克隆仓库并复制 `vps-init/config/vps.example.yaml`。详细配置与恢复方式见 [`vps-init/README.md`](../../vps-init/README.md)。

快速验证路线：

```bash
cd tu-devkit/vps-init
./install.sh --profile quick --config config/vps.local.yaml --dry-run
./install.sh --profile quick --config config/vps.local.yaml --yes
./doctor.sh --config config/vps.local.yaml
```

安装即加固路线：

```bash
./install.sh --profile secure --config config/vps.local.yaml --dry-run
./install.sh --profile secure --config config/vps.local.yaml --yes
# 在第二终端验证目标端口的密钥登录后：
./install.sh --profile secure --finalize --verified-ssh --config config/vps.local.yaml --yes
./doctor.sh --config config/vps.local.yaml
```

执行 secure 前必须具备供应商控制台/恢复入口并保留当前 SSH 会话。Quick 可以随时按 secure 命令原地升级。
