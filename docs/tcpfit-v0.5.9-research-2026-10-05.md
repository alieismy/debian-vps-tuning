# `Kylin010/tcpfit` v0.5.9（`38fbf5a`）增量研究与吸收评估

日期：2026-10-05（Asia/Singapore）

状态：研究证据包与决策输入；未批准实现。只读检查固定源码、补丁、Release 说明和一手技术资料；没有运行第三方脚本，没有连接 VPS，也没有产生公网测速流量。

研究模式：`rd-research` 技术与开源研究。前序研究见 [v0.5.8 研究](tcpfit-v0.5.8-research-2026-09-11.md)和 [2026-09-28 可行性评估](tcpfit-policer-refactor-feasibility-2026-09-28.md)。本报告只评估两者之后新增的唯一提交，不重做历史提交矩阵。

## 1. 结论

**结论：当前实现不需要修改，没有可直接移植的代码。置信度高。** v0.5.9 修复的问题大多是本项目早已用更强机制防住的失败模式，例如扫描流量失控、不完整扫描被说成“没有限速器”、写入失败仍报告成功，以及非交互环境自动接受默认值。这些修复为本项目保留现有设计提供了外部现场佐证，不需要追加实现。

本轮形成两项新的有条件候选，并为两项既有候选补充设计输入：

| 编号 | 内容 | 性质 | 置信度 |
|---|---|---|---|
| N1 | 高速率测量增加多流聚合对照，用于区分单流受限和聚合瓶颈 | 新增条件候选；当前 `parallel=1`，入口允许最高 10000 Mbps | 中 |
| N2 | 验证 networkd 重启或链路重建后 fq 是否仍保持 | 新增低优先级验证候选；当前只有源码推断和重启生命周期证据 | 中 |
| U1 | PPP/PPPoE 候选补充 ARPHRD 设备类型判断，并按接口过滤默认路由 | 补充 2026-09-11 既有候选 | 高（内核常量已核实） |
| U2 | 持久 HTB 补充约束：负载不足的新测量，不能覆盖或删除较强的旧配置 | 补充既有独立决策项 | 中 |

initcwnd 持久化在 v0.5.9 中需要四种入口，且存在已知缺口，这进一步支持不采纳的结论；其他机制已覆盖或不适用。

最强反对意见：tcpfit 有大量来自 10G 主机和多种网络管理器的用户现场反馈，本项目的公网证据主要来自低速单流，因此 tcpfit 发现的问题可能是本项目尚未暴露的问题。本轮逐项对照了本项目源码。凡是能对应到本项目的路径，都已存在等价或更强的控制，所以这项反对意见不会推翻“无需修改”。它确实提高了 N1 的优先级，而且只在高速测量进入范围时才需要处理。

## 2. 研究问题、基线与方法

研究问题：

1. 最新提交实际改了什么？Release 中的声明有哪些可以从仓库复现？
2. 每项变化在本项目当前实现中是否已覆盖、是否适用、能否带来新增价值？
3. 哪些内容只能作为有条件候选？进入实施需要什么新证据？

| 对象 | 固定证据 | 能证明的范围 |
|---|---|---|
| tcpfit | `main` 与 `v0.5.9` 解引用均为 `38fbf5af30daf87735f2ffbc5e0905033ee2b86e`；tag 对象 `f834e23f49862bc6f7d8556f33c78a1d5fbb7fe5`，打标时间 `2026-10-01T22:16:42Z`；Release 发布时间 `2026-10-01T22:18:44Z`，不是 draft，也不是 prerelease | 2026-10-05 读取的远端引用与源码 |
| 变更范围 | 相对 `7633158`（v0.5.8）改动 5 个文件，`+971/−132`；`tcpfit.sh` 变更 1008 行，现为 4484 行 | 补丁全文已逐段阅读 |
| 文件摘要 | `tcpfit.sh` `8331cc40950229a3280ce32406330a85b1a3d21ba398a4db3dc7e25c39783741`；`install.sh` `cb8362f96b22f196eebefe6b81d9526757cc9807222a0b1626e7303304b8450a`；与仓库内 `SHA256SUMS` 一致 | 只核对仓库文件；没有下载 Release 资产做逐字节比对 |
| 本项目 | `1c5e922c2fce916d5217bf6c238d6cd50a8c51b0`（`measurement-explanation-v0.1.0`），工作区只有用户未提交的 `AGENTS.md` 修改 | 当前源码对照；`AGENTS.md` 阶段文字落后于备忘，属于既有治理待办 |

方法：将上游克隆到会话临时目录（不进入仓库），用 `git diff 7633158 38fbf5a` 取得补丁，并结合 [Release 说明][R1] 逐项定位变化。随后在本项目的模板、测量、预算、安装和 HTB 事务源码中查找对应路径。影响判断的外部事实使用一手来源核实，包括内核提交、内核文档、systemd 手册源文件和内核 UAPI 头文件。检索关键词为英文，例如 `netdev_budget_usecs minimum 2 jiffies commit`。

证据边界：Release 中“新增流量、持久化两套回归测试，连同原有五套全部通过”、容器 networkd 验证、OVH 10G 实跑和“400 GB”用户事故，都是维护者声明。上游仓库只跟踪 9 个文件，没有测试目录，因此这些测试无法从仓库复现。本报告只把它们当作维护者报告的现场现象，不当作已复现事实。

## 3. 变化与本项目逐项对照

“已覆盖”只表示本项目源码中存在对应控制，不表示本项目参考或复制过 tcpfit。

| # | v0.5.9 变化（上游位置） | 本项目对应实现 | 判断 |
|---|---|---|---|
| 1 | 扫描流量失控：精扫档数加上限；按实测速率估算流量；超过 50 GB 或明显超出预估时确认，默认不扫；`--yes` 放行；取消后不再满速验证（[T1][T1]、[T2][T2]、[T3][T3]） | 每次尝试发流量前按 `rate×(秒数+23)+1 MiB` 预留，余额不足时以 `BUDGET_LIMIT` 停止；失败按预留额结算；精扫最多 3 档；计划可先 `--plan-only`（[D1][D1]、[D2][D2]、[D3][D3]） | **已覆盖且更强。** tcpfit 的估算不是上界：不含不限速基线及其补采、8 流复核、异常复测、向下控制点，也不含每档最多 3 次的重试（[T4][T4]、[T5][T5]）。确认发生在不限速基线之后，所以 Release 自己的表格写明拒绝后仍会用掉约 13 GB。这次事故从外部支持保留逐次预留账本，不采用“估算加确认线” |
| 2 | 菜单检测到没有终端就退出，避免自动选择 1 并跑完向导（[T6][T6]） | 非交互运行 probe 必须加 `--yes`；总控在非交互环境中必须指定 action，guided 需要终端（[D4][D4]、[D5][D5]） | 已覆盖。非交互且没有指定带宽时，总控使用默认端口速率，只影响缓冲推导，不产生流量 |
| 3 | 单流有丢包而 8 流零丢包时，按聚合结论处理；8 流负载不足时判为“判不出”（[T7][T7]） | 测量固定 `parallel: 1`，`--rate-cap` 最高 10000；负载不足标为 `UNDERDRIVEN`，接收端偏离标为 `RECEIVER_DIVERGENCE`，任一问题都进入 `INSUFFICIENT_EVIDENCE`（[D6][D6]、[D7][D7]） | **条件候选 N1**。当前低速范围不受影响。高速单流可能先受单连接窗口、CPU 或对端限制。上游说的“单流丢包不是限速器”超出了证据：按连接限速时也会出现单流有丢包、8 流干净。这个结论只能支持“聚合整形无益”，不能证明不存在限速器 |
| 4 | 记录扫描覆盖率（`VERIFIED_TO`/`REQUESTED_TO`）；中途失败或负载低于标称 70% 时判为 `INCONCLUSIVE`，并保留旧整形（[T8][T8]、[T9][T9]） | 分析器把不完整、控制无效、样本无效和负载不足都并入 `INSUFFICIENT_EVIDENCE`；无上升时只报告 `NO_RISE_IN_TESTED_RANGE`；`policer_identified=false`，不给整形建议（[D7][D7]） | 已覆盖。本项目测量不会自动应用或删除配置。“新的弱结果不得推翻旧的强结果”这条原则补充到持久 HTB 决策项（U2） |
| 5 | initcwnd 持久化改为四条入口：PPP 钩子、networkd drop-in（systemd ≥255）、dispatcher 钩子、开机单元（[T10][T10]） | 受管集合为 17 项 sysctl，不管理 initcwnd/initrwnd（[D8][D8]） | **进一步支持不采纳。** systemd 源文件确认 `[DHCPv4] InitialCongestionWindow=` 从 v255 开始提供（[N1][N1]）。上游注释承认 dispatcher 入口在 networkd 重启而链路保持 routable 时不会补回。上游此前 [`a8ad428`][C1] 也报告过小带宽限速线路上 initcwnd 32 的负面实测。路由属性的持久化、所有权和回滚成本很高，收益证据不足 |
| 6 | 回滚与恢复存档时，只在当前路由上摘除或套用窗口字段，不再回放旧的整条路由（metric 是路由键）（[T11][T11]） | 本项目不改路由。同一原则已用于 rc.18 的 mq 回滚：按当前非零根 handle 和保存的队列 minor 重建 parent，不复用保存时的 parent（[v0.5.8 报告补充](tcpfit-v0.5.8-research-2026-09-11.md#2026-09-14-补充更正mq-0-句柄寻址)） | 已覆盖（同类原则） |
| 7 | 快照和 sysctl 写入改为临时文件、完整性检查、结尾标记和原子改名；整形或验证失败时不再报告成功，退出码随之变化（[T12][T12]、[T13][T13]） | 受管文件使用临时文件、显式 `chmod`/`chown` 和 `mv`，并记录 SHA-256；状态 JSON 提交前校验；`sysctl -p` 失败即报错；有独立的 `EXIT_VERIFY`/`EXIT_ROLLBACK`（[D9][D9]、[D10][D10]、[D11][D11]） | 已覆盖。结尾标记针对“截断但 `cat` 返回 0”的场景；本项目已有退出状态检查、哈希记录和应用后核验，再加结尾标记没有新增保护 |
| 8 | 不再设置 `netdev_budget_usecs`（[T13][T13]） | 17 项受管 sysctl 不含该项（[D8][D8]） | 不适用。上游内核 [`c180188ec022`][N2] 已把下限设为 2 jiffies（HZ=250 时为 8000 µs），因此旧值 4000 会被拒绝。这也支持只为有证据的参数扩展受管集合。上游列出的稳定分支回移版本号未核实 |
| 9 | 安装器改为临时文件、`bash -n` 和原子改名（[T14][T14]） | 固定 Release tag，校验 installer 内置的清单摘要，再逐项校验资产（[D12][D12]） | 已覆盖且更强。上游仍下载可变的 `main`，agent 模式不校验摘要；`update` 拿不到清单时会退回版本号校验（[T15][T15]）；默认遥测仍开启（[T16][T16]）。均不采用 |
| 10 | 多出口或策略路由时，按测速目标运行 `ip route get` 选择网卡（[T17][T17]） | 用 `ip -j route get` 解析端点出口并固定路由，每次尝试前复核；HTB 要求出口等于已确认接口（[D13][D13]、[D14][D14]） | 已覆盖 |
| 11 | 后台统计子进程继承锁 fd，导致同一次运行再次加锁时被自己挡住（[T18][T18]、[T16][T16]） | 每次调用只加一次锁；iperf3 子进程同步等待，并按进程组回收；Python 子进程默认不继承 fd（[D15][D15]、[D16][D16]） | 已覆盖。父进程被强杀后，残留的 iperf3 会持有锁直到超时，这能阻止流量重叠，属于保守行为 |
| 12 | 把 HTB 守卫下沉到 `qdisc_save` 这一共同入口；拒绝替换不是 tcpfit 下发的 HTB（[T19][T19]） | HTB 事务预检只接受可完整恢复的单一根 fq，存在 class/filter、mq、clsact 或 ingress 时拒绝（[D17][D17]） | 已覆盖且更严格 |
| 13 | 输入 `08` 等前导零时，bash 算术按八进制解析出错（[T20][T20]） | 用户数值统一使用 `10#` 归一化（[D18][D18]、[D19][D19]、[D20][D20]） | 已覆盖 |
| 14 | 用 `/sys/class/net/<if>/type == 512` 判断 PPP 设备；钩子按 `$1` 接口过滤默认路由（[T10][T10]） | 本项目没有 PPP 支持；2026-09-11 已登记为条件候选 | **补充 U1。** 内核 UAPI 确认 `ARPHRD_PPP` 为 512（[N3][N3]）。“目录存在不等于该接口由 pppd 管理”也应纳入该候选的判据 |
| 15 | `networkctl status \| grep -q` 在 pipefail 下因 SIGPIPE 误判（[T10][T10]） | `\| grep -qx` 和 `\| head -n1` 只用于 jq 的单值或短输出（[D21][D21]） | 低风险，无需修改（推断，置信度中高）。jq 的短输出在退出前一次写完，读端提前退出时写端没有剩余写入；模板中已有 SIGPIPE 注释，说明此前已注意到这一问题 |
| 16 | 部分 locale 下 mawk 输出逗号小数点（[T1][T1]） | 唯一带小数的 awk 输出只用于显示 | 不适用。上游关于 mawk 行为的说法未核实 |

## 4. 候选的进入条件与最小验证

### N1：高速率多流聚合对照

- 价值：单流在高速率下的上升或负载不足，可能来自单连接窗口、CPU 或对端，不一定是出口聚合瓶颈。加入同端点、同时窗的多流对照，可以区分“只限制单连接”和“聚合也受限”。
- 进入条件：用户把 ≥1 Gbps 的测量纳入目标；或者真实报告中较高档位反复出现 `UNDERDRIVEN`，或只有单流出现上升。
- 必须保留的约束：每条流都计入逐次预留；记录接收端能力；“多流干净”只能写成“未观察到聚合瓶颈”，不能写成“没有 policer”；不自动给出整形值。
- 最小验证：合成样本覆盖单流上升而多流干净、两者都上升、多流负载不足三种情况；只有在用户另行授权预算时，才做一次同端点的公网对照。

### N2：networkd 重启或链路重建后 fq 是否保持

- 当前依据：内核文档说明 `default_qdisc` 作用于新建 qdisc，多队列物理设备的 mq 叶子也会使用它（[N4][N4]）。fq 服务是开机执行一次的 oneshot，用于修正开机期间的状态（[D22][D22]）。平台生命周期覆盖两次真实重启，但没有覆盖 networkd 重启和链路重建（[平台说明](platform-support.md)）。
- 推断：没有 `[QDisc]` 配置时，systemd-networkd 重启不应改动 qdisc；设备重建时会按 `default_qdisc=fq` 创建 qdisc。以上未经运行验证，置信度中。
- 重新评估条件：verify 在网络服务重启、DHCP 续租或接口重建后报告非 fq；或者 Ubuntu 24.04 等使用 networkd 的平台需要更高的持久性支持等级。
- 最小验证：在现有平台虚拟机生命周期中，apply 后执行 `systemctl restart systemd-networkd`，然后检查 qdisc；另做一次接口 down/up 并复查。这需要单独立项，不修改产品。

### U1 / U2：补充既有候选

- U1（PPP/PPPoE）：判断 PPP 接口时用设备类型，不用名称或目录；钩子只处理触发它的那个接口；`/etc/ppp/ip-up.d` 存在只说明安装了 ppp，不说明接口由 pppd 管理。其他重新评估条件保持 [2026-09-11 原文](tcpfit-v0.5.8-research-2026-09-11.md#结论与重新评估条件)。
- U2（持久 HTB）：任何自动建议或应用流程，都必须把“取消”、“不完整”和“未发现上升”分成不同终态；负载低于已有整形值时，不得删除或覆盖已有配置。当前测量不自动应用配置，所以这条只约束未来设计。

## 5. 重新评估条件与剩余缺口

以下任一情况出现时，应重新判断“无需修改”：tcpfit 后续提交涉及 fq/mq 恢复、预算上界或证据完整性的新失败模式；本项目开始支持 ≥1 Gbps 测量或 PPP 拓扑；运行证据显示 fq 在网络服务事件后丢失。

未验证：上游 Release 中所有现场数字和测试结果；mawk 的 locale 行为；`netdev_budget_usecs` 的稳定分支回移版本；systemd-networkd 重启对 qdisc 的实际影响；本项目在高速单流下的表现。本轮没有运行任何第三方或产品脚本，因此证据最高只到源码实现和一手文档层级。

## 6. 已检查来源

源码链接固定到对应提交；在线文档检查日期为 2026-10-05。

[R1]: https://github.com/Kylin010/tcpfit/releases/tag/v0.5.9
[C1]: https://github.com/Kylin010/tcpfit/commit/a8ad4280e876bca066970ff97458003df30c7eae
[T1]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L802-L816
[T2]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L3080-L3141
[T3]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L3237-L3243
[T4]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L2797
[T5]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L2821
[T6]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L4374-L4393
[T7]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L2958-L2996
[T8]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L3014-L3033
[T9]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L3265-L3278
[T10]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L2085-L2327
[T11]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L465-L508
[T12]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L1068-L1108
[T13]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L1746-L1850
[T14]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/install.sh#L40-L64
[T15]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L3471-L3485
[T16]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L1022-L1050
[T17]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L539-L566
[T18]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L103-L114
[T19]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L2463-L2560
[T20]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L441-L446
[D1]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/dvt-measure.py#L111-L131
[D2]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/dvt-measure.py#L383-L409
[D3]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/dvt-measure.py#L147
[D4]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/dvt-probe.sh#L103
[D5]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/debian-vps-tuning.sh#L816
[D6]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/dvt-measure.py#L754
[D7]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/dvt-measure.py#L262-L322
[D8]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/tools/profile-template.sh.in#L1126-L1142
[D9]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/tools/profile-template.sh.in#L1089-L1100
[D10]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/tools/profile-template.sh.in#L400-L404
[D11]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/tools/profile-template.sh.in#L1369-L1374
[D12]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/install.sh#L114-L123
[D13]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/dvt-measure.py#L200-L203
[D14]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/dvt-measure.py#L575-L577
[D15]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/tools/profile-template.sh.in#L170-L175
[D16]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/tools/measurement_phase.sh.in#L37-L59
[D17]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/dvt_htb_transaction.py#L190-L203
[D18]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/tools/profile-template.sh.in#L192-L254
[D19]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/dvt-probe.sh#L76-L83
[D20]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/dvt-traffic-budget.sh#L43-L46
[D21]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/tools/profile-template.sh.in#L398
[D22]: https://github.com/alieismy/debian-vps-tuning/blob/1c5e922c2fce916d5217bf6c238d6cd50a8c51b0/tools/profile-template.sh.in#L1334-L1365
[N1]: https://github.com/systemd/systemd/blob/main/man/systemd.network.xml
[N2]: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=c180188ec02281126045414e90d08422a80f75b4
[N3]: https://github.com/torvalds/linux/blob/master/include/uapi/linux/if_arp.h
[N4]: https://docs.kernel.org/admin-guide/sysctl/net.html

- 上游：[v0.5.9 Release][R1]；[38fbf5a 提交](https://github.com/Kylin010/tcpfit/commit/38fbf5af30daf87735f2ffbc5e0905033ee2b86e)；源码锚点 T1–T20；早期 initcwnd 实测提交 [a8ad428][C1]。
- 本项目：源码锚点 D1–D22，固定到 `1c5e922`。
- 一手技术资料：[systemd.network 手册源文件][N1]（`[DHCPv4]` 中的 `InitialCongestionWindow=` 标注 v255，`[Route]` 中的同名项标注 v237）；[内核提交 c180188ec022][N2]；[if_arp.h][N3]；[内核 net sysctl 文档][N4]。
