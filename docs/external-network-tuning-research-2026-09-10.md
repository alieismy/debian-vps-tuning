# 外部网络调优项目研究与 rc.16 吸收评估

研究日期：2026-09-10（Asia/Singapore）
研究模式：`rd-research` 技术与开源研究 + 配置与基础设施研究
研究对象：

- [Kylin010/tcpfit](https://github.com/Kylin010/tcpfit)
- [sanmussh/vps-netpilot](https://github.com/sanmussh/vps-netpilot)
- [bear4f/netshape-manager](https://github.com/bear4f/netshape-manager)

## 研究问题与停止条件

本研究只回答三个问题：

1. 三个项目实际实现了哪些网络调优、观测、整形、安装和回滚机制？
2. 哪些机制与本仓库 `v0.1.0-rc.16` 的单 VPS、可验证、可回滚和预算受控边界相容？
3. 哪些内容只能作为实验假设，哪些内容应拒绝吸收？

停止条件是：每个项目至少检查当前 `main` 或当前 tag 的仓库元数据、README、主要脚本、测试入口和关键实现；对主要结论给出固定 commit、源码位置、证据层级和适用限制。本轮不执行第三方 root 脚本，不连接目标 VPS，不运行公网 `iperf3`，不修改项目运行参数。

本仓库的比较基线是 [设计范围](design-scope.md)、[验证说明](validation.md)、`tools/profile-template.sh.in` 和当前 `docs/releases/v0.1.0-rc.16.md`：Debian 12/13 amd64 的四个资源档、17 项受管 sysctl、资源感知 BDP 缓冲、根 `fq`、非持久 HTB 研究面、事务状态/所有权、共享流量 ledger，以及将静态、fixture、Linux root、目标 VPS、业务和性能证据分层。该基线不支持通用 UDP 调参、RPS/RFS、MSS Clamp、`initcwnd/initrwnd`、CAKE、永久 HTB 或第三方内核。

## 来源冻结与可复现记录

GitHub API 在 2026-09-10 查询到：

| 项目 | 来源状态 | 固定来源 | 许可证 | 主要脚本 SHA-256 |
|---|---|---|---|---|
| `tcpfit` | `v0.5.7` tag 与 `main` 同指向 | `1163c20e88a4a7130ef7d885da8be3a163505003` | MIT | `tcpfit.sh` = `704c9f284cb60a76e8ee3c54d69e0d87fca28178e23ea1e93c0641fd6281ce79` |
| `vps-netpilot` | `main`，无 tag | `705a307684b7b0cb57747bf2e5abb4ed6ada6cdd` | MIT | `tcp.sh` = `0a3bc8708372373d931949e3ea3d9f7d9ee4d71079315b01ec2e4bd2301c868f` |
| `netshape-manager` | `main`，无 tag | `647b454b934349a179b1db289518eb9280adc839` | MIT | `netshape-manager.sh` = `a038d6e6213d7bf5fcd770323aeab250e5e35e334277b414a4e2340312389bc3` |
| `netshape-manager/peertune` | 与 NetShape 同一 commit | `647b454b934349a179b1db289518eb9280adc839` | MIT | `peertune.sh` = `f381a3365bb1d99c347a27d6a10d948a2c434f79e7c7d7a1fbe2e02abdd578f4` |

GitHub 提供的提交验证元数据显示：tcpfit 当前提交为 unsigned，NetPilot 和 NetShape 当前提交分别显示为 verified。该字段只说明 GitHub 对提交签名的识别状态，不证明脚本安全、作者身份、运行效果或性能；本研究仍以固定字节、源码和测试证据为主。

复现入口：

- [tcpfit 固定 commit](https://github.com/Kylin010/tcpfit/tree/1163c20e88a4a7130ef7d885da8be3a163505003)
- [NetPilot 固定 commit](https://github.com/sanmussh/vps-netpilot/tree/705a307684b7b0cb57747bf2e5abb4ed6ada6cdd)
- [NetShape 固定 commit](https://github.com/bear4f/netshape-manager/tree/647b454b934349a179b1db289518eb9280adc839)

本地复核结果：三个主脚本均通过 `bash -n`；NetShape `tests/self-test.sh` 全部断言通过，`peertune/tests/self-test.sh` 报告 `All peertune self-tests passed.`。tcpfit 和 NetPilot 没有随快照提供等价的运行时自检套件；这些结果只证明语法或合成 fixture，不证明目标 VPS 生效、持久性、业务链路或性能改善。

## 项目一：tcpfit

### 实际功能

README 将工具定位为按机器测量 BDP 和 policer 拐点的单机 TCP 调优器。当前脚本版本为 `0.5.7`，提供 `detect`、`probe`、`tune`、`sweep`、`shape`、`harden`、`verify`、`status`、`rollback`、归档和卸载；多机 `fleet.py` 仍在 README 中标为“未上线、未在真实环境验证”。主要实现位置见 [`tcpfit.sh`](https://github.com/Kylin010/tcpfit/blob/1163c20e88a4a7130ef7d885da8be3a163505003/tcpfit.sh)：

- 使用 `flock` 串行化调优、扫描、归档和 qdisc 操作；扫描子进程在中断时尝试 `TERM` 后 `KILL`，并清理脚本拥有的 `iperf3`/`timeout` 进程（约 L79-L123、L1943-L1985）。
- 用 `TUNED_KEYS` 明确列出需要快照和回滚的 sysctl；当前列表是 32 项，包含拥塞控制、缓冲、队列、连接回收、端口范围、`vm.min_free_kbytes`、`fs.file-max` 和 `vm.swappiness`（约 L656-L693）。
- 默认 RTT 是固定 `150 ms`，可由 `--rtt` 覆盖；缓冲目标约为 `2 × BDP + 2 MiB`，再受内存 `/32`、256 MiB 上限和 4 MiB 下限约束（约 L460-L485、L541-L595）。这不是无条件的“每台机器实测 RTT”。
- `sweep` 先用不整形流量建立基线，再根据 receiver goodput、sender retransmission 比例和重复采样的 loss spike 判断候选 policer knee；结果有 `NO_KNEE`、`OUT_OF_RANGE`、`ABOVE_CAP` 等终态（约 L2057-L2543）。扫描会按带宽放大时长和档数，脚本自身只做流量估算和提示。
- 正确区分 `fq maxrate` 的单流上限与 HTB 聚合上限，整形路径是 HTB 根加 `fq` 叶子（约 L1680-L1920）。它还处理 `mq` 叶子、根 qdisc 替换和扫描后恢复。
- 第一次调优前保留最早快照，并在 0.5.7 增加归档、出厂状态、重名阻断和卸载保留归档选项（约 L888-L1022、L1239-L1331）。

### 可吸收内容

| 机制 | 评价 | 与 rc.16 的关系 | 分类 |
|---|---|---|---|
| 操作锁、拥有进程清理、qdisc 恢复路径 | 实现细节有工程价值，能减少并发和中断遗留 | rc.16 已有 lock、进程组硬超时、`INCOMPLETE` 和完整 qdisc 语义恢复；可作为回归样本 | 已覆盖/仅借鉴测试思路 |
| receiver goodput、重传比例、重复 loss-spike 确认 | 比单看 sender bitrate 更接近“有效吞吐”和路径异常，但仍无法单独归因 provider policer | 可放入 HTB 研究分析器或实验笔记；必须沿用固定 endpoint、方向、窗口、预算和 A/B/A | 条件实验 |
| `NO_KNEE`/越界/超过扫描上限等显式终态 | 防止把没有找到拐点误写成推荐值 | rc.16 的 reference/sweep 已有 `REVIEW_REQUIRED`、`REVIEW_BLOCKED` 和候选窗口门禁；可做语义对照 | 已覆盖/不改默认行为 |
| `fq` 单流与 HTB 聚合的语义分离 | 关键机制判断正确 | rc.16 的 HTB 文档和 runner 已明确同一边界 | 已覆盖 |
| 最早快照、归档和 legacy 迁移提示 | 对交互式单机工具有用 | rc.16 的 schema 4、所有权、哈希、事务回滚更严格；增加归档会扩大状态/迁移面 | 暂不吸收 |

### 不应吸收的内容

- 32 项 sysctl 不是本项目的“更完整版本”。其中 `tcp_slow_start_after_idle=0`、`tcp_tw_reuse=1`、`tcp_fin_timeout=15`、`netdev_budget*`、`vm.min_free_kbytes`、`fs.file-max`、端口范围和 `initcwnd/initrwnd=32` 会扩大所有权、兼容性和回滚面；rc.16 已明确保持 17 项受管 sysctl。
- `initcwnd/initrwnd` 是默认路由属性，不是单纯 sysctl。tcpfit 通过路由替换和 networkd dispatcher hook 写入它（约 L412-L460、L1589-L1612）；这会改变默认路由语义，并不适用于当前单一默认路由之外的策略路由、VRF 或多 WAN。
- 其 qdisc 快照主要保存 `tc qdisc show` 的首行文本（约 L904-L911、L1004-L1008），不能达到 rc.16 `tc -j` 数值快照、恢复命令和后置语义比较的完整性门槛。
- `estimate_traffic_gb` 只是显示预估（约 L625-L641），没有 rc.16 的原子 reservation/ledger、未知量保守结算和失败保留机制；不能用来替换 `dvt-traffic-budget.sh`。
- 公共测速对端、自动 sweep 和“检测到 policer”的结论受端点、路径、CPU/steal、虚拟交换机和共享带宽影响。README 或维护者提交中的吞吐/重传数字是维护者声明，不是本轮复现的目标机因果证据。

## 项目二：vps-netpilot

### 实际功能

NetPilot 是单文件交互面板，当前 `main` 没有版本 tag。它把功能分为 IPv4 优先解析、BBR+FQ、普通调优、中转增强和 RPS/RFS，脚本可将自身和后续更新直接下载到 `/usr/local/bin/tcp.sh`（[安装/更新代码](https://github.com/sanmussh/vps-netpilot/blob/705a307684b7b0cb57747bf2e5abb4ed6ada6cdd/tcp.sh#L35-L69)）。

- IPv4 优先通过修改 `/etc/gai.conf` 的 `precedence ::ffff:0:0/96`，首次备份为 `/etc/gai.conf.bak`（约 L97-L127）。这是名称地址选择策略，不是路由、出口或业务链路证明。
- BBR+FQ 写入两个 sysctl drop-in，并只检查当前拥塞控制和默认 qdisc；代码按内核版本 `>=6.12` 输出“BBRv3”（约 L131-L168），这一推断不作为本项目事实依据。
- 普通/中转调优按总内存约 5% 计算 TCP/UDP 缓冲，范围 4–256 MiB；同时写入 UDP buffer、conntrack、`somaxconn=65535`、`netdev_max_backlog=65535`、`tcp_tw_reuse`、`tcp_fin_timeout`、ECN、MTU probing、端口范围和文件句柄等（约 L246-L365）。中转模式另写 IPv4/IPv6 forwarding 和 iptables TCPMSS clamp（约 L352-L385）。
- RPS/RFS 菜单把所有 RX 队列分配到全部 CPU、设置每队列流表 4096 和全局 `rps_sock_flow_entries=32768`；README 明确它不持久化（约 L420-L485）。
- “回退”只保存拥塞控制、默认 qdisc 和两项 forwarding 值；删除 drop-in 后直接写回这些值、清理 RPS 和 MSS 规则，并将缺失状态时的默认值设为 `cubic`/`fq_codel`（约 L178-L197、L493-L540）。

### 可吸收内容

| 机制 | 评价 | 分类 |
|---|---|---|
| 普通与中转模式分开呈现 | 有助于提醒用户 forwarding/MSS 只属于转发拓扑 | 当前项目不是通用转发器；可作为文档边界示例，不进入 profile |
| 模块能力检查、sysctl 加载后读取运行值 | 是低成本的只读验证模式 | rc.16 已有更完整的文件/运行值、所有权和状态验证，可不复制实现 |
| 对 RPS/RFS、MSS、IPv4 优先的显式菜单 | 让高风险动作至少显式可见 | 不构成机制有效性证据；本项目继续只读诊断、不写入这些项 |

### 明确拒绝

- 可变 `main` 下载、自更新没有 tag、摘要或签名门禁（约 L35-L69）；这与 rc.16 固定 Release、清单和递归哈希链直接冲突。
- 只保存四个值的回退不等于完整回滚：缓冲、UDP、conntrack、队列、MTU、ECN、端口范围、limits、`gai.conf` 之外的外部修改都可能留下。它不能替代项目事务状态和所有权模型。
- 按总内存 5% 的缓冲和 4–256 MiB 固定界限没有端到端 RTT/带宽输入，也未证明适合当前四个资源档；通用 UDP/conntrack、`somaxconn=65535`、`netdev_max_backlog=65535`、RPS/RFS 和 MSS Clamp 均超出 rc.16 范围。
- `gai.conf` 的 IPv4 优先不能被表述为“解决 IPv6 绕路”；它只改变地址选择偏好，无法证明 DNS、路由、PMTU 或应用是否使用 IPv4。
- 仅凭内核版本号判断 BBRv3 不满足本项目真实性纪律；BBR 版本、内核来源和实际拥塞控制应分别取证。

## 项目三：netshape-manager 与 peertune

### NetShape Manager 的实际功能

当前脚本版本为 `5.4.0`。它把机器分成 `relay`（跨境/高 RTT，按单连接速率和整机总速率控制）与 `landing`（低 RTT，重点是聚合出口 policer）两条互不共用公式的路径（代码约 L8、L134-L281、L754-L916）。

- relay 使用 `2 × BDP`、RAM/`tcp_mem` 预算和单连接 `fq maxrate`；landing 固定 32 MiB/16 MiB（低内存）、HTB aggregate 加 `fq` 叶子，解释为保护约 1 ms 路径上的上游 policer。
- 整形有 HTB→TBF→fq 的回退，并在失败时删除已建 root，避免留下半成品；`verify_shaper` 会从 `tc` 输出复核实际速率（约 L1014-L1158）。
- 保存 baseline qdisc，卸载时尽量恢复；拒绝静默替换未知 root qdisc，并对 multipath default route 拒绝改写（约 L939-L980、L1179-L1224）。
- `TUNED_KEYS` 与 `append_sysctl` 做静态覆盖测试；`release_unmanaged_keys` 只有在当前值仍等于 NetShape 先前写入值时才恢复被新角色放弃的键，避免悄悄覆盖其他所有者（约 L585-L752）。
- README 和最新 commit message 声称在真实 landing box 上 HTB 950M 将每 15 秒十几万重传降到几十；这只能作为维护者的实验主张，不能当作本仓库的独立性能证据。

### peertune 的实际功能

`peertune` 是同仓库的另一个工具，重点不是调固定单流速率，而是通过 `ss -tin` 多次采样按客户端展示 RTT50/P95、min RTT、抖动、排队膨胀、窗口重传增量、连接方向和按 `/24`/`/64` 聚合。它包含 IPv4-mapped 地址归一化、低于 5 ms 或少于 1000 段时不判定、P50/P95 尾部区分，以及“排队在接入网而非服务器”的诊断组合（约 [解析和采样代码](https://github.com/bear4f/netshape-manager/blob/647b454b934349a179b1db289518eb9280adc839/peertune/peertune.sh#L291-L526)）。

它的 `tune` 可以选择 CAKE `dual-dsthost`，退到 `fq_codel` 或 `fq`，并写一套新的 sysctl/drop-in、root qdisc 和快照；README 明确要求不要与 NetShape 同机使用（约 [qdisc/ownership 代码](https://github.com/bear4f/netshape-manager/blob/647b454b934349a179b1db289518eb9280adc839/peertune/peertune.sh#L668-L816)）。这使它适合未来的“只读多客户端观测器”研究，不适合直接接管当前 rc.16 的 root qdisc。

### 可吸收内容

| 机制 | 评价 | 分类 |
|---|---|---|
| relay/landing 分角色 | 对多跳中转与落地拓扑的信任边界描述清楚；说明 RTT、单流限制和聚合 policer 不是同一个问题 | 只有在本项目明确支持多跳角色后重新评审；当前单 VPS 不吸收 |
| HTB 聚合 + fq 叶子、失败清理、速率复核 | 机制语义正确，适合解释“单流上限≠总出口上限” | rc.16 已有受限、非持久 HTB；只作为实验对照，不进入默认 profile |
| qdisc drift 检测、multipath 拒绝、ownership-aware stale key 处理 | 与可回滚治理高度相关 | 当前项目已有更严格的 `tc -j`、状态哈希、外部所有权和策略路由警告；吸收为评审用例即可 |
| peertune `ss -tin` 解析、窗口重传增量、RTT 分布和小样本闸门 | 对“服务端能否修复远端接入网问题”提供有价值的只读证据 | 条件候选；未来可设计为 `diagnose`/证据工具，当前不改实现 |
| NetShape/peertune 自检 fixture | 证明作者重视合成回归 | 可借鉴测试结构；不能替代目标机、业务和性能验收 |

### 明确拒绝或延期

- landing 的固定缓冲、2.5G/1G 预设和“约 98% 端口”的经验值只适用于作者描述的低 RTT、上游 policer 拓扑；当前项目没有该角色、端口集合或 A/B/A 证据。
- `tcp_ecn=0`、`tcp_frto=0`、`tcp_fastopen=0`、`tcp_tw_reuse=1`、`tcp_fin_timeout=15`、conntrack、`kernel.panic`、`vm.min_free_kbytes` 等仍是额外系统政策，不因 NetShape 的角色模型而自动进入 rc.16。
- CAKE、`dual-dsthost`、TBF fallback 和持久 root-qdisc 接管会改变当前 apply/rollback 契约；`peertune` 只能作为未来独立实验或观测工具，不能与 DVT 默认 profile 并装。
- README 中的 BBRv3 版本说明、固定阈值和真实重传数字是项目自己的解释或维护者实验结果；本轮没有在相同端点、方向、窗口、CPU/steal 和业务负载下复现。

## 整形专项再评估：tcpfit 与本项目重传问题

### 先给结论

用户描述的“应用本项目后，若干 VPS 的 TCP 重传明显”使**缺少聚合出口整形**成为一个值得验证的机制假设，但还不能把它写成根因。当前 profile 的 `BBR + fq` 主要依据每个 socket 的 pacing 和按流排队；它没有把所有出向流量放进一个 aggregate cap。若服务商在虚拟交换机、宿主机端口或上游链路实施低于标称端口的聚合 policer，多条代理连接叠加后可能持续超过稳定容量，形成远端丢包和 sender retransmission。tcpfit 的 `HTB root → HTB class(rate=ceil) → fq leaf` 正好针对这一类出口形态。

这只能得到“机制上合理、尚未在用户 VPS 证明”的判断。整形不会修复入向丢包、远端发送端重传、路径拥塞/乱序、CPU/softnet 饥饿、NIC 错误、PMTU 问题或代理应用本身的问题；错误方向的整形还可能降低 goodput、增加队列延迟或把本地 qdisc 丢包引入问题。

### tcpfit 整形机制的可复用部分

固定 commit `1163c20e88a4a7130ef7d885da8be3a163505003` 的源码明确把两个控制面分开：

- `HTB class` 写入 `rate=RATE`、`ceil=RATE`，承担**聚合出口上限**；`fq` 叶子写入 `maxrate=RATE`、`limit=40960`、`flow_limit=8192`，承担逐流 pacing/fairness。实现见 [tcpfit.sh#L1795-L1822](https://github.com/Kylin010/tcpfit/blob/1163c20e88a4a7130ef7d885da8be3a163505003/tcpfit.sh#L1795-L1822) 和临时实验路径 [tcpfit.sh#L1900-L1916](https://github.com/Kylin010/tcpfit/blob/1163c20e88a4a7130ef7d885da8be3a163505003/tcpfit.sh#L1900-L1916)。这与 Linux/iproute2 的语义一致：[`tc-fq(8)`](https://man7.org/linux/man-pages/man8/tc-fq.8.html) 把 FQ 定义为面向本地生成流量的 per-flow pacing，`maxrate` 默认是无限且是单流上限；[`tc-htb(8)`](https://man7.org/linux/man-pages/man8/tc-htb.8.html) 把 HTB `rate`/`ceil` 定义为 class 及其子级的保证/最大速率。
- `burst` 按 `RATE × 500` 字节计算，约为 4 ms 的线速数据量，低速下不小于 32 KiB；这是 [tcpfit.sh#L617-L623](https://github.com/Kylin010/tcpfit/blob/1163c20e88a4a7130ef7d885da8be3a163505003/tcpfit.sh#L617-L623) 的实现事实，不是适用于所有 VPS 的最佳值。HTB 手册明确说明 `burst/cburst` 是 token bucket 深度，并且 `cburst` 会允许以接口速度瞬时释放数据；它们需要结合内核 timer、MTU、驱动队列和上游 policer 实测。
- sweep 用 receiver goodput 和 sender retransmission/GiB 的比例，而不是只看绝对重传；首个疑似跳变最多复测三次，保留 `NO_KNEE`、`OUT_OF_RANGE`、`ABOVE_CAP` 和 `PEER_TOO_SLOW` 等不可判定状态。相关代码见 [tcpfit.sh#L2095-L2110](https://github.com/Kylin010/tcpfit/blob/1163c20e88a4a7130ef7d885da8be3a163505003/tcpfit.sh#L2095-L2110) 和 [tcpfit.sh#L2214-L2242](https://github.com/Kylin010/tcpfit/blob/1163c20e88a4a7130ef7d885da8be3a163505003/tcpfit.sh#L2214-L2242)。这套结果表达方式值得保留，但必须接入本项目已有的固定 endpoint、地址族、方向、冷却、原子流量 ledger 和 `REVIEW_*` 门禁。

下列参数不能从 tcpfit 直接搬入：它的默认 RTT 仍为固定 `150 ms`，而本项目的目标基线是 `200 ms`；`fq limit=40960` 和 `flow_limit=8192` 会显著改变排队容量，Linux FQ 在达到 `limit`/`flow_limit` 时会本地丢包；持久化 unit 会引入启动顺序、所有权、迁移和回滚问题。Linux 内核 UAPI 对 `drops` 的定义是因资源不足丢弃的包，对 `overlimits` 的定义是令牌不足造成的 throttle event（见 [pkt_sched.h](https://github.com/torvalds/linux/blob/master/include/uapi/linux/pkt_sched.h)），两者都不能直接当作远端路径丢包或 TCP 重传。

### 当前本项目的高置信度证据缺口

当前 `tools/profile-template.sh.in:qdisc_counter_snapshot` 只把 `parent :N` 识别为 `leaf`（约 L2373-L2415）。而本项目 HTB 实验实际建立的是：

```text
qdisc htb 1: root
qdisc fq 10: parent 1:10
```

本轮以当前函数原样和上述 `tc -s -d qdisc` 形态运行临时合成 fixture，得到：

```text
eth0.root.htb.1:.dropped    0
eth0.root.htb.1:.overlimits 17
eth0.other.fq.10:.dropped   3
eth0.other.fq.10:.requeues  1
```

也就是说，`parent 1:10` 的 FQ 叶子会被归入 `other`，而不是 `leaf`。现有 `tests/static-check.sh` 覆盖了 `mq` 的 `parent :1`/`:2` fixture，却没有覆盖 HTB 的 `parent 1:10`。随后 `build_benchmark_phase_summary` 只从 `.root.` 和 `.leaf.` 键构造汇总；在非 `mq` 情况下，`qdisc_active_totals` 使用 root 汇总。因此存在一个高置信度的**证据完整性缺口**：HTB root drop 为零时，叶子 FQ 的 drop/requeue 可能不进入主要分析字段，分析器可能把“root 没丢包”误读为“HTB/FQ 层没本地 qdisc 丢包”。这不改变默认 profile 的运行行为，但会削弱未来 HTB 实验对“整形降低重传”的证明力。

这项发现目前是静态源码 + 合成 fixture 证据，不是目标 Linux `tc` 运行证据。修复时应优先采用 `tc -j` 拓扑或至少按已识别 root handle 解析 `parent MAJOR:MINOR`，同时分别汇总 root `overlimits`、root drops、所有受管 leaf drops/requeues/backlog，并在预期 HTB→FQ 拓扑缺失叶子时 fail closed。`overlimits` 仍必须单独表达“整形器被触发”，不能与 drops 合并。

### 当前固定 HTB 参数与 tcpfit 的差异

rc.16 临时实验器使用 `burst=262144`、`cburst=32768`、`quantum=15140`，见 [htb-aggregate-experiment.sh#L10-L18](../experiments/htb-aggregate/htb-aggregate-experiment.sh#L10-L18)；其 HTB 叶子只建立普通 `fq`，没有再设置 tcpfit 的 `maxrate`。在 190 Mbit/s 时，前者约等于 11.0 ms 的线速数据，后者约等于 1.38 ms；tcpfit 在同速率约使用 95,000 bytes（约 4 ms），并令 `burst` 与 `cburst` 相同。这个差异说明“重传明显”时可以把 burst/cburst 和叶子 `maxrate` 作为第二阶段实验变量，但它**不能**证明当前参数有缺陷，也不能单独解释用户现象：更大的令牌桶可能允许微突发打穿 provider policer，更小的令牌桶又可能受 timer/CPU 限制而欠发；在已有 HTB aggregate cap 时，叶子 `maxrate=RATE` 还可能只是重复约束。先固定速率、修复统计，再比较 burst/leaf 组合，才能分离变量。

### 重传归因矩阵

| 观察组合 | 更符合的机制 | HTB egress 可能性 |
|---|---|---|
| sender retransmits/GiB 上升、receiver goodput 下降；HTB `overlimits>0`；root/leaf drops、softnet、接口错误均为 0；CPU/steal 稳定 | 聚合出口超过稳定 policer 的假设 | 值得做临时 HTB A/B/A |
| leaf 或 root drops 增长，且伴随 backlog/flow limit 证据 | 本机 qdisc 队列溢出或队列配置问题 | 先修正队列/统计，不把它写成 provider loss |
| 只有反向窗口或远端 sender retransmits 增长，本机 egress 无同向异常 | 入向路径、远端发送端或路径问题 | 本机 HTB 不应作为默认修复 |
| softnet `dropped/time_squeeze`、接口 drops/errors 或 CPU steal 增长 | vCPU/软中断/虚拟网卡资源瓶颈 | 先处理资源/拓扑证据 |
| RTT P95 相对 min RTT 膨胀，`rwnd_limited`/`sndbuf_limited` 或 pacing/delivery 不匹配 | 排队膨胀、接收窗口或 BBR 观测问题 | 需要 socket/RTT 观测，不能只调 rate |
| iperf3 正常而 VLESS + REALITY + TCP 业务重传/断流 | 应用连接模型、端点或业务路径差异 | 直连 HTB 结果不能替代业务验收 |

当前 `rate-sweep-run.sh` 的脱敏 `ss -tin` 白名单（约 L329-L346）没有保留 `pacing_rate`、`delivery_rate`、`minrtt`、`dsack_dups`、`rcv_ooopack` 等字段；因此现有证据能回答“重传发生多少”，却不能充分回答“发送 pacing 是否超过稳定 delivery、是否为乱序/伪重传、是否集中在少数连接”。这些字段应作为后续只读诊断候选，保留缺失值，不应在本轮直接改变 qdisc/sysctl。

同样不能把每个 `iperf3` 的 `sender.retransmits` 自动解释为本机出口丢包：它是发送端基于 TCP_INFO 的统计；使用 `--reverse` 时，发送端可能是远端服务端。方向、发送端身份和 host-wide `TcpRetransSegs` 必须一起记录（参见 [iperf3 API](https://github.com/esnet/iperf3/blob/master/src/iperf_api.c) 与 [TCP_INFO 代码](https://github.com/esnet/iperf3/blob/master/src/tcp_info.c)）。

还要区分测试限速和生产整形：当前 benchmark 只有在显式设置 `BENCHMARK_ENFORCE_RATE_CAP=1` 与 `BENCHMARK_RATE_CAP_MBPS` 时，才给 `iperf3` 加 `--bitrate`；并行流时该值还需按流拆分。它只约束本次 benchmark 生成的测试流，不改变 VPS 的生产 qdisc、代理连接或服务商聚合 policer，不能作为 HTB 的替代品。

### 对本项目的重新决策

1. **不把 tcpfit 的完整脚本或参数包写入默认 profile。** 17 项 sysctl、资源感知 BDP、根 `fq`、状态/所有权和非持久 HTB 边界继续保持。
2. **优先修复证据链，再评价整形收益。** HTB/FQ parent-handle 统计缺口应在任何新的 HTB 性能结论前修复并补 fixture；它是研究证据缺陷，不是默认 profile 需要立即启用 HTB 的理由。
3. **保留聚合整形作为条件候选。** 在固定 endpoint、地址族、方向、并发、窗口和 ledger 后，先做 HTB200 reference，再做 190/180/195 等受控候选，并完成 `A1 → B1 → A2` 和独立反向窗口；要求 sender retransmits/GiB、receiver goodput、socket pacing/delivery、RTT 尾部、CPU/steal、softnet、接口和 root/leaf qdisc 同时可解释。
4. **rate 采用实测稳定 knee 的最高通过值。** `90%`、`95%` 或 tcpfit 的固定 4 ms burst 都只能是第一候选，不能从标称端口推广成通用默认；若没有稳定 knee，结果应为 `NO_KNEE`/`REVIEW_REQUIRED`，而不是自动持久化。
5. **只有重复证据支持且另有授权时，才设计持久 opt-in shaper。** 届时需新增 qdisc 完整快照、所有权、启动/重启、回滚、multi-queue、burst/overhead、发布资产和真实 VLESS + REALITY + TCP 验收；本轮不进入实现。

本节结论的证据等级为：tcpfit/内核语义为固定源码与官方手册，当前 parser 问题为本地源码与合成 fixture，用户 VPS 的重传根因和整形收益仍为未知。置信度：HTB 能形成聚合上限——高；缺少聚合 cap 是用户现象的实际根因——中低；当前固定 burst 应直接替换为 tcpfit 公式——低。

## 对 rc.16 的吸收矩阵

| 外部内容 | 证据状态 | 对当前项目的判断 | 下一步 |
|---|---|---|---|
| tcpfit receiver goodput + 重传百分比 + 多次确认 | 源码实现；未在本项目目标机复现 | 与受控 HTB 分析方向一致，但 ledger、窗口和 `REVIEW_*` 门禁必须由 DVT 保持 | 仅在新实验需求获批时复用算法思想 |
| tcpfit 锁、异常回收、qdisc 恢复 | 源码实现；DVT 已有更强契约 | 作为回归用例比直接复制代码更有价值 | 保留在测试审计清单 |
| NetPilot 普通/中转菜单 | README/源码实现 | 当前产品不是转发器；菜单不会改变支持边界 | 不吸收 |
| NetPilot RPS/RFS、MSS Clamp、UDP/conntrack、IPv4 优先 | 源码实现；无目标机因果证据 | 扩大参数面、所有权和风险 | 拒绝进入 rc.16 |
| NetShape relay/landing | 源码实现 + maintainer claim | 仅对未来多跳拓扑有条件意义 | 登记延期，不改 rc.16 |
| NetShape HTB + fq aggregate | 源码实现；无独立复现 | 与现有实验语义一致 | 作为实验对照，禁止默认持久化 |
| peertune RTT/膨胀/抖动/重传观测 | 源码实现 + 93 条合成断言 | 适合未来只读诊断，不能直接写 qdisc/sysctl | 新需求或可复现业务症状时再立项 |
| HTB→FQ parent-handle 叶子统计 | 本地源码 + `parent 1:10` 合成 fixture；尚未目标机复现 | 当前实验分析存在证据完整性缺口，不能把 root drop=0 当成全层 drop=0 | 先补 parser/fixture，再使用 HTB A/B/A |
| 三项目的宽 sysctl、固定经验值和宣传性能数值 | 文档声明或维护者主张 | 不足以支持修改当前受管参数和默认值 | 保持现状 |

## 结论、反证和后续边界

最强的支持性结论是：三项目没有提供可以直接替换 rc.16 核心实现的“更优默认参数包”。tcpfit 和 NetShape 的可复用价值主要在测量结果表达、异常清理、qdisc 语义和只读观测；NetPilot 主要提供功能分档的用户界面思路，但它的完整性、所有权和回滚不满足当前项目门禁。对用户重传现象而言，tcpfit 的聚合 HTB→FQ 机制是合理的条件候选，但当前本项目还存在 HTB/FQ 叶子统计缺口，必须先补证据链。

最强的反证是：如果未来目标从“单台 Debian VPS 的保守主机调优”变成“多跳 relay/landing、多个客户端公平排队、远端接入网观测”，当前 rc.16 的单角色模型确实不足，NetShape 的双角色和 peertune 的分布式观测会成为有价值的上游输入。但这将改变需求、信任边界、qdisc 接管和验证矩阵，不能以“借鉴参数”名义暗中扩展 rc.16。

因此本轮决策为：

1. 保持 rc.16 的 17 项 sysctl、资源感知 BDP、根 `fq`、fail-closed 流量预算和非持久 HTB，不吸收三项目的扩张参数或永久整形。
2. 把“HTB/FQ 叶子统计修复 + socket 观测扩展”列为证据链优先项；在它们完成前，不把现有 HTB 结果用于默认行为或永久整形决策。
3. 保留两个条件候选：将 tcpfit/NetShape 的 goodput、重传增量、聚合速率语义用于未来受控实验；将 peertune 的 `ss -tin` 分布解析用于未来只读诊断。
4. 只有出现明确的多跳/多客户端需求、可复现业务症状或经过批准的性能实验时，才重新启动上述候选；重新启动前必须补需求、拓扑、预算、回滚和目标机证据，不以 README、stars、单次演示或维护者数字作为批准依据。

本轮未取得目标 VPS 运行、重启持久性、真实代理业务或性能改善证据。研究结论只达到固定源码和合成测试层级。
