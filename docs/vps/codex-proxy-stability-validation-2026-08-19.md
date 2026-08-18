# Codex 代理稳定性修复与验证报告

验证时间：2026-08-18 23:49 至 2026-08-19 00:26（Asia/Shanghai）

## 结论

本次问题由配置链路中的多个偏差共同放大，不是单一的 VPS 出口网络故障：

1. `D:\vps\company-vps.yaml` 已更新，但 Clash Verge 当前 Profile 仍是旧副本，源文件和实际运行配置不一致。
2. sing-box 服务端 multiplex 使用 `padding: true`，客户端候选配置使用 `padding: false`。sing-box 文档明确说明，服务端启用 padding 后会拒绝未 padding 的 multiplex 连接。
3. VPS 没有 IPv6 默认路由，但 sing-box 未限制域名解析策略；日志中存在 IPv6 目标的 `cannot assign requested address`。
4. WireGuard 只在 VPS 端存在，Windows 没有对应客户端服务、私网路由或近期握手，不能作为可用代理入口。
5. Clash Verge 2.5.2 的应用级设置覆盖了 Profile：实际端口为 7897、IPv6 原为启用、TUN 为关闭，而且新版使用命名管道而非默认 REST Controller。
6. 对 Codex 长流式请求启用 `h2mux` 后延迟更低，但观察到模型刷新超时、WebSocket 建连失败和响应重试。回退普通 Shadowsocks TCP 后，硬错误消失，因此最终以稳定性优先，不启用客户端 `smux`。

最终状态：服务端配置有效且服务正常；客户端实际运行配置与源 Profile 一致；Codex 已确认连接本机 7897；WireGuard 不参与 AI 路由；端到端探测全部成功。当前方案是本次环境中“经过验证的稳定性最优解”，不是理论上的最低单请求延迟配置。

## 已实施变更

### 服务端 sing-box

- 保留 Shadowsocks 2022 TCP-only。
- multiplex 入站保持启用，以兼容支持该能力的客户端。
- `padding` 固定为 `false`，允许普通 TCP 和非 padding multiplex 客户端。
- DNS 与默认域名解析策略固定为 `ipv4_only`，与 VPS 的实际路由能力一致。
- 配置经 `sing-box check` 验证后重启服务。
- 变更前配置备份：`/etc/sing-box/config.json.pre-codex-stability-20260818T154950`。

### Clash Verge Rev 2.5.2

- 将 `D:\vps\company-vps.yaml` 部署到当前 Profile，而不是只修改未加载的源文件。
- 实际运行配置：Rule 模式、IPv6 关闭、TCP keepalive interval/idle 为 15 秒、keepalive 未禁用。
- AI 组不含 `DIRECT`，当前只选择公网 Shadowsocks 节点。
- WireGuard 节点定义仍可保留供以后恢复，但不在 AI 组成员中，不会被选择或参与健康检查。
- 客户端不启用 `smux/h2mux`，避免一个复用连接迁移同时影响模型刷新、WebSocket 和流式响应。
- TUN 保持关闭，使用 Clash Verge 系统代理；运行时连接表确认 `codex`、ChatGPT 和 Chrome 均连接本机 7897。
- 最终 Profile 变更前备份：`LFQTUtILnNvE.yaml.pre-no-smux-20260819T000937`。

### 仓库防回归

- 模板和生成器支持仅在 WireGuard 实际启用时生成 WG 节点。
- sing-box 安装脚本写入 IPv4 resolver 和兼容的 multiplex/padding 配置。
- `doctor.sh` 增加 multiplex、padding、DNS 与 route 稳定性检查。
- Clash 运行时检查器支持 REST Controller；Controller 不可用时，安全回退检查 Clash Verge 合并后的 `clash-verge.yaml`，不读取或输出节点密码。
- 测试阻止 Codex Profile 再次启用 `smux/h2mux`。

## WireGuard 判定

| 检查项 | 结果 |
| --- | --- |
| Windows WireGuard 应用/服务 | 未安装或未运行 |
| Windows 私网路由 | 不存在 |
| 私网代理入口 | 不可达 |
| VPS `wg0` | 已启动 |
| VPS peer 最近握手 | 约 15.2 天前 |
| 最终 AI 路由 | 仅公网 Shadowsocks |

结论：当前 WireGuard 不是一条可用客户端链路。把它放进 fallback 只会引入失败探测和切换延迟，因此已从实际 AI 组中排除。将来只有在 Windows WireGuard 安装完成、出现近期握手并通过私网 8080 探测后，才应重新加入。

## 测试结果

### 服务端

| 项目 | 结果 |
| --- | --- |
| `systemctl is-active sing-box` | active |
| `sing-box check` | pass |
| 服务端直连 ChatGPT IPv4 | 10/10 成功，75.8–100.8 ms |
| 重启后 IPv6 `cannot assign requested address` | 0 |
| 客户端复测期间 dial/route/timeout/reset/multiplex 错误 | 0 |

复测期间 systemd 记录过 1 条孤立 ERROR，但它不属于 dial、route、IPv6、timeout、reset、TCP read/write 或 multiplex 类别，也没有对应的客户端探测失败。报告不把它解释为已证明的代理故障；公网端口可能持续收到非代理协议探测，应结合后续日志趋势观察。

### 客户端运行时

| 项目 | 结果 |
| --- | --- |
| Profile 源文件与活动文件 SHA-256 | 一致 |
| Mihomo 配置检查 | pass |
| mixed port | 7897，监听正常 |
| Rule / IPv6 / keepalive | rule / false / 15s |
| 客户端 `smux` | 未启用 |
| AI 组 `DIRECT` | 不存在 |
| AI 组 WireGuard 成员 | 不存在 |
| Codex 是否实际连接 7897 | 是 |

### 端到端代理探测

普通 Shadowsocks TCP 最终配置：

| 目标 | 成功率 | 预期状态 | 平均 | P95 | 最大 |
| --- | ---: | --- | ---: | ---: | ---: |
| ChatGPT favicon | 30/30 | 403 | 658 ms | 1112 ms | 1293 ms |
| Codex backend 路由 | 10/10 | 405 | 685 ms | 1363 ms | 1363 ms |
| OpenAI API | 10/10 | 401 | 677 ms | 834 ms | 834 ms |

这些 401/403/405 是未携带业务认证或使用探测方法时的预期应用状态；它们证明 DNS、TCP、Shadowsocks、TLS 和目标路由已完整建立，不代表业务认证失败。

### h2mux A/B 结论

`h2mux` 的 30 次 ChatGPT 探测平均约 461 ms、P95 约 737 ms，明显低于普通 TCP；但同一观察阶段出现 2 次模型刷新超时、1 次 WebSocket 建连失败，以及响应自动重试。普通 TCP 在 22.9 分钟观察中：

- 模型刷新 ERROR：0
- WebSocket ERROR：0
- 全部 Codex ERROR：0
- 流读取自动重试日志：28 条；均被客户端恢复，当前任务没有终止或丢失响应

因此没有为了约 200 ms 的探测延迟收益保留 h2mux。当前剩余的流读取重试没有对应服务端网络错误，可能包含 Codex/OpenAI 应用层或公网瞬时抖动，不能仅凭本次证据归因于 VPS。

## 自动化验证

- `vps-init/tests/test-*.sh`：8/8 通过。
- 修改脚本 `bash -n`：通过。
- 修改脚本 ShellCheck：通过。
- PowerShell 运行时检查器语法解析：通过。
- PowerShell 运行时检查器在 Clash Verge 2.5.2 命名管道模式：通过。
- `git diff --check`：通过。

## 剩余边界与建议

1. VPS 的 UFW 当前未启用。这是安全暴露面，不是本次延迟根因；未经单独防锁死方案验证，不在本次变更中直接开启。
2. BBR 未启用。VPS 出口测试稳定，当前没有证据证明切换内核拥塞控制能改善 Codex 长流，因此不做系统级实验性变更。
3. TUN 当前关闭。Codex 已被实测走系统代理；若未来出现某个应用绕过系统代理，再单独启用并验证 TUN，而不是为了本次问题增加接管复杂度。
4. 若要恢复 WireGuard，必须先完成 Windows 客户端安装、近期握手、路由和私网代理探测四项验收。
5. 代理无法保证消除 OpenAI 服务端或公网的所有短时重试；验收目标是消除配置性失败、保证重试可恢复并避免终端失败。

## 参考

- sing-box multiplex：<https://sing-box.sagernet.org/configuration/shared/multiplex/>
- sing-box Shadowsocks inbound：<https://sing-box.sagernet.org/configuration/inbound/shadowsocks/>
- sing-box dial / resolver：<https://sing-box.sagernet.org/configuration/shared/dial/>
- Mihomo general configuration：<https://wiki.metacubex.one/en/config/general/>
- OpenAI Codex configuration reference：<https://learn.chatgpt.com/docs/config-file/config-reference>
