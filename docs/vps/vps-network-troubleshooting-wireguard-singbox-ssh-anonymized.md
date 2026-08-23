# VPS 网络故障排查实战：WireGuard / sing-box / SSH 同时不可用

> 场景：RackNerd Ubuntu VPS，作为 WireGuard / sing-box 出口节点使用。  
> 故障表现：上午仍可正常使用，随后 WireGuard、sing-box、SSH 几乎同时不可用。  
> 最终结论：VPS 本身正常，但公网 IP `203.0.113.10` 对中国大陆方向出现明显阻断 / 回程异常；中国大陆多节点 100% 丢包，而香港、日本、美国、欧洲等节点正常。  
> 本文重点沉淀一套可复用的 VPS 网络故障排查 SOP，避免一上来就改配置、重装服务或清空防火墙。

> 脱敏说明：文中的公网 IP 均使用 RFC 5737 文档示例地址替代，不代表真实服务器或客户端地址。

---

## 1. 故障背景

VPS 基础信息：

```text
OS: Ubuntu 22.04
VPS Provider: RackNerd
Public IP: 203.0.113.10
Primary NIC: eth0
WireGuard Interface: wg0
WireGuard Network: 10.66.66.0/24
WireGuard Port: 51820/UDP
sing-box: Shadowsocks
sing-box Port: 8080/TCP
SSH Port: 22/TCP
```

当天故障表现：

- WireGuard 客户端无法握手
- `ping 10.66.66.1` 超时
- sing-box 客户端不可用
- SSH 无法连接 VPS
- VPS 后台 VNC / Console 可以正常进入
- VPS 自身访问公网正常

最容易产生的误判：

> “刚刚改了 WireGuard 配置，然后 SSH 就断了，所以一定是 WireGuard 配置把 VPS 网络搞坏了。”

后续通过抓包证明，这只是时间上高度相关，但不是根因。

---

# 2. 第一原则：先判断“VPS 挂了”还是“网络路径异常”

不要第一时间：

```text
重装 WireGuard
重装 sing-box
iptables -F
nft flush ruleset
重装系统
Change IP
```

优先确认 VPS 自身是否健康。

---

## 3. VPS 基础体检

最初执行：

```bash
uptime
```

确认系统仍然正常运行。

### 3.1 检查网卡与路由

```bash
ip -br addr
```

正常结果：

```text
lo    UNKNOWN  127.0.0.1/8
eth0  UP       203.0.113.10/24
wg0   UNKNOWN  10.66.66.1/24
```

检查路由：

```bash
ip route
```

正常：

```text
default via 203.0.113.1 dev eth0 onlink
10.66.66.0/24 dev wg0
203.0.113.0/24 dev eth0
```

### 3.2 检查 VPS 自身公网访问

```bash
curl -4 --connect-timeout 5 https://icanhazip.com
```

返回：

```text
203.0.113.10
```

再测试：

```bash
ping -c 4 1.1.1.1
```

结果：

```text
0% packet loss
```

说明：

> VPS 自身公网网络正常，不是 VPS 整体断网。

---

# 4. WireGuard 检查

## 4.1 服务状态

```bash
systemctl status wg-quick@wg0 --no-pager -l
```

服务为：

```text
active (exited)
```

这是正常状态。

## 4.2 查看 WireGuard 实际状态

```bash
wg show
```

发现：

```text
listening port: 51820
latest handshake: 11 hours ago
```

说明：

- WireGuard 服务仍然运行
- 但客户端已经很久没有成功握手

---

# 5. 发现一个真实配置问题：WireGuard 端口不一致

检查：

```bash
grep -nE 'ListenPort|PostUp|PostDown' /etc/wireguard/wg0.conf
```

发现：

```ini
ListenPort = 51820

PostUp = iptables -I INPUT -p udp --dport 60273 -j ACCEPT

PostDown = iptables -D INPUT -p udp --dport 60273 -j ACCEPT
```

也就是说：

```text
WireGuard 实际监听：51820
iptables 放行端口：60273
```

这是明确的配置错误。

最终统一为：

```text
51820/UDP
```

修改后重启：

```bash
systemctl restart wg-quick@wg0
```

---

## 5.1 重要经验

这个问题可以解释：

```text
WireGuard 为什么无法握手
```

但不能解释：

```text
SSH 22 为什么也无法连接
sing-box 8080 为什么也异常
临时 TCP 22222 为什么也异常
```

所以：

> 找到一个配置错误，不代表它就是整个故障的根因。

这是本次排查最重要的经验之一。

---

# 6. sing-box 检查

执行：

```bash
systemctl status sing-box --no-pager -l
```

结果：

```text
active (running)
```

监听：

```bash
ss -lntup
```

看到：

```text
0.0.0.0:8080
```

说明 sing-box 正常运行。

日志中出现：

```text
cipher: message authentication failed
```

并且来源是大量陌生公网 IP。

这通常表示：

> 公网扫描器正在探测 Shadowsocks 端口，并使用错误密码 / 协议连接。

它不能直接说明 sing-box 服务坏了。

---

# 7. SSH 无法连接：开始区分“服务问题”和“网络问题”

客户端最初出现：

```text
Connection established
Starting SSH session
Connection closed with error: end of file
```

后来变成：

```text
ssh: connect to host 203.0.113.10 port 22: Connection timed out
```

这时候通过 RackNerd NerdVM VNC 登录服务器。

---

# 8. VNC 侧检查 SSH

## 8.1 sshd 是否监听

```bash
ss -lntp | grep ':22'
```

结果：

```text
0.0.0.0:22
[::]:22
```

说明 SSH 服务确实监听公网。

## 8.2 磁盘是否满

```bash
df -h
```

根目录使用约：

```text
36%
```

排除磁盘满导致 SSH session 无法创建。

## 8.3 SSH 日志

```bash
journalctl -u ssh -f
```

发现大量：

```text
Failed password for root
Invalid user admin
Invalid user kafka
Invalid user harbor
Invalid user aliyun
```

说明公网 SSH 正持续被机器人扫描。

这是公网 VPS 的常见现象。

---

# 9. 防火墙检查

## 9.1 iptables

```bash
iptables -L INPUT -n -v --line-numbers
```

结果：

```text
Chain INPUT (policy ACCEPT)
```

仅有 WireGuard：

```text
ACCEPT udp dpt:51820
```

说明：

> iptables 没有 DROP SSH 22。

## 9.2 nftables

```bash
nft list ruleset
```

结果同样显示：

```text
policy accept
```

没有针对 TCP 22 / 8080 的 DROP。

因此排除：

```text
WireGuard PostUp/PostDown 意外把 SSH 拦掉
```

---

# 10. 最关键的一步：tcpdump 抓 SSH 三次握手

执行：

```bash
tcpdump -ni eth0 tcp port 22
```

然后客户端执行：

```powershell
ssh tu@203.0.113.10
```

抓包发现：

```text
客户端 -> VPS:22      Flags [S]
VPS:22 -> 客户端      Flags [S.]
VPS:22 -> 客户端      Flags [S.]
VPS:22 -> 客户端      Flags [S.]
```

含义：

```text
客户端 SYN        ✅ 到达 VPS
VPS SYN-ACK       ✅ 已从 eth0 发出
客户端 ACK        ❌ 没有回来
```

网络链路表现：

```text
China Client
     |
     | SYN
     v
RackNerd VPS
     |
     | SYN-ACK
     v
Middle Network / Return Path
     X
China Client
```

这是整个排查中最关键的证据。

---

# 11. 检查 VPS 回程路由

执行：

```bash
ip route get 198.51.100.23
```

结果：

```text
198.51.100.23 via 203.0.113.1 dev eth0 src 203.0.113.10
```

说明 VPS 的 Linux 路由选择正常：

```text
VPS -> 默认网关 203.0.113.1 -> 客户端
```

没有异常 policy route。

---

# 12. 排除“只封 SSH 22”：临时 TCP 端口测试

临时启动一个 HTTP Server：

```bash
nohup python3 -m http.server 22222 --bind 0.0.0.0 >/tmp/http22222.log 2>&1 &
```

客户端测试：

```powershell
Test-NetConnection 203.0.113.10 -Port 22222
```

结果：

```text
TcpTestSucceeded : False
```

因此可以排除：

```text
只有 SSH TCP 22 被限制
```

问题扩大为：

```text
这个公网 IP 与中国大陆方向整体通信异常
```

测试结束后关闭：

```bash
pkill -f "python3 -m http.server 22222"
```

---

# 13. 使用 ping.pe 做全球粗筛

访问：

```text
https://ping.pe/<VPS-IP>
```

例如：

```text
https://ping.pe/203.0.113.10
```

结果非常典型。

海外：

```text
美国      0% Loss
加拿大    0% Loss
欧洲      0% Loss
香港      0% Loss
日本      0% Loss
新加坡    0% Loss
台湾      0% Loss
```

中国大陆：

```text
中国电信    100% Loss
中国联通    100% Loss
中国移动    100% Loss
腾讯云      100% Loss
阿里云      100% Loss
```

因此：

> VPS 全球网络正常，但中国大陆方向基本不可达。

---

# 14. RackNerd 官方支持确认

RackNerd 技术支持回复核心内容：

```text
VPS is responding to ping fine.
Network connectivity on our side is up.
It appears to be blocked when accessing from China locations.
```

并给出了两个选择：

```text
1. 等几天，看是否自动恢复
2. Change IP
```

这与本地 tcpdump 和 ping.pe 测试完全吻合。

---

# 15. 最终故障结论

本次故障不是：

```text
❌ VPS 宕机
❌ sshd 崩溃
❌ 磁盘满
❌ iptables 把 SSH 22 DROP
❌ nftables 配置错误
❌ sing-box 挂掉
❌ WireGuard 单独导致 TCP 22 失效
```

存在一个 WireGuard 配置错误：

```text
ListenPort = 51820
防火墙放行 = 60273
```

但这只是独立问题。

真正导致“SSH / WireGuard / sing-box 同时不可用”的核心问题是：

> VPS 公网 IP `203.0.113.10` 对中国大陆方向出现明显的网络阻断 / 回程异常。

更严谨地描述：

```text
中国大陆客户端请求可以抵达 VPS
VPS 回包也从 eth0 发出
但回包无法正常抵达中国大陆客户端
```

具体丢包点无法仅依赖 VPS 判断，可能涉及：

```text
中国运营商国际出口
跨境链路
GFW / 网络过滤
RackNerd 上游运营商
中间 Transit
路由黑洞 / 单向路由异常
```

---

# 16. 推荐的 VPS 网络故障排查 SOP

以后发现：

```text
代理突然不可用
SSH 也异常
```

建议严格按照下面的顺序。

---

## Step 1：先做全球可达性粗筛

使用：

```text
ping.pe
```

重点看：

```text
中国电信
中国联通
中国移动
香港
日本
美国
```

如果出现：

```text
中国大陆全部 100%
海外全部正常
```

不要第一时间修改 VPS 服务。

---

## Step 2：本地裸连接

关闭：

```text
Clash TUN
系统代理
WireGuard
其他 VPN
```

然后：

```powershell
Test-NetConnection VPS_IP -Port 22
```

再：

```powershell
ssh user@VPS_IP
```

SSH 到自己 VPS 通常不需要代理。

---

## Step 3：检查 VPS 自身网络

通过 Provider VNC / Console：

```bash
ip -br addr
```

```bash
ip route
```

```bash
curl -4 https://icanhazip.com
```

```bash
ping -c 4 1.1.1.1
```

---

## Step 4：检查 SSH

```bash
systemctl status ssh
```

```bash
ss -lntp | grep ':22'
```

```bash
journalctl -u ssh -f
```

---

## Step 5：检查防火墙

```bash
iptables -L INPUT -n -v --line-numbers
```

```bash
nft list ruleset
```

不要直接：

```bash
iptables -F
```

也不要直接：

```bash
nft flush ruleset
```

除非已经明确知道影响。

---

## Step 6：tcpdump 是最终裁判

```bash
tcpdump -ni eth0 tcp port 22
```

### 情况 A

```text
客户端 SYN 完全没有到 VPS
```

优先怀疑：

```text
客户端网络
运营商
国际链路
上游网络
```

### 情况 B

```text
SYN 到 VPS
VPS 不回 SYN-ACK
```

优先怀疑：

```text
iptables
nftables
sshd
内核网络栈
VPS 防火墙
```

### 情况 C

```text
SYN 到 VPS
VPS 发 SYN-ACK
客户端没有 ACK
```

优先怀疑：

```text
回程路由
中间网络丢包
运营商过滤
IP / 网段阻断
```

本次事故属于：

```text
情况 C
```

---

# 17. WireGuard 专项排查

检查：

```bash
systemctl status wg-quick@wg0
```

```bash
wg show
```

重点：

```text
listening port
latest handshake
transfer
```

然后：

```bash
grep -nE 'ListenPort|PostUp|PostDown' /etc/wireguard/wg0.conf
```

必须保证：

```text
ListenPort
iptables 放行端口
客户端 Endpoint 端口
```

三者一致。

例如：

```ini
ListenPort = 51820
```

```bash
iptables ... --dport 51820
```

客户端：

```ini
Endpoint = VPS_IP:51820
```

---

# 18. sing-box 专项排查

```bash
systemctl status sing-box
```

```bash
ss -lntup
```

```bash
journalctl -u sing-box -n 100 --no-pager
```

对于：

```text
cipher: message authentication failed
```

先确认来源 IP。

大量陌生公网来源通常只是：

```text
扫描
探测
错误密码连接
```

并不等于 sing-box 服务损坏。

---

# 19. 不要把“时间相关”直接当成“因果关系”

本次最容易误判的是：

```text
执行 WireGuard 命令
↓
几分钟内 SSH 也不能用了
↓
因此一定是 WireGuard 命令导致
```

但最终证据表明：

```text
iptables 正常
nftables 正常
sshd 正常
VPS 正常
TCP SYN 能到
SYN-ACK 能发
中国大陆收不到回包
```

因此：

> 时间上紧邻发生 ≠ 技术上的因果关系。

网络问题尤其容易出现这种误导。

---

# 20. 公网 VPS 安全提醒

本次 SSH 日志中发现大量：

```text
root
admin
kafka
harbor
aliyun
demo
```

的自动扫描 / 密码爆破。

后续建议：

```text
SSH Key Only
禁止 root 密码登录
关闭 PasswordAuthentication
部署 Fail2ban
必要时修改 SSH 端口
```

但注意：

> 修改 SSH 安全策略应在网络稳定后进行，不要在故障排查中一次修改过多变量。

---

# 21. 是否应该删除 WireGuard / sing-box？

本次经验：

```text
不要因为“代理不可用”就立即卸载代理服务。
```

更好的策略：

```text
先停止服务
而不是删除配置
```

例如：

```bash
systemctl stop sing-box
```

或：

```bash
systemctl stop wg-quick@wg0
```

如果停止后问题仍然存在，就可以快速排除。

保留配置可以：

```text
方便恢复
保持现场
减少变量
```

---

# 22. 是否应该立即 Change IP？

建议：

### 短期

等待：

```text
24 ~ 72 小时
```

观察是否自动恢复。

### 长期持续异常

如果：

```text
中国大陆多运营商持续不可达
```

而 VPS 的主要用途就是：

```text
国内设备 -> VPS -> 海外互联网
```

那么这个 IP 的实际价值已经非常低。

此时：

```text
Change IP
```

比继续修改 WireGuard / sing-box 更有效。

---

# 23. 换 IP 后的正确验证顺序

拿到新 IP 后不要立即改一堆东西。

第一步：

```powershell
Test-NetConnection NEW_IP -Port 22
```

第二步：

```powershell
ssh user@NEW_IP
```

第三步：

使用：

```text
ping.pe
```

查看中国大陆三网情况。

确认公网 IP 基础链路正常后，再依次修改：

```text
SSH Config
WireGuard Endpoint
Clash
Shadowrocket
sing-box 客户端
其他设备
```

---

# 24. 一句话经验总结

以后 VPS 的 WireGuard / sing-box / SSH 同时异常时：

```text
先查 IP 是否可达
↓
再查 TCP
↓
再查 VPS 网络
↓
再查防火墙
↓
tcpdump 判断包到底在哪里断
↓
最后才动 WireGuard / sing-box 配置
```

不要一开始就：

```text
重装
删配置
flush 防火墙
```

---

# 25. 快速决策树

```text
VPS 突然无法使用
        |
        v
ping.pe 中国节点是否异常？
        |
   +----+----+
   |         |
  是        否
   |         |
   v         v
先怀疑    Test-NetConnection :22
公网线路       |
             v
        SSH 是否能连接？
             |
        +----+----+
        |         |
       否        是
        |         |
        v         v
     VNC进入    查 WG/sing-box
        |
        v
   sshd 是否监听？
        |
        v
   防火墙是否 DROP？
        |
        v
 tcpdump tcp port 22
        |
        +-----------------------------+
        |              |              |
 SYN不到         SYN到但不回      SYN到且SYN-ACK已发
        |              |              |
 客户端/运营商     VPS内部问题       回程/中间网络问题
```

---

## 附：本次故障最终判断

```text
VPS Provider: RackNerd
VPS IP: 203.0.113.10
VPS Status: Normal
Global Connectivity: Normal
China Mainland Connectivity: Abnormal
China Nodes: Nearly 100% packet loss
Hong Kong / Japan / US: Normal
```

最终：

> **公网 IP 中国大陆方向可达性异常 / 阻断，属于底层网络问题，不是 WireGuard / sing-box 本身的主要故障。**

