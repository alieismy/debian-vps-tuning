# tcpfit 源码、Policer sweep 与下一版本重构可行性评估

日期：2026-09-28（Asia/Singapore）

状态：研究与可行性决策输入；未批准的重构建议。已核验固定源码与本地隔离样例，未实施产品重构，未访问真实 VPS 或执行公网测速。

## 1. 结论与决策范围

**建议吸收自动测速端点发现、按能力开放诊断、分阶段拐点测量三个方向；采用渐进重构，有条件可行，置信度中。** 源码和官方服务资料支持技术路线，但集成与运行成本尚未通过目标环境验证，性能收益未知。自动选点的使用价值明确，本项目当前把诊断入口绑定到受管 profile，确实增加了不必要的使用门槛。保留可靠的预算、证据和恢复机制，不需要同时保留所有历史发行版、CPU、内存和带宽的入口限制。

最强反对意见是：本项目已有受控 probe、临时 HTB 与离线校准，重做通用网络工具会增加端点目录维护、兼容性和运行验证成本，而 tcpfit 的公共节点结果不能证明真实代理业务收益。这个反对意见足以否定整体照搬或一次性重写，但不足以否定一个独立、有限流量、无需先 apply 的自动测量入口。后者直接解决用户找对端、配服务、开端口的负担。

本轮建议修正旧研究中对“公共节点自动选点”的整体拒绝：**在新版本中有条件采用自动选点；继续拒绝把公共单路径扫描结果直接作为服务商 policer 定论或持久整形依据。** 这是当前用户重新提出产品目标后的采用判断变化，不是上游出现新版本，也不改写旧阶段记录。

本报告回答：tcpfit 实际如何选点与扫描，全部 `fix`/`feat` 提供什么经验，哪些已被本项目吸收，哪些限制值得调整，以及下一版本最小可行范围。完整 PRD、详细设计、编码、发布和目标机运行均不在本次交付内。

## 2. 基线、方法与证据等级

| 对象 | 本轮固定证据 | 可证明的范围 |
|---|---|---|
| tcpfit | `main` 与 `v0.5.8` 解引用均为 `76331588af487a973d3445a1bf8bba7037d566ca`；tag 对象为 `5b3b2e34ac0da4328b7f8e2e7c1ad8fed439c906` | 2026-09-28 远端 Git 引用及源码；未重做 Release 资产验收 |
| tcpfit 历史 | 24 个可达提交；按 subject 前缀为 13 fix、8 feat、1 change、1 docs、1 init | 全部提交清点、补丁定位及对应当前实现的定向比较；提交中的实测描述仍是维护者声明 |
| 本项目 | `efacf1941d8b6dd7504ca7fda76b4045b2fe46f2`；`git describe` 为 `v0.1.0-rc.19-6-gefacf19`；初始工作树干净 | 当前 rc.19 后续文档基线及实现，不能继续按 rc.17 评估 |
| 项目阶段 | 现有备忘及发布记录说明 rc.19 已发布；`AGENTS.md` 仍写 rc.18 未发布实现候选 | 发现控制面状态漂移；本轮不更新指令文件，不重做远端发布核验 |
| 官方交叉来源 | Leaseweb、Clouvider、ESnet iperf3、Linux kernel、tc-htb 文档 | 服务公开用途、端口、计量/整形语义；不能证明节点当前可达或剩余容量 |
| 本地隔离样例 | 从固定 Git blob 提取函数，以合成 iperf3 结果和本地 stub 执行 | 特定函数的控制流与算术，不能替代完整脚本或 Linux `tc` 生命周期 |

tcpfit 固定文件 SHA-256：

```text
tcpfit.sh  3a4d720bf7acb5b77eb24708ca17b6b42487628eefbdcb982e62454c2287358e
install.sh 8a521bcc2f89c336fba239d7b722cede8638ac9df06b28eb8be1536a22fd5085
README.md  d840314b8c7caf3fbe8ce1558bf6556532e781966bec752731c6cc7927ff8b11
```

方法为：先读当前仓库与历史研究，再冻结上游，按提交清点定位源码，沿选点→探测→扫描→恢复→应用调用链检查，最后用官方资料和无网络样例检验关键判断。检索使用英文关键词，例如 `Leaseweb iperf3 speedtest 5201 5210`、`iperf3 bitrate parallel omit retransmits fq-rate`、`Linux tcp_mem pages`。完整查询、返回材料、补丁与本地样例保存在忽略目录 `.tmp/local/tcpfit-research-20260928/`，不作为发布资产。

旧研究及 2026-09-22 备忘只作为导航；本轮重新检查当前代码。历史研究见[2026-09-11 报告](tcpfit-v0.5.8-research-2026-09-11.md)，已实现吸收项见[实测校准说明](measured-calibration.md)。

## 3. 自动选点：值得吸收，但需准确理解“近处”

### 3.1 当前实现

自动选点由交互菜单/向导调用；`tcpfit sweep` 命令本身仍要求 `--peer`，不是省略参数后自动发现。源码 `PEER_POOL` 内置 **18 个主机**，包括 15 个 Leaseweb、2 个 Clouvider、1 个 OVH。它没有调用地理位置 API，也没有在运行时下载公共服务器目录。[T1]、[T2]

1. 按选定 IPv4/IPv6 协议族并行对所有候选 ping 两次，以平均 RTT 的整数毫秒值排序。
2. 依次检查候选。预检端口为 `5201/5202/5203/5200`，缓存可通端口；正式尝试使用共享 `5201–5210` 加 `5200` 池。
3. 已安装 iperf3 时，用 `-t 3 -P 1` 做真实测试，以退出成功作为可用判断；没有 iperf3 时降级为端口可连接。端口连通并不证明协议和吞吐正常。
4. 默认 RTT ≤50 ms 优先；50–100 ms 作为备选；若较近候选都不可用且存在远端节点，再检查 RTT 排序前五个，放宽距离限制。
5. 测试失败时会轮换端口。`run_iperf` 也会在后续测试中轮换端口，故各样本不一定来自同一服务实例。[T1]、[T2]

因此，“不用用户自己找 iperf3 服务器”成立；“自动找到物理最近、空闲且容量足够的服务器”不成立。更准确的说法是：从内置目录中选择低 RTT、能够完成短测试的候选。ICMP 被过滤、DNS 多地址、瞬时拥塞、IPv4/IPv6 路径不同，都可能改变选择结果。

### 3.2 公共服务是一条可行路径

Leaseweb 官方公开测速地址与 `5201–5210`，说明每个端口同时只能接受一个连接，结果会受其他测速及文件下载负载影响。[N1] Clouvider 官方指向自己的测速页面，当前页面列出 `5200–5209`，并明确为 **10 Gbps best effort**，高峰可能降速。[N2]

这支持本项目维护公共端点目录，而不是要求用户拥有每一台对端。目录应逐条记录运营方一手来源、允许端口、地址族、服务用途、核对日期及使用限制；不能把“能连接某个端口”当作使用授权或容量保证。本轮核对了 Leaseweb 和 Clouvider，一手证据未闭合的其他条目先不进入推荐目录。未逐台探测上述服务器。

建议首版直接提供“自动选择公开测速节点 / 使用自己的节点”两个入口。用户确认本轮端点范围、总流量与最长时间后，在该范围内自动选择与失败回退，不要求每换一个合法端口都重新确认。目录随固定版本发布，允许用户指定自有端点；初期不建设中心服务或账户系统。

### 3.3 需要改变的实现细节

- **选点也要计量。** tcpfit 的 3 秒可用性测试未设置 bitrate；向导的总确认和 `traffic_mark` 在自动选点之后。假设实际达到 1/10 Gbps，单次 3 秒 payload 约为 0.375/3.75 GB，尚未包括协议开销和失败重试。这是算术估算，不是本轮实测。[T1]、[T5]
- **使用各节点公布的端口集合。** 不对所有提供商套同一端口池；没有明确替代端口用途时停止，不扩大扫描范围。
- **固定实际测量路径。** 保存实际远端 IP、端口、协议族与本机出口；更换端点/端口后重新建立该组基线，不把不同实例数据拼成一条曲线。公开报告可以使用匿名端点标签。
- **ping 只用于排序。** ping 不通不能直接判 iperf3 不可用；允许在小额预算内做 TCP/协议预检，并给出 ICMP 未知状态。
- **目录提供候选，健康检查提供当次可用性。** 近端用于出口压力测量；业务相关远端用于业务路径校准。两种结果分别报告。

## 4. Policer sweep：算法、价值与边界

Policer 是超出策略速率时丢弃或标记流量的限速器；shaper 是在本地排队延迟发送的整形器。tcpfit 用本地 HTB 整形改变发送压力，寻找重传随速率变化的区间。HTB 控制链路出向流量，FQ 的逐流 pacing 不能代替聚合限速。[T3]、[N4]

### 4.1 当前完整路径

| 阶段 | 当前源码行为 | 分析 |
|---|---|---|
| 基础调优 | 完整向导先执行 `cmd_tune`，再验证路径与 sweep | 此时已改变 sysctl；不是针对原始配置的纯观察 |
| 低速路径检查 | 标称值 40%，8 秒、2 流，临时 HTB；dirty/slow/失败都会警告后继续 | 40% 不保证低于真实瓶颈；源码没有把失败当作硬阻断 |
| 自动基线 | 临时改成 fq，默认 12 秒单流，不限速；异常低值可能补采两次，取 receiver 最高的整组样本 | 配对取值值得保留；best-of-three 不能代表稳定容量 |
| 大带宽复核 | nominal ≥2500 Mbps 且单流可疑时可能补 8 流；默认扫描 cap 为 10000 Mbps | 多流辅助排除单流受限，但不是单流业务性能 |
| 建立扫描区间 | 以 receiver goodput 为依据；下界约 0.95 倍；上界随估计损失扩大并受 cap 限制；步长约区间宽度的 1/10 | 自适应步长比固定 20 Mbps 更适合小带宽；区间仍是经验启发式 |
| 每档扫描 | 替换整张网卡根 qdisc 为 HTB→class→FQ，rate=ceil；默认每档 12 秒、间隔 3 秒 | 会影响同接口其他业务；不能称“只测试一个 socket” |
| 异常复核 | 超阈值时再测两次，至少 2/3 次异常才确认；首档异常可向下 25% 测控制点，最多三次 | 有助减少偶发误判；同一端点的重复不是独立因果证据 |
| 细扫与结束 | 约 1/4 粗步长细扫；恢复 qdisc；输出 KNEE/RECOMMEND 或 NO_KNEE/OUT_OF_RANGE/ABOVE_CAP | 保留不可判定结果有价值；`KNEE` 实际取最后干净档，真实区间在它与首个异常档之间 |
| 后续应用 | 单独 `sweep` 只输出建议；完整向导会继续调用 `cmd_shape` 并写 systemd 持久配置 | 不能把两个入口的副作用混为一谈 |

直接证据：[扫描主体 T3][T3]、[测试 qdisc T4][T4]、[完整向导 T5][T5]。`--cap` 控制搜索范围，**不限制前面的“不限速基线”**；不能把 `--cap 1000` 理解为整个流程最多产生 1000 Mbps 流量。

### 4.2 `Loss%` 不是直接测得的链路丢包率

源码计算为：

```text
estimated_segments = sender_Mbps × 1,000,000 × configured_seconds / 8 / 1448
Loss% = retransmits / max(estimated_segments, 1) × 100
```

它依赖固定 MSS=1448、格式化文本中的 sender 速率和请求时长，不是抓包计算的丢包率。重传还受重复重传、误判重传、ACK 路径及 TCP 行为影响；真实 MSS、有效窗口和分母也可能不同。默认阈值为 0.1%，实际 spike 阈值为 `min(1%, max(0.1%, 5 × BASE_LOSS))`，属于上游经验规则。[T3]

本项目应继续保留 raw JSON、精确 bytes、真实测量窗口和 `retransmits/GiB`，用它描述重传强度；该指标也不能解释为网络丢包概率。ESnet 文档明确 `-b` 对多流逐流生效，TCP 默认不限速，`-O` 才省略预热统计；tcpfit 的 `run_iperf` 未使用 `-J` 或 `-O`。[T2]、[N3]

### 4.3 能发现压力相关转折，不能单独定位服务商 policer

**有价值的观察是：在特定路径、时间、协议族和发送方式下，超过某个负载后重传持续增多，或有效接收吞吐不再增加。** 同样曲线可由服务商 policer、共享链路拥塞、vSwitch/虚拟网卡队列、对端接收瓶颈或本机 CPU 引起。降低发送速率对其中多种原因都有帮助。

低 RTT 只能减少部分路径不确定性，不会排除上述原因；远端也不保证只造成“保守低估”。不同端点、不同时间的共享负载变化可以造成假转折或掩盖真转折。源码的 `policer present`、README 的“高丢包=有限速器”措辞超出测量本身的辨识能力。[T3]、[T6]

更可靠的后续测量应包含：有效的低速控制点、重复且负载充分的档位、首尾 reference 或换序复测、本机 CPU/softnet/qdisc 证据；必要时增加第二个独立端点。多端点一致可加强“共同出向瓶颈”的假设，仍不能替代服务商策略或瓶颈处观测。直连 iperf3 结论也不能替代 VLESS/REALITY/Xray 业务验收。

建议输出“候选转折区间”“本次预算内未观察到转折”“路径或端点受限”“本机资源受限”“证据不足”，并保留已测范围。预算不足或测不到声明上限时，不能写成“没有 policer”。

### 4.4 当前实现不宜复制的可复现问题

| 位置 | 本轮证据 | 影响与吸收方式 |
|---|---|---|
| `scan_range` L2355–2363 | 合成样本：目标 100 Mbps、sender 50、receiver 48、重传 0，仍置 `LAST_OK=100`；下一档连续异常时形成 `LAST_OK=100/BROKE_AT=120` | 下界没有证明达到目标负载。保留 DVT 的 shaping exposure 与 HTB acted 证据，不采用“低重传即干净可用”规则。这里只复现扫描子函数，不声称完整向导必然错误限速 |
| `restore_qdisc` L2276 | stub 的 `qdisc_restore` 返回 1，包装函数仍打印 `qdisc restored` 并退出 0 | 恢复成功状态不可信。使用本项目恢复后语义比较，失败保留中间状态与恢复材料 |
| `qdisc_save/restore` L2027–2082 | 保存根 kind；mq 仅保存首个匹配叶 kind；不保存每个叶子的 options/异构类型；已有持久脚本优先用于恢复 | 无法保证原始拓扑和参数完整恢复。沿用 DVT 的数值快照与复杂拓扑拒绝，不复制这组 helper |
| `detect_iface` L449–453 | 优先取 IPv4 默认路由，仅缺失时退到 IPv6，与测试 `IP_FAMILY` 不绑定 | 双栈不同出口或策略路由下可能整形到非测试出口；需要按实际端点解析路径。此项为源码条件推断，未在真实多网卡复现 |
| `auto_pick_peer`/`run_iperf` | 短测试不限速、共享端口池、重试未进入全局预算；读取人类文本而非 JSON | 自动选点应重写为受预算约束的探测，复用 DVT 计量/进程回收机制 |

本轮另外验证：重复 spike 被确认；一次 spike 后两次正常会继续；没有 spike 时不会产生 `BROKE_AT`。这些正向行为应一并保留，不能只依据缺陷否定算法的使用价值。

## 5. 全部 fix/feat 的采用矩阵

以下链接固定到提交；同一行所列范围依据补丁及当前实现，不把提交标题等同于验收。表中“已覆盖”指现有源码有对应机制，不意味着证明历史上直接复制了 tcpfit。

| 提交 | 机制与经验 | 相对当前 rc.19 的结论 |
|---|---|---|
| [85ced43][C01] feat | 检查更新 | 已有固定 Release/摘要/版本目录；保留本项目安装链 |
| [6ce5bf9][C02] fix | 参数快照覆盖、modules-load 回滚、swap 清理与更新校验 | 所有权及完整恢复原则已覆盖；不引入校验降级 |
| [ddf3a03][C03] fix | 锁、中断、参数前置校验、qdisc 保护、错误传播、迁移保留 | 大部分已覆盖；作为失败路径清单，不复制宽松锁或恢复代码 |
| [a32e2f6][C04] feat | 基线决定是否扫描、按观测建立范围 | 条件吸收渐进探测与早停；基线必须有预算，不采用“高重传=policer” |
| [5671da0][C05] feat | 菜单署名与地址 | 展示性调整，无技术重构增量 |
| [9239f61][C06] fix | 子进程回收、终点必测、保留粗扫异常边界、无拐点状态 | DVT 已有进程组/终态；新通用 sweep 应吸收边界语义与相关 fixture |
| [24a4793][C07] fix | 归一化重传，结合实际整形状态给建议 | 原则已覆盖；保留精确 bytes/GiB，不采用估算 Loss% 为真丢包率 |
| [954887d][C08] fix | 清旧结果、区分失败与区间不足、BusyBox 适配 | 运行目录与完整性链已覆盖旧结果隔离；能力探测值得吸收，不能据此宣称 Alpine 持久化支持 |
| [a1be918][C09] feat | 展示持锁者并提供结束操作 | rc.19 已有 PID/starttime/时长诊断；不引入强制接管 |
| [b5c9446][C10] fix | 避免重新查询 PID 后误杀，区分 pkill 能力 | 保留 owned process 回收；不把这套锁接管流程引入产品 |
| [df34072][C11] feat | 手填端点即时检查 | 新版交互值得吸收；端口通、协议可用、容量足够要分级 |
| [38a7f3e][C12] fix | swap 大小单位一致、校验早于快照 | 原则已覆盖；不增加任意 swap 管理范围 |
| [6a0b5a0][C13] feat | 无效交互输入重问 | 可用性模式可吸收；默认值仍由受审策略决定 |
| [243ce42][C14] feat | IPv4/IPv6 一致性、多端口、过滤 mapped IPv6 | 地址族已有支持；端点目录内的多端口回退与实际地址绑定是新版候选 |
| [e7a7329][C15] fix | 新 inode 原子替换、更新后进入新进程 | DVT 原子版本切换已覆盖；该修复不等于当前独立安装器已固定版本/完整校验 |
| [99ce5f0][C16] fix | IPv6-only 路由、地址/端口解析、业务 RTT 与测试族分离 | 保留独立 host/port 参数；“近端测试 RTT 不等于业务 RTT”应成为新入口的明确语义 |
| [6588581][C17] fix | pipefail、receiver、速率单位、小带宽步长、实际状态展示 | rc.19 已有定向 swap 修复与 receiver 背离提示；继续吸收低带宽测量与单位归一化 |
| [a8ad428][C18] fix | mq 0、重读拓扑、低速控制点、冷却、旧窗口所有权 | rc.18 已有更完整 mq 修复；控制点/冷却列入新实验；不默认吸收 initcwnd、固定 burst 或余量 |
| [67c0bdf][C19] fix | 低读数补采，sender/receiver/retrans 同组，保留结果页 | 配对样本原则有价值；保持重复样本和 median/MAD，不用最高值替代稳定容量 |
| [1163c20][C20] feat | 存档/卸载、10G cap、handle 0、sysctl 拒绝、远端回退、遥测 | 支持能力与恢复错误经验可吸收；命名存档非优先；遥测、静默缩减配置契约及默认持久 HTB 不采用 |
| [7633158][C21] fix | 无 via 路由按 token 解析、PPP hook | 普通路由发现已覆盖；PPP 持久化待明确需求；实际测试出口解析仍需升级 |

另检查 [3e28593][C22] `change`：RTT 改为固定 150 ms，`--rtt` 可覆盖。因此 README 的“按每台机器实测推导”不能理解为全部输入均实测。README 仍写 2500 Mbps 默认上限及“未找到拐点会取区间上界”，当前代码分别是 10000 和明确的 NO_KNEE/OUT_OF_RANGE；判断以固定源码为准。[T3]、[T6]

## 6. 操作系统、资源与带宽限制应如何调整

### 6.1 对用户判断的核实

本项目总控 `main` 先 `need_root → detect_environment → resolve_profile_script`，然后才 dispatch `diagnose/probe`。其支持范围为 Debian 12/13、x86_64，以及 1C512M、1C1G、1C2G、2C2G 四个资源组合；物理内存区间为 384–3072 MiB，并非范围内任意 CPU 组合都接受。声明带宽和 probe cap 均限定 100–1000 Mbps。临时 HTB 的研究契约更窄，固定 Debian 13、1C1G/1C2G profile、200 Mbps。[D1]、[D2]、[D3]

合成 `/etc/os-release`、`meminfo` 对当前 `detect_profile_from` 的隔离执行确认：Debian13/1C1G 返回 0；Debian13/2C1G、4C8G 返回 3；Ubuntu/1C1G 和 Debian/aarch64 返回 2。用户指出的限制是实际入口行为。它们来源于已定义并验证的产品范围，不能解释为 Linux BBR、iperf3 或 HTB 的普遍技术上限。

tcpfit 没有同类固定档位白名单，但仍有 root、Linux 工具、内核能力、可识别接口及数值范围要求；README 明确完整功能需要 systemd/iproute2。包管理器存在 apk 分支，不代表 OpenRC 的重启持久化已经实现。[T5]、[T6]

### 6.2 宽支持也需要正确的资源模型

tcpfit buffer 为 `min(2×BDP+2 MiB, RAM/32, 256 MiB)`，再设 4 MiB 下限，确实比离散 profile 更灵活。它默认 RTT 150 ms，并写入 32 项基础 sysctl；`TUNED_KEYS` 含 swap 共 33 项。扩大支持时可以借鉴资源相关的计算方式，不应直接复制公式和参数包。[T7]

一个具体可移植性问题是 `calc_tcp_mem` 用 `RAM_MiB×1024/4` 换算页数，假定 4 KiB 页；Linux 官方规定 `tcp_mem` 使用页数。[T7]、[N5] 合成 2 GiB 内存输入得到 `32768 65536 131072`：在 4 KiB 页下 max=512 MiB；在 64 KiB 页下则为 8 GiB，是原意的 16 倍。这里只验证算术，没有宣称某台 ARM64 主机使用 64 KiB 页，更没有复现 OOM。未来跨架构策略必须读取真实 page size，并考虑可用内存、容器限额和业务占用。

### 6.3 推荐的限制分层

| 当前边界 | 下一版本建议 | 保留的判据 |
|---|---|---|
| 诊断要求匹配 Debian profile | 改为能力检测；Ubuntu、ARM64、较大内存/核数可先进入诊断候选 | 命令/字段是否存在、权限是否足够；缺项明确 unavailable，不伪装完整 |
| 诊断与应用共同依赖 root/受管状态 | 测量不要求先 apply；普通权限运行可完成部分任务 | 需要特权的计数或 qdisc 变更单独检查；不能把 UNMANAGED 伪装成 VERIFIED |
| CPU 必须 1–2、内存必须落离散档 | 诊断取消硬件档位拒绝；应用保留旧策略作为兼容策略，逐步增加资源预算策略 | 实际 CPU/softirq/内存压力和恢复能力，不因硬件更大就自动放大缓冲 |
| 带宽 100–1000 Mbps | 测量层优先覆盖 10/20/50 Mbps，随后有预算地验证 2.5/10 Gbps；上限改为显式计划与已验能力 | 不无上限试跑；预算、时限、有效负载、端点与 CPU 能力必须成立 |
| 自动选择公共端点被排除 | 本轮改为建议采用 | 运营方公开用途、限定端口、预算覆盖所有重试、实际路径绑定 |
| HTB 固定 200 Mbps 研究入口 | 新版单独形成通用临时实验，保留原研究协议及旧分析器 | 整机影响确认、原拓扑可恢复、同版本工具、负载充分、失败恢复 |
| 17 项 sysctl 与默认 BBR+fq | 作为兼容策略保持；新增策略逐项有依据 | 核心参数缺失应阻断该策略；可选项可降级但必须显式记录实际策略 |
| 持久 HTB | 不随自动发现功能默认开启；后续根据临时实验与业务证据独立决定 | 完整生命周期、重启、幂等、回滚和业务对照 |

尤其要分开五个数：虚拟网卡报告速率、服务商声明带宽、路径实测 goodput、本轮测试 cap、拟应用 shaping rate。它们可能全部不同。近端 RTT 也不能自动回填为全局 TCP 缓冲的业务 RTT；现有校准器的代表性路径确认应保留。[D4]

## 7. 重构候选与建议范围

| 路线 | 用户收益 | 成本与主要问题 | 判断 |
|---|---|---|---|
| A：维持现状，只完善手工对端文档 | 对现有受支持主机改动少 | 继续要求自己准备端点，无法解决更宽主机测量入口 | 可作为维护基线，不满足当前目标 |
| B：复制 tcpfit 向导并删除现有检查 | 快速获得一键体验与广输入范围 | 量测、全局改参、临时整形、持久化耦合；丢失恢复/预算不变量；公共结果误作配置依据 | 不建议 |
| C：保留受管内核，分离发现、测量、建议与应用 | 同时改善易用性和兼容范围，复用已有可靠采集 | 需要调整总控分发和证据适配，但可逐步交付 | 推荐，有条件可行 |

### 7.1 建议作为下一版本第一阶段的最小范围

1. **独立诊断/测量入口。** 在 action 分发后按需选择 profile；抽出模板中现有采集和 benchmark 能力，避免再复制一整套。未受管主机的证据拥有真实的独立状态，离线分析器通过明确适配接受，不能补造旧 managed-state 字段。
2. **受维护的公共端点目录与选择器。** 首批采用有运营方一手来源的 Leaseweb/Clouvider，允许自有端点；先轻量排序和有限协议检查，再选少量候选。保留每次解析与失败原因，目录失效能安全停止。
3. **有预算的速率阶梯测量。** 先使用 iperf3 的 socket/application pacing，记录当前 qdisc 而不替换它。这只能回答路径在这种发送方式下的压力响应，不能等同 HTB 聚合整形效果，也不能假定已有 HTB 不会限制结果。
4. **机器可复核、人可理解的建议。** 展示成功路径、实际测试范围、receiver goodput、sender/retrans、RTT、资源异常和剩余不确定性；有限预算内测不到拐点也是正常终态。保留原始证据和恢复手段，同时把日常使用收敛为一次计划确认。

首个预发布的核心用户结果应是：**在具备必要测量能力的主机上，无需预先应用 DVT 配置、无需自建对端，即可完成一次有预算的自动选点和路径测量，并得到边界明确的报告。** 第一阶段不承诺自动修好网络或识别厂商限速器。

### 7.2 第二、三阶段

- **第二阶段：通用临时 HTB 拐点实验。** 复用现有临时生命周期，扩展速率/拓扑契约；加入低速控制点、上下界与精扫、首尾 reference、负载和资源门禁。mq、clsact、过滤器及其他非受管对象不能因为“测一次”而丢失；无法证明恢复时只允许不改 qdisc 的测量。
- **第三阶段：扩展持久配置支持。** 先增加明确目标的 Ubuntu LTS、ARM64 和大资源主机，再考虑更多发行版。操作系统适配、内核能力、网络拓扑、资源策略应分别判断；swap/journald 不随网络测量自动改变。持久 HTB 作为独立策略候选，需业务对照而不是只看直连重传。

建议按 `0.2.x` 新能力线规划，具体版本号待立项；当前 rc.19 及更早资产保持不可变。旧六份 profile 可继续作为兼容入口，不因内部模块化就强迫用户迁移，也不需要给每种“发行版×CPU×内存×带宽”新增完整脚本。旧证据 schema 保留专用读取路径；只有契约确实变化才升级 schema，不用泛化正则伪装兼容。

## 8. 可行性、成本、风险与验收

| 维度 | 判断与最低条件 |
|---|---|
| 必要性 | 高：自动选点和去除诊断 profile 耦合直接解决当前使用负担 |
| 技术 | 有条件可行：公共服务存在，现有采集/预算/分析可复用；主工作在职责拆分、证据适配和实机验证 |
| 成本 | 不需要因自动选点强制购买专属对端；但流量成本仍存在，维护目录和兼容矩阵会增加投入。未提供开发资源与测试机，不能给可靠人日、费用或交付日期 |
| 进度 | 第一阶段可以独立闭环；10G、更多发行版及持久 HTB 不应成为自动选点交付的前置条件 |
| 运行 | 必须限制 endpoint/port 数、重试次数、时限和数据量；保持 owned process 清理。目录不可用时明确结束，保留自有端点入口 |
| 许可 | 两项目均 MIT；采用实质代码需保留上游版权与许可。许可允许使用不证明实现适用 |
| 隐私与供应链 | 公共对端会观察来源地址和流量。保留本地证据权限及公开脱敏，不加入 tcpfit 默认遥测；目录按数据验证，不下载执行远程脚本 |
| 可持续性 | 无中心账号依赖，可替换目录来源或只用自有节点；从公共诊断退回现有手工 endpoint 流程无需迁移系统配置 |

主要风险是误归因、公共端点拥塞、低负载假“干净”、未经计量的重试、跨架构页大小假设、临时整形影响业务和恢复失败。前四项在测量设计中收口；后三项决定能否进入配置/整形阶段，不能用提示框替代恢复证明。

预算必须说明计量单位。当前 `dvt-traffic-budget.sh` 明确仅核算 application payload，不包含未知协议、重传和服务商计费开销；不能宣称它是精确账单硬上限。[D5] 新版应将 discovery、预热、重试和所有样本纳入预算预留，失败保守结算；网卡 tx/rx 差值只作旁证，因为含背景业务且不等于账单。预算不足时结束并报告已测范围，不能为了寻找拐点自行扩量。

建议首版验收最低集合：

- 合成/本地：目录格式与端口约束、ICMP 不通但 TCP 可用、busy/超时、IPv4-mapped IPv6、地址/端口变更后的基线分组、无旧结果污染、预算不足/失败结算、Ctrl-C 仅回收自有进程。
- 兼容：Linux 的实际依赖探测；明确纳入的 Debian/Ubuntu 与 amd64/arm64 诊断环境；低速和高资源主机不因旧 profile 被拒；旧 apply/verify/rollback 行为不变。
- 运行：经授权的短测证明可自动选点、停止、结算和产出完整报告；无 sysctl/qdisc 持久变化。该验收仍不证明吞吐改善。
- HTB 后续：真实 tc、信号中断、原 mq 叶参数与队列集合、其他 qdisc/过滤器保留、恢复失败终态；再做路径和业务对照。CI 和 mock 不能代替此层证据。

只有出现“用户实际无需手找端点即可完成受控测量”的证据，才算自动选点功能交付；只有配置/重启/回滚及业务路径验证通过，才提升扩展平台的应用支持等级。未给成本、时间或性能收益数值，避免把估计写成承诺。

## 9. 本轮验证与剩余缺口

已完成固定源码哈希与 24 提交清点；`bash -n` 检查 tcpfit 两个 Shell 文件通过，`fleet.py` AST 解析通过；没有执行第三方主入口、安装器或遥测。直接检查源码中性能注释引用的 results 路径不在当前跟踪文件集合，因而没有把其 A/B 数字当作可独立复算的实验数据。

本地隔离样例已验证 4 组扫描输入、恢复失败包装、4/64 KiB 页算术与 5 组本项目支持门禁。首轮 fixture 在 Windows 写出 CRLF，影响 Bash 数字读取；改为 LF 后全部断言通过。这是研究 fixture 问题，不是第三方产品失败。检查脚本与 `evidence-summary.json` 保留在上述忽略目录；可复跑，但不随产品发布。

`python tools/render_profiles.py --check` 通过。文档交付检查覆盖相对链接、固定提交链接与行锚、Markdown 表格/代码围栏、敏感标识及 `git diff --check`。本轮只交付本报告并更新项目阶段备忘，不修改运行代码、版本、安装摘要、发布状态或全局规则。

未验证：公共节点当前可达性与容量、候选自动选点实际体验、Linux root qdisc/信号/重启生命周期、跨发行版与 ARM64 应用、服务商 policer 归因、代理业务或性能改善。以上缺口不影响“可以开展第一阶段渐进重构”的可行性判断，但阻止宣称新版本已实现或已验收。

## 10. 已检查来源

源码链接固定版本；官方在线文档检查日期为 2026-09-28。Clouvider 知识库显示更新于 2021-12-23，仅用于其自有测速服务用途与负载限制说明；端口以本轮读取的当前测速页为依据。文档当前在线不等于服务当前在线。

- [T1：tcpfit 节点目录与自动选择][T1]；[T2：run_iperf][T2]；[T3：sweep 与 loss_pct][T3]。
- [T4：临时 qdisc 与恢复][T4]；[T5：完整向导][T5]；[T6：README][T6]；[T7：资源计算][T7]；[T8：安装器][T8]。
- [D1：本项目总控][D1]；[D2：probe][D2]；[D3：HTB 分析器][D3]；[D4：离线校准][D4]；[D5：流量账本][D5]。
- [N1：Leaseweb Link Speeds & Speed tests][N1]；[N2：Clouvider 当前测速目录][N2]及[运营方说明](https://www.clouvider.com/knowledge_base/i-am-not-getting-10gbps-why)。
- [N3：ESnet iperf3 使用手册][N3]；[N4：tc-htb 手册][N4]；[N5：Linux IP sysctl][N5]。

[T1]: https://github.com/Kylin010/tcpfit/blob/76331588af487a973d3445a1bf8bba7037d566ca/tcpfit.sh#L2850-L3011
[T2]: https://github.com/Kylin010/tcpfit/blob/76331588af487a973d3445a1bf8bba7037d566ca/tcpfit.sh#L2164-L2196
[T3]: https://github.com/Kylin010/tcpfit/blob/76331588af487a973d3445a1bf8bba7037d566ca/tcpfit.sh#L2198-L2657
[T4]: https://github.com/Kylin010/tcpfit/blob/76331588af487a973d3445a1bf8bba7037d566ca/tcpfit.sh#L2011-L2101
[T5]: https://github.com/Kylin010/tcpfit/blob/76331588af487a973d3445a1bf8bba7037d566ca/tcpfit.sh#L3135-L3527
[T6]: https://github.com/Kylin010/tcpfit/blob/76331588af487a973d3445a1bf8bba7037d566ca/README.md#L111-L179
[T7]: https://github.com/Kylin010/tcpfit/blob/76331588af487a973d3445a1bf8bba7037d566ca/tcpfit.sh#L529-L737
[T8]: https://github.com/Kylin010/tcpfit/blob/76331588af487a973d3445a1bf8bba7037d566ca/install.sh
[D1]: https://github.com/alieismy/debian-vps-tuning/blob/efacf1941d8b6dd7504ca7fda76b4045b2fe46f2/debian-vps-tuning.sh#L154-L208
[D2]: https://github.com/alieismy/debian-vps-tuning/blob/efacf1941d8b6dd7504ca7fda76b4045b2fe46f2/dvt-probe.sh#L167-L240
[D3]: https://github.com/alieismy/debian-vps-tuning/blob/efacf1941d8b6dd7504ca7fda76b4045b2fe46f2/experiments/htb-aggregate/rate-sweep-analyze.sh
[D4]: https://github.com/alieismy/debian-vps-tuning/blob/efacf1941d8b6dd7504ca7fda76b4045b2fe46f2/tools/calibrate_probe.py
[D5]: https://github.com/alieismy/debian-vps-tuning/blob/efacf1941d8b6dd7504ca7fda76b4045b2fe46f2/dvt-traffic-budget.sh#L20-L39
[N1]: https://kb.leaseweb.com/kb/network/network-link-speeds
[N2]: https://as62240.net/speedtest
[N3]: https://software.es.net/iperf/invoking.html
[N4]: https://man7.org/linux/man-pages/man8/HTB.8.html
[N5]: https://docs.kernel.org/networking/ip-sysctl.html
[C01]: https://github.com/Kylin010/tcpfit/commit/85ced4318e63138e2ed793f713deb822f7c01a59
[C02]: https://github.com/Kylin010/tcpfit/commit/6ce5bf95cfc0ddc8d6d7e6e1dc64685fe76c79dd
[C03]: https://github.com/Kylin010/tcpfit/commit/ddf3a033f08e9f4eb49d9ef55b04958b100ea679
[C04]: https://github.com/Kylin010/tcpfit/commit/a32e2f6966009628f265174a0d0c2209f81c54a0
[C05]: https://github.com/Kylin010/tcpfit/commit/5671da0a01814997216903c3ac6825a1512bf4da
[C06]: https://github.com/Kylin010/tcpfit/commit/9239f616ec82637d212e9c6e92bbf7ad751ce0f2
[C07]: https://github.com/Kylin010/tcpfit/commit/24a47938cc5861fea5dd43feb86cc6abe1d99db2
[C08]: https://github.com/Kylin010/tcpfit/commit/954887d2e834863f9478dfaed9644816e2effb7f
[C09]: https://github.com/Kylin010/tcpfit/commit/a1be918e90cb1cfae17d07dfc1d9395adc59628d
[C10]: https://github.com/Kylin010/tcpfit/commit/b5c9446c11ea8490671f3798a0cd6bfbfdf7bb05
[C11]: https://github.com/Kylin010/tcpfit/commit/df34072e20112503c7452f66ffb5b0c3ee6f1581
[C12]: https://github.com/Kylin010/tcpfit/commit/38a7f3ed243a2ae98598458c6ba3033ba9f51792
[C13]: https://github.com/Kylin010/tcpfit/commit/6a0b5a0e3bea6eace9074eceaf6031e95e9f6123
[C14]: https://github.com/Kylin010/tcpfit/commit/243ce42ed77feb93b162f68b2e2839febbfb43b3
[C15]: https://github.com/Kylin010/tcpfit/commit/e7a7329bf4ece6bb805cf82051a189fbbe653ca1
[C16]: https://github.com/Kylin010/tcpfit/commit/99ce5f0c7220115c8e42aef7fca1246ad7915609
[C17]: https://github.com/Kylin010/tcpfit/commit/65885816bb77be38d041218f1bf62fe4ebe5c300
[C18]: https://github.com/Kylin010/tcpfit/commit/a8ad4280e876bca066970ff97458003df30c7eae
[C19]: https://github.com/Kylin010/tcpfit/commit/67c0bdfb35dd98e86982600298237b6ecc08ebe4
[C20]: https://github.com/Kylin010/tcpfit/commit/1163c20e88a4a7130ef7d885da8be3a163505003
[C21]: https://github.com/Kylin010/tcpfit/commit/76331588af487a973d3445a1bf8bba7037d566ca
[C22]: https://github.com/Kylin010/tcpfit/commit/3e285932e5f212eef9be9591ebba9a78a3b4d1c7
