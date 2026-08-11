# VPS 网络架构

两条 Profile 复用同一套阶段脚本和配置，不维护两份安装实现。

```mermaid
flowchart TD
  N["全新 Ubuntu"] --> B["base"]
  B --> QF["quick firewall"]
  QF --> S["sing-box TCP + Clash"]
  S --> Q["状态 quick"]
  Q --> SF["secure firewall transition"]
  B --> SF
  SF --> SSH["SSH 双端口密钥认证"]
  SSH --> W["WireGuard + sing-box + Clash"]
  W --> T["状态 secure-transition"]
  T --> V["人工验证目标 SSH"]
  V --> F["finalize"]
  F --> X["状态 secure"]
```

Quick 的公网入站仅有当前 SSH TCP 与 sing-box TCP。Secure 过渡期额外开放目标 SSH TCP 和 WireGuard UDP；完成收口后公网 SSH 保留在目标端口并仅允许密钥认证。sing-box 始终为 TCP-only，Clash 拒绝 UDP/443 后回落 HTTP/2。
