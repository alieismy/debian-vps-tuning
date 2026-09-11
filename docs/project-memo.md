# 项目阶段备忘

文档性质：资料性状态与延期事项记录
当前阶段：rc.17 Pre-release 已发布并反向验证（Basic HTB200 reference 已完成；default-fq 对照、A/B/A 与 Core 尚未执行）
更新日期：2026-09-11（Asia/Singapore）

本文件是 `AGENTS.md` 指定的唯一项目阶段备忘入口，用于记录每轮对话工作的闭环状态，以及当前阶段不主动展开的后续候选事项。它不构成需求批准、生产变更授权、发布授权或下一阶段启动决定；控制规则以 [项目级 AGENTS.md](../AGENTS.md) 为准，具体验证事实以 [验证矩阵](validation.md) 和对应发布说明为准。

## 本轮记录：2026-09-11（Basic/endpoint 证据同步到相关文档）

### 已完成及证据

- 根据 `F:\Software\Software\翻墙\VPS\VMISS\测试\Basic\basic-htb200-reference-retry-20260911T064016Z.tar.gz` 的已核验结果，同步更新 `README.md`、`README.en-US.md`、`docs/network-tuning-and-test-strategy.md`、`docs/validation.md` 以及两个当前 HTB 研究 SOP。文档现在明确记录三次 HTB200 单流 IPv4 reference 已完成，吞吐约 187–190 Mbit/s，sender/主机级重传增量为 0，HTB root/FQ leaf drop/requeue 为 0，root `overlimits` 为正，且 reference 完成后已停止 candidate sweep。
- 将 endpoint closeout 作为受控私有证据同步到相关文档：归档外层 SHA-256 为 `6c1b30561866ef6913a4fb9d2227e7fdba6b322ac9c57500de02fb313fef0c16`，内部清单和路径安全检查通过，临时 server/observer unit、TCP/5201 listener、`iperf3` 进程和 UFW 规则已清理，其他 UFW 规则未变化；observer/closeout 原目录按要求保留，不作为公开 Release、issue 或仓库资产。
- 明确保留证据边界：Basic reference 不证明相对默认 `fq` 的因果收益，不证明真实 VLESS + REALITY + TCP 业务改善，不授权默认或持久 HTB；default-fq 对照、A/B/A、Core 和真实业务验收仍未执行。将 1C2G/Core A/B/A SOP 标为不因 Basic reference 自动启动，并把旧 rc.13/rc.14 命令块标作历史协议参考。

### 未完成门禁

- 本轮只做文档同步和静态一致性检查，没有连接或修改 VPS，没有运行 Basic、endpoint、Core、candidate sweep、A/B/A、重启、发布或生产变更。
- 文档同步不改变 rc.17 源码、生成 profile、fixture、Release 资产或目标机通用 L4 门禁；目标 VPS 的 default-fq 对照、真实业务验收、重启持久性和任何持久 HTB 仍未验证或未授权。

### 延期事项变化

- 无新增延期事项。Basic candidate sweep、Core、default-fq 对照、A/B/A、真实 VLESS + REALITY + TCP 验收、burst/cburst 比较和持久 HTB 继续保持停止或未授权状态。

### 当前成熟度判断

相关现行文档已与 Basic HTB200 reference 和 endpoint closeout 的最高证据层级一致；项目仍处于 rc.17 证据完整性实现候选阶段，未进入下一轮主动网络实验或生产变更阶段。

## 本轮记录：2026-09-11（tcpfit v0.5.8 当前源码吸收评估）

### 已完成及证据

- 只读冻结并检查 `Kylin010/tcpfit` 当前 `main`/`v0.5.8`：提交 `76331588af487a973d3445a1bf8bba7037d566ca`，`tcpfit.sh` SHA-256 为 `3a4d720bf7acb5b77eb24708ca17b6b42487628eefbdcb982e62454c2287358e`，release 为非 draft、非 prerelease；`bash -n tcpfit.sh`、`bash -n install.sh` 和 `python -m py_compile orchestrator/fleet.py` 通过。结论只达到固定源码、发布元数据和语法证据层级，未运行第三方 root 脚本、未连接目标 VPS、未产生公网流量。
- 已形成唯一研究记录 [tcpfit v0.5.8 研究与 rc.17 吸收评估](tcpfit-v0.5.8-research-2026-09-11.md)：v0.5.8 的主要新增是按 `dev`/`via` 关键字解析无 `via` 默认路由，以及可选 PPP `ip-up` 重拨钩子；goodput、重传/GiB、loss-spike、HTB rate/ceil 与 FQ leaf 语义具有条件参考价值，但固定 RTT、32 项 sysctl、`initcwnd/initrwnd`、持久 HTB、可变 `main` 安装、默认遥测和未上线 fleet 编排不满足 rc.17 边界。
- 对照当前 rc.17 源码确认：本项目默认路由网卡已按 `dev` 关键字发现，HTB/FQ root/leaf schema 3、socket 脱敏、共享流量 ledger、进程组回收、状态/所有权和非持久 HTB 已以更严格契约覆盖 tcpfit 的主要工程机制；当前没有需要因 tcpfit 参数包而修改默认 profile 的证据。

### 未完成门禁

- PPP/PPPoE 重拨后的 qdisc 持久化仍只是条件候选，尚未进入 rc.17。若未来纳入支持范围，必须先补需求、hook 所有权与哈希、schema/回滚、无 `via`/多路径/重拨 fixture 和 Linux root 生命周期证据。
- tcpfit 的维护者 PPPoE 实测、吞吐数字和 policer 归因未在本项目目标环境复现；不能把 README 或单次外部运行声明写成目标 VPS 性能证据。
- 本轮未修改网络实现、生成 profile、版本、发布资产或任何 VPS；现有 rc.17 本地/目标机/发布门禁状态不变。

### 延期事项变化

- 新增一项有边界的延期候选：“明确 PPP/PPPoE 拓扑需求后，评估受管 `ip-up` qdisc 恢复”；触发条件是用户提出该支持需求或出现可复现的 PPP 重拨后 qdisc 丢失问题。除此之外无新增延期事项。

### 当前成熟度判断

当前仍为 rc.17 证据完整性实现候选；tcpfit v0.5.8 研究未发现可直接替换 rc.17 默认参数或生命周期契约的内容。研究交付完成，后续只有 PPP/PPPoE 支持需求或新的可复现实验问题出现时才重新打开该候选。

## 本轮记录：2026-09-11（六台 VPS 版本统一建议）

### 已完成及证据

- 通过 GitHub Releases API 确认当前已发布的最新版本为 `v0.1.0-rc.17`，状态为非 draft、非稳定版的 Pre-release，发布时间为 `2026-09-10T08:34:26Z`；Release 提供 19 个固定资产，包括 `install.sh`、总控、六份 profile、迁移器、预算/证据/HTB 工具和 `SHA256SUMS`。未使用可变 `latest` 或分支内容。
- rc.17 的迁移器源码约束为：目标必须是 `0.1.0-rc.17`，来源允许 `rc.1`–`rc.16`；迁移过程要求旧版 verify、旧版 rollback/purge、第一次人工 reboot、目标版 preflight/apply、第二次人工 reboot 和最终 verify。迁移器本身不执行 reboot，也不声称控制台可达性或真实业务验收。
- rc.17 当前仍保持 17 项受管 sysctl、默认 `BBR + fq`、managed-state schema 4 和按资源/端口计算的缓冲矩阵；500 Mbps 不会因为版本升级自动启用 HTB。1C1G/500 Mbps 的自动缓冲仍为 16 MiB，1C2G/500 Mbps 为 32 MiB；1C1G/100–200 Mbps 均为 16 MiB。
- 结合已完成的 Basic 1C1G/200 Mbps HTB200 三样本零重传和 endpoint closeout 证据，当前没有依据把 HTB reference、candidate sweep 或真实业务测速作为六台 VPS 的版本迁移前置条件。版本迁移和性能/业务验收继续分层处理。

### 决策建议

- 建议最终将六台 VPS 的 **Debian VPS Tuning 管理版本统一到 rc.17**，以消除诊断字段、迁移器、证据 schema 和回滚行为的版本漂移；这是管理面统一，不表示六台机器应使用相同的端口参数、缓冲大小或 HTB 状态。
- 不建议一次性并行升级六台。先完成全量只读盘点并按业务风险分批：已完成 rc.17 的 Basic 保持现状作为已验证样本；随后在维护窗口升级 Core；再升级两台 500 Mbps；最后升级另外两台 1C1G/200 Mbps 与 1C1G/100 Mbps。每台都必须独立保存 checkpoint 和证据。
- 对当前确实由 rc.1–rc.16 管理、且 managed state 完整、旧版 profile 可取得并通过 verify 的主机，采用 rc.17 `migrate` 路径；不能用 rc.17 `apply` 直接覆盖旧状态。对旧状态损坏、来源是无状态契约的历史 v5/v6、无法取得旧版固定资产或无法验证备份/控制台的主机，先停在只读盘点，不猜测 rollback；必要时选择已验证备份和控制台可用后的干净重装路径。
- 同一 rc.17 profile 已形成 `VERIFIED` 状态后，服务商只改变带宽时使用 `reconfigure --port`：100→200 Mbps 对 1C1G 保持 16 MiB；1C2G/2G 200→500 Mbps 自动缓冲变为 32 MiB；500→200 Mbps 恢复 16 MiB。版本迁移和带宽重配置不能混成一次未审计操作。

### 未完成门禁

- 六台 VPS 的实际当前版本、Debian 主版本、运行内核、CPU/内存档、managed-state 状态/hash、端口记录、qdisc、swap、x-ui/Fail2ban 状态和业务维护窗口尚未形成当前统一清单；在该清单完成前不能给每台机器下达具体迁移命令。
- rc.17 是最新已发布候选，不是稳定版 `v0.1.0`；README 中部分旧段落仍固定写 `rc.16`，这些段落不能作为当前联网安装入口。实际安装必须以 rc.17 Release 的固定 `SHA256SUMS` 和对应资产为准。
- 版本统一后的重启持久性、3X-UI/Xray 严格 NOFILE、真实 VLESS + REALITY + TCP 和业务重传仍需按台验收；Basic HTB200 reference 的零重传不能替代这些证据。

### 延期事项变化

- 六台 VPS 的统一升级从“是否升级”转为“先盘点、后分批迁移到 rc.17”的建议路线；没有新增公网 benchmark、HTB、持久整形或系统参数变更授权。
- Core 与四台未完成盘点的 VPS 暂不执行远程变更；先收集只读清单，再按业务窗口安排迁移顺序。无新增延期事项。

### 当前成熟度判断

当前为 `RC17_LATEST_RELEASE_CONFIRMED_SIX_HOST_INVENTORY_REQUIRED_BEFORE_BATCH_MIGRATION`。下一最短动作是为六台 VPS 建立一份脱敏只读 inventory；完成后才能生成逐台 rc.17 迁移计划。

## 本轮记录：2026-09-11（Basic reference 与 endpoint closeout 全部闭合）

### 已完成及证据

- 已审阅 `dvt-endpoint-20260911T063156Z-closeout-20260911T071901Z.tar.gz` 及其 sidecar。外层 SHA-256 `6c1b30561866ef6913a4fb9d2227e7fdba6b322ac9c57500de02fb313fef0c16` 与 sidecar 一致；归档共 51 个成员，包括 49 个普通文件和 2 个目录，无重复路径、绝对路径、父目录穿越、链接或特殊对象。内部 `SHA256SUMS` 的 48 个条目全部通过并覆盖 observer 与 closeout 中除清单本身外的所有文件。
- closeout 合同绑定正确：observer pointer 精确指向 `/root/dvt-endpoint-20260911T063156Z`，server/observer units 分别为 `dvt-endpoint-20260911T063156Z-server.service` 与 `dvt-endpoint-20260911T063156Z-observer.service`，来源地址、IPv4、TCP/5201 和 `eth7` 与启动窗口记录一致。关闭前两个 unit 均为 active/running、RuntimeMaxUSec 为 2h；关闭后均为 inactive/dead、MainPID 0、LoadState not-found。
- closeout 结果与原始快照交叉核对通过：server/observer 均已停止，TCP/5201 listener 和 `iperf3` 进程均 absent，observer open-file 匹配为 0；UFW 删除前检查与删除前二次快照逐字节一致，精确删除 rule `9`，目标临时规则数量变为 0，其他 UFW 规则规范化集合 diff 为空；`inet dvt_iperf3` 表在关闭前后均 absent；pointer 已删除，observer 原目录按约定保留。
- endpoint journal 中启动阶段和 Basic 的 TCP connect 预检阶段各出现一次 `unable to receive cookie at server: Bad file descriptor`，这是无 iperf3 控制协议的裸 TCP 探测被 server 记录的预期日志；随后在 `06:40:33Z`、`06:45:48Z`、`06:51:04Z` 三个窗口各有一次来自 Basic 的正常 iperf3 接受记录，与三份 reference 样本一一对应。该 closeout 归档属于受控私有证据，包含 endpoint/source 地址和端口，不应直接公开发布。
- Basic reference 归档已在本轮前一阶段完成独立校验并判定为三次 HTB200 零重传；候选速率扫描已经停止，未发生新的性能流量、默认 profile 变更、持久 HTB 或重启。

### 未完成门禁

- Basic 与 endpoint 的本轮运行证据已闭合；不再有待执行的 endpoint 清理命令。observer 和 closeout 原目录仍按用户要求保留，未来删除必须使用精确路径和新的明确授权。
- 本轮仍没有 default root `fq` 对照、HTB200 A/B/A、Core 测试或真实 VLESS + REALITY + TCP 业务验收，因此不能把零重传归因于 HTB，也不能据此把 HTB 纳入默认或持久生产配置。
- 公开发布的 rc.17 资产、源码和 Release 状态不因这些目标机证据而改变；运行归档不应作为公开 Release asset。

### 延期事项变化

- 新 endpoint closeout 阻断已关闭，Basic HTB200 reference 与临时服务生命周期均已完成；无新增延期事项。
- Basic candidate sweep 保持停止状态；Core、default-fq 对照、A/B/A、真实业务验收、burst/cburst 比较和持久 HTB 仍属于未授权后续事项。

### 当前成熟度判断

当前为 `BASIC_HTB200_REFERENCE_AND_ENDPOINT_CLOSEOUT_VERIFIED_NO_MORE_BASIC_TRAFFIC`。本轮运行阶段完成；后续若继续推进，只能先形成新的对照测试设计并取得单独授权。

## 本轮记录：2026-09-11（Basic HTB200 reference 审阅通过，候选速率扫描停止）

### 已完成及证据

- 已审阅 `basic-htb200-reference-retry-20260911T064016Z.tar.gz`。外层 SHA-256 `1f95569796bbee19b88217e29a2ae84c33da44b6d2a59057ab7542117e4336a8` 与独立 sidecar 一致；归档共 163 个成员，包括 148 个普通文件和 15 个目录，无重复路径、绝对路径、父目录穿越、链接或特殊对象。wrapper 清单 147/147、reference 清单 112/112、三份 benchmark 内层清单及各级 `COMPLETED` 对 manifest/result/analysis 的摘要绑定均通过。
- reference 为 schema 3、analyzer `0.4.0`、`reference-screen`，三个样本的 evidence-contract、measurement、shaping-exposure、root/leaf qdisc-health 和 resource gate 全部有效。`REVIEW_REQUIRED` 是该模式预期的人工判读状态，不是执行失败，也不会产生候选 shortlist 或持久化授权。
- 三个 HTB200 单流 IPv4 upload 样本的 sender/receiver 分别为 `190.302/189.869`、`187.995/187.822`、`187.160/187.148` Mbit/s；sender 中位数 `187.995` Mbit/s，receiver 中位数 `187.822` Mbit/s。三次 iperf3 sender retransmits、主机级 `TcpRetransSegs` 增量均为 0。
- 三次均识别到真实 `HTB root 1:` 与 `FQ leaf 10: parent 1:10`。HTB root `overlimits` 分别为 5375、5380、5316，证明 200 Mbit/s 整形器在测量窗口内实际参与调度；root/leaf drops 和 requeues、softnet drops/time-squeeze、接口 drops/errors 均为 0。CPU idle 为 `94.449%–96.565%`，steal 为 `0.390%–1.163%`，没有触发 1 vCPU 资源门禁。
- 原始 iperf3、TCP、link 和 qdisc 前后计数已与 schema 3 phase summary 逐项交叉核对。脱敏 socket 辅助证据保留了 `pacing_rate`、`delivery_rate`、`minrtt`、`rcv_ooopack`、`snd_wnd`、`rcv_wnd` 等实际出现字段，没有保留 IPv4 endpoint、端口、PID、进程名或 inode；未出现的可选字段没有被伪造。
- 流量 ledger 将本次计划上限 `975000000` bytes 结算为实际已知 `706871296` bytes，状态为 `COMMITTED`，reserved 回到 0。保留第一次失败的 `975000000` bytes 保守计账后，window 总 accounted 为 `1681871296` bytes，受控预算尚余 `6908063296` bytes（约 `6.434 GiB`）。
- wrapper 恢复证据通过：x-ui 与 Fail2ban 均 active，严格 `dvt verify` 为 0 警告，HTB runtime 已停止，root qdisc 恢复为唯一 `fq`，class 为空；没有创建持久整形。
- 人工停止判断：HTB200 已在固定 endpoint、固定地址族、固定单流负载的三次 reference 中稳定达到约 187–190 Mbit/s 且零重传。当前没有证据支持继续扫描 180/190/195 Mbit/s；为避免无收益流量消耗，candidate sweep 在本轮停止。
- 已形成新窗口 closeout 操作者脚本 `endpoint-closeout-fresh-reference-window-20260911.sh`，固定绑定 `/root/dvt-endpoint-20260911T063156Z`、其 server/observer units、Basic 来源、TCP/5201 和 `eth7`。脚本允许 unit 仍 active 或已自然到期两种终态；校验 pointer/READY/元数据和精确 UFW 规则后停止仍 active 的两个 unit，验证无 listener、iperf3 进程和 observer open fd，仅删除目标临时 UFW 规则及 pointer，保留 observer 原目录，并生成内部清单、归档和 sidecar。操作者副本 SHA-256 为 `ae3dfb5af57bc3030d330487707261730afa0485dbf7cf55fca0595c418fc013`；Bash `-n`、复制摘要和 UFW 精确端口/冲突 fixture 通过。本机无 ShellCheck，因此未新增该脚本的本地 ShellCheck 证据。

### 未完成门禁

- 新 endpoint 窗口在最后一次现场证据中仍可能运行，必须尽快执行已校验 closeout，并下载审阅其 `.tar.gz` 与 `.tar.gz.sha256`。在归档完整性、两个 unit 终态、listener/进程、临时 UFW 规则、pointer 和其他 UFW 规则未变化证据闭合前，不清理 endpoint 上的 observer/closeout 原目录。
- 本轮只证明 Basic 在隔离 iperf3 单流路径下的临时 HTB200 reference 稳定，不能区分“HTB 平滑突发”的增益与该时段路径本来就无丢包，也不能证明服务商 policer 存在、默认 root `fq` 存在问题，或真实 VLESS + REALITY + TCP 业务重传已改善。
- 不再执行 Basic candidate sweep。若仍要判断是否将 HTB 纳入默认或持久配置，需要另行设计并授权低流量、同时间窗的 default `fq` 与临时 HTB200 A/B/A，再结合真实代理业务证据；当前 reference 本身不授权该变更。

### 延期事项变化

- Basic 的 180/190/195 Mbit/s candidate sweep 从“reference 后待决定”变为“依据三样本零重传停止”，不再作为当前主线待办。剩余受控 benchmark 预算保留，不因余额存在而继续消耗。
- 新 endpoint closeout 归档成为唯一近期运行收尾事项。Core 测试、默认/持久 HTB、burst/cburst 比较、多流并发和真实业务 A/B/A 均未启动。
- 无新增 sysctl、默认 profile、永久服务、重启或生产代理配置变更。

### 当前成熟度判断

当前为 `BASIC_HTB200_REFERENCE_VERIFIED_ZERO_RETRANSMITS_CANDIDATE_SWEEP_STOPPED_ENDPOINT_CLOSEOUT_READY`。下一最短动作是在 endpoint 执行 closeout、下载并审阅归档；不运行新的性能样本。

## 本轮记录：2026-09-11（新 endpoint READY，Basic HTB200 reference 重试器就绪）

### 已完成及证据

- endpoint 新窗口 `dvt-endpoint-20260911T063156Z` 已建立并通过启动器终态：server/observer units 分别为 PID 109596/109594，均 `LoadState=loaded`、`ActiveState=active`、`SubState=running`、`RuntimeMaxUSec=2h`；IPv4-only TCP/5201 listener 为 `0.0.0.0:5201`，endpoint loopback PASS，UFW 中恰有一条只允许 Basic 固定 IPv4 来源的临时规则。启动器退出码为 0，理论到期时间为 `2026-09-11T08:31:56Z`。
- 已重新读取旧失败归档中的原 ledger 与 plan：window id 为 `basic-htb-ref-20260911T033823Z`，预算 `8589934592` bytes，reserved 0，accounted `975000000`，唯一 entry 为 `FAILED_CONSERVATIVE`；旧 plan 是 schema 3、3 个 HTB200 样本、单流 IPv4 upload、10 秒测量、3 秒 omit 和 300 秒冷却，计划 payload 上界同为 `975000000` bytes。
- 已形成 `basic-run-htb200-reference-retry-20260911.sh`。脚本要求 endpoint 至少剩余 1800 秒，验证 Basic 到固定 endpoint 的 `eth0`/固定源 IPv4 路由和 TCP connect、iperf3 client-only、rc.17 verify、稳定 HTB 执行器、preflight、x-ui/Fail2ban、旧 ledger 完整合同和旧 `reference/INCOMPLETE`；随后停止 x-ui，在新的时间戳 session/reference 目录运行原三样本 HTB200 计划并复用同一 ledger/window/budget。
- 重试器的 EXIT/signal 收尾会在需要时调用稳定执行器 `stop`，验证 preflight、唯一 root `fq`、空 class，恢复并验证 x-ui、Fail2ban 和 `dvt verify`，保存前后 ledger 与 reference 终态，并生成 wrapper 内部清单、`.tar.gz` 和 sidecar。操作者副本 SHA-256 为 `2822a9f2cefbca1f3205628ca75b11fc0f4aa718515bd07b7e8ccc4550330df7`；复制前后摘要一致、Bash `-n` 通过，旧 ledger jq 合同与 route parser fixture 通过。脚本尚未执行，没有产生新的 Basic 流量或 qdisc 变更。

### 未完成门禁

- 必须在 endpoint 到期前上传并校验 Basic 重试器，以限时 transient systemd unit 启动；若启动器发现 endpoint 剩余不足 1800 秒、TCP 不通、ledger 漂移、依赖/verify/preflight 失败，应保留其无流量或失败归档并重新建立 endpoint 窗口，不能放松门禁。
- reference 执行后必须下载并审阅 wrapper 归档、sidecar、reference 内部 `SHA256SUMS`、schema 3 analysis、三个 stage、iperf sender/receiver、root/leaf qdisc、CPU/steal、softnet、接口、恢复和 ledger 结算。`REVIEW_BLOCKED` 是有效的停止结论，不能通过重试或提高并发自动绕过。
- 未完成 reference 审阅前不得运行 candidate sweep。即使 reference 为 `REVIEW_REQUIRED`，也必须先判断 HTB200 重传是否已可接受；只有仍反复偏高且替代解释不足时，才需要用户另行确认 candidate sweep。

### 延期事项变化

- 新 endpoint 前置阻断已关闭，主线进入 Basic reference 重试执行。旧 endpoint 与新 endpoint 的服务器端证据目录继续保留，待本窗口 closeout 归档后统一精确清理。
- 无新增默认/持久 HTB、sysctl、burst/cburst、P2/P4 并发、candidate sweep、A/B/A 或 Core 流量授权。

### 当前成熟度判断

当前为 `FRESH_ENDPOINT_READY_BASIC_HTB200_REFERENCE_RETRY_RUNNER_READY`。下一最短动作是在 Basic 运行已校验的 transient reference unit并回传 wrapper 归档；结果审阅前不进入候选速率测试。

## 本轮记录：2026-09-11（旧 endpoint closeout 归档通过，新窗口启动器就绪）

### 已完成及证据

- endpoint 已执行经固定摘要验证的 closeout，脚本输出 `endpoint_closeout=PASS`、`endpoint_closeout_exit=0`：删除的 UFW rule number 为 1，旧 observer pointer 已删除，observer 原目录保留；TCP/5201 listener、iperf3 进程、目标临时 UFW 规则和旧 `inet dvt_iperf3` table 均为 absent，其他 UFW 规则为 unchanged。
- 已审阅下载的 `dvt-endpoint-20260911T033753Z-closeout-20260911T061402Z.tar.gz`。外层 SHA-256 `ec61d60c291cb9230cb76b10d7c4cabd6a7f8014bbb9c62bc28fdcfb1b263f9e` 与 sidecar 一致；35 个成员由 33 个普通文件和 2 个目录组成，无重复、绝对路径、父目录穿越、链接或特殊对象；内部 `SHA256SUMS` 32/32 覆盖并通过。
- 归档内 pre/delete/post 证据确认：UFW 检查与删除前快照逐字节一致，删除命令报告成功，目标规则消失，其他规则的规范化集合 diff 为空；listener、iperf3 进程和旧 nft table 前后均为空，`dvt-*` units 前后为空，记录的 server/observer unit 前后均不 active，归档的 pointer 副本精确指向旧 observer。旧 endpoint 窗口达到可复核 closeout 终态。
- 归档确认 endpoint 到 Basic 的观测接口仍为 `eth7`；旧 unit 名为时间戳隔离的 `dvt-endpoint-20260911T033753Z-server.service` 与 `...-observer.service`。已据此形成新的 `endpoint-start-fresh-reference-window-20260911.sh`，固定 Basic IPv4 来源、TCP/5201、IPv4、`eth7` 和 7200 秒 RuntimeMax；脚本只在无 pointer、无 listener/iperf3/dvt unit/旧 nft table/5201 UFW 规则且到 Basic 路由走 `eth7` 时创建新窗口，并在部分失败时尝试停止本次新 unit 和撤销本次新增规则。
- 新窗口启动器通过 Bash `-n`、复制前后摘要一致性和 UFW 合成 fixture；fixture 同时验证 `5201/tcp` 不会误匹配 `15201/tcp`。操作者副本 SHA-256 为 `551baaff2a228459fbb74513a7252347243eb6170568efeedd9003e6873b49cc`。该脚本尚未执行，没有启动新 listener、修改新规则或产生测试流量。

### 未完成门禁

- 必须先在 endpoint 上传并核验新窗口启动器及 sidecar，再执行一次；取得新的 session id、pointer、两个 active/2h unit、TCP/5201 listener、仅 Basic `/32` 的 UFW rule 和 endpoint loopback PASS 后，才能从 Basic 做 TCP connect。
- Basic reference 仍未重跑。新 endpoint 门禁通过后，必须先在 Basic 复核 iperf3 client-only、rc.17 verify、HTB preflight、原 ledger/window/budget 不变量和现有 `FAILED_CONSERVATIVE` reservation，再建立新的 reference output directory；不能覆盖旧 `reference/INCOMPLETE`，也不能释放第一次失败的保守预算占用。
- candidate sweep、A/B/A、Core 测试和默认/持久 HTB 继续未启动。reference 完成后必须先审阅 schema 3 的 measurement、shaping exposure、resource 和 root/leaf qdisc 健康，再决定是否有理由授权 candidate sweep。

### 延期事项变化

- 旧 endpoint server、observer、pointer 和临时 UFW closeout 阻断已关闭；服务器端旧 observer/closeout 原目录暂时保留，待整个新 reference 窗口归档确认后再统一做精确清理，不阻塞创建时间戳隔离的新窗口。
- 无新增默认 profile、sysctl、永久 HTB、burst/cburst、额外并发或额外流量范围。Basic 的服务商剩余配额和共享 ledger 上限不变。

### 当前成熟度判断

当前为 `OLD_ENDPOINT_CLOSEOUT_VERIFIED_FRESH_ENDPOINT_START_READY`。下一最短动作是建立一个全新的两小时 endpoint 窗口并回传 READY/units/listener/UFW 证据；在此之前不运行 Basic reference。

## 本轮记录：2026-09-11（旧 endpoint server 自动结束，observer closeout 待确认）

### 已完成及证据

- endpoint 于 `2026-09-11T05:50:05Z` 的只读复核显示旧 `dvt-iperf3-server.service` 已被 transient `--collect` 清理：`LoadState=not-found`、`ActiveState=inactive`、`SubState=dead`、MainPID 0，TCP/5201 无 listener；因此旧 server 不需要再 stop，也不能作为下一 reference 的服务端窗口复用。
- 旧独立 `inet dvt_iperf3` table 已不存在。UFW 中仍恰有一条 `5201/tcp ALLOW IN`，来源为 Basic `/32`，注释为 `TEMP DVT iperf3`；该规则属于旧窗口，需在 observer 证据停止和归档后删除。
- 修正版只读检查确认 observer pointer 是 root:root、mode 600 的普通文件并精确指向 `/root/dvt-endpoint-20260911T033753Z`；observer 目录是 root:root、mode 700 的普通目录，inventory 只有既有元数据、pre 快照和截至 `04:07:52Z` 的 `vmstat.txt`。所有 `dvt-*` unit/unit-file 查询为空，`observer_open_file_matches=0`，没有 iperf3 listener 或进程，因此 observer 已静止，可以进入归档和精确 ACL 清理。
- related process summary 中的 PID 92016 是 MobaXterm 的系统监控循环，因为命令行含 `/proc/net/dev` 被宽匹配命中；它没有持有 observer 文件，也不是 `dvt-*`/iperf3 进程。上一轮 `UNEXPECTED_PATH` 已确认只是辅助检查遗漏 `/root/dvt-endpoint-*` 合法前缀，不是 endpoint 故障。
- 已形成旧 endpoint closeout 脚本并完成本地 Bash `-n` 与合成 UFW fixture。脚本在变更前再次验证 pointer、observer 所有权和对象类型、记录 unit 非 active、无 open fd、无 iperf3 进程/listener、旧 nft table 不存在，以及临时 UFW 规则精确匹配数量为 1；删除前再次比较 UFW 快照，删除后验证目标规则消失且其他规则的规范化集合完全不变。脚本保留 observer 原目录，删除已归档的旧 pointer，生成内部清单、`.tar.gz` 和外部 SHA-256，不启动服务或产生测试流量。操作者副本 `endpoint-closeout-old-window-20260911.sh` 的 SHA-256 为 `143783eddfb33f9cd7d8669d448771657f872f69fe1da7f57b1a2c4d7628d597`，复制前后摘要一致且副本再次通过 Bash `-n`。

### 未完成门禁

- 旧 endpoint closeout 脚本尚未在 endpoint 执行，因此临时 UFW `/32` 规则和旧 pointer 仍存在，完整归档、SHA-256、其他 UFW 规则未变化以及无 listener/无临时规则终态仍待回传。此门禁闭合前不得启动新的 endpoint transient server 或 Basic reference。
- closeout 成功后，必须先下载并审阅 `.tar.gz` 与 `.tar.gz.sha256`；在外部归档完整性确认前保留 endpoint 上的 observer 与 closeout 原目录，不做额外删除。

### 延期事项变化

- endpoint 阻断从“observer 命名和终态待确认”收窄为“observer 已确认静止，closeout 归档和 UFW 临时规则精确删除待执行”。Basic iperf3 客户端就绪状态不变。
- 新增一次性辅助检查修正：endpoint observer 合法路径前缀必须包含实际采用的 `/root/dvt-endpoint-*`，相关 unit 查询应覆盖 `dvt-*`，不能只匹配 server 命名。无新增调优、流量或持久化范围。

### 当前成熟度判断

当前为 `BASIC_CLIENT_READY_OLD_ENDPOINT_OBSERVER_QUIESCENT_UFW_CLOSEOUT_PENDING`。下一最短动作是在 endpoint 执行已自检的 closeout，下载并审阅归档；成功后才能建立全新的 endpoint/reference 窗口。

## 本轮记录：2026-09-11（Basic iperf3 客户端安装与低流量验收通过）

### 已完成及证据

- 审阅 `dvt-basic-iperf3-client-install-20260911T050958Z.tar.gz`。外层 SHA-256 `970e3cb5abb11fc3beff9926f2dc0b83437dd7cc56dc3bba32296d040f92bf9d` 与独立 sidecar 一致；18 个归档成员无绝对路径、父目录穿越、链接或设备节点；内部 `SHA256SUMS` 15/15 通过，安装脚本 `exit_code=0`。
- Basic 从 Debian 13 trixie 当前 mirror 安装 `iperf3 3.18-2+deb13u2`、`libiperf0 3.18-2+deb13u2` 和 `libsctp1 1.0.21+dfsg-1`，共下载约 163 kB、增加约 425 kB；`0 upgraded`，没有执行系统升级或 reboot。`/usr/bin/iperf3` 报告 iperf 3.18，并支持 socket pacing 等本次 TCP client 所需能力。
- 安装后已执行 `systemctl disable --now iperf3.service`；Basic 上没有 TCP/5201 listener，client-only 门禁通过。安装前后 `x-ui.service` MainPID 均为 38980，Fail2ban active，`proxy-vps-fq.service` active/exited；严格代理 verify 为 0 警告，说明安装没有重启或破坏代理服务。
- 安装前后 `eth0` 都保持同一唯一 root `fq` handle `8002:`、class 为空，drops/overlimits/requeues/backlog 均为零；HTB preflight 再次通过，managed state SHA-256 仍为 `a8a4242d262b096050bf54ea272a69e5739137f7fe662c520de3c5cbd9fb63a0`。安装窗口没有启动 HTB 或运行 benchmark。

### 未完成门禁

- 旧 endpoint transient unit、observer、临时 UFW `/32` 规则的 closeout 归档尚未回传。新的 reference 前必须确认旧 unit/listener 已停止、旧临时规则已删除，然后创建全新两小时 unit、observer 和临时 allow，并重新验证 endpoint loopback、Basic TCP connect 与接收端资源基线。
- 下一次 Basic reference 尚必须使用新 output directory，保留旧 `reference/INCOMPLETE`；继续复用 `/root/basic-htb-ref-20260911T033823Z/traffic-ledger.json` 和同一 window ID，使首个 `FAILED_CONSERVATIVE` reservation 继续占用预算。reference 仍固定 IPv4、单流、upload、3 个 HTB200 样本、3 秒 omit、10 秒测量与 300 秒冷却。
- `iperf3.service` 的 inactive 和本机无 listener 已验证；下一 reference 前还应补一个 `systemctl is-enabled` 只读结果，明确记录 client 包的持久 daemon 状态。安装验收不等于 endpoint 或 reference 通过。

### 延期事项变化

- “Basic 缺少 iperf3 客户端”阻断已关闭；主线转到 endpoint 旧窗口 closeout 和新 reference 窗口建立。rc.17 runner 的依赖预检时序改进仍作为下一版本候选，不阻塞当前使用已安装客户端继续实验。
- 无新增默认 profile、sysctl、HTB 参数、持久整形或额外流量授权；candidate sweep、A/B/A、Core 测试和真实代理性能复验继续未启动。

### 当前成熟度判断

当前为 `BASIC_IPERF3_CLIENT_READY_AWAITING_FRESH_ENDPOINT_REFERENCE_WINDOW`。Basic 的客户端、调优状态、代理服务、Fail2ban、root `fq` 与 HTB preflight 均已闭合；尚不能开始主动流量，直到旧 endpoint 窗口安全结束并以全新临时服务、ACL、observer 和可达性证据重新建立 reference 前置门禁。

## 本轮记录：2026-09-11（Basic reference 失败归档审阅：确认缺少 iperf3，恢复通过）

### 已完成及证据

- 审阅用户下载的 `basic-htb-ref-20260911T033823Z-failure-bundle-20260911T045901Z.tar.gz`。外层 SHA-256 `9c352a0ee3bb8a2dcaf012b1a7b7f816053929ee46502dedb98cba99ad5042f3` 与独立 sidecar 一致；70 个归档成员没有绝对路径、父目录穿越、符号链接、硬链接或设备节点；独立 failure-review 的 36 项内部 `SHA256SUMS` 全部通过。
- 根因已经确认：Basic 的 `tool-prerequisites.txt` 明确为 `iperf3=MISSING`，而 `setsid`、`timeout`、`jq`、`tc`、`ss` 均存在；首阶段 `benchmark.log` 只有“benchmark 需要已安装 iperf3；脚本不会自动安装软件包”。profile 在创建 benchmark 输出和调用 `run_benchmark_phase` 前即终止，因此没有启动 iperf3 进程、没有 `upload.iperf3.json`、phase summary、`benchmark-result.json` 或性能样本。
- HTB 生命周期本身通过：200 Mbit/s root HTB、class `1:10` 和 parent `1:10` 的 FQ leaf 建立成功，前后 ACTIVE gate 均通过；runner 在 `03:38:41Z` 正常执行 managed stop，`stopped_by_watchdog=false`、`already_restored_before_stop=false`，随后 preflight 通过。pre-stop HTB root/leaf/class 各累计 34,684 bytes、492 packets，drop/overlimit/requeue/backlog 均为零；这些是约 15 秒内的 SSH/控制与背景流量，不是 iperf throughput evidence。
- 失败时外层恢复立即把 `x-ui.service` 恢复为 active，`recovery-state.txt` 已记录 root `fq`。`04:59Z` 的独立复核再次证明 active state 缺失、无活动 watchdog、唯一 root `fq`、class 为空、preflight 通过；`x-ui.service` PID 在复核前后未变化，Fail2ban 和 `proxy-vps-fq.service` 均为 active，严格代理 verify 返回 0 且警告数 0。Basic 无需 reboot 或额外 qdisc 恢复。
- 共享 ledger 已按既有 fail-closed 契约把完整计划上界 `975000000` bytes 记为 `FAILED_CONSERVATIVE`，`actual_known_bytes=null`；这不是服务商实际流量。原 8192 MiB 账本仍有 `7614934592` bytes（约 7.092 GiB）可用，足以继续保守覆盖一次新三样本 reference 和一次既定 candidate sweep，并剩余约 1.803 GiB；后续应复用同一 ledger，保留失败 reservation，不得编辑或释放该条目。
- 已形成仅安装 Basic 客户端的 `basic-install-iperf3-client.sh`，并通过本地 Bash `-n` 与复制后 SHA-256 一致性检查。脚本只运行 `apt-get update` 和 `apt-get install --no-install-recommends iperf3`，预置不启动 iperf3 daemon，随后显式 disable/stop 本机 `iperf3.service`，验证 Basic 不监听 TCP/5201、HTB preflight、root `fq`、严格代理、Fail2ban，并生成独立证据归档；不 reboot、不停止 x-ui、不运行 benchmark。

### 未完成门禁

- Basic 尚未实际安装 `iperf3`。安装完成后必须取得 `/usr/bin/iperf3` 版本、包状态、本机无 TCP/5201 listener、无 active iperf3 service、root `fq`、HTB preflight 和严格代理 verify 证据；安装本身不构成 reference 通过。
- endpoint 本次 transient unit/observer 和临时 UFW `/32` 规则尚未提供 closeout 归档。必须先停止并归档旧 endpoint 窗口、删除临时规则；下一次 reference 需要新的两小时 unit、observer 和前置面板快照，不复用已经过期的运行窗口。
- 新 reference 必须使用新的 output directory，但应复用现有 ledger/window 以保留 `FAILED_CONSERVATIVE` 占用。只有新 reference 的 3 个 stage、schema 3 analyzer、manifest 和 `COMPLETED` 全部闭合后，才能人工判断是否需要 candidate sweep。

### 延期事项变化

- 新增后续版本的最小运行可靠性修复候选：HTB runner 应在预算 reserve、创建 session 和修改 qdisc 之前检查 `iperf3`、`setsid` 和 `timeout`，避免已知缺失依赖仍进入 HTB/失败保守结算。该缺口不影响 HTB restore 安全性，也不改变 rc.17 已发布资产；是否形成 rc.18 需在当前运行验证之外单独实施和发布。
- 一次性 failure-review 辅助脚本把 stage 错按 `${SESSION_ROOT}/stages` 定位，而真实目录是 `${SESSION_ROOT}/reference/stages`，导致 `selected-evidence.txt` 的便捷摘录显示 absent；归档同时完整包含原始 session，因此本次诊断与证据没有丢失。后续如复用该工具须先修正路径，不得把便捷摘要当作原始文件缺失。
- candidate sweep、A/B/A、Core 测试、真实代理性能复验、默认 profile 修改和持久 HTB继续未启动。

### 当前成熟度判断

当前为 `BASIC_RUNTIME_RECOVERED_REFERENCE_BLOCKED_BY_MISSING_IPERF3_CLIENT`。本次失败证明 rc.17 HTB 启停和恢复门禁正常，也暴露了 runner 的依赖预检时序缺口；它没有提供任何吞吐、重传或 HTB 收益证据。下一最短动作是关闭旧 endpoint 窗口并在 Basic 安装仅客户端用途的 `iperf3`，完成低流量验收后再建立全新 endpoint/reference 窗口。

## 本轮记录：2026-09-11（Basic HTB200 reference 首阶段失败，转入证据保全）

### 已完成及证据

- 用户在 Basic 上完成 rc.17 版本绑定、严格代理验证、稳定 HTB 执行器语法复核、同一 endpoint TCP 可达性检查和 HTB preflight；这些门禁均通过。停止 `x-ui.service` 后启动三样本 HTB200 reference，新会话目录为 `/root/basic-htb-ref-20260911T033823Z`。
- runner 只进入首个 `01-R-s1-htb200` 阶段即失败，外层报告 `benchmark、ACTIVE gate 或恢复失败；退出码 3`，reference wrapper 最终返回 1。没有第二、第三样本，没有 `COMPLETED` 终态，也没有形成可用于 analyzer 或候选速率决策的有效 HTB200 reference。
- 代码复核确认，stage runner 将 benchmark、后置 ACTIVE、HTB stop 和 postflight preflight 合并到同一失败出口；因此终端摘要本身不能定位根因。退出码 3 与 profile 的 `EXIT_UNSUPPORTED` 一致，且用户展示的前置检查没有 `iperf3 --version`；“Basic 缺少 `iperf3` 客户端或 benchmark 专用依赖”是当前高可能性假设，仍须由原始 `benchmark.log`、`benchmark/INCOMPLETE`、`upload.iperf3.json` 和工具存在性证据确认。
- 已为操作者形成只读优先的失败审阅脚本并通过 Bash `-n` 语法检查。脚本不改写原始失败目录；它先保存 `/run/htb-aggregate-experiment`、qdisc/class、watchdog、service 和工具前置条件，再在存在合法 active state 时调用稳定执行器的受管 `stop`，验证唯一根 `fq`、空 HTB class、无 active state、无活动 watchdog和 postflight preflight，恢复 `x-ui.service` 并执行严格 verify，最后把原始 session 与独立 review 目录一起打包并生成 SHA-256。

### 未完成门禁

- Basic 当前是否已经由 runner trap 恢复到唯一根 `fq`、是否仍有 active state/watchdog、`x-ui.service` 是否恢复 active，以及严格 verify 是否再次通过，均尚无用户回传的现场证据。上述状态确认优先于任何依赖安装、reference 重试、候选 sweep 或重启。
- 首阶段的实际失败点和是否发送过任何 iperf payload 尚未确认。共享 ledger 按 runner 设计应把失败 reservation 以完整计划上界保守结算，但实际 ledger 文件与条目还没有采集，不能把代码预期写成目标机已证事实。
- endpoint 临时 iperf3 unit、observer、临时 UFW `/32` 规则及接收端证据仍须在 Basic 证据保全后结束并归档。本次失败会话不得原地覆盖或重跑；如确认只是缺少客户端依赖，也必须使用新的 session 目录和经复核的预算状态。

### 延期事项变化

- HTB200 reference 从“可开始”退回“首阶段失败、等待证据保全和根因诊断”。180/190/195 candidate sweep、A/B/A、Core 测试、真实代理性能复验和持久 HTB继续未启动。
- 无新增默认 profile、sysctl、HTB rate/burst/cburst、持久化或额外高流量 campaign 变更。只有证据确认 rc.17 工具存在明确实现缺陷时，才新开最小修复；缺少 VPS 运行依赖属于运行前置条件缺口，不自动构成发布缺陷。

### 当前成熟度判断

当前为 `BASIC_HTB200_REFERENCE_STAGE1_FAILED_EVIDENCE_PRESERVATION_AND_RECOVERY_PENDING`。rc.17 的本地/发布完整性和此前 HTB190 smoke 证据不变，但此次运行没有形成任何有效 reference 结论；在 Basic 的 root `fq`、代理服务和失败归档闭合前，不得继续主动流量测试或根据该失败判断 HTB 是否有效。

## 本轮记录：2026-09-11（endpoint 最终门禁与 Basic HTB190 冒烟通过）

### 已完成及证据

- endpoint 最终复核通过：transient iperf3 unit 为 active/running，IPv4 `0.0.0.0:5201` 正常监听；UFW 中恰有一条只允许 Basic 实际源 IPv4 访问 TCP/5201 的临时规则；旧 `inet dvt_iperf3` table 已不存在；删除旧 table 后 endpoint loopback TCP 检查返回 0，`endpoint_final_gate=PASS`。
- Basic 的 rc.17 绑定通过：`/usr/local/bin/dvt` 指向固定 `0.1.0-rc.17` Release，managed profile 为 `debian13-1c1g`、schema 4 语义下的 `VERIFIED`、200 Mbps；冒烟前严格代理验证警告数为 0。当前 Release 中 HTB 执行器源资产和安装到 `/usr/local/sbin/htb-aggregate-experiment` 的稳定副本均通过 manifest SHA-256 校验。
- 冒烟前 Basic 到同一 endpoint IPv4/TCP 5201 再次返回 `tcp_connect_exit=0`，HTB preflight 通过。停止 `x-ui.service` 后，10 秒 HTB190 smoke 成功建立 `htb root → class 1:10 rate=ceil=190Mbit → fq parent 1:10`，ACTIVE 联合门禁和 40 分钟 watchdog 均通过。
- 冒烟活动期 root HTB、FQ leaf 和 class 均为 drop 0、requeue 0、backlog 0；`overlimits=0` 只说明零高带宽 payload 的 smoke 没有产生整形暴露，符合该阶段用途，不能解释为 HTB 功能失败或路径无丢包。执行器在 10 秒后受管停止，`stopped_by_watchdog=false`、`already_restored_before_stop=false`。
- 冒烟后 active state 消失，watchdog inactive，HTB class 列表为空，唯一根 qdisc 恢复为 `fq`，后置 preflight 通过。`x-ui.service` 恢复为 active，新主进程及 Xray 子进程 NOFILE 均为 65536，严格验证再次为 0 警告；最终 `smoke_gate=PASS`。

### 未完成门禁

- HTB200 reference 尚未发送 payload。正式窗口前仍需保存 Basic 与 endpoint 服务商面板额度快照，在 endpoint 重新建立完整两小时的 transient iperf3 unit，并启动覆盖 reference 全窗口的有界 CPU/接口观察器。
- reference 必须继续固定同一 IPv4 endpoint/TCP 5201、Basic `eth0`、单流、3 样本、每样本 3 秒 omit 加 10 秒测量、阶段间 300 秒冷却，并使用新建 8192 MiB 共享 ledger。计划 payload 上界为 975,000,000 bytes，约 929.8 MiB 或 0.908 GiB，不包含协议、重传及服务商计费差异。
- reference 结束后仍须证明每阶段受管恢复、最终 root `fq`、active state 缺失、`x-ui.service` 严格验证、证据清单与完成标记通过，并取得 endpoint 同窗口资源证据和两端面板对账。若为 `REVIEW_BLOCKED` 或任一门禁异常，保留现场并停止；即使为 `REVIEW_REQUIRED` 也必须先人工审阅，不能自动进入 sweep。

### 延期事项变化

- endpoint 终态检查和 Basic HTB190 smoke 从待办更新为通过，主线推进到三样本 HTB200 reference。180/190/195 candidate sweep、A/B/A、Core 迁移/测试和持久 HTB继续未启动。
- 无新增默认 profile、sysctl、HTB 参数、持久化或额外 campaign 范围。上一轮登记的历史 SOP 文字漂移继续作为后续版本候选，不影响使用 rc.17 wrapper 的当前受控 reference。

### 当前成熟度判断

当前为 `BASIC_HTB190_SMOKE_PASS_READY_FOR_BOUNDED_HTB200_REFERENCE`。主机、endpoint、临时 ACL、稳定执行器、watchdog、恢复和严格代理服务门禁均已取得当前运行证据；可以在保存两端面板前置快照后执行已授权的三样本 HTB200 reference，但其结果尚不能支持候选速率、默认值或持久 HTB 结论。

## 本轮记录：2026-09-11（iperf3 endpoint TCP 可达性恢复，进入 HTB 前置门禁）

### 已完成及证据

- endpoint 本机全局 IPv4 与 Basic 使用的 `IPERF3_HOST` 一致，默认出口为 `eth7`；transient `dvt-iperf3-server.service` 当时仍为 active/running，`iperf3` 在 IPv4 `0.0.0.0:5201` 监听。Basic 到该地址的路由明确选择 `eth0` 和预期源 IPv4。
- 第一次 endpoint loopback `/dev/tcp` 返回 124 的原因已经由防火墙证据解释：当时独立 `inet dvt_iperf3` input base chain 只允许 Basic 源地址，随后无条件 drop 其他 TCP/5201，因此 loopback 源 `127.0.0.1` 在 UFW 的 loopback accept 之前已被丢弃。该结果不能用于否定 listener。
- endpoint 的真实 firewall authority 是 active UFW，INPUT policy 为 drop。独立早期 nftables chain 的 Basic allow counter 已有命中，但其 `accept` 不能阻止后续 UFW chain 再次 drop；这与第一次 Basic TCP 超时一致。操作者随后在 UFW 中加入仅允许 Basic 实际 `/32` 源地址访问 TCP/5201 的临时规则，并删除独立 `dvt_iperf3` table。
- 完成上述修正后，Basic 对同一 endpoint IPv4/TCP 5201 的 5 秒 `/dev/tcp` 检查返回 0。该证据闭合 IPv4 TCP 三次握手可达性门禁，但仍不是 iperf3 吞吐、接收端资源或 HTB 效果证据。

### 未完成门禁

- 正式流量前仍需在 endpoint 上复核：临时 UFW `/32` 规则仍存在、独立 `dvt_iperf3` table 已不存在、transient iperf3 unit 尚未达到两小时上限；Basic 上查询不到同名 table 只说明 Basic 本机没有该 table，不能替代 endpoint 复核。
- 仍需冻结测试前 VMISS/endpoint 面板额度、endpoint 接收端接口和资源基线，并用 bounded observer 覆盖 reference 窗口。Basic 还需在维护窗口内通过 rc.17 strict verify、稳定 HTB 执行器 manifest 校验、preflight 和 10 秒 HTB190 smoke，确认 active state 消失且根 `fq` 恢复。
- HTB200 reference 的 payload 尚未开始。只有上述门禁通过后，才执行 IPv4、单流、3 样本、10 秒测量加 3 秒 omit、300 秒阶段冷却、8192 MiB 共享 ledger 的 reference；结束后恢复 `x-ui.service` 并再次 strict verify。reference 结果必须先审阅，不能自动进入 180/190/195 sweep。

### 延期事项变化

- “endpoint TCP 公网可达性阻断”已关闭，主线推进到 endpoint 最终复核和 Basic HTB 前置门禁。candidate sweep、A/B/A、Core 迁移和持久 HTB继续未启动。
- 发现研究 SOP 中仍存在 rc.14 与 1C2G 示例路径等历史文字漂移；本轮真实执行必须使用 rc.17 已安装的 `dvt htb` wrapper 和当前 managed profile，不照抄这些旧路径。该文档清理登记为后续版本候选，不修改已发布 rc.17 资产。
- 无新增默认 profile、sysctl、持久 HTB或额外主动流量授权。

### 当前成熟度判断

当前为 `IPERF3_ENDPOINT_TCP_REACHABILITY_PASS_HTB_PREFLIGHT_PENDING_REFERENCE_NOT_STARTED`。下一最短动作是在 endpoint 复核临时 UFW/unit 并启动有界资源观测，然后在 Basic 的恢复 trap 内完成 strict verify、HTB190 smoke 和恢复检查；这些通过后可在同一已授权维护窗口执行 HTB200 reference。

## 本轮记录：2026-09-11（iperf3 endpoint 监听成功但 Basic TCP 可达性阻断）

### 已完成及证据

- endpoint 上的 transient `dvt-iperf3-server.service` 已由 `systemd-run` 启动，`RuntimeMaxUSec=2h`、MainPID 非零、Result success、ActiveState/SubState 为 active/running；`ss` 显示 `iperf3` 在 IPv4 `0.0.0.0:5201` 监听。该证据证明本机进程和 socket 正常，不证明公网路径或 ACL 放行。
- Basic 使用 Bash `/dev/tcp` 对当前指定 endpoint IPv4/TCP 5201 做无测速连接检查，5 秒后由 `timeout` 返回 124。该返回表示 TCP open 未在窗口内完成，符合 SYN 静默丢弃、目标地址不匹配或路径不可达；不是 iperf3 性能结果，也没有进入 HTB/reference 流量阶段。
- 当前 Basic 使用的 endpoint IPv4 与此前材料冻结的固定 endpoint 地址不同。该变化可能是有意切换到另一台自有 VMRack 主机，也可能是目标地址选择错误；必须先用 endpoint 控制台地址和本机全局 IPv4核对，不能仅以 UUID hostname 或 `0.0.0.0:5201` 推断公网目标正确。
- 复审了此前给出的独立 nftables table 建议。nftables 在同一 hook 存在多个 base chain 时，较早 chain 的 `accept` 只结束当前 chain，包仍可被后续 UFW/nftables chain drop；因此独立 `dvt_iperf3` chain 的 allow counter 即使命中，也不能保证绕过现有默认拒绝防火墙。该方案需要修正为：先识别实际 firewall authority；UFW active 时把临时 allow 写入 UFW 自身，只有不存在后续拒绝 chain 时才单独使用临时 nftables table。

### 未完成门禁

- 尚未确认当前 `IPERF3_HOST` 是否确实对应启动 transient unit 的主机公网 IPv4，也未取得 endpoint 本机 loopback TCP/5201 结果、Basic 到目标的 route-selected source、provider ACL、UFW/nftables 实际 input policy和临时规则 counters。
- 需要在 endpoint 上用有界 `tcpdump` 与 Basic 同步重试一次：无 SYN 到达则定位到错误目标/provider ACL/前置路径；SYN 到达但无 SYN-ACK则定位到 endpoint host firewall/listener path；SYN-ACK 发出但 Basic 无 ACK则检查返回路径或 Basic 侧过滤。门禁闭合前不得运行 iperf3 payload、HTB smoke 或 reference。
- transient unit 最长两小时会自动停止；排障完成或放弃本窗口后仍要显式停止 unit并删除仅为本次建立的 firewall 规则。不得为便于排障把 5201 永久开放给全网。

### 延期事项变化

- Basic HTB200 reference 从“endpoint 准备中”细化为“endpoint 本机监听通过、TCP 公网可达性阻断”。candidate sweep、A/B/A、Core 迁移和持久 HTB继续未启动。
- 新增操作方案修正：临时 ACL 必须进入真实生效的 firewall authority，不能把独立早期 nftables `accept` 误写为最终放行。无新增调优参数或主动流量授权。

### 当前成熟度判断

当前为 `IPERF3_ENDPOINT_LISTENING_TCP_REACHABILITY_BLOCKED_HTB_REFERENCE_NOT_STARTED`。下一最短动作是核对 endpoint 地址、本机 loopback、Basic route source 和防火墙规则 counter，再用单次 SYN 抓包定位；不需要操作 DVT、qdisc 或 Core。

## 本轮记录：2026-09-10（Basic rc.17 迁移后验收闭合）

### 已完成及证据

- 只读审阅了 `dvt-basic-post-rc17-20260910T150213Z.tar.gz`。外层 SHA-256 `c925576ca84e1c3e97e8e1bc33328d55bd20a4dc4c022066832c6217ae97734b` 与独立 `.sha256` 一致，归档路径安全；内部 `SHA256SUMS` 的 18 个文件全部通过。`capture-exit-codes.tsv` 中 18 项均返回 0，前一版采集器的 DVT PATH、空 reboot-required 表示和 `systemctl status` 日志泄露缺陷均已关闭。
- `/usr/local/bin/dvt --version` 明确为 controller/release rc.17；strict proxy verify 返回警告数 0。managed state 为 rc.17、`VERIFIED`、`debian13-1c1g`、200 Mbps、kernel `6.12.107+deb13-cloud-amd64`、auto 16 MiB buffer、1 GiB project swap active，5 个受管文件完整。当前 state SHA-256 为 `a8a4242d262b096050bf54ea272a69e5739137f7fe662c520de3c5cbd9fb63a0`。
- `x-ui.service`、`fail2ban.service` 和 `proxy-vps-fq.service` 均为 active/enabled，结果 success、重启次数 0；`systemctl --failed` 为空。没有 `/var/run/reboot-required`，没有活动 HTB state，`eth0` 无 HTB class；根 `fq` 累计约 649.1 MB/650918 包，drop/overlimit/requeue 与 backlog 均为零。接口 RX/TX error/drop 为零，swap 使用 0，内存 available 约 650.9 MB。
- 30 秒只读 diagnose 返回 0：CPU idle `96.80%`、steal `0.49%`、softnet processed 1402 且 dropped/time_squeeze 为零；接口增量约 RX 327590 bytes、TX 320012 bytes，接口和 ethtool drop/error/timeout 增量均为零；qdisc 前后 drop/requeue 维持零。窗口记录 `TcpRetransSegs=1`、`TCPLostRetransmit=1`、`TCPTimeouts=1`，但这是主机级累计增量且窗口仅发送约 320 KB，缺少固定流和有效字节分母，不能作为 normalized reference，也不构成当前资源/qdisc 异常或 HTB 收益证据。
- 用户确认实际客户端代理冒烟已经完成。该证据属于操作者业务验收声明；结合 strict verify、活动 Xray 子进程和当前服务状态，Basic 的 rc.17 迁移后主机/服务/基础业务验收可以闭合。无需再次迁移、执行 `apply` 或为了清零计数重启。

### 未完成门禁

- 尚未建立固定 iperf3 endpoint：服务端软件/版本、固定 TCP 端口、IPv4 监听、仅允许 Basic 源地址的 provider/local ACL、接收端 CPU/链路余量、服务端面板额度和测试前截图仍待确认。没有这些证据不得运行 Basic reference。
- HTB200 reference 尚未执行。正式窗口仍须停止 Basic 的 `x-ui.service`，在外层恢复 trap 保护下先运行零 iperf 流量的 rc.17 HTB190 smoke，确认根 `fq` 恢复和无 active state，再执行 3 样本、IPv4、单流、8192 MiB ledger 的 reference；完成后恢复服务、strict verify并与 VMISS 面板对账。
- Core 的 DVT rc.12 路径/strict verify 缺口继续延期，不阻塞 Basic。只有 Basic reference 因 1C1G 资源门禁不可判读，或形成可信候选后确需跨资源档确认时再补采和迁移 Core。

### 延期事项变化

- Basic post-migration 归档和真实代理冒烟从“待完成”更新为“通过”。下一主线由迁移验收转为固定 endpoint 准备与只读/低风险联通门禁；candidate sweep、A/B/A、Core 迁移和持久 HTB仍未启动。
- 无新增默认 profile、sysctl、持久 HTB或旧 TcpQuality 流量授权。30 秒 diagnose 中的单次主机级重传只保留为背景观测，不扩展成故障调查或参数修改。

### 当前成熟度判断

当前为 `BASIC_RC17_POST_MIGRATION_ACCEPTANCE_PASS_ENDPOINT_PENDING_HTB200_REFERENCE_NOT_STARTED`。Basic 已具备进入 endpoint 准备的主机条件；只有 endpoint 和测试前面板门禁闭合后，才可在独立维护窗口执行有预算的 HTB200 reference。

## 本轮记录：2026-09-10（Basic/Core 当前归档与 Basic rc.17 迁移终态审阅）

### 已完成及证据

- 只读审阅了用户下载到 VMISS Basic/Core 测试目录的两个当前归档。Basic 外层归档 SHA-256 为 `6a36e4b42e77f945a36a8137004b9ae12ea737433ee1b01ba5f550b3e93b337c`，Core 为 `8b592cd55eeb63f17909c6ea0b1a164df61142331d3342106077355c1410cb59`，均与各自 `.tar.gz.sha256` 一致；两个归档的内部 `SHA256SUMS` 均逐项通过，且没有路径逃逸条目。归档传输与内部文件完整性通过。
- 采集脚本存在已复现的运行缺陷：两台归档中的 `dvt --version/status/verify/diagnose` 均返回 127，原因为非交互脚本环境找不到 `dvt`。此前 `bash -n` 只覆盖语法，不能证明目标 PATH/安装入口可用；必须改为显式、已验证的 DVT 可执行路径，或在旧版 Core 上先人工解析控制器实际路径后再运行。`reboot-required` 文件存在但内容为空时，原脚本也不能区分“空标记文件”和“不需要重启”，后续应显式记录存在性、大小和包列表。原脚本的 `systemctl status` 还带入了最近 journal 行和外部扫描源地址，超出服务健康判断所需范围；后续改用 `systemctl show`、`is-active`、`is-enabled` 和 `--failed`，不采集服务日志尾部。
- DVT 缺失项之外的归档证据有效。两台均为 Debian 13、单一 IPv4/IPv6 default route 走 `eth0`、无活动 HTB state、无 HTB class、3X-UI 与 Fail2ban active、接口 RX/TX error/drop 为零、磁盘余量充足、约 1 GiB project swap 只使用 268 KiB。10 秒 `vmstat` 中 Basic idle 为 96–99%、steal 主要为 0%且单点 1%；Core idle 为 93–99%、steal 为 0–1%，当前没有资源饱和证据。
- Basic 迁移前根 `fq` 累计约 101.07 GB/1.157 亿包，drop/requeue 为零。Core 根 `fq` 累计约 349.41 GB/3.302 亿包，记录 38 drops、23 requeues，其中 `flows_plimit=34`、`horizon_drops=4`；折合约 0.115 drop/百万包和 0.070 requeue/百万包。这是自 qdisc 建立以来的累计值，不是当前窗口增量，不能据此认定 Core 正在丢包或归因 TCP 重传；若以后测试 Core，必须以 rc.17 phase delta 重新判断。
- 审阅了用户提供的 Basic 第二次重启后输出：checkpoint 到达 `COMPLETE`，迁移器内置 verify 和随后显式 strict proxy verify 均返回“警告数 0”；状态为 rc.17/schema 4 语义下的 `VERIFIED`、`debian13-1c1g`、200 Mbps、BBR + root `fq`，3X-UI active，Xray 子进程与主进程 NOFILE 均为 65536，项目 swap 为 1 GiB、active 且使用 0，内存 available 约 660.5 MB，根 `fq` 当时 drop/overlimit/requeue 为零。该证据足以判定 rc.14→rc.17 checkpoint 生命周期和严格代理服务门禁通过。
- Basic 迁移前归档使用 `6.12.101+deb13-cloud-amd64`，最终状态使用 `6.12.107+deb13-cloud-amd64`。checkpoint `COMPLETE` 证明两次 boot gate 与 rc.17 apply/verify 已执行，但内核同时变化，因此不能用迁移前后差异单独归因 rc.17；后续 reference/sweep 必须全部固定在当前 6.12.107 boot/runtime 内比较。

### 未完成门禁

- Basic 尚缺迁移后的新归档、`fail2ban.service` 明确 `is-active` 结果、`systemctl --failed`、30 秒 post-migration diagnose、真实客户端 VLESS + REALITY + TCP 冒烟和迁移后 VMISS 面板快照。当前可判定 DVT 生命周期通过，尚不能把“控制台监听存在”写成真实业务验收通过，也不能立即把迁移前归档当作 reference 前基线。
- Core 当前 DVT 版本、controller 路径、managed state 与 strict verify 仍被采集脚本的 127 缺口阻断。Core 现阶段没有迁移或主动测试需要；先保留完整归档，只有需要跨资源复核时再解析旧 controller 的实际路径并补采 DVT 门禁。
- 固定 iperf3 endpoint 仍缺服务端安装、固定端口、仅允许测试源地址的 ACL、防火墙、版本、监听、接收 CPU/链路余量和面板前置快照。Basic reference 尚未授权执行，也不得在业务冒烟和 post-migration 基线闭合前运行。

### 延期事项变化

- Basic rc.14→rc.17 checkpoint 迁移与两次重启从“待执行”更新为“运行证据通过”；下一步收敛为短时 post-migration 验收和修正版最小补采。Basic reference 保持下一独立窗口，candidate sweep、A/B/A、Core 迁移和持久 HTB仍未启动。
- 新增采集器修复项：DVT 命令必须绑定显式可信可执行路径；reboot-required 必须记录存在性和内容大小。该修复只影响证据采集可靠性，不改变 rc.17 profile 或目标机调优状态。

### 当前成熟度判断

当前为 `BASIC_RC17_MIGRATION_VERIFIED_POST_MIGRATION_ACCEPTANCE_PENDING_REFERENCE_NOT_STARTED`。Basic 已达到 rc.17 lifecycle/strict service 验证层，归档完整性和非 DVT 系统基线也可信；补齐迁移后最小证据与真实代理冒烟后，才可进入独立 HTB200 reference 窗口。Core 继续作为条件复核机。

## 本轮记录：2026-09-10（Basic 在线事实更正与操作脚本复审）

### 已完成及证据

- 用户更正当前运行事实：Basic 并未停机，500 GB 套餐尚余 315 GB；Core 的 1000 GB 套餐尚余 638 GB。Basic 为 1C1G、200 Mbps/`eth0`、rc.14，只服务一名代理用户且全天可重启；Core 为 1C2G、200 Mbps/`eth0`、rc.12，为其他机器提供代理，白天尽量不中断、夜间可重启。此前以“Basic 已停机”为前提选择 Core 为首台主动实验机的建议随之失效。
- 更新后的最短路径是 Basic 优先：先在两台机器采集只读当前基线；只在 Basic 上完成 rc.14→rc.17 checkpoint 迁移、稳定观察和独立的 HTB200 reference。Basic 的历史 HTB190 信号、较低业务影响和随时可重启条件，使其比 Core 更适合作为同机复验对象。Core 暂时保持只读旁证；只有 Basic 因 1C1G CPU/steal/softnet 使 reference 无法判读，或 Basic 产生可信 shortlist 后需要跨资源档夜间复核时，才迁移并测试 Core。
- 按 rc.17 当前默认参数，3 样本 HTB200 reference 应用 payload 约 0.908 GiB，180/190/195 candidate sweep 约 4.381 GiB，合计约 5.289 GiB；8192 MiB 共享 ledger 可以覆盖应用 payload。继续采用 12–15 GiB 服务商额度预留，并在每阶段前后保存 VMISS 面板计费快照。该预留分别低于 Basic 当前剩余额度约 5% 和 Core 当前剩余额度约 2.5%，但不构成自动重试、旧 TcpQuality campaign 或双机完整 sweep 的授权。
- 对此前建议的 Shell 片段进行了逐项静态复审并修正：摘要生成必须排除 `SHA256SUMS` 自身并先写临时文件；每次重启登录后必须重新赋值迁移 `CHECKPOINT`；analyzer 人工核对字段应使用 `qdisc_health_gate`；主动窗口必须用 `EXIT/INT/TERM` trap 尝试停止 HTB 并恢复原本运行的 `x-ui.service`；安装 rc.17 controller 前先由旧 controller 执行 `dvt update --target v0.1.0-rc.17`；旧版本基线改用直接读取 active-state 与 `tc`，不依赖旧 `dvt htb status`；active-state 检查必须在 `set -Eeuo pipefail` 或显式分支中 fail closed。
- Basic 1G 内存使迁移 rollback 的 owned-swap 清理成为额外运行风险。迁移前必须保存 `free -b` 和 `swapon --show --bytes`，并在 rollback/apply 窗口停止 `x-ui.service` 降低内存压力；如果迁移器不能安全完成 `swapoff` 或保留 checkpoint，则停止并保留状态，不得手工删除迁移状态或强制清理 swap。
- 本地验证已闭合：公开 rc.12、rc.14 controller 均按各自 Release `SHA256SUMS` 反向核验且包含 `update`；rc.17 migrator 源码确认接受 rc.1–rc.16 直迁 rc.17；修正后的采集/维护窗口片段通过 Git Bash `bash -n`；`python tools/render_profiles.py --check` 和完整 `bash tests/static-check.sh` 均通过。未连接、停止、迁移、重启或测试任何真实 VPS，也未产生公网流量。

### 未完成门禁

- 尚未取得两台机器的当前只读基线、VMISS 面板阶段快照、Basic 的控制台/系统快照和 3X-UI 数据库备份，也未确认固定获授权 iperf3 endpoint 的端口、地址族、接收容量、防火墙/ACL 和服务端额度。当前只应执行只读采集，不能把历史记录视为当前运行事实。
- Basic 迁移必须与主动 reference 分成两个窗口。迁移完成后先验证 rc.17 schema 4 `VERIFIED`、根 `fq`、`x-ui.service`、Xray NOFILE、Fail2ban 和真实代理业务，并完成稳定观察；随后才能在独立窗口停用真实代理流量并运行 3 样本 reference。
- 若 Basic reference 在 200 Mbps 下测量有效且重传可接受，应停止，不运行 sweep，也无需仅为完成研究而测试 Core。只有重传反复偏高且资源、softnet、接口、endpoint 与 root/leaf qdisc 门禁健康时，才运行一次 Basic candidate sweep。正式 A/B/A 仍需先把旧 rc.14/TcpQuality SOP 更新为 rc.17、固定 iperf3、schema 3、共享 ledger 和显式 payload，再由用户单独批准。
- 当前用户要求的是方案与脚本自检及事实更新，不构成连接 VPS、停止服务、迁移、重启、配置 endpoint 或产生主动流量的本轮执行授权。

### 延期事项变化

- Basic 从“等待服务商恢复、不能测试”更正为“当前在线且是首台 rc.17 迁移/reference 候选”；Core 从“首台主动候选”调整为“只读旁证及条件触发的夜间跨资源复核”。此前基于错误停机前提形成的记录保留为历史过程，由本条最新记录取代其当前决策效力。
- 不再计划预先迁移两台机器或在两台上各跑完整 campaign。Core 的迁移/reference 以 Basic 出现资源受限或形成候选后确有交叉验证价值为重新纳入条件。无新增默认/持久 HTB、sysctl、TcpQuality 或公网大流量测试授权。

### 当前成熟度判断

当前为 `BASIC_PRIMARY_BOUNDED_RC17_REFERENCE_READY_AFTER_LIVE_BASELINE_SCRIPT_PLAN_CORRECTED`。主机选择、流量上界和操作脚本的高影响缺陷已经修正并通过本地静态门禁；下一安全动作仅为在 Basic 与 Core 分别运行修正后的只读采集脚本，人工审阅当前状态后再决定 Basic 迁移窗口。

## 本轮记录：2026-09-10（Core/Basic 可重启条件更新后的实验角色）

### 已完成及证据

- 用户更新运行约束：Core 只运行一个 3X-UI 服务，为其他机器提供代理；白天尽量不停机，夜间可以安排重启。Basic 也只运行一个 3X-UI 服务，仅一名用户使用，全天均可安排重启。该信息消除了此前将 Core 限定为“绝不重启、只能被动旁证”的维护阻塞。
- 两台仍是配额受限的代理业务机。Core 的 1C2G、1000 GB 套餐、当前约 643 GB 剩余、200 Mbps/`eth0` 和夜间维护条件，使它成为现有两台中更合适的 rc.17 迁移及有界 HTB reference/sweep 候选；主动测试窗口必须协调用户、停止 3X-UI/Xray 并确认接口字节稳定，测试后恢复服务并严格验证。Basic 仍因 500 GB 账期封停等待恢复，历史流量事故和较小额度使它更适合作为候选速率冻结后的低预算交叉复验机。
- 推荐把运行拆成独立门禁：白天只读基线 → 第一夜 rc.12→rc.17 checkpoint 迁移与两次人工重启 → 稳定观察 → 第二夜只执行 3 样本 HTB200 reference（默认 payload 上界约 0.91 GiB）→ 人工评审。reference 已稳定且重传可接受则停止；只有测量有效、200 Mbps 下重传反复偏高且 CPU/steal、softnet、接口、root/leaf qdisc 和 endpoint 无更强解释时，才另开夜间窗口执行 180/190/195 candidate sweep（约 4.38 GiB）。
- reference+sweep 默认应用 payload 合计约 5.29 GiB，可由 8192 MiB 共享 ledger 覆盖；考虑 VMISS 双向计费、协议开销、失败保守结算和禁止无审查重试，Core 控制台建议为该阶段预留 12–15 GiB。该预算相对用户报告的剩余额度可控，但必须在每个阶段前后与 VMISS 面板对账。

### 未完成门禁

- 尚未取得 Core 当前只读基线、控制台/快照、3X-UI 配置备份、夜间维护窗口、客户端停用确认、固定获授权 iperf3 endpoint、服务端版本/端口/IPv4 ACL/接收容量及两端额度证据。当前不能直接迁移或发流量。
- rc.17 迁移器要求旧版 rollback 后第一次 reboot，再执行 rc.17 preflight/apply，随后第二次 reboot 和最终 verify；不得把两个重启与 HTB reference 混成一个故障难以归因的窗口。迁移完成后还要严格验证 `x-ui.service`、Xray NOFILE、Fail2ban、根 `fq`、schema 4 `VERIFIED` 和真实代理业务。
- 正式 A/B/A 与反向窗口仍受旧 rc.14/TcpQuality SOP 漂移阻断。candidate shortlist 出现后，必须先把 SOP 更新为 rc.17、固定 iperf3 endpoint、schema 3 root/leaf qdisc 证据和共享预算，再单独批准执行；不能原样运行旧文档。
- Core 上的有界实验只能回答该 Core/该 endpoint/该时段的主机特定问题。要修改项目默认值、启用持久 HTB 或提出跨 VPS 性能主张，仍需独立无业务测试资源和 Basic/Core 的短时真实代理路径复验。

### 延期事项变化

- Core 从“仅被动诊断”调整为“夜间可迁移、可承担分阶段有界 reference/sweep”；此前不重启相关延期条件关闭。Basic 从“完全暂停”调整为“服务商恢复后先做当前状态和业务恢复，候选冻结后再决定是否低预算交叉复验”。
- 当前用户提供的是运行条件更新和操作方案请求，不等于已经授权本轮连接 VPS、停止 3X-UI、迁移、重启、配置 endpoint 或产生主动流量。无新增默认/持久 HTB、sysctl 或生产候选速率授权。

### 当前成熟度判断

当前为 `CORE_PRIMARY_BOUNDED_RC17_HTB_CANDIDATE_BASIC_CROSS_VALIDATION_AFTER_RESET`。主机选择和分阶段顺序已经收敛；下一安全动作是白天采集 Core 当前只读基线并冻结第一夜迁移所需的控制台、备份和维护条件，HTB 流量必须等迁移与稳定验证独立闭合后再开始。

## 本轮记录：2026-09-10（VMISS 重传问题的下一步执行顺序）

### 已完成及证据

- 根据 3X-UI 方案和 2026-08-28 已批准的分层测试策略，将下一步收敛为“业务机被动诊断优先、独立研究机承担 HTB 因果实验”。仓库 README 已明确 `diagnose` 是无主动流量的首选故障入口；`probe` 只用于症状触发且有硬预算的单机诊断；benchmark、TcpQuality 和 HTB 属于需要独立高额度测试机的研究层。
- Core 当前最适合在不重启、不迁移和不改 qdisc 的条件下采集真实问题窗口，判断重传是否与聚合出口速率、RTT、CPU/steal、softnet、接口错误或路径变化同步。Basic 在服务商账期恢复后只做控制台额度、当前状态、低流量生命周期和真实代理冒烟，不承担 reference→sweep→A/B/A 速率发现。
- rc.17 已发布的 HTB 证据修复不改变默认网络参数，也不要求立即运行公网测试；只有要决定默认/持久 HTB、具体候选速率或发布性能主张时，才进入独立因果实验。

### 未完成门禁

- 尚未采集 Core 同一真实重传窗口的脱敏 `diagnose`、聚合吞吐或接口字节增量和业务侧时间戳，不能判断整形假设是否值得进入主动验证。不得只凭累计重传数、单次 `ss` 或本地 qdisc 零丢包归因服务商 policer。
- 若 Core 被动证据仍显示接近 200 Mbps 聚合发送时重传稳定升高，下一步需要无业务、可重装、有控制台/快照、高额度或不计量的独立测试机，以及固定获授权 iperf3 endpoint、地址族、端口和硬预算。rc.17 可直接使用的测试机仍须满足真实 200 Mbps、唯一默认出口 `eth0`；500 Mbps/`eth7` VMRack 资源需要后续版本先完成接口和 provider-rate 通用化。

### 延期事项变化

- 暂停为 Basic/Core 准备完整 HTB campaign 和大流量 endpoint 窗口。是否启动独立 HTB 研究，以 Core 被动诊断能否形成可复现的“速率相关重传膝点”线索为重新纳入条件。
- 无新增生产迁移、重启、主动流量、默认/持久 HTB 或网络参数修改授权。

### 当前成熟度判断

当前为 `CORE_PASSIVE_DIAGNOSIS_FIRST_HTB_RESEARCH_CONDITIONAL`。下一安全动作是收集 Core 的低风险真实症状证据；Basic 等待服务商恢复；独立 HTB 测试资源仅在整形假设仍有充分依据时准备。

## 本轮记录：2026-09-10（VMISS 3X-UI 方案中的 HTB 测试必要性追溯）

### 已完成及证据

- 只读复核了 `F:\Software\Software\翻墙\VPS\VMISS VPS 3X-UI 详细配置方案.md` V1.14。该文档正式适用对象仅为 `US.LA.TRI.Core`；其调优接口边界明确记录 rc.12 `BBR + fq` 生命周期通过不证明吞吐或 HTB 收益，不增加全局 `fq maxrate` 或持久 HTB/TBF，临时 HTB A/B/A 或 candidate sweep 属于独立实验而非 3X-UI 部署步骤。最终维护门禁仍要求根 qdisc 保持受管 `fq`，不得被未归因的持久整形替代。
- 文档只在“多 VMISS 实例复用边界”中引用 Basic 的独立 500 GB 账期/自动重置契约和低重要性告警豁免；这些内容不把 Core 方案变成 Basic/Core 共用性能测试方案，也没有要求 Basic 或 Core 完成 HTB/TcpQuality 才能验收 3X-UI。
- 追溯 2026-08-28 的项目决策：Basic 29 次 TcpQuality 日志窗口已产生约 264.27 GB 出站，公共节点和时段漂移使继续主动测试的边际价值不足；用户批准将 Basic 完整 HTB campaign 和 1C2G A/B/A 降为研究专用，不再作为 VPS 升级、日常验收或 3X-UI 部署门禁。只有出现可复现真实业务症状、确实需要 HTB 因果结论、使用独立高额度测试机并批准硬预算时，才重新评审。
- 2026-09-10 用户以“实际重传明显”和 tcpfit 专项重新提出因果研究，满足了重新评审研究问题的触发条件，但没有自动满足“独立高额度测试机”条件。Basic 是 500 GB 配额业务机且已因历史测试封停，Core 是 1000 GB 配额业务机且要求尽量不重启；因此二者当前都不应承担完整 HTB 速率发现/A/B/A campaign。

### 未完成门禁

- Basic 解封后可以完成低流量生命周期、当前只读诊断和真实业务冒烟；在候选速率已由独立测试机发现前，不再把它规划为 HTB200 reference→sweep→A/B/A 的发现主机。若未来仅做最终短时业务相关复验，也需独立授权、硬字节上界和 VMISS 面板对账。
- Core 继续保持 rc.12、根 `fq` 和不重启边界，只做被动诊断及 3X-UI 方案规定的业务/路由/账期验收。不得把 tcpfit 研究、rc.17 发布或 Basic 不可用解释为 Core 必须迁移或执行 HTB。
- 若仍需形成聚合整形因果结论，应使用可重装、无业务、高额度或不计流量的独立测试机。现有 500 Mbps/`eth7` VMRack 测试资源不符合 rc.17 固定 200 Mbps/`eth0` 执行契约；需要另准备 200 Mbps/`eth0` 合格资源，或在后续版本先完成真实 provider-rate/默认接口通用化，再进行独立实验。

### 延期事项变化

- 修正此前“Basic 解封后作为完整 HTB 主实验机”的建议：Basic 只保留低流量现状/业务复验候选，完整速率发现回到独立高额度测试机。Core 维持被动旁证。
- 三项目研究和 rc.17 证据能力的静态/fixture结论不受影响；默认或持久 HTB 仍需独立实验因果证据。无新增 VPS 操作、主动流量或持久整形授权。

### 当前成熟度判断

当前为 `VMISS_BUSINESS_HOST_HTB_CAMPAIGNS_NOT_REQUIRED_DEDICATED_RESEARCH_HOST_NEEDED`。既有决策一直排除把 Basic/Core 的完整 HTB/TcpQuality 作为升级、部署或日常验收门禁；新重传问题只使独立研究重新具有价值。当前正确路线是 Core 不重启、Basic 等待重置并仅做低流量恢复/业务检查，完整 HTB 因果实验转移到合格的独立测试资源。

## 本轮记录：2026-09-10（首轮三项目研究与整形专项任务复盘）

### 已完成及证据

- 对首个“三项目深入研究和吸收评估”任务进行过程复盘：最初执行确实在完成 tcpfit 深读、仅开始 NetShape 后发生中止/任务漂移，没有当轮交付三项目完整比较和吸收矩阵；该过程缺陷成立。后续工作已用固定版本补齐 tcpfit `v0.5.7`、vps-netpilot 和 netshape-manager/peertune 的源码级功能、证据边界、吸收/延期/拒绝矩阵，并形成 [外部网络调优项目研究](external-network-tuning-research-2026-09-10.md)，但这不消除用户需要再次纠偏的执行问题。
- 第二个“重点重评 tcpfit 整形能否改善本项目重传”任务正确把问题收敛为聚合出口 policer 假设。Linux HTB 可控制 egress class 聚合速率，FQ 主要做逐流 pacing；因此 tcpfit 的 `HTB rate=ceil → fq leaf` 机制在理论上适配“多流总出口超过稳定 policer”这一特定故障形态，但不能修复入向/远端重传、路径拥塞或乱序、CPU/softnet、接口错误、PMTU 和代理应用路径问题。
- 后续 rc.17 已吸收不依赖性能结论的证据工程价值：识别 `parent MAJOR:MINOR` 的 HTB→FQ 叶子，phase summary schema 3 分离 root/leaf totals，任一 root/leaf drop/requeue 或旧证据 fail closed 为 `REVIEW_BLOCKED`，并扩展脱敏 socket pacing/delivery/min RTT/DSACK/乱序/窗口字段。这些属于观测契约正确性，可由源码语义、fixture、Linux root/真实 qdisc smoke 分层验证，不需要先证明 HTB 能降低目标 VPS 重传。
- HTB 性能测试只对仍未决的运行主张是必要门禁：是否存在稳定的聚合 policer knee、180/190/195 中哪个速率改善 retransmits/GiB 且保持 receiver goodput、tcpfit 约 4 ms burst/cburst 是否优于当前参数、是否值得设计持久 opt-in shaper。没有同机、同端点、同方向/地址族、多窗口 A/B/A 和真实代理复验，这些结论均不能成立。

### 未完成门禁

- 当前还没有目标机证据证明“缺少 aggregate cap”是用户若干 VPS 重传的根因，也没有证据支持把 HTB、190 Mbps、90%/95%、tcpfit burst、`fq maxrate`、`limit=40960`、`flow_limit=8192` 或持久 systemd shaper加入默认 profile。
- Basic 已因历史 HTB 研究期间的流量生成超过 500 GB 而停机，Core 又要求尽量不重启；因此目前不具备运行 HTB 因果实验的主机条件。Basic 解封后也只能先运行独立、最小预算 HTB200 reference并与 VMISS 面板对账，不能为了“完成研究”自动继续 sweep/A/B/A。
- 只有 reference 显示重传问题可复现、整形暴露充分、主机/endpoint/qdisc 证据健康时，才有理由运行一次受控候选 sweep；只有候选出现可重复收益时，才修订并执行有硬字节上界的 A/B/A。旧公共 TcpQuality 多轮流程不再作为正式因果实验入口。

### 延期事项变化

- tcpfit/NetShape 的聚合整形从“待吸收功能”明确分为两层：非持久研究能力和证据语义已经吸收；生产默认或持久 opt-in 整形继续延期，触发条件是低流量、同机多窗口因果证据及单独设计/发布授权。
- tcpfit/NetPilot/NetShape 的宽 sysctl、固定 RTT/缓冲、`initcwnd/initrwnd`、RPS/RFS、UDP/conntrack、MSS Clamp、CAKE/TBF fallback 和固定经验速率仍维持拒绝或独立需求状态；HTB 测试即使成功也不能同时验证这些不同机制。

### 当前成熟度判断

当前达到 `THREE_PROJECT_RESEARCH_COMPLETE_HTB_PRODUCT_DECISION_REMAINS_CONDITIONAL`。三项目的源码价值判断和 rc.17 证据链吸收已经具备充分静态/fixture依据；HTB 运行测试不是完成吸收评估所必需，但若要声明降低目标 VPS 重传、选择生产速率或进入持久整形设计，则是不可替代的因果证据门禁。现阶段因 Basic 配额封停和 Core 不重启约束而暂停该门禁是正确选择。

## 本轮记录：2026-09-10（VMISS 配额与 Basic 流量封停约束修正）

### 已完成及证据

- 用户补充并纠正当前资源约束：Basic 为 1C1G、500 GB 配额、面板已用 180 GB；Core 为 1C2G、1000 GB 配额、面板已用 357 GB；两台端口均为 200 Mbps。按面板数值直接相减，名义剩余分别为 320 GB 和 643 GB，但该算术值不代表当前可发流量状态。
- Basic 曾在 HTB 测试期间累计超过 500 GB 后被服务商停机，目前必须等待流量重置后才能开机。该服务商封停状态优先于“已用 180 GB”的面板数字；在用户确认重置完成、实例可启动且面板新周期口径明确前，Basic 不再视为当前可迁移或可测试主机。
- rc.17 Basic 五样本 HTB200 reference 的协议 payload 上界约 1.625 GB，reference 加 180/190/195 sweep 约 6.329375 GB，远低于 500 GB。历史测试能耗尽 500 GB，说明旧 TcpQuality/重复运行/背景业务/失败重试或服务商计费口径中至少有一项没有被现有历史记录可靠约束；不能仅凭 rc.17 计划上界解释旧封停，也不能继续复用旧 TcpQuality A/B/A 流程。
- Core 名义剩余约 643 GB，但用户要求尽量不重启，且它仍为 rc.12/1C2G。Core 继续只用于不重启的只读与被动观测，不因 Basic 暂时不可用而自动升级为主动 HTB 替代机。

### 未完成门禁

- Basic 必须等待服务商完成流量重置并恢复开机；恢复后先核对新计费周期起止、面板已用/剩余、封停阈值、上下行是否都计费及重置规则，再执行任何迁移或网络测试。不得以面板当前“180 GB 已用”推断实例已经解封。
- 在 Basic 上重新开始时，第一批主动流量只允许独立五样本 HTB200 reference，不预授权 sweep、TcpQuality、A/B/A 或失败自动重试。reference 的本地账本建议只给覆盖 1.625 GB payload 的最小预算，并在完成后人工对账 VMISS 面板增量；面板增量与 sender bytes 无法解释地偏离时立即终止整个 campaign。
- 旧 A/B/A SOP 在修订为 rc.17、固定 iperf3 endpoint、显式 payload 上界、共享账本和每阶段人工停顿前不得执行。鉴于 Basic 已发生配额封停，后续不再使用无法形成可靠上界的旧公共 TcpQuality 流程作为正式 HTB 因果实验。
- Core 仍需单独的只读运行证据；任何 rc.12→rc.17 迁移、重启或主动流量都保持未授权。Basic 解封前，项目没有符合“rc.17、200 Mbps、eth0、可重启、可控额度”的当前 HTB 主实验机。

### 延期事项变化

- Basic 的 rc.17 迁移和 HTB reference 从“等待当前只读基线”改为“先等待服务商额度重置和实例解封，再做当前只读基线”。candidate sweep、A/B/A 和真实代理复验继续保持后续逐阶段授权。
- 新增正式实验门禁：每个主动流量阶段结束后必须把 sender bytes、本地预算账本和 VMISS 面板计费增量三方对账；不能解释的超额计费或面板延迟必须阻断下一阶段。无新增 Core 重启、持久 HTB或默认 profile 修改授权。

### 当前成熟度判断

当前为 `BASIC_BLOCKED_BY_PROVIDER_TRAFFIC_RESET_CORE_PASSIVE_ONLY`。Basic 仍是硬件和生命周期上更合适的主实验机，但现在受服务商流量封停阻断；Core 在不重启约束下只能提供被动旁证。下一安全检查点是确认 Basic 新计费周期已重置且实例恢复，然后只读重建基线，并先以单独、最小预算的五样本 HTB200 reference 验证本地账本与服务商计费是否一致。

## 本轮记录：2026-09-10（VMISS Core/Basic 历史证据复核与差异化测试准备）

### 已完成及证据

- 只读复核了用户指定的 `Core` 与 `Basic` 本地测试记录；本轮没有连接或修改两台 VPS，也没有产生公网测试流量。记录主要形成于 2026 年 8 月，属于历史快照，不能证明两台机器当前仍保持相同内核、服务、qdisc、路由、连接、额度或受管状态。
- `Core` 历史证据显示 Debian 13、1C2G、200 Mbps、`eth0`、rc.12 schema 受管状态和 `BBR + fq` 生命周期验证曾通过，旧版 HTB200 smoke 也曾完成 HTB 建立、断言、停止和根 `fq` 恢复；但四个 `htb200-reference-*` 目录均为空，旧 schema 2 plan 不能作为 rc.17 reference 结果。Core 当前按用户要求应尽量不重启，因此暂不迁移 rc.12→rc.17，也不把它作为 rc.17 HTB 主实验机。
- `Basic` 历史证据显示 Debian 13、1C1G、200 Mbps、`eth0`，旧 S3 多窗口重传密度存在明显波动，说明时段和路径是重要混杂变量。旧 S4 第一次 A/B/A 中标记为 B1 的 TCPQuality 运行实际开始和结束均为根 `fq`，不构成 HTB 条件；第二次尝试的 B1 确认运行 HTB190，重传密度约 `699/GiB`、HTB root overlimits `103044` 且 root/leaf drop/requeue 为零，但缺少 A2，且 A1 与 B1 的字节量和时段不同。该结果是值得复验的强信号，仍不足以批准持久 190 Mbps。
- 用户说明 Basic 当前为 rc.14 且允许重启。结合 rc.17 执行契约，Basic 是主 reference/sweep/A/B/A 候选：先现场只读重建当前基线，再按 rc.14→rc.17 checkpoint 完成两次重启和最终严格验证；Core 只保留为不重启的当前状态观察对照。两台硬件档、软件版本、业务负载和测试时段不同，因此 Core 不能替代 Basic 的同机 A/B/A 因果对照。

### 未完成门禁

- 两台机器均需补采当前只读证据：boot ID、Debian/kernel、DVT version/status/state、strict verify、root/class qdisc、IPv4/IPv6 route/rule、3X-UI/Xray 与 Fail2ban 状态、活动 socket 与接口字节增量、CPU/steal、softnet、接口 error/drop、磁盘/流量额度、包管理锁和 `reboot-required`。Core 的只读核验不应触发重启、迁移或 HTB。
- Basic 在迁移前需冻结维护窗口、确认控制台与快照、备份 3X-UI 配置，并确认真实客户端流量可停。迁移和主动实验期间必须消除或量化 3X-UI/Xray 背景流量；Fail2ban 可保持运行，但两次重启后均需验证恢复。
- 固定 iperf3 endpoint 仍需确认自有或获授权、端口、版本、IPv4 源地址限制、监听与防火墙、单流持续接收能力、CPU/网卡余量和服务商额度。历史第三方 endpoint、Core 空 reference 目录、schema 1/2 plan、旧 `COMPLETED` 标记以及旧 qdisc 零丢包结论均不得复用为 rc.17 运行证据。
- Basic 的最短有效序列为：当前只读基线 → rc.14→rc.17 迁移与两次重启验证 → 5 样本 HTB200 reference → 人工评审 → 必要时 180/190/195 sweep → 冻结唯一候选率 → 更新旧 A/B/A SOP 到 rc.17/schema 3 → 新目录运行同机 A/B/A。按 Basic 既有 campaign 的 5 样本设置，reference+sweep 计划 payload 上界为 `6.329375 GB`（约 `5.89 GiB`）；考虑协议开销、失败保守结算和重试，服务商额度建议预留 12–15 GiB。A/B/A 预算须在候选冻结后另行计算和批准。

### 延期事项变化

- Core 的 rc.12→rc.17 迁移和主动 HTB 实验改为有条件延期：只有用户以后接受其两次重启和维护窗口时再纳入。不得为了避免重启而绕过 rc.17 checkpoint 或手工伪造受管状态。
- Basic 的 rc.17 迁移、endpoint 写入、服务停止、重启和主动流量仍需按具体步骤执行授权；本轮只有本地记录分析。无新增默认或持久 HTB、sysctl、3X-UI、Fail2ban 配置修改授权。

### 当前成熟度判断

当前达到 `BASIC_SELECTED_AS_PRIMARY_RC17_HTB_CANDIDATE_AWAITING_LIVE_READ_ONLY_BASELINE`。历史数据给出了重新验证 HTB190 的充分理由，但旧实验存在无效 B1 或缺少 A2 的关键缺口；下一步应先只读核验两台当前状态，随后仅在 Basic 上进入迁移和新 rc.17 reference，Core 保持不重启。

## 本轮记录：2026-09-10（两台 200 Mbps/eth0 旧版 VPS 候选复核）

### 已完成及证据

- 用户补充存在两台真实 200 Mbps、默认出口 `eth0` 的 VPS，DVT 管理版本分别为 rc.12 和 rc.14；两台均已安装并运行 3X-UI 与 Fail2ban。本轮只核对仓库 rc.17 迁移、HTB 和代理验证契约，没有连接或修改任一 VPS。
- rc.17 `dvt-migrate.sh` 明确接受 rc.1–rc.16 的来源并迁移到 rc.17，因此 rc.12 和 rc.14 在版本格式上都可以直接进入一次受控 rc.17 checkpoint，无需逐个经过中间 Release。迁移仍会固定旧版/目标 profile 摘要，先调用旧版 `verify/rollback`，要求第一次 boot ID 变化，再执行 rc.17 `preflight/apply`，要求第二次 boot ID 变化，最后完成 rc.17 `verify`。
- 两台机器的 200 Mbps 和 `eth0` 已满足 rc.17 HTB 合同的关键静态类别，比此前提供的 500 Mbps/`eth7` VPS 更适合作为 HTB200 reference 候选。若业务重要性、硬件、线路、流量和恢复条件相同，rc.14 因生命周期差距较小可作为初始优先候选；最终选择必须由停机能力、业务负载和恢复证据决定，不能只按版本号。
- Fail2ban 不属于 DVT 调优或 HTB 的修改范围，正常情况下可以保持运行；endpoint 只需允许测试机主动发起的出站 TCP。3X-UI/Xray 会共享同一 egress、CPU 和 qdisc 计数，若存在客户端或后台流量会污染吞吐、重传和 root/leaf 证据，因而必须在实验窗口内停止或以运行证据证明无连接、无显著字节增长。

### 未完成门禁

- 尚未取得两台候选机各自的 Debian/资源档、完整 rc.12/rc.14 `dvt status`、schema/state、根 qdisc、当前连接与流量、剩余额度、控制台、快照、可停机窗口和业务归属证据；不能据当前两行信息选定最终测试机。
- 任何候选机在 HTB 流量前都必须完成 rc.17 只读 `update`、受控迁移、两次人工重启、最终 schema 4 `VERIFIED`，并用 `REQUIRE_PROXY_SERVICE=1 PROXY_SERVICE_UNITS='x-ui.service'` 做严格代理服务验证。迁移阶段对 3X-UI 的临时 NOFILE drop-in 状态和真实业务可用性必须在维护窗口分别检查；Fail2ban 状态也须在两次重启后确认。
- 若 3X-UI 承载真实生产业务、不能在完整 reference 窗口停用，或无法接受两次迁移重启，则该机不能作为独立性能测试机。不能以“已安装服务但当前看起来空闲”代替业务所有者确认和连接/接口增量证据。
- iperf3 endpoint 的端口、已安装版本、源地址限制和持续接收能力仍未冻结；这些门禁与测试机选择相互独立，必须在任何主动流量前完成。

### 延期事项变化

- 500 Mbps/`eth7` 通用化候选暂不必作为最短路径实施，因为已经出现符合 rc.17 端口/接口合同的 200 Mbps 候选机；只有两台 200 Mbps 主机都因生产或恢复约束不可用时，才重新启用该实现候选。
- 无新增默认 HTB、持久化、sysctl、Fail2ban 或 3X-UI 配置修改授权。停止代理服务、迁移、重启、endpoint 安装和主动流量仍须按具体主机单独授权执行。

### 当前成熟度判断

当前达到 `RC17_HTB200_HOST_CATEGORY_FOUND_AWAITING_HOST_SELECTION_AND_LIFECYCLE_EVIDENCE`。已有两台在 200 Mbps/`eth0` 类别上匹配的候选机，rc.12/rc.14 均可由 rc.17 迁移器直接接入；但生产隔离、主机细节、迁移和 endpoint 门禁尚未闭合，不能开始 reference。

## 本轮记录：2026-09-10（VMRack 500 Mbps 测试资源与 rc.17 HTB 契约适配复核）

### 已完成及证据

- 用户提供了一台 Debian 13、1C2G、500 Mbps、约 1 TB 剩余额度并有控制台和快照的 VMRack VPS，以及另一台自有 500 Mbps VPS 作为固定 IPv4 iperf3 endpoint 候选。本轮只读取用户提供的脱敏所需字段和仓库源码，没有连接主机、安装软件、修改防火墙或产生测试流量。
- 测试机当前仍由 rc.16 管理，schema 4 `VERIFIED`、profile `debian13-1c2g`、状态端口 500 Mbps、默认出口 `eth7`、运行态 `BBR + fq`。用户称其不承载生产业务，但状态输出同时显示公网 Xray 443 和 wildcard x-ui 监听；因此实验前仍须用连接、流量和客户端配置证据确认窗口内没有业务，不能仅按“无生产业务”字段通过门禁。
- 当前 rc.17 HTB 契约与该机器不匹配：`dvt-htb.sh` 明确只支持 Debian 13 rc.17、`eth0`、200 Mbps、1C1G/1C2G；HTB 执行器固定 `EXPECTED_IFACE=eth0`；runner 要求 managed state 为 rc.17 schema 4 `VERIFIED` 且 `network.port_speed_mbps == 200`；plan 固定 HTB200 reference 和 180/190/195 candidates。相关 200 Mbps/接口假设跨执行器、计划、runner、analyzer、fixture 和文档，不能通过改一条命令安全绕过。
- endpoint 的 IPv4 与 500 Mbps 声明满足候选方向，但端口尚未冻结、iperf3 尚未安装、版本和实际持续接收能力尚无运行证据、源地址限制尚未配置。地址族 `4`、初始 parallel `1`、90 分钟窗口和 8192 MiB 账本在形式上清楚；但它们不能消除测试机契约不匹配。

### 未完成门禁

- 当前不得运行 rc.17 `dvt htb reference`、smoke 或 candidate sweep。把真实 500 Mbps 套餐状态改写为 200 Mbps、把 `eth7` 冒充 `eth0`，或仅把 HTB cap 设为 200 Mbps，都会使状态/恢复/预算契约失真，并且只能说明“把 500 Mbps 主机压到 200 Mbps 后的行为”，不能检验 500 Mbps 端口附近的聚合 policer。
- 若继续使用这台测试机，必须先形成后续版本的通用接口和 provider-rate 设计与实现：从唯一默认出口安全绑定 `eth7`，以真实 500 Mbps 作为 reference，重新批准候选率集合、流量上界、暴露阈值、fixture、恢复命令和文档，再走 PR/CI/Release。候选率不能在没有 500 Mbps 基线证据时直接照搬 180/190/195 或任意指定。
- 若坚持使用已发布 rc.17 而不改代码，则需另用真实套餐 200 Mbps、唯一默认出口 `eth0`、rc.17 schema 4 `VERIFIED` 的独立测试机。endpoint 仍须安装并固定 iperf3 版本与端口、只允许测试机源地址、验证单流和计划并发下持续接收能力，并保存防火墙和监听证据。
- 不论选择哪条路径，正式流量前还需完成 rc.16→目标版本的受控迁移、两次 reboot/verify、稳定 HTB 执行器摘要绑定、无活动 HTB 状态、端点路径检查、背景业务冻结和服务商剩余额度复核。升级本身不会自动解决 500 Mbps/`eth7` 契约差异。

### 延期事项变化

- 新增一个有明确触发条件的实现候选：只有用户决定继续使用 VMRack 500 Mbps/`eth7` 机器时，才把 HTB 研究工具从单一 200 Mbps/`eth0` 合同扩展为真实 provider-rate 和唯一默认接口绑定；该工作不得改变默认 profile 或自动启用持久 HTB。
- rc.17 的公开发布完整性不变。旧 rc.14 A/B/A 文档同步项继续保留；若实施 500 Mbps 路径，还必须先以新的 reference/sweep 结果冻结候选，再生成对应 A/B/A，而不是预设 190 Mbps。

### 当前成熟度判断

当前为 `RC17_RELEASE_READY_BUT_PROVIDED_TEST_HOST_INCOMPATIBLE_WITH_HTB_CONTRACT`。测试资源在控制台、快照、额度和时长方面充足，但真实端口、接口和当前服务状态不满足 rc.17 的执行契约；在选择“扩展后续版本支持 500 Mbps/eth7”或“更换 200 Mbps/eth0 测试机”前，不能进入 HTB reference 流量阶段。

## 本轮记录：2026-09-10（v0.1.0-rc.17 Pre-release 发布与公开反向验证）

### 已完成及证据

- 用户明确授权发布 `v0.1.0-rc.17` Release。本轮从已合并且与 `origin/master` 一致的提交 `6bed55333a6483a4c5efd899d9942e7df3ced088` 导出资产，没有把本地未提交的阶段备忘纳入 tag 或发布字节。合并后的 `shell-static-checks` run `34454128159` 为 `success`，head SHA 与发布提交一致；本地 `python tools/render_profiles.py --check`、`git diff --check`、导出资产 `bash -n` 和 `sha256sum -c SHA256SUMS` 均通过。
- 已创建并推送注释 tag `v0.1.0-rc.17`；远端 tag 对象 SHA 为 `7ec04f4fd0daf963ee7a8036c05317343ee8d23c`，GitHub tag API 确认其目标类型为 commit，目标 SHA 精确为 `6bed55333a6483a4c5efd899d9942e7df3ced088`。
- 已发布非 Draft、Pre-release 的 [v0.1.0-rc.17](https://github.com/alieismy/debian-vps-tuning/releases/tag/v0.1.0-rc.17)，Release ID `386117329`，发布时间 `2026-09-10T08:34:26Z`。发布包含 19 个扁平资产：清单管理的 17 项，加 `SHA256SUMS` 和 `install.sh`；发布说明已使用真实 Pre-release/CI 状态，没有沿用仓库草案中的“未发布候选”表述。
- 已从公开 Release 重新下载全部 19 个资产；资产名称集合和 GitHub API `sha256` digest 逐项一致。下载所得 `SHA256SUMS` 摘要为 `d44284ed010a5a9774fc104cea50a51bd209f8e0d1e57b9680cdf147e5bdc208`，`install.sh` 摘要为 `4fd4dde90df4524d657623c4e22e355ab9adac70a703cff61a68e41e09007cbc`；按清单逻辑路径重建目录后，17 项 `sha256sum -c` 全部为 `OK`。
- 本轮没有连接或修改任何 VPS，没有运行公网 `iperf3`、TcpQuality 或代理业务流量，也没有启用持久 HTB、改变默认 `BBR + fq`、17 项受管 sysctl、HTB rate 或 burst/cburst 参数。

### 未完成门禁

- Release 完整性已经闭合，但目标测试 VPS 的 Debian/资源档/200 Mbps 套餐/`eth0`/rc.17 schema 4 `VERIFIED`/根 `fq`、服务商剩余流量、无业务负载窗口，以及自有或获授权 iperf3 endpoint、port、地址族和服务端容量仍需现场冻结和验证。
- 正式 A/B/A 仍不能直接执行：必须先运行 HTB200 reference，必要时运行 candidate sweep 并人工冻结唯一 shortlist rate；随后须把旧 rc.14/TcpQuality A/B/A SOP 更新为 rc.17、schema 3 root/leaf qdisc 与共享预算契约，再分别生成独立 `aba` 和 `bab` 窗口。
- 本轮发布证明的是版本、资产和证据工具完整性，不证明 aggregate shaping 能降低特定 VPS 的重传，也不证明生产 VLESS + REALITY + TCP 业务改善、重启持久性或服务商 policer 根因。

### 延期事项变化

- rc.17 tag、Pre-release、19 项资产和公开反向摘要校验从未完成门禁转为已完成。目标 VPS 与 endpoint 冻结、HTB200 reference、candidate sweep 和 A/B/A 仍保持分阶段授权与证据门禁。
- 无新增默认 HTB、持久化、sysctl、burst/cburst 或生产速率授权。旧 A/B/A 文档/执行契约的 rc.17 同步仍是进入正式 A/B/A 前必须完成的修复项。

### 当前成熟度判断

当前达到 `RC17_PRERELEASE_PUBLISHED_AND_PUBLIC_ASSETS_VERIFIED`。rc.17 的提交、合并后 CI、注释 tag、Pre-release、19 项公开资产及摘要链已经闭合，可以作为测试 VPS 的固定安装来源；性能研究仍停在运行前准备层级，尚未达到目标 VPS reference、candidate、A/B/A 或真实业务改善证据层级。

## 本轮记录：2026-09-10（HTB200 reference、candidate sweep 与 A/B/A 准备复核）

### 已完成及证据

- 用户表示 rc.17 的独立授权事项已经完成，并询问如何准备测试 VPS、固定 iperf3 endpoint、地址族和流量预算。实时 GitHub 复核确认 PR `#16` 已于 `2026-09-10T08:14:47Z` 合并，merge commit 为 `6bed55333a6483a4c5efd899d9942e7df3ced088`；但 `gh release view v0.1.0-rc.17` 返回 `release not found`，Git tag ref API 返回 HTTP 404，因而不能把“已合并”写成“tag、Pre-release 和公开资产反向验证已完成”。
- 重新核对 rc.17 wrapper：`dvt htb reference/sweep` 只接受 Debian 13、`debian13-1c1g`/`debian13-1c2g`、schema 4 `VERIFIED`、200 Mbps、`eth0` 和非持久 HTB；每阶段临时执行 `HTB rate=ceil + fq`，并要求固定 Release 中 root-owned、非符号链接、不可由 group/world 写入且摘要一致的 `/usr/local/sbin/htb-aggregate-experiment`。runner 只测 upload，并在每阶段恢复根 `fq`。
- 按默认 3 样本、10 秒有效窗口、3 秒 omit 现场复算：HTB200 reference payload 上界为 `975000000` bytes（约 `0.9080 GiB`）；180/190/195 candidate sweep payload 上界为 `4704375000` bytes（约 `4.3813 GiB`）；合计 `5679375000` bytes（约 `5.2893 GiB`）。共享账本 `8192 MiB` 可覆盖一次完整 reference+sweep，并剩余约 `2775.73 MiB` 账本空间，但不包含协议开销、重传、失败重试或服务商计费差异，服务商实际剩余额度建议至少预留 10–12 GiB。
- 确认 `reference-screen` 和 `candidate-sweep` 已有 rc.17 自动执行、schema 3 root/leaf qdisc 健康、预算与恢复门禁；正式 A/B/A 仍只有 `experiment-plan.sh` 和一份标为 rc.14/TcpQuality 的手工 SOP。该 SOP 的适用版本、state 示例和部分直接 runner 命令未同步到 rc.17，不能在 shortlist 出现后原样执行。

### 未完成门禁

- 必须先补齐 `v0.1.0-rc.17` tag、Pre-release、19 项固定资产和公开反向摘要校验，随后才可从固定 Release 安装到测试 VPS。当前不得从 `master` 或工作树直接运行 HTB 流量实验。
- 测试机的 Debian/资源档/200 Mbps 套餐/`eth0`/rc.17 schema 4 `VERIFIED`/根 `fq`、服务商控制台、剩余流量、磁盘空间和无业务负载窗口尚未提供运行证据；固定自有或获授权 iperf3 endpoint、port、地址族、iperf3 版本和服务端容量也尚未冻结。
- A/B/A 不能在 reference 前预先授权自动执行。必须先完成 reference，必要时完成 candidate sweep 并人工冻结一个 shortlist rate；其后还需把 A/B/A SOP 升级到 rc.17、补齐与 schema 3 root/leaf 证据和共享预算一致的执行契约，再分别生成 `aba` 与 `bab` 两个独立窗口。

### 延期事项变化

- 新增一个文档/执行契约修复项：`docs/experiments/htb-candidate-rate-sweep.md` 和 `docs/experiments/vmiss-1c2g-200mbps-htb-aba.md` 仍含 rc.14 适用文字；A/B/A SOP 还依赖旧 TcpQuality 手工 harness。重新执行前必须同步 rc.17 版本与摘要、明确预算和 schema 3 qdisc 证据，不靠操作者手工替换版本号。
- 无新增默认 HTB、持久化、sysctl、burst/cburst 或生产速率授权。burst 比较仍须等待候选 rate 的 A/B/A 结论关闭后再作为单独变量。

### 当前成熟度判断

当前达到 `PR_MERGED_EXPERIMENT_PREPARATION_BLOCKED_BY_RELEASE_AND_ABA_CONTRACT`。reference/sweep 工具实现和 CI 已通过，但固定 rc.17 Release 尚不存在，测试环境与 endpoint 尚未冻结，A/B/A 文档契约仍是旧版；因此现在只能准备资源和只读信息，不能开始 HTB 流量。

## 本轮记录：2026-09-10（rc.17 候选提交、PR 与 Linux CI）

### 已完成及证据

- 用户明确授权提交当前 rc.17 候选、创建并推送 `codex/rc17-htb-evidence` 分支、创建 PR、等待并修复本次改动引入的 CI 问题，并要求 CI 全部通过后停止，不创建 tag 或 Release。实施提交为 `b16a96845595d9dd881215cf85e63815f654d817`，提交主题 `fix(htb): preserve root and leaf qdisc evidence`；提交后工作树干净，`git diff HEAD^ --check` 通过。
- 分支已推送到 `origin/codex/rc17-htb-evidence`，GitHub PR 为 `#16`（`https://github.com/alieismy/debian-vps-tuning/pull/16`），base 为 `master`，head 精确绑定上述提交。PR 描述记录了原缺陷、schema 3 root/leaf 证据、脱敏 socket 指标、默认参数不变和未包含目标 VPS/发布操作的边界。
- 同一提交的 push 工作流 `34453343912` 和 PR 工作流 `34453404532` 均为 `success`。PR `validate` job `102794092373` 完成 checkout、生成 profile 与 shell 结构、Linux root verified installer lifecycle 和固定 ShellCheck 0.11.0；没有需要修复的本次引入失败。唯一 annotation 是 `actions/checkout@v4` 的 Node.js 20 弃用提示，GitHub runner 强制使用 Node.js 24，job 仍成功；该提示不属于 HTB 实现缺陷。

### 未完成门禁

- 本记录作为 docs-only 状态提交推送后，PR head 必须重新通过同一 GitHub Actions 门禁，才能在最终回复中称为当前 head CI 全部通过。该提交不修改 profile、installer、HTB 工具或候选摘要。
- 合并 PR、创建 `v0.1.0-rc.17` tag、Pre-release、上传及公开反向校验仍未授权；目标 VPS、iperf3、HTB A/B/A 和真实代理业务也未授权、未执行。

### 延期事项变化

- 无新增调优或实现延期事项。`actions/checkout@v4` Node.js 20 annotation 仅登记为上游 action 维护提示；当前 workflow 成功，不在本轮扩展为 CI 依赖升级。

### 当前成熟度判断

rc.17 实现提交已达到 `IMPLEMENTATION_COMMIT_AND_INITIAL_PR_CI_PASS`。在资料性状态提交的最终 head CI 通过后，本轮授权范围即闭合并停在开放 PR，不自动合并或发布；性能改善和生产采用仍没有目标 VPS 证据。

## 本轮记录：2026-09-10（rc.17 实现后的下一步门禁建议）

### 已完成及证据

- 基于 rc.17 已达到 `LOCAL_IMPLEMENTATION_AND_FIXTURE_COMPLETE`，确认下一条最短路径是先完成候选交付门禁：提交本地实现、推送独立分支、创建 PR、等待 Linux root 与固定 ShellCheck CI，并在修复所有本次引入的失败后再准备 `v0.1.0-rc.17` Pre-release。CI 和公开资产反向校验通过前，不把本地工作树候选部署到目标 VPS。
- 用户本轮只询问“下一步需要我怎么做”，尚未授权 commit、push、PR、tag、Release、目标 VPS 连接或主动流量测试；本轮没有执行这些动作，也没有修改实现、摘要或默认网络参数。

### 未完成门禁

- 第一门禁等待用户明确授权候选交付闭环，包括 commit、push、PR/CI、tag、Pre-release 和公开资产反向校验。若只授权 PR/CI，不自动创建 tag 或 Release。
- 第二门禁是在 rc.17 发布并通过公开资产复核后，由用户准备或指定独立测试 VPS、自有或获授权的固定 iperf3 endpoint、允许的地址族和总流量预算；随后才生成 reference-screen 计划。candidate sweep、A/B/A、反向窗口和真实 VLESS + REALITY + TCP 仍分别受证据及授权约束。

### 延期事项变化

- 无新增延期事项。既有永久 HTB、默认参数修改、tcpfit 参数包和 burst/cburst 独立比较继续保持原有边界。

### 当前成熟度判断

当前状态仍为 `LOCAL_IMPLEMENTATION_AND_FIXTURE_COMPLETE_AWAITING_DELIVERY_AUTHORIZATION`。用户现阶段无需在 VPS 上手工执行命令；只需决定是否授权 rc.17 候选的 Git/GitHub 交付闭环。目标机整形实验应在该闭环通过后单独开始，避免把未经过 Linux root CI 和公开摘要复核的工作树字节带入性能结论。

## 本轮记录：2026-09-10（rc.17 HTB/FQ 证据完整性实现候选）

### 已完成及证据

- 用户已授权进入实现阶段。本轮在本地工作树形成未发布的 `v0.1.0-rc.17` 候选，修复 `qdisc_counter_snapshot` 对 HTB 子 qdisc `parent MAJOR:MINOR` 的识别，同时保留 `mq` 的 `parent :N` 语义，并明确排除 `ingress`/`clsact`。HTB root 与 FQ leaf 现在分别写入 `qdisc_root_totals`、`qdisc_leaf_totals` 和 `qdisc_health`；root/leaf bytes 不相加，HTB root `overlimits` 只作为整形暴露证据。缺少与 HTB root 同接口的 FQ leaf 时摘要生成 fail closed。
- benchmark phase summary 升级到 schema 3；`rate-sweep-analyze.sh` 升级到 `0.4.0`，只接受完整的 schema 3 HTB→FQ upload 摘要。任一 root/leaf drop 或 requeue、旧 schema、缺失 qdisc 健康字段、无正 root `overlimits`、速率暴露不足、测量窗口无效、CPU/steal、softnet 或接口异常都会输出 `REVIEW_BLOCKED` 且 shortlist 为空。零本地 qdisc drop/requeue 只表示该采样窗口内未观察到本地两层队列异常，不解释下游或远端路径丢包。
- `rate-sweep-run.sh` 的脱敏 `ss -tin` 白名单新增 `pacing_rate`、`delivery_rate`、`minrtt`、`dsack_dups`、`rcv_ooopack`、`snd_wnd` 和 `rcv_wnd`。带空格的 rate 字段只接受数值加速率单位，继续丢弃 endpoint、端口、PID、进程名和 inode；字段缺失时保持缺失，不伪造零值。
- 新增或收紧的 fixture 覆盖：HTB root + `parent 1:10` FQ leaf、`parent ffff:fff1` ingress 不误归类、root drop 为零而 leaf drop/requeue 非零、root requeue 非零、root `overlimits > 0` 且 leaf 健康、HTB 缺叶 fail closed、既有 `mq parent :1/:2`、旧 schema 和 socket 脱敏。缺叶 fixture 的前后快照都保持相同键集合，确认失败来自拓扑门禁而不是计数器键漂移。
- 六份 profile 已从单一模板重新生成；controller、installer、预算、迁移、TcpQuality 和 HTB 实验绑定统一为未发布的 rc.17 候选。最终 `SHA256SUMS` SHA-256 为 `d44284ed010a5a9774fc104cea50a51bd209f8e0d1e57b9680cdf147e5bdc208`，`install.sh` SHA-256 为 `4fd4dde90df4524d657623c4e22e355ab9adac70a703cff61a68e41e09007cbc`。已发布 rc.16 文件和公开地址未被覆盖，README 仍把联网命令固定到不可变 rc.16。
- 最终本地验证均 exit 0：`bash -n` 覆盖本轮核心脚本和测试，`python tools/render_profiles.py --check`，`sha256sum -c SHA256SUMS`，`experiments/htb-aggregate/tests/static-check.sh`，`tests/static-check.sh` 和 `git diff --check`。主静态门禁末尾为 `static checks passed for 6 scripts`；其中 `mock tc failure` 和无效 eBPF 元数据是预期负向 fixture。没有连接或修改目标 VPS，没有运行公网测速、真实代理流量或第三方 root 脚本。

### 未完成门禁

- 当前 Windows/Git Bash 环境不能提供 Linux root lifecycle；`tests/installer-check.sh` 和 `tests/rc17-check.sh` 的 root 路径、固定 ShellCheck CI、GitHub PR/CI、tag、Pre-release、公开资产反向下载与摘要复核均未执行。用户本轮没有授权 commit、push、tag 或 Release，当前 rc.17 只能称为本地实现候选。
- 该实现修复的是 HTB 研究的证据完整性和 shortlist 门禁，不会直接降低用户 VPS 的重传。是否需要 aggregate shaping 仍须在单独授权后，以固定 endpoint、方向、地址族、并发、预算和时间窗执行 HTB200 reference、候选速率扫描、A/B/A、反向窗口和真实 VLESS + REALITY + TCP 复验；还须同时检查 RTT/min RTT、CPU/steal、softnet、接口与 root/leaf qdisc 计数。
- 默认 profile 继续使用 `BBR + fq`、17 项受管 sysctl、资源感知缓冲和非持久 HTB 实验边界。本轮没有采用 tcpfit 的完整 sysctl 参数包、固定 150 ms RTT、持久 systemd shaper、`fq maxrate` 二次逐流限速、`initcwnd/initrwnd`，也没有把当前 `burst=262144`/`cburst=32768` 改为 tcpfit 约 4 ms burst。

### 延期事项变化

- 新增 rc.17 发布门禁：只有用户另行授权后，才能进行提交、PR/CI、tag、Pre-release 和公开资产反向验证；在此之前不得把候选摘要或 installer 当作已发布入口。
- 新增目标 VPS 证据门禁：取得独立高额度测试机、固定 iperf3 endpoint 和量化流量预算后，先用 schema 3 验证真实 HTB root/FQ leaf 采集，再决定是否进入速率扫描和 A/B/A。burst/cburst 比较只能在速率候选稳定后作为单独变量，不能与 aggregate cap 同轮混杂。
- 无新增默认参数、永久 HTB、通用 UDP、CAKE、RPS/RFS、MSS Clamp 或第三方内核候选；既有延期状态保持。

### 当前成熟度判断

rc.17 达到 `LOCAL_IMPLEMENTATION_AND_FIXTURE_COMPLETE`：已从静态复现缺陷推进到本地实现、生成资产、摘要链和正负 fixture 闭环，能够避免 HTB root 零 drop 掩盖 FQ leaf 异常，并阻止旧或不完整证据进入 shortlist。它尚未达到 Linux root、公开发布、目标 VPS 或性能改善证据层级；因此只能支持“研究工具的证据可信度已提高”，不能支持“HTB 已降低用户 VPS 重传”或“应默认启用 HTB”。

## 本轮记录：2026-09-10（tcpfit 整形专项与重传因果再评估）

### 已完成及证据

- 在上一轮三个外部项目固定源码研究的基础上，针对用户报告的 VPS TCP 重传重新检查 tcpfit `v0.5.7`（commit `1163c20e88a4a7130ef7d885da8be3a163505003`）的整形路径、Linux FQ/HTB 一手语义、当前 rc.16 非持久 HTB 参数和重传证据链；详细主张、源码锚点与限制已补入 [外部网络调优研究证据包](external-network-tuning-research-2026-09-10.md) 的“整形专项再评估”章节。
- 确认 tcpfit 的 `HTB rate=ceil` 负责聚合出口上限，`fq maxrate` 只是单流上限；receiver goodput、sender retransmission/GiB 和重复 loss-spike 复测具有条件参考价值，但其固定 RTT、单一端点、流量估算和持久 unit 不能直接替换 rc.16 的资源/预算/所有权契约。
- 用当前 `tools/profile-template.sh.in:qdisc_counter_snapshot` 原样函数和 `qdisc htb 1: root` + `qdisc fq 10: parent 1:10` 合成输出复核：`parent 1:10` 被归入 `other`，不是 `leaf`。因此 HTB root drop 为零时，FQ 叶子 drop/requeue 可能未进入 `build_benchmark_phase_summary` 的主要汇总；这是高置信度的静态证据完整性缺口。现有 `tests/static-check.sh` 的 `mq` `parent :1/:2` fixture 未覆盖该拓扑。
- 本轮运行了现有本地 `bash tests/static-check.sh`，最终 exit 0；该结果只说明已有门禁未回归，不能抵消新增 HTB parent-handle fixture 缺口，也不构成 Linux root 或目标 VPS 性能证据。没有执行第三方 root 脚本、目标 VPS、公网 `iperf3` 或生产业务。

### 未完成门禁

- 用户报告的重传尚未绑定同一 endpoint、方向、地址族、负载窗口、sender bytes/retransmits、receiver goodput、RTT/pacing、CPU/steal、softnet、接口和 root/leaf qdisc 增量，因而不能确认根因是 provider aggregate policer、路径问题、虚拟化资源、队列溢出、端点或代理业务。
- 当前默认 profile 仍为 `BBR + fq`，没有 aggregate egress cap；tcpfit 的 HTB→FQ 只能作为条件候选。当前非持久 HTB 的 `burst=262144`/`cburst=32768` 与 tcpfit 约 4 ms burst 不同，但没有证据支持直接替换任何一组参数。
- HTB/FQ parent-handle 解析、root/leaf 全层 drop/requeue/backlog 汇总和 `pacing_rate`/`delivery_rate`/`minrtt` 等只读 socket 观测仍未实现；在此之前不应把现有 HTB 结果用于默认行为或永久整形决策。目标 VPS A/B/A、反向窗口、重启持久性和真实 VLESS + REALITY + TCP 业务仍未验证。

### 延期事项变化

- 新增一个有边界的证据链修复候选：在重新启用 HTB 性能研究前补齐 `parent MAJOR:MINOR` 叶子识别、HTB/FQ fixture 和全层 qdisc 汇总；它不等同于默认启用 HTB，也不改变 rc.16 已发布资产。
- 无新增默认参数或生产整形授权。tcpfit 的聚合 shaping、burst 比较和持久 opt-in 入口继续等待单独的需求、实现授权、固定 endpoint、预算和 A/B/A 证据；NetPilot/NetShape 的扩张 sysctl、CAKE、永久 HTB 等既有延期状态不变。

### 当前成熟度判断

rc.16 发布完整性和默认 profile 边界不变。当前结论从“没有已证明的 rc.16 功能缺陷”精炼为：没有已证明的**默认整形行为**缺陷，但发现了会影响 HTB 研究证据可信度的静态 parser 缺口；用户重传使缺少 aggregate shaping 成为中低置信度、高价值待验证假设。当前只达到固定源码、官方语义、本地源码和合成 fixture 层级，未达到目标 VPS 根因或性能改善层级。

## 本轮记录：2026-09-10（tcpfit、vps-netpilot、netshape-manager 外部研究）

### 已完成及证据

- 已按当前 GitHub `main`/tag 快照重新冻结并只读检查三个项目：`tcpfit` `v0.5.7`/commit `1163c20e88a4a7130ef7d885da8be3a163505003`，`vps-netpilot` `main`/commit `705a307684b7b0cb57747bf2e5abb4ed6ada6cdd`，`netshape-manager` `main`/commit `647b454b934349a179b1db289518eb9280adc839`；许可证均为 MIT。固定脚本摘要、源码锚点、功能和采用矩阵已写入 [外部网络调优研究证据包](external-network-tuning-research-2026-09-10.md)。
- 三个主脚本均通过只读 `bash -n`；NetShape `tests/self-test.sh` 和 `peertune/tests/self-test.sh` 全部通过。该证据只达到源码/合成 fixture 层级，未执行第三方 root 脚本、未连接目标 VPS、未运行公网 `iperf3` 或生产业务。
- 研究确认 tcpfit 的 receiver goodput、重传增量、重复 loss-spike、锁和异常回收具有条件参考价值；NetShape 的 HTB aggregate/fq 语义、qdisc drift/ownership 处理以及 peertune 的 `ss -tin` 分布观测可作为未来实验或只读诊断输入。当前 rc.16 已覆盖或以更强契约覆盖这些机制的核心边界。
- 研究确认 NetPilot 的可变 `main` 自更新、四项关键值回退、总内存 5% 缓冲、通用 UDP/conntrack、RPS/RFS、MSS Clamp、IPv4 优先和按内核版本推断 BBRv3 均不足以进入 rc.16；tcpfit/NetShape 的扩张 sysctl、`initcwnd/initrwnd`、CAKE、固定经验值和永久整形同样不进入默认 profile。

### 未完成门禁

- 本轮没有目标 VPS 的第三方运行、重启持久性、真实 VLESS + REALITY + TCP 业务、A/B/A 性能或 provider policer 因果证据；外部项目 README、维护者提交中的实时数字和合成测试不能提升这些证据层级。
- 当前 rc.16 的 17 项 sysctl、资源感知 BDP、根 `fq`、fail-closed 流量 ledger、非持久 HTB 和策略路由只读边界保持不变；本轮没有发现已被证明的默认整形行为缺陷，但默认 profile 没有 aggregate shaping，用户重传使该缺口成为高价值待验证假设。

### 延期事项变化

- 无新增延期事项。tcpfit/NetShape 的 goodput/聚合速率算法只在新实验需求、固定 endpoint、批准预算和 A/B/A 证据出现时重新评审；peertune 的多客户端 RTT/膨胀/抖动只在明确的多客户端诊断需求或可复现业务症状出现时重新评审。多跳 relay/landing、CAKE、永久 HTB、通用 UDP、RPS/RFS、MSS Clamp、`initcwnd/initrwnd` 和第三方内核继续保持既有延期或未授权状态。

### 当前成熟度判断

rc.16 发布完整性和阶段成熟度判断不变。本轮新增的是固定源码证据和采用分类，不构成参数、拓扑、默认 qdisc、发布资产或目标 VPS 运行状态变更；当前结论仍只达到仓库/公开发布完整性与外部源码研究层级，目标 VPS 真实性能和业务验收仍未验证。

## 本轮记录：2026-09-03（3X-UI v3.4.2 Stage 6A 安装前只读与供应链门禁）

### 已完成及证据

- 用户明确授权 Stage 6A：允许通过严格 SSH 对目标机重新执行系统健康、包管理、DVT 状态、受管文件、端口和防火墙只读检查，并固定核对 3X-UI v3.4.2 tag、commit、安装器和 amd64 Release 资产；同时明确禁止安装、修改防火墙、开放端口、reboot、创建代理入站和主动流量测试。执行始终使用独立确认的 ED25519 host key、`StrictHostKeyChecking=yes`、`HostKeyAlgorithms=ssh-ed25519`、`BatchMode=yes`、禁用密码/键盘交互认证、`IdentitiesOnly=yes` 和指定 agent identity；本轮没有把 host key 写入用户全局 `known_hosts`。
- 目标机最终精简复核共 18 项只读门禁全部通过：Debian 13、目标内核及 Stage 4/5 boot-ID 值摘要保持，systemd running、failed unit 0、SSH active、时间同步、无 reboot-required、`dpkg --audit` 为空且没有真实包管理进程；`dvt verify`/`status` 均 exit 0，state 摘要仍为 `77db50a4a26989133f7a58554d52c566d44724204698c9abb5c73366407ce8c9`，schema 4 `VERIFIED`、`debian13-1c2g`、500 Mbps、200 ms、33554432 字节保持。17 项 sysctl 文件值和运行值一致，`bbr + fq`、唯一根 `fq`、无 HTB、1024 MiB 项目 swap、fq service、默认 policy rules、provider source/backup 固定摘要和 DVT x-ui NOFILE drop-in 均未漂移。
- 3X-UI 在目标机上仍不存在：没有 `/usr/local/x-ui`、`/usr/bin/x-ui`、`/etc/x-ui`、systemd 主 unit、x-ui/Xray 进程或代理入站。当前监听集合仍只有 TCP 22/53/5355 和 UDP 53/5355，80/443 及 3X-UI 默认内部端口均空闲；UFW installed/inactive，`nft` 命令和服务未安装、guest 内没有 nft 对象。服务商侧防火墙无法由 guest 反向证明，继续保留为外部证据缺口。
- 固定上游证据为 3X-UI `v3.4.2` 非 Draft、非 Pre-release Release，发布时间 `2026-06-29T18:30:19Z`；lightweight tag 解析到 commit `f3a57d4c57fbcae94414138de42b7ef11dc513c8`，该 commit 的 GitHub verification 为 `verified=true, reason=valid`。固定 commit 的 `install.sh` 为 71736 字节，SHA-256 `bd1e19b674526c3e1fb7944500fef81e1e049e5c1db2ae7bbfa9a15b05667a1b`；`x-ui-linux-amd64.tar.gz` 为 83352799 字节，GitHub API digest 和本机实际下载摘要均为 `1086716ea4b09f87893da3d83d5957af28ab7094c3a3a374cb3b369f6c0009a6`。tag 本身不是 annotated/signed tag；本轮也没有取得 Release 二进制的维护者独立签名或可复现构建证明，因此该摘要门禁证明“将安装的字节等于本轮固定的 GitHub Release 字节”，不把它夸大为完整源码到二进制来源证明。
- 固定压缩包共 17 项、只有单一 `x-ui/` 顶层目录，未发现绝对路径、`..` 逃逸、重解析点或符号链接；压缩包中的 `x-ui.sh` 与固定 tag/commit 源码逐字节一致。关键内容摘要为：3X-UI 主程序 `03ee1876ad3fdea20edec890bd1169b7a35aaad23cfcc70eae839fcc59f58c25`、`x-ui.sh` `14b9ed4cd14aaf9bd54932249170c53ceac147940844e7929eb7b2b204568397`、Debian unit `dbd78334fc1931f4f8f8693050076193234685e7f2abf2ec91ea08c8c7a8343b`、Xray amd64 二进制 `8ef87ac07f95617e094b8e9302ea3e0c2d0edaa7045d57b455fdee28b3c9e41e`。固定源码内版本为 3X-UI 3.4.2，Release 声明捆绑 Xray 26.6.27；3X-UI Go build metadata 指向 Xray commit 前缀 `45cf2898ab12`，仍须在实际安装前用有界版本命令核对归档内二进制输出。
- 官方安装器即使传入固定 `v3.4.2`，仍会无条件从 `main/x-ui.sh` 下载管理脚本；当前 `main` 版本已与固定 tag 内容不同。安装器无 `sha256sum`/`sha512sum`、GPG 或 Cosign 校验原语；未传版本时还会查询 `releases/latest`。Debian 路径无条件执行 `apt-get update` 并安装 `cron curl tar tzdata socat ca-certificates openssl`；目标机仅缺 `cron`，当前模拟结果为 `0 upgraded, 18 newly installed, 0 to remove`，会连带 Exim、Perl 等与本次 SQLite、loopback 面板无关的包。APT 源递归解析后只有 `deb.debian.org` 且没有 insecure override；首次把 `mirror+file:` 当域名的结果是采集器假阴性。
- 官方安装器会把用户名、密码、panel port、WebBasePath、access URL 和 API Token 输出到 stdout，并写入 `/etc/x-ui/install-result.env`；这不满足本轮“秘密不得进入日志或对话”的约束。固定源码还确认：首次 `database.InitDB` 在空库中创建 bcrypt 化的默认 `admin/admin`；`x-ui setting` 的各单项更新失败可能只打印错误而总体仍返回成功；SQLite 初始化只 `MkdirAll(..., 0755)`，不显式把数据库改为 `0600`。因此下一阶段必须在服务第一次启动前以 `umask 077` 预建 root:root/0700 的 `/etc/x-ui`，立即覆盖默认凭据、panel port、WebBasePath 和 `listenIP=127.0.0.1`，把命令输出隔离后逐项回读比较，并确认 `/etc/x-ui/x-ui.db` 为 root:root/0600，不能只信 CLI exit 0。
- 固定源码确认 API Token 默认值为空，只有显式执行 `setting -getApiToken true` 才会创建并一次性打印明文，数据库只存 SHA-256。Stage 6B 不需要 API 自动化，推荐不调用该命令、不创建 API Token；后续若确需 API，再在独立授权阶段生成并一次性写入 root-only 凭据文件。Xray 运行配置由同目录临时文件原子替换并强制 `0600`；空业务配置下只含回环 API `127.0.0.1:62789` 和 metrics `127.0.0.1:11111`，面板启动时仍会启动 Xray，因此安装后须验证只存在这些内部监听且没有业务入站。
- 推荐 Stage 6B 不运行官方 `install.sh`，改用固定 Release 资产的等价手工安装：目标机从固定 URL 下载到 root-only staging，先核对字节数和 SHA-256，再复用归档内同 tag 的 `x-ui.sh` 和 `x-ui.service.debian`；不执行 APT update/install，从而同时消除 `latest`、`main`、无摘要下载和 18 个无关包。Debian unit 直接执行 `/usr/local/x-ui/x-ui`，无动态下载；与既有 `/etc/systemd/system/x-ui.service.d/90-proxy-vps.conf` 兼容，后者应使 x-ui 主进程和直接 Xray 子进程的 NOFILE soft/hard 均不低于 65536。
- Stage 6B 的秘密只在远端内存中生成，禁止 `set -x`，设置命令 stdout/stderr 进入 root-only 临时缓冲且不回传；用户名、密码、panel port 和 WebBasePath 只写 `/root/3x-ui-bootstrap.env`，root:root/0600，不写 access URL。3X-UI 可在数据库初始化时生成内部 panel GUID，但不得输出该值；本阶段不创建代理客户端 UUID、REALITY 密钥或客户端链接。普通证据只输出布尔门禁。服务启动后先用 `ss` 证明 panel 只绑定 `127.0.0.1`，再允许一次有界的本机回环 HTTP GET 作为 readiness；它不是公网或性能测试。用户应在自己的交互式 SSH 中读取 bootstrap 文件并存入密码管理器，不得把内容粘贴回 Codex。固定 CLI 只支持通过命令参数设置用户名和密码，因而在极短设置窗口内仍存在被同机 root 或可读 `/proc` 的本地观察者看到进程参数的剩余风险；Stage 6B 应先确认没有其他交互登录会话并立即执行、回读和清除 shell 变量，但不能把它描述为抵御已获得本机 root 权限的攻击者。
- 失败回滚仅允许删除 Stage 6B 新建对象：先 stop/disable `x-ui.service`，删除本阶段创建的主 unit、enable symlink、`/usr/local/x-ui`、`/usr/bin/x-ui`、`/etc/x-ui`、`/var/log/x-ui`、bootstrap 和 staging，再 `daemon-reload` 并运行普通 `dvt verify`。不得删除既有 x-ui drop-in、`/var/lib/proxy-vps-tuning`、`/swapfile-proxy`、项目 sysctl 或 `proxy-vps-fq.service`；若删除边界或回滚动作不能证明，停止并保留现场，不做宽泛清理。
- 两轮临时终态采集器出现的红项均已查明且未造成 VPS 写入：第一轮误用了不存在的 `state.env` 而非 `state.json`，对 boot-ID 文件直接哈希而不是对无换行值哈希，并使用了不适用的 swap 输出断言；第二轮把 `tcp_rmem`/`tcp_wmem` 的 tab 与空格差异误判为值漂移，且 PowerShell 传输尾部 CR 使诊断脚本在已输出结果后返回 2。改为真实 state 路径、权威 boot 摘要算法、`/proc/swaps`/`stat`、规范化向量空白并增加传输终止注释后，最终 18/18 只读门禁 exit 0；没有把采集器问题冒充主机故障。

### 未完成门禁

- Stage 6A 已完成并停在安装计划审阅。Stage 6B 尚未授权或执行；目标机没有下载或安装 3X-UI，没有创建数据库、bootstrap、API Token、代理入站或客户端材料，没有启动 x-ui/Xray、修改 UFW/服务商防火墙、开放端口、reboot 或运行主动公网流量。
- Stage 6B 若获授权，仍须紧邻写入重新检查严格 SSH、DVT 固定摘要、包管理、监听端口和安装目标均未漂移；完成固定资产安装、秘密内部回读、loopback 监听、systemd/进程/NOFILE、默认 Xray config、一次本机 readiness、严格 `REQUIRE_PROXY_SERVICE=1 PROXY_SERVICE_UNITS='x-ui.service' dvt verify`、`dvt status` 和 DVT 前后摘要不变性后立即停止。任何秘密回显、默认凭据残留、非 loopback panel、未知监听、版本/摘要不符或回滚不完整都必须 fail closed。
- 用户已确认的快照创建发生在 DVT Stage 2 之前；尚未确认是否另建 Stage 5 `VERIFIED` 终态快照。Stage 6B 前优先新增该快照；若服务商只允许一份，应由用户明确选择保留 pre-DVT 恢复点、替换为 Stage 5 恢复点，或接受只依赖受控文件级回滚的风险。
- 第二次 reboot、重启后严格 3X-UI/Xray 验证、VLESS + REALITY 配置、真实 1/3/5/10 并发 TCP 冒烟、业务期 `diagnose` 和真实性能对比仍未执行。Stage 4 的 `TCP22_CYCLE_OBSERVATION=NOT_OBSERVED` 继续保留；benchmark、probe、TcpQuality、HTB、故障注入、DVT rollback/purge 和快照恢复演练仍未授权。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。3X-UI 固定资产、凭据隔离、loopback 暴露面和安装失败回滚属于进入既定代理验收前的运行门禁，不把 3X-UI 安装器、API Token、面板安全或防火墙治理吸收到 rc.16 DVT 的产品管理面。

### 当前成熟度判断

目标机达到 `STAGE6A_SUPPLY_CHAIN_AND_READONLY_GATE_PASS_READY_FOR_STAGE6B_AUTHORIZATION`：固定 Release 资产、上游安装器风险、等价手工安装路径、秘密处理、监听顺序、systemd/DVT 兼容性、成功判据和有限回滚边界均已形成可执行计划，且目标机 Stage 5 终态无漂移。该状态只证明安装前就绪，不证明 3X-UI 已安装、面板已绑定 loopback、Xray/REALITY 已运行、第二次 reboot 或真实业务链路通过。

## 本轮记录：2026-09-03（确认 Stage 6 的 3X-UI 安装前门禁）

### 已完成及证据

- Stage 5 已以 `STAGE5_IDEMPOTENCY_PASS_READY_FOR_3XUI_AUTHORIZATION` 封口。用户本轮只询问下一步，不构成安装、服务启动、防火墙、reboot、代理入站或主动流量授权；本轮没有连接目标 VPS，也没有改变目标机状态。
- 依据当前仓库验收顺序，下一项运行门禁是安装并启动固定 3X-UI v3.4.2 后执行 `REQUIRE_PROXY_SERVICE=1 PROXY_SERVICE_UNITS='x-ui.service' dvt verify`；该严格验证只证明 `x-ui.service`、直接 Xray 子进程和 systemd/运行时 NOFILE 不低于 65536，不替代后续第二次 reboot、VLESS + REALITY + TCP 业务链路或性能验收。
- 本轮从官方 `MHSanaei/3x-ui` 重新核对 `v3.4.2` Release/tag：Release 为非 Draft、非 Pre-release，tag 解析到 commit `f3a57d4c57fbcae94414138de42b7ef11dc513c8`；tag 下 `install.sh` 的 SHA-256 为 `bd1e19b674526c3e1fb7944500fef81e1e049e5c1db2ae7bbfa9a15b05667a1b`，amd64 资产大小为 83352799 字节，GitHub API digest 为 `sha256:1086716ea4b09f87893da3d83d5957af28ab7094c3a3a374cb3b369f6c0009a6`。
- 上游安装器的当前固定源码审阅发现四项必须在写入前解决的操作风险：不传版本参数会查询 `releases/latest`；即使传入 `v3.4.2`，仍从 `main` 下载 `/usr/bin/x-ui` 管理脚本；下载 Release 压缩包后没有摘要校验；安装流程会向 stdout 输出用户名、密码、WebBasePath 和 API Token，并写入 root:root/0600 的 `/etc/x-ui/install-result.env`。此外，非交互且跳过 TLS 时明确选择不绑定 loopback；交互路径才可调用 `x-ui setting -listenIP "127.0.0.1"`，而安装器随后启用并启动 `x-ui.service`。
- 因此推荐把下一阶段拆为 Stage 6A/6B：Stage 6A 只读复核供应链、系统防漂移、端口/暴露面、凭据处理、systemd 和恢复路径，停在安装前；Stage 6B 再按审阅结论安装固定资产，默认使用 SQLite、面板仅监听 `127.0.0.1`、通过 SSH 本地转发访问、不启用 UFW、不创建 VLESS/REALITY 入站、不 reboot，并在不采集秘密的前提下执行严格运行态验证。进入 Stage 6B 前建议保留原始 pre-DVT 快照，并另建一份 Stage 5 终态快照；若服务商只允许单快照，应先决定保留哪个恢复点。

### 未完成门禁

- Stage 6A 尚未得到用户授权，也未执行。固定安装资产的安全落地方式、`main/x-ui.sh` 的消除或固定策略、解压前摘要门禁、面板 loopback 生效顺序、失败恢复和脱敏证据方案仍待 Stage 6A 形成最终安装计划；在此之前不执行 3X-UI 安装。
- Stage 6B 安装及安装后严格 `dvt verify`、第二次 reboot 与再次严格验证、真实 VLESS + REALITY + TCP 冒烟、业务期只读 `diagnose` 均未执行。Stage 4 的 `TCP22_CYCLE_OBSERVATION=NOT_OBSERVED` 限制继续保留；benchmark、probe、TcpQuality、HTB、故障注入、rollback、purge 和快照恢复演练仍未授权。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。上述 3X-UI 供应链、凭据和监听地址问题是进入既定代理验收前的运行门禁，不据此扩大 rc.16 的 DVT 功能范围，也不吸收 3X-UI 安装、防火墙或代理凭据管理职责。

### 当前成熟度判断

目标机仍为 `STAGE5_IDEMPOTENCY_PASS_READY_FOR_3XUI_AUTHORIZATION`。当前最小安全下一步是用户单独授权 Stage 6A 安装前只读审阅；本轮对上游源码的静态核对不能替代目标机安装、服务运行、第二次 reboot 或业务链路证据。

## 本轮记录：2026-09-03（新目标机 rc.16 重复 apply 幂等性验收）

### 已完成及证据

- 用户明确授权 Stage 5：在严格 SSH 和 apply 前防漂移通过后，只运行一次 `dvt apply --port 500`，核对预期 no-op 文本，证明 state、受管文件、provider 文件、swap inode、根 `fq` 和 service 前后不变，再运行 `dvt verify/status` 并完成最终自检；同时明确禁止 reboot、安装 3X-UI 和主动流量测试。执行始终使用任务专用单条 ED25519 host-key pin、`BatchMode=yes`、`IdentitiesOnly=yes`、禁用密码/键盘交互认证、root/TCP 22 和唯一匹配的 `vps_rsa` agent 身份，没有依赖或写入用户全局 `known_hosts`。
- 首个客户端只读 SSH 包装器把 `dvt --version` 误断言为单一版本号，在已经确认严格 SSH、root、目标内核、systemd running、failed units 0 和 SSH active 后 exit 1；实际接口为 `controller=0.1.0-rc.16 release=v0.1.0-rc.16`。统一真实接口并同时核对 boot ID 的“文件含换行”和“值不含换行”两种摘要后，确认不含换行的权威算法仍得到 Stage 4 固定摘要，启动时间仍为 Stage 4 的唯一实际 reboot；该包装器没有写远端证据或配置，也没有调用 `apply`。
- 第一次远端 apply 前审阅已依次通过 root、证据目录、目标内核/boot、systemd/SSH/时间同步、7 份 Stage 4 权威日志、state/qdisc/provider 摘要、schema/profile/network、5 个受管文件、17/17 安装资产、17 项 sysctl、BBR、默认路由和根 `fq`，随后仅因临时审阅器把 `ip rule` 的空白固定为空格、而 Debian 输出制表符，在三条 IPv4 默认规则的文本比较处停止。失败日志为 `stage5-pre-apply.failed.log`，SHA-256 `12c25e0c27df053290b5426aa44aa867d6f5b045dccda7fd63856442d2e1ba74`，其中没有 `APPLY_INVOKED=YES`。修正为逐行空白规范化、保留而不覆盖该失败证据后，完整 apply 前门禁通过 105 项 `PASS`、0 项 `FAIL`，权威日志 `stage5-pre-apply.log` 的 SHA-256 为 `97bfcae785cbe028a29b264ec1a38800ae7363760f2a871320c4fb2178606d0f`。
- apply 前分别运行的 `dvt verify` 和 `dvt status` 均 exit 0，日志 SHA-256 分别为 `8d6a3878ba902ce3315b5e143f03eef697f864d3eb9ca0efd88b7d01be1f6c4f` 和 `4f74fd10c7772feddb375a70aff8f706d91424e93ae4b9632b905db3d4bd7462`。随后固定的稳定快照覆盖 boot、内核、state 及 state 目录、5 个受管文件、provider source/backup、swap file/state/active record/fstab、默认出口根 qdisc、fq service 和 17 项文件/运行 sysctl，SHA-256 为 `ea3f4700aec4ed55088bbd3138d15fdb7d0553fd689d72ff29c3d1ecdf23a625`。
- 紧邻调用前再次核对上述权威日志和快照摘要、boot、state `VERIFIED`、500 Mbps/200 ms/33554432 字节、qdisc 原快照、provider 两份文件、state 目录、根 `fq`、swap device/inode、fq service、包管理进程和 DVT lock 后，受控包装器只调用一次 `dvt apply --port 500`。命令内部 preflight 和 `verify_settings` 均通过，exit 0，并精确输出“配置已存在且验证通过，无需重复写入。”；紧邻返回后的 boot、state、qdisc 原快照、provider 两份文件和 state 目录仍匹配。权威 apply 日志为 `stage5-repeat-apply.log`，SHA-256 `3882f0b7d4519e1a5c00e2daceac590deee93e2dbd8d7bb4e492f92f2f2d075c`，包含唯一一组调用、命令、exit 0 和 no-op 标记，且没有失败、未运行或歧义临时制品。
- apply 后分别运行的 `dvt verify` 和 `dvt status` 再次 exit 0；两份日志不仅摘要分别仍为 `8d6a3878ba902ce3315b5e143f03eef697f864d3eb9ca0efd88b7d01be1f6c4f` 和 `4f74fd10c7772feddb375a70aff8f706d91424e93ae4b9632b905db3d4bd7462`，还与 apply 前输出逐字节一致。post-apply 审阅完成 78 项 `PASS`、0 项 `FAIL`，日志 `stage5-post-apply.log` 的 SHA-256 为 `25b218386c62216c8dc6166f518a9a60f68cd708cc071e799285b9434ccca042`；post 稳定快照与 pre 快照逐字节相同，SHA-256 同为 `ea3f4700aec4ed55088bbd3138d15fdb7d0553fd689d72ff29c3d1ecdf23a625`，没有生成 snapshot diff。
- 最终独立自检完成 105 项 `PASS`、0 项 `FAIL`：state SHA-256 仍为 `77db50a4a26989133f7a58554d52c566d44724204698c9abb5c73366407ce8c9`，schema 4 `VERIFIED`、`debian13-1c2g`、500 Mbps、200 ms、33554432 字节、5 个受管文件、17 项文件/运行 sysctl、BBR、根 `fq`、provider `TRANSFERRED`、1024 MiB swap 的 device/inode/owner/mode/active/fstab、fq service enabled/active/exited 和 ExecMainStatus 0 全部通过。`stage5-final-self-audit.log` 的 SHA-256 为 `1d28cbe7184a5d0ba0fc75ee8039ba851e81bd97c9b2bf080a27f44eecd4d1cc`；新的严格 SSH 封口检查确认最终日志 root:root/0600、Stage 5 证据共 11 份、意外失败文件 0、隐藏临时文件 0、boot/state/system health 未变。全阶段未 reboot、未安装 3X-UI、未运行主动流量测试。

### 未完成门禁

- Stage 5 重复 apply 幂等门禁已完成。下一项既定生命周期门禁是另行授权安装并严格验证 3X-UI/Xray 运行态；在取得该授权前不安装面板或代理、不开放端口、不生成或使用真实客户端配置。其后仍需分别授权和执行第二次 reboot、真实 VLESS + REALITY + TCP 冒烟及业务期只读 diagnose，当前结果不证明代理进程的 NOFILE、生效配置、REALITY 链路或真实业务性能。
- Stage 4 的 `TCP22_CYCLE_OBSERVATION=NOT_OBSERVED` 限制继续保留；本轮按授权没有为补该观测再次 reboot。benchmark、probe、TcpQuality、HTB、故障注入、rollback、purge 和服务商快照恢复演练仍未授权且未执行。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。两次停止均来自本轮临时只读验收包装器对当前输出格式的过严断言，分别通过核对真实 `dvt --version` 接口和规范化 `ip rule` 空白修正；它们均发生在唯一 `apply` 之前，没有发现 rc.16 controller、profile、no-op 分支、managed state 或运行配置缺陷，不据此扩展通用框架。

### 当前成熟度判断

目标机达到 `STAGE5_IDEMPOTENCY_PASS_READY_FOR_3XUI_AUTHORIZATION`：固定 rc.16 在一次真实 reboot 后保持持久有效，并已证明相同 `--port 500` 输入下重复 `apply` 只验证现状、返回 0 且不改写稳定状态。该结论由严格 SSH、唯一调用日志、前后 `verify/status`、逐字节相同的稳定快照、独立自检和封口复核共同支撑；它不等于 3X-UI/Xray、第二次 reboot、真实 VLESS + REALITY + TCP、业务期 diagnose 或性能验收通过。

## 本轮记录：2026-09-03（确认 Stage 5 重复 apply 幂等性门禁）

### 已完成及证据

- 在 Stage 4 已完成一次真实 reboot、恢复后持久性审阅和最终自检的前提下，重新核对当前 rc.16 控制器：当已安装参数与本次输入一致且 state 为 `VERIFIED` 时，`apply` 会先执行 `verify_settings`，验证通过后输出“配置已存在且验证通过，无需重复写入。”并返回 0；因此下一项最短且有序的生命周期门禁是相同 `--port 500` 输入下的重复 `apply` 幂等性验收，而不是安装 3X-UI、再次 reboot 或运行流量测试。
- 用户本轮只询问“下一步需要我做什么”，不构成远端变更授权。本轮没有连接目标 VPS，没有执行 `dvt apply`、reboot、3X-UI/Xray 安装或主动流量测试，也没有改变任何目标机状态。

### 未完成门禁

- Stage 5 尚待用户明确授权。获授权后，应先完成严格 SSH、系统健康、包管理和摘要防漂移检查，记录 state、受管文件、provider 文件、swap、根 qdisc 和 service 的前置证据；只运行一次 `dvt apply --port 500`，核对预期 exit 0 和 no-op 文本，再证明 boot ID、state、文件摘要、swap device/inode、根 `fq` 与 service 状态未变化，并分别运行 `dvt verify` 和 `dvt status` 后停止。
- 严格 3X-UI/Xray 运行态验证、第二次 reboot、真实 VLESS + REALITY + TCP 冒烟、业务期只读 diagnose，以及另行授权和量化预算后的 benchmark/probe/TcpQuality/HTB 仍未执行。Stage 4 的 `TCP22_CYCLE_OBSERVATION=NOT_OBSERVED` 限制继续保留，不为补该观测单独增加 reboot。

### 延期事项变化

- 无新增项目功能或网络调优延期事项；本轮仅确认既定生命周期中的下一授权门禁，没有扩大范围。

### 当前成熟度判断

目标机状态仍为 `STAGE4_PERSISTENCE_REBOOT_PASS_READY_FOR_IDEMPOTENCY_AUTHORIZATION`，当前检查点为等待 Stage 5 明确授权。源码中的 `VERIFIED` no-op 分支只给出预期行为，不能替代目标 VPS 上对重复 `apply`、前后摘要不变性和后续 `verify/status` 的运行验收。

## 本轮记录：2026-09-03（新目标机 rc.16 单次持久性 reboot 与恢复验收）

### 已完成及证据

- 用户明确授权一次 DVT 持久性 reboot，要求在发出 reboot 前启动客户端 TCP/22 连续监测，并在恢复后核验 boot ID、严格 SSH、目标内核、`dvt verify/status`、schema 4 `VERIFIED`、17 项 sysctl、BBR、根 `fq`、项目 swap、fq service、受管文件和 provider 哈希；同时明确禁止重复 `apply`、安装 3X-UI 和主动流量测试。本轮始终使用任务专用 ED25519 host-key pin、`BatchMode=yes`、`IdentitiesOnly=yes`、root/TCP 22 和指定 identity，没有写入用户全局信任库。
- 紧邻实际 reboot 的最终防漂移检查完成 111 项 `PASS`、0 项 `FAIL`：Stage 3 权威日志、schema 4 state、9 个关键持久制品、17 项文件/运行 sysctl、`bbr + fq`、根 qdisc、1024 MiB 项目 swap、fq service、provider transfer、17/17 安装资产、`dvt verify/status` 和系统健康均未漂移；权威日志 `stage4-pre-reboot-armed.log` 的 SHA-256 为 `9bdfb8cad67df78963df8dc88f8ceed32cbd5b799e67cc2110a3794885212e27`。
- 首轮 TCP 监测实现每 500 ms 建立并立即关闭未认证的 TCP/22 连接。三个 dispatch 新 SSH 会话均在远端脚本启动前被丢弃；每次均以“无 dispatch 成功/失败/临时文件、boot hash 未变化、uptime 未归零、对应时间窗无 shutdown/reboot journal、systemd 无 reboot job”确认没有发生 reboot，因此没有把客户端 `exit 255` 误记为实际重启。目标 `sshd -T` 显示 `PerSourcePenalties` 包含 `noauth:1`、`min:15`；对应日志窗口出现 54 条 penalty 相关消息、46 条拒绝/丢弃消息，并明确记录 `penalty: connections without attempting authentication`，另有 124 次丢弃被日志限速汇总。该证据解释了未认证 TCP 探针与新 SSH dispatch 会话的冲突，但不把该时间窗内所有互联网扫描连接都归因于本机监测器。
- 在不改变实际 reboot 次数的前提下，改为先建立并校验一个严格、已认证且等待单次令牌的 SSH 会话，再启动新的 TCP/22 监测器；监测器达到连续 3 次 `UP` 后，只向既有会话发送一次令牌。远端 dispatch 门禁原子写入 `DISPATCH_GATE=PASS` 和 `REBOOT_REQUEST_PREPARED=YES`，日志 SHA-256 为 `d93e93b5c96174223444e4da7bcfae7b6757bfac9f8ef6faac3d69e6561d8f9d`，`systemctl reboot --no-block` 返回 0。只有这一请求实际进入 systemd 并形成 boot ID 变化，故目标机实际只重启一次。
- 最终客户端监测于 `2026-09-03T08:34:28Z` 在 reboot 前启动，`08:34:29Z` 达到 ready，并连续运行至 300 秒上限；恢复后的 boot 起始时间为 `08:34:53Z`，明确落在该监测窗口内，但 TCP connect 始终返回 `UP`，因此结果为 `ready=yes offline=no recovered=no`、exit 3，而不是预期的 `UP→DOWN→UP`。原始日志已以 root:root/0600 归档为 `stage4-tcp22-monitor.log`，SHA-256 为 `a46d89f6af41b8fa012b7719041efc656fcfc8830d4aacca631bb08dccc7e8fe`。该日志证明监测确实跨越实际 reboot，但不能证明端口下线窗口；不能排除服务商网络层仍完成 TCP 握手，也不能据此判断 guest sshd 在重启期间始终可用。
- 探针停止且 OpenSSH 来源惩罚窗口解除后，严格 SSH 重新认证成功。重启前 boot ID 的 SHA-256 为 `7300fbb9c034f6b475114331ee09c68c4a95f02a353b7b09c8f63622af705e52`，恢复后为 `b6421b00302173c81cdd49eee6db5a0b9ff7bec70318025b02a6a880d5112272`；仅记录摘要，不记录完整 boot ID。运行内核仍为目标 `6.12.107+deb13-amd64`，systemd running、failed unit 为 0、SSH active、时间同步、单 IPv4 默认路由和默认 policy rules 均正常。
- 独立 post-reboot 持久性审阅完成 157 项 `PASS`、0 项 `FAIL`，日志 SHA-256 为 `3affc7b675d69b56503ecb8aee382e4ab331dec3535f3b2e9c42475ea0391237`。分别执行并保存的 `dvt verify` 与 `dvt status` 均返回 0，日志 SHA-256 分别为 `27fe36cbabf164a03f93e33a8852e1beda0fc555463abc18ede5e3f0e7d3c78a` 和 `848d78074789c45f3abdd6cb7991f38fdcf9a3fecacfa50e51fce47726b5c982`；verify 为警告数 0，status 为 schema 4、`0.1.0-rc.16`、`VERIFIED`、`debian13-1c2g`、500 Mbps、200 ms、自动 `33554432` 字节，并报告 `bbr + fq`。
- 独立审阅逐项确认 17 个受管 sysctl 的文件值与运行值完全一致、BBR 可用且已启用、唯一 IPv4 默认出口实际根 qdisc 为 `fq`；`/swapfile-proxy` 为 root:root/0600、1024 MiB、device/inode 与 state 一致、已激活且 fstab 项目行精确一次；`proxy-vps-fq.service` enabled/active/exited、ExecMainStatus 0；journald 三项为 `128M/1G/64M` 且服务 active；x-ui 仍未安装而 NOFILE drop-in 保持 `65536`；无 iperf3、无 DVT 事务残留。state、qdisc 原快照、provider 原始备份、迁移后 `/etc/sysctl.conf` 及 5 个受管文件的固定摘要全部与 Stage 3 一致，17/17 安装资产校验通过。
- 最终自检再次完成 108 项 `PASS`、0 项 `FAIL`，日志 SHA-256 为 `d72a3a349fe8c7cd8fc5a241d5172a22d18989cbc83fe1bce7f2b68bd9d2525f`；其后新的严格 SSH 会话复核该日志、当前 boot hash、目标内核、state 摘要、systemd/SSH 和 failed units 均通过。3 个只用于 dispatch 的远端隐藏脚本在逐一核对固定摘要、owner/mode 和限定路径后删除，远端 Stage 4 隐藏临时文件计数为 0；没有再次 reboot、重复 `apply`、安装 3X-UI 或运行任何主动流量测试。

### 未完成门禁

- 客户端原始 TCP connect 监测没有观察到 `DOWN`，因此“TCP/22 `UP→DOWN→UP`”仍为 `NOT_OBSERVED`，不能写成通过。boot hash 变化、持久 dispatch 日志、目标内核和重启后运行态足以证明一次真实 reboot 以及 DVT 持久性，但不能替代该特定链路观测。不得只为补这一观测再次 reboot；若后续已授权阶段包含 reboot，应先建立已认证控制会话，或使用不会触发 `PerSourcePenalties` 的认证型 SSH 可用性监测，再独立保留 TCP 层结果。
- 重复 `dvt apply --port 500` 的幂等门禁尚未授权和执行。严格 3X-UI/Xray 验证、第二次 reboot、真实 VLESS + REALITY + TCP 冒烟和业务期 diagnose 仍未执行；当前 x-ui drop-in 只证明持久文件预置，不证明代理服务、Xray/REALITY 链路或业务性能。
- benchmark、probe、TcpQuality、HTB、故障注入、rollback 和 purge 继续未授权且未执行。服务商快照恢复能力仍停留在用户已创建并确认控制台可用的操作者证据层，本轮没有主动执行恢复演练。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。新增的是目标 OpenSSH 接受层与临时验收监测器之间的操作性证据：未认证高频 TCP/22 connect 会触发 `PerSourcePenalties` 并阻断同来源的新 SSH 控制会话。该问题不属于 rc.16 DVT 配置缺陷；其最小处置已在本轮验证为“先建立已认证控制会话，再启动监测”，不据此扩展新的仓库功能或安全专项。

### 当前成熟度判断

目标机的 DVT 持久性达到 `STAGE4_PERSISTENCE_REBOOT_PASS_READY_FOR_IDEMPOTENCY_AUTHORIZATION`：一次真实 reboot 后，严格 SSH、目标内核、schema 4 `VERIFIED`、17 项 sysctl、BBR、根 `fq`、项目 swap、fq service、受管文件、provider transfer 和发布资产均通过独立审阅及最终自检。该成熟度同时保留 `TCP22_CYCLE_OBSERVATION=NOT_OBSERVED` 限制；它不等于重复 apply、代理链路、第二次 reboot、真实业务或性能验收通过，下一步只能由用户另行授权幂等门禁。

## 本轮记录：2026-09-03（新目标机 rc.16 apply 与立即验收）

### 已完成及证据

- 用户明确授权重新执行 apply 前防漂移检查、运行一次 `dvt apply --port 500`，并完成立即 `verify`、`status`、managed state/文件/运行态审阅后停止；本阶段明确不 reboot、不安装 3X-UI、不运行主动流量测试。执行前再次确认 Windows OpenSSH alias 为 root/TCP 22、配置的 `vps_rsa` 与当前 agent 中身份唯一匹配，任务专用 `known_hosts` 只有固定 ED25519 记录；严格 host-key 校验的连接和 rc.16 版本检查通过。服务商快照继续以用户控制台确认作为操作者证据，目标机内部不能反向证明。
- 第一次防漂移采集器核对 Stage 2 权威日志摘要时，误把包装器返回的 `PASS_COUNT=55` 当作日志内文本；7 份 Stage 2 日志固定 SHA-256、系统健康和包管理门禁均已通过，但因过严格式断言以 exit 41 停止，未执行 apply，失败日志 SHA-256 为 `c31d9a19845cde970315ad8ad9b290d6edf4b0c985654080122bfd03cd648c06`。只读检查确认权威日志实际包含 55 条 `PASS:`、0 条 `FAIL:` 和 `OVERALL=PASS`，随后按真实格式修正断言。
- 第二次完整防漂移检查的 72 项系统断言和重跑的 `dvt preflight --port 500` 均已通过；preflight 仍为 `PASS_WITH_PROVIDER_SYSCTL_TRANSFER`、警告数 3，且 `/etc/sysctl.conf`、`/etc/fstab`、qdisc、`cubic + fq_codel`、无 swap/managed state 均确认零写入。PowerShell 在脚本 EOF 后追加只含 CR 的空行，远端 Bash 在全部通过标记之后返回 127；仍未执行 apply，失败日志 SHA-256 为 `5a585a1466fc3cacfafb3cdb09fbf0e08fbb3dfbd455f255cafd8f0ad324732b`。改用注释终止传输后第三次完整重跑通过，权威 pre-apply 日志 SHA-256 为 `d3011d4bc8af5cdd4452e95733e12d9f9f0d41ae55581827cbdfd3117b607f05`。
- 在紧邻 apply 的最小门禁继续确认 pre-apply 日志、`/etc/sysctl.conf` 固定原始摘要、未管理状态、rc.16 版本、systemd、failed units、真实包管理进程和四个锁均未漂移后，只执行一次 `dvt apply --port 500`。DVT 内部 preflight 再次通过，完整备份并事务化迁移厂商 sysctl 归属，写入受管配置，启用持久根 `fq` service，创建并激活 1024 MiB `/swapfile-proxy`，内建 verify 通过并提交 schema 4 `VERIFIED`；命令和外层包装均返回 0，apply 日志 SHA-256 为 `8693949bd02be957b00b1bd19dbe309a6f17e541e8cfaf2ad9e7d688b2e07ff7`。apply 前后 boot ID 一致，SSH 会话持续在线。
- apply 后使用新的严格 SSH 会话复核日志并分别运行 `dvt verify` 和 `dvt status`，两者均返回 0。立即 verify 确认自动选择 `debian13-1c2g`、固定 profile 摘要和警告数 0；因未安装代理服务，只报告 x-ui NOFILE drop-in 已预置，不把代理运行时写成通过。verify 日志 SHA-256 为 `c97a84e1f7ce8e655868b5fa007b8224c5427b46c0a9cea3c3657e9773b872ff`，status 为 `ee66a8e82dae20685fd11e8304b70440ced716660acb44ba11e5e282f5e3b66b`。
- 独立 post-apply 审阅完成 173 项 `PASS`、0 项 `FAIL`：state 为 schema 4、`0.1.0-rc.16`、`VERIFIED`、`debian13-1c2g`、500 Mbps、200 ms、自动 `BUF_MAX=33554432`；provider transfer 为 `TRANSFERRED`，原始 `/etc/sysctl.conf` 备份保持原摘要，迁移后源文件不再含活动定义；5 个受管文件的 owner/mode/marker/状态哈希全部匹配，17 个受管 sysctl 的文件值与运行值逐项一致；原 qdisc 快照为 `fq_codel`，当前唯一出口根 qdisc 为 `fq`；项目 swap 的路径、1024 MiB 文件大小、device/inode、活动状态和唯一 fstab 行一致；`proxy-vps-fq.service` enabled/active/exited，journald 三项有效配置和服务状态通过，x-ui 仍未安装。policy rules/default route、systemd、SSH、时间同步、UFW、dpkg 和包管理锁均正常，无 iperf3 进程。审阅日志 SHA-256 为 `cede4f6b134dd17e237cb0ef2f49cb4279f33e4474aabe272de0f6be10498d7a`。
- 关键终态摘要为：state `77db50a4a26989133f7a58554d52c566d44724204698c9abb5c73366407ce8c9`，qdisc 原快照 `33d926bdb2b9a27df37afeeb6106834e2a88b5ea752fac22b4198d727750bf4e`，provider 原始备份 `3f8a0bc244ff20b7ab4aa5900d736a7dba6b69f196d6125230bd7c34b7498ffd`，provider 迁移后文件 `7cf5fff5135b53f7eb84ff88d8d1b59d24540bed0e59b9b76ea740359adedfe6`，受管 sysctl `d0d2e7477f2f8c377857955f6d663310e44a78a9ebf080379d4527f826b6a9bb`。最终自检 42 项 `PASS`、0 项 `FAIL`，日志 SHA-256 为 `6f7b5e52231512153bb521c011a9d331c382686027b3b677c5c14739cc796601`；日志原子提交后严格重连和摘要复核通过，Stage 3 临时证据文件及 state 事务临时文件均为 0。

### 未完成门禁

- 本轮按授权停在立即审阅，不 reboot。尚未证明 17 项 sysctl、根 `fq`、活动项目 swap、journald、NOFILE drop-in、fq service 和 schema 4 state 在一次真实 reboot 后持续有效；下一次 reboot 必须在发出命令前先启动客户端 TCP/22 监测，以补齐此前未直接观察到的“在线→下线→上线”周期，再严格重连并运行 `dvt verify/status` 与文件哈希复核。
- 重启后通过以前，不执行重复 `apply` 幂等门禁。严格 3X-UI/Xray 验证、第二次 reboot、真实 VLESS + REALITY + TCP 冒烟和业务期 diagnose 仍未执行；当前 x-ui drop-in 仅是静态预置，不能证明代理服务存在、NOFILE 已作用到进程、Xray/REALITY 可用或业务性能改善。
- benchmark、probe、TcpQuality、HTB、故障注入、rollback 和 purge 继续未授权，也没有因 apply 成功而自动纳入默认路径。服务商快照恢复能力仍只达到“已创建且控制台可用”的操作者确认层，没有为了本轮成功主动执行恢复演练。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。两次 pre-apply 失败均来自本轮临时证据包装器，分别通过检查真实日志格式和修正 CRLF 传输闭合；失败证据完整保留，没有发现 rc.16 installer、controller、profile、事务迁移或立即 verify 缺陷，不据此扩展新的通用框架。

### 当前成熟度判断

目标机达到 `STAGE3_APPLIED_IMMEDIATE_VERIFY_PASS_PENDING_PERSISTENCE_REBOOT`：固定 rc.16 已在该 Debian 13 / 1C2G / 500 Mbps 目标机实际应用，立即 DVT 自验、独立运行态审阅、严格 SSH 连通和证据完整性均闭合。该结论仅证明本次启动周期内的配置与状态正确；下一安全检查点是用户单独授权一次 DVT 持久性 reboot，而不是自动安装代理、重复 apply 或运行性能流量。

## 本轮记录：2026-09-03（新目标机 rc.16 安装与 500 Mbps preflight）

### 已完成及证据

- 用户确认已在服务商控制台创建快照，并授权固定 rc.16 installer、未管理状态 `verify` 和 `preflight --port 500`，明确要求停在 preflight 审阅、不执行 `apply`。快照状态属于操作者确认，目标机自身无法反向证明；SSH identity 与任务专用 ED25519 host-key pin 在执行前再次匹配。
- 已现场反查 GitHub `v0.1.0-rc.16` Release：tag 精确、非 Draft、Pre-release，19/19 资产均为 `uploaded`，名称集合与当前清单一致，GitHub API 的 19 个 SHA-256 digest 全部匹配。目标机从固定 Release URL 下载的 `install.sh` 与 `SHA256SUMS` 分别通过外层固定摘要，清单为 17 项且包含预期总控与 `debian13-1c2g` profile；安装前系统、Stage 1B 哈希、包管理、路由、qdisc、swap 和未管理状态均未漂移。安装前日志 SHA-256 为 `3f32c276f61aa79a233b6b85931f2e243eef3e3ed65cfad6ef7585a379fb71ad`。
- `install.sh --no-launch` 实际返回 0 并完成版本化安装，下载并校验 17 项运行资产；外层证据包装因在当前 shell 的重定向块中使用 `exit` 而提前结束，只留下唯一 root-only 临时日志。只读确认 installer 完成、`dvt --version` 与 `current` 正确且 managed state 不存在后，未重复安装，直接把该唯一日志原子归档并完成遗漏的 postcheck。安装原始日志 SHA-256 为 `816de6ed179732975a711d4c9638210ae711c07183e35715dded16145c167ba2`，postcheck 为 `102e886640f055b04e86a1fad00fcb93db1dd343cf7a63ad0c065002f2a7d934`；17/17 资产、固定 manifest、root 所有权、非 group/world 可写权限、wrapper、symlink 和版本契约全部通过。
- 首次未管理 `dvt verify` 已实际返回预期 exit 5，选择固定 `debian13-1c2g-vps-tuning.sh` 并输出“当前主机尚未安装本项目配置”的预期语义；外层 state guard 写成无效复合 `[` 表达式，SSH stderr 出现语法错误，但 DVT 输出和内部断言已完成且没有系统写入。原日志 SHA-256 为 `d9e76714dff43480a727217b56aad16f62b33ce0d67ca7892e6d4ead9878a8c3`；改用显式文件/符号链接判断后完整重跑，再次精确返回 exit 5，权威日志 SHA-256 为 `f55e490c3907e8d8c7ff5261dcb59d0fe40c4661ddb3d09300985e632b38afef`。
- `dvt preflight --port 500` 返回 0，自动识别 Debian 13、1 vCPU、1973 MiB、`debian13-1c2g`，固定 profile SHA-256 与 Release 清单一致。preflight 输出 500 Mbps、目标 RTT 200 ms、理论 BDP 12500000 字节、3/2 BDP 目标 18750000 字节、自动 `BUF_MAX=33554432` 字节和约 536 ms 理论覆盖；ext4 允许创建 1024 MiB swap，磁盘余量超过 swap 加 1024 MiB 保留空间门禁，根 `fq_codel` 可安全切换为 `fq`。原始 preflight 日志 SHA-256 为 `767af1637ed19bf6fe65ee422e9158854e999e0fe4c317338f5136238e98e069`。
- preflight 结论为 `PASS_WITH_PROVIDER_SYSCTL_TRANSFER`、警告数 3：`/etc/sysctl.conf` 中分别且仅一次定义 `net.core.default_qdisc=fq` 和 `net.ipv4.tcp_congestion_control=bbr`，第三条警告说明未来 apply 的事务迁移。只读审阅确认该文件为 root:root/0644 普通文件、只有这两条活动配置、无其他活动行，`/etc/sysctl.d/99-sysctl.conf` 不存在，systemd-sysctl 当前有效配置也不包含这两项，因此运行态保持 `fq_codel + cubic` 是一致的。该情况严格符合 rc.16 仅允许迁移的厂商基线白名单；审阅日志 SHA-256 为 `a762ba96002489cbf992ea4cce1af9c6901e57710100a7843119d8e85c437e6f`。
- 第一次最终自检的 53 项中 52 项通过，唯一失败是检查过程把自己正在写的 `.stage2-final-self-audit.*` 临时文件计为残留；失败日志 SHA-256 为 `f141527dfb76080e6ba1955f9debc977d4f4baac57fa2f9bbf5df8688b006011`。改为创建新临时文件前计数并在原子提交后复核，完整重跑 55 项 `PASS`、0 项 `FAIL`，提交后临时文件为 0；权威最终自检日志 SHA-256 为 `c8839378da355454c7baeeded17822c32ce0a004f4f6fe391ab5c8dbfeae4c3a`。

### 未完成门禁

- 按授权已停在 preflight 审阅，未执行 `apply`。当前只有固定 rc.16 命令资产；不存在 `/var/lib/proxy-vps-tuning` managed state、项目 sysctl/journald/NOFILE/fq service 文件或 `/swapfile-proxy`，运行态仍为 `cubic + fq_codel`、无 swap，UFW inactive，systemd running、failed unit 为 0。
- 若后续授权 `dvt apply --port 500`，将先建立 schema 4 事务状态和 qdisc 快照，完整备份 `/etc/sysctl.conf` 并把其中两条厂商定义注释化，再写入 17 项受管 sysctl、journald 配置、x-ui NOFILE drop-in、fq helper/service，切换实际根 qdisc 为 `fq`，创建并持久化 1024 MiB 项目 swap，最后执行内建 verify 并提交 `VERIFIED`。任一步失败应由内建事务回滚；仍须在执行前复核 provider 文件哈希和系统状态没有漂移。
- apply 后的立即 `verify/status`、受管 state/文件哈希审阅、DVT 持久性 reboot、提前启动的 TCP/22 下线/上线观测、重启后 verify、重复 apply 幂等、严格 3X-UI/Xray、第二次 reboot、真实 VLESS + REALITY + TCP 冒烟和业务期 diagnose 均未执行。benchmark、probe、TcpQuality、HTB、故障注入、rollback 和 purge 继续未授权。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。三次失败均来自本轮临时证据包装器，已分别保留失败日志、查明原因并以改变后的判据重跑；未发现 rc.16 installer、controller 或 profile 缺陷，不据此扩大为新的通用测试框架。

### 当前成熟度判断

目标机已达到 `STAGE2_PREFLIGHT_REVIEWED_READY_FOR_APPLY_AUTHORIZATION`：公开资产、目标下载、版本化安装、未管理 exit 5、500 Mbps preflight 和 provider sysctl 迁移适用性均闭合；系统调优仍未应用。下一安全检查点是用户审阅上述明确变更后单独授权 `dvt apply --port 500`，不是自动继续。

## 本轮记录：2026-09-03（首次内核 reboot 与新内核恢复验证）

### 已完成及证据

- 已现场确认 SSH 配置引用的 `vps_rsa` 公钥 fingerprint 存在于当前 Windows OpenSSH agent，任务专用 `known_hosts` 中唯一匹配的 ED25519 host key 与控制台已确认值一致；后续连接持续使用 `StrictHostKeyChecking=yes`、`BatchMode=yes`、`IdentitiesOnly=yes` 和任务专用信任文件，没有写入用户全局 `known_hosts`。
- 首次预重启门禁把常驻的 `unattended-upgrade-shutdown --wait-for-signal` 关机协调器误判为包管理工作进程，按 fail-closed 以 exit 41 停止且没有 reboot。失败日志 SHA-256 为 `a52b83627c926a103466eb444bc1ce262a478115c6953828074589166f8e13dc`；只读诊断确认 `apt-daily`/`apt-daily-upgrade` inactive、无 APT/DPKG 锁后，修正为“排除空闲协调器，同时要求无真实更新进程和包管理锁”。完整重跑通过，日志 SHA-256 为 `8bc8607e61710f1e8ed13f216cdee32e879585a1da043a40b00930f6de0de865`。
- 第一次即时 reboot 门禁使用 `cmp` 比较普通 boot-ID 文件和 `/proc` 伪文件时产生假阴性，按设计再次停止且没有 reboot；失败日志 SHA-256 为 `40df0833bb8846c659026c6c3d6172eb30992340e244b91255c876751451f1c2`。分别读取两端内容后确认 boot ID 完全一致且旧内核仍在运行，随后改用内容比较；修正后的即时门禁通过，日志 SHA-256 为 `c1f29b2fec0bf223f3f5a06574bd758d1f4211d258319cfbdd11b3eb1682c7df`，再按用户授权发出一次 `systemctl reboot --no-block`。
- reboot 后严格 SSH 重新认证成功；boot ID 已变化，运行内核为 `6.12.107+deb13-amd64`，目标与旧回退 kernel/initrd 均保留。systemd 为 running、failed unit 为 0、SSH active、时间同步正常、`/run/reboot-required` 已清除，单 IPv4 默认路由和默认 IPv4/IPv6 policy rules 未漂移。
- post-reboot 继续确认原始 `cubic + fq_codel`、BBR 可用、出口唯一根 `fq_codel`、无 swap、UFW inactive、无真实包管理进程或锁、根分区可写、EFI 正常；Stage 0、Stage 1A 及四份 reboot 前证据的 SHA-256 全部通过。post-reboot 日志 SHA-256 为 `d1d5f00a2bc0f5e36d6adeb0295bbefe16866a03fa05547e795e235b4110e6be`，包含 38 项 `PASS`、0 项 `FAIL`；无遗留临时文件，`dpkg --audit` 为 0，`dvt` 命令和版本化安装目录仍不存在。

### 未完成门禁

- 客户端监测在 reboot 请求后才启动，开始监测时目标已恢复，因此 90 秒窗口内没有观察到 TCP/22 下线事件；boot ID 变化、目标内核和近期启动时长提供了更强的实际 reboot 证据，但本轮不把未观察到的“端口下线→上线”写成通过。无需仅为补这一观测重复内核 reboot；可在后续另行授权的 DVT 持久性 reboot 中提前启动监测并补齐。
- 本轮授权只覆盖第一次内核 reboot 及恢复验证。固定 rc.16 installer、未管理状态 `dvt verify` 的预期 exit 5、`dvt preflight --port 500`、preflight 审阅、`apply`、立即 verify/status、DVT 持久性 reboot、幂等 apply、严格 3X-UI/Xray、第二次 reboot、真实 VLESS + REALITY + TCP 冒烟和业务期 diagnose 均未执行。
- 进入 DVT 写入阶段前仍建议在服务商控制台创建快照，并须取得 installer/preflight 及后续 apply 的相邻阶段授权。benchmark、probe、TcpQuality、HTB、故障注入、rollback 和 purge 继续不在默认目标机门禁内。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。仅保留一次客户端 TCP 下线观测缺口，计划在后续已授权 reboot 中补证；它不改变 rc.16 功能范围，也不削弱本轮 boot ID 与目标内核形成的实际 reboot 结论。

### 当前成熟度判断

目标机首次内核 reboot 与新内核恢复门禁达到 `PASS_WITH_CLIENT_TCP_CYCLE_OBSERVATION_LIMITATION`：实际 reboot、目标内核、SSH/网络/systemd/时间/包状态和原始基线均已闭合，两个采集器假阴性已保留而未冒充主机故障。rc.16 仍未安装，目标机生命周期和真实代理业务验证尚未开始。

## 本轮记录：2026-09-03（首次内核 reboot 授权后的本机认证暂停）

### 已完成及证据

- 用户确认目标为可随时重装的专用验收机、服务商控制台/救援入口已实际可用、当前维护窗口可重启，并明确授权第一次内核 reboot；服务商支持快照但尚未创建，用户在知情情况下仍授权本次 reboot。
- 执行紧邻重启的防漂移检查时，首次命令在本地 PowerShell 解析阶段因内嵌 Bash 引号冲突失败，没有发出远端命令。改用已验证的 stdin 脚本方式前，本地身份门禁发现 Windows `ssh-agent` 已停止，任务 `vps_rsa` 不再可见，因此按设计停止。
- 已仅在本机把 Manual 启动类型的 Windows `ssh-agent` 恢复为 Running，没有改变启动类型。恢复后 agent 只有既有的其他 RSA identity，目标 `vps_rsa` 仍未加载；未尝试用错误 identity 连接，也未执行远端证据写入或 reboot。

### 未完成门禁

- 用户须在自己的 PowerShell 中使用 Windows OpenSSH `ssh-add.exe` 重新加载 `vps_rsa`，并确认 `ssh-add -l` 出现目标 key。私钥口令不得进入对话。
- 原 reboot 授权、任务专用 ED25519 host-key pin 和远端 root 身份证据继续有效，但实际执行前仍须重新完成紧邻重启的只读防漂移检查。只有 target identity、当前 6.12.105、目标 6.12.107、systemd/更新进程和证据哈希全部正常，才保存预重启证据并 reboot。

### 延期事项变化

- 无新增延期事项；这是本机临时认证状态变化，不改变目标机计划或授权范围。

### 当前成熟度判断

目标机技术与人工 reboot 门禁已具备，但本机 `vps_rsa` 临时身份不可用，当前状态为 `REBOOT_AUTHORIZED_WAITING_FOR_LOCAL_IDENTITY`。VPS 未发生任何本轮变更。

## 本轮记录：2026-09-02（HTB 脚本修改必要性澄清）

### 已完成及证据

- 已基于上一轮全部 HTB 文档、当前 rc.16 实现和运行证据边界，确认当前批准范围内不需要修改项目脚本：现有实现仍应保持 200 Mbps、Debian 13 1C1G/1C2G、`eth0`、非持久 HTB、100–199 Mbit/s 候选和根 `fq` 恢复契约；190 Mbit/s 继续只是待验证候选，缺少的是 A/B/A、反向窗口和真实业务证据，而不是当前脚本功能缺陷。
- 已区分“无需修改”与“尚未授权扩展”：将 95%设为所有端口的默认值、支持 100/500/1000 Mbps、多端口动态候选、永久 HTB 或开机持久整形，均会改变当前产品范围和安全契约，届时需要先批准新阶段，再修改执行器、计划/runner/analyzer、包装层、fixture、文档和生成/发布资产。本轮没有修改这些文件。

### 未完成门禁

- 200 Mbps 的 HTB200 reference、180/190/195 candidate sweep、双顺序窗口和真实代理链路仍未闭合；在这些证据完成前，不能把“不需要修改脚本”误解为“190 已验证有效”或“应立即部署永久 HTB”。
- 500/1000 Mbps 及 100 Mbps 的多端口能力仍处于未启动、未授权状态；上一轮发现的 rc.13/rc.14 研究文档版本标记漂移，应在重新启用相关实验前修订，但不构成当前 rc.16 已发布脚本的缺陷。

### 延期事项变化

- 无新增延期事项；多端口临时 HTB 与永久整形继续保持上一轮登记的延期和未授权状态。

### 当前成熟度判断

当前最小正确决策是保持 rc.16 脚本不变，先补证据或由用户明确启动新的多端口/持久整形阶段；没有证据支持为了体现 95%经验而立即改动现有实现。

## 本轮记录：2026-09-02（HTB 文档全量评审与 95% 速率外推）

### 已完成及证据

- 已逐行复核 `docs/experiments` 中全部 4 份、合计 2202 行的 HTB Markdown：候选速率发现 SOP、1C1G 完整 campaign、1C2G A/B/A 协议和历史 1C1G A/B/A 材料；文件名匹配与正文 `HTB` 匹配集合一致，没有遗漏同目录中的 HTB 文档。
- 已对照当前 rc.16 的 HTB 执行器、rate-sweep plan/runner/analyzer、A/B/A plan 和 `dvt htb` 包装层，并联网复核当前 iproute2 HEAD `873daf67da6d330b2d5778a335463a03ff30c1f2` 的 HTB/fq/police/stab 手册、Linux HEAD `89a312991dc6e638a36adc43ccb91dbc25504c04` 的 `tcp_wmem` 文档、iperf3 HEAD `c9b74229d0d9bfec6d2307b66b43c29a7665ad0b` 的方向语义、RFC 4022/5681/8985 及 OpenWrt SQM 当前指南。论坛经验只作为假设线索，没有替代一手来源和仓库证据。
- 评审结论为：`HTB 190 Mbit/s + fq` 是 200 Mbps 档合理的首选实验候选，但不是已经证明有效的生产默认值。当前历史有效 B1 只证明约 3.389 GB 流量经过 190 Mbit/s 聚合整形、`overlimits=103044` 且本地 qdisc 无 drop/requeue/backlog；缺少完整 A2、归一化重传对比和反向窗口，不能证明 95% 降低重传。另一个根 `fq` 单流样本曾达到约 199.96 Mbps 且 sender retransmits 为 0，也反驳“所有 200 Mbps 标称端口都必须留 5%”的普遍化结论。
- 95% 的数学映射是 100→95、200→190、500→475、1000→950 Mbit/s，但当前实验契约只支持 Debian 13 1C1G/1C2G、`eth0`、200 Mbps；执行器只接受 100–200 Mbit/s，候选计划只接受 100–199 Mbit/s，rate-sweep、runner 和 analyzer 都硬校验 provider port 200。因此 95、475、950 均不是当前可执行、已测试或可发布的项目能力。
- 当前固定 `burst=262144`、`cburst=32768` 在 190/475/950 Mbit/s 下分别约代表 11.04/4.42/2.21 ms 和 1.38/0.55/0.28 ms 的数据量；直接只放大 rate 会改变突发抑制和计时语义。500/1000 Mbps 扩展必须重新评估 timer、burst/cburst、CPU/softnet、队列拓扑、流量预算、计费层开销和目标机 fixture，不能只改端口与候选数字。
- 对“优化后重传增加”的判断仍须使用同发送方向、同端点和地址族下的 sender retransmits/GiB、goodput、RTT、qdisc、CPU/steal、softnet 和接口增量。HTB 只约束 VPS egress；绝对重传数会随发送字节增加，`tcpRetransSegs` 也不是等价的丢包计数。当前文档对归一化、方向、A/B/A、反向窗口和非持久化边界总体正确。本轮未修改 HTB 文档、代码、生成资产、发布资产或任何 VPS，也未运行公网流量。

### 未完成门禁

- 用户的新观察尚未形成与当前 schema、工具哈希和窗口契约绑定的原始证据；无法确认重传增加来自服务商 policer/虚拟交换机、路径拥塞或乱序、端点漂移、CPU/steal/softnet、计费层开销，还是吞吐提升后绝对计数自然增加。
- 200 Mbps 的 HTB200 reference、180/190/195 candidate sweep、独立 `A1/B1/A2`、另窗 `B2/A3/B3` 和真实代理链路复验仍未闭合；190 Mbit/s 只能保留为候选。若实测拐点明显低于标称端口，最终 shaper 应围绕拐点选择最高通过速率，而不是继续使用标称值的固定 95%。
- 500/1000 Mbps 以及 100 Mbps 的多端口 HTB 实验能力尚无已批准需求、设计、实现、fixture、Linux root 或目标机证据。三份研究专用现行文档仍标注 rc.13/rc.14，而执行器已硬绑定 rc.16；若下一阶段获准执行实验，必须先同步版本契约并重新完成静态、root、目标机和预算门禁。

### 延期事项变化

- 新增具体延期候选“100/500/1000 Mbps 多端口临时 HTB 速率发现与 A/B/A 能力”，包括动态 provider port、候选比例/整数化、burst/cburst、预算、队列/路由和资源门禁；它属于既有聚合整形研究边界，未获下一阶段或实现授权。永久 HTB 仍保持既有延期状态。

### 当前成熟度判断

rc.16 发布闭环不变。本轮达到“全部 HTB 文档、当前实现和外部机制证据已复核；200 Mbps 的 190 Mbit/s 可作为有条件实验候选；95% 跨档默认化不通过”的评审层级。尚无证据支持修改现有 BDP/socket-buffer 公式、发布多端口 HTB 或建立生产持久整形。

## 本轮记录：2026-09-02（标称带宽 0.9 倍与 TCP 重传只读研究）

### 已完成及证据

- 已按配置与基础设施研究边界联网核对 Linux 6.12/当前内核 `tcp_wmem` 文档、RFC 5681/RFC 8985/RFC 4022、当前 iproute2 的 `fq`/HTB/CAKE/police 手册、iperf3 当前手册、VMISS 当前法律与 Fair Use 文本，以及独立的 Bufferbloat/SQM 调整建议；论坛引语仅作为问题线索，没有作为关键结论依据。
- 已区分三种不同语义：`PORT_SPEED_MBPS` 是套餐端口/BDP 与状态元数据输入，`tcp_wmem[2]` 是每连接自动发送缓冲上限，HTB/CAKE/iperf3 pacing 才是实际速率控制。降低前两者不会自动把出口限制到套餐的 90%，不能用 socket buffer 改参替代聚合整形。
- 按当前 `debian13-1c1g` 默认 200 ms、1.25 倍 BDP 和 16/32/64 MiB 离散档计算，100/200/500 Mbps 分别改为 90/180/450 Mbps 后仍全部选择 16 MiB；其中 90 Mbps 还低于当前 `PORT_SPEED_MBPS=100..1000` 输入契约。因此把 0.9 直接写进现有 BDP 公式，对用户列出的 1C1G 默认场景不产生预期的重传控制效果，却会混淆标称端口、预算和状态语义。
- 当前仓库证据中，一次根 `fq`、单流、10 秒、200 Mbps cap 的样本达到约 199.96 Mbps 且 sender retransmits 为 0，反驳“标称 200 Mbps 必然达不到”的普遍化结论；另一次 HTB190 B1 只证明整形生效和本地 qdisc 无丢包，因缺少完整 A2/同窗比较，仍不能证明 95% 或 90% 整形降低重传。
- 研究结论是：0.9 可以作为出现可复现满速重传拐点时的首个、可逆出口整形候选，但应作用于经受控端点、多时段、固定方向和地址族确认的稳定瓶颈/拐点，并与 95%/85% 或相邻速率进行独立 A/B/A；不得无条件成为所有 VPS 的 BDP、socket buffer 或永久 HTB 默认值。本轮未修改实现、生成资产、README、验证矩阵或发布资产。

### 未完成门禁

- 用户本轮描述的是昨晚观察和论坛引语，尚未提供相同端点、方向、地址族、时段、负载、sender bytes/retransmits、CPU/steal、softnet、接口和 qdisc 前后增量，因而不能确认主要机制是服务商 policer、共享上联、路径拥塞/乱序、CPU/虚拟化资源、远端节点还是测试方法。
- 未连接或修改任何 VPS，未执行 iperf3、TcpQuality、qdisc 切换、主动流量或生产变更；现有新目标机仍停在首次 reboot 的人工门禁前，本轮分析不构成 reboot、DVT apply 或测速授权。
- 若后续考虑持久出口整形，仍须先使用授权端点和硬流量预算完成同机、同路径、双顺序窗口及真实代理链路复验；需把标称端口、实测稳定容量和最终 shaper rate 作为不同字段/证据保存，并由用户另行批准实现与生产持久化。

### 延期事项变化

- 无新增延期事项。“基于实测容量的永久聚合整形”继续属于既有 L4/永久 HTB 研究边界；本轮没有把它升级为 rc.16 发布缺陷或默认配置变更。

### 当前成熟度判断

rc.16 仓库与公开发布完整性结论不变。本轮达到“机制与仓库语义已核对、0.9 默认化不获支持、可逆候选实验方向明确”的研究层级；尚无目标机因果证据支持修改 socket buffer 公式或发布永久 HTB。

## 本轮记录：2026-09-01（首次 SSH 与内核 reboot 前只读门禁）

### 已完成及证据

- SSH alias 现场解析为 root、TCP/22、独立 `vps_rsa`、`IdentitiesOnly yes`；私钥及公钥文件存在，Windows OpenSSH agent 已加载该 identity。网络侧真实 SSH 握手观察到的 ED25519 host-key fingerprint 与用户从控制台提供的 fingerprint 逐字一致，随后仅写入任务专用临时 `known_hosts`，未改用户全局信任库。
- 在 `StrictHostKeyChecking=yes`、固定 ED25519 host key、`BatchMode=yes` 下，密钥认证成功，远端 UID/用户确认为 0/root。首次连接及后续审计均只读，没有执行 remote file write、软件包操作、reboot、DVT、UFW、代理或主动流量。
- 目标正在运行 6.12.105；`linux-image-amd64` 和 `linux-image-6.12.107+deb13-amd64` 均为已安装状态，目标 kernel/initrd 资产为 root-owned、0644、可读。GRUB `GRUB_DEFAULT=0`，配置同时包含 6.12.107 与 6.12.105，目标 6.12.107 位于默认 Debian 入口，旧内核保留为控制台回退候选。
- 根与 `/boot` 位于同一 ext4 分区，EFI 为独立 vfat 且空间充足。根目录 `/vmlinuz`/`initrd.img` 链接不存在，但当前 GRUB 配置直接包含两个 `/boot` 内核版本，不构成该镜像的 reboot 阻断。
- systemd 为 running、failed unit 为 0、时间同步正常、APT/dpkg/hold 清洁；单 IPv4 默认路由、默认 policy rules、原始 `cubic + fq_codel`、无 swap、UFW inactive 均未漂移。Stage 0 与 Stage 1A 日志重新执行 SHA-256 校验均为 OK。
- 首轮 `findmnt` 多目标调用和 GRUB 正则截断是采集命令错误；已改用逐目标 `findmnt -T`、固定版本 presence 与 menuentry 检查闭合，未把采集器错误误报为 VPS 失败。

### 未完成门禁

- 技术 reboot readiness 已通过，但用户尚未明确确认服务商控制台/救援入口、快照、VPS 用途和维护窗口，也尚未授权实际 reboot。当前必须停在第一次 reboot 前。
- 获得授权后应先把预重启摘要保存到既有 root-only 证据目录，再执行一次 reboot；恢复后必须确认 boot ID 变化、运行内核为 6.12.107、SSH/默认路由/time sync/systemd/failed units/Stage 0 与 Stage 1A 哈希正常。若启动或网络异常，使用控制台选择仍保留的 6.12.105，不进入 DVT installer。

### 延期事项变化

- 无新增延期事项。SSH 连接方式和内核 reboot 不改变 rc.16 核心验收与研究通道边界。

### 当前成熟度判断

首次 SSH 信任、root 密钥认证和 reboot 前技术门禁已闭合；目标达到 `READY_FOR_REBOOT_PENDING_OPERATOR_GATES`。尚未取得新内核运行证据，也未进入 DVT installer、M1 或 preflight。

## 本轮记录：2026-09-01（SSH config VPS 别名指导）

### 已完成及证据

- 已核对用户截图：现有用户级 SSH config 仅定义 `github.com`，通过 `ssh.github.com:443`、用户 `git` 和一把 RSA identity 连接 GitHub；该 Host block 不会为 VPS 登录提供 root、实际 SSH 端口或独立目标别名。
- 已建议保留 GitHub block 不变，为目标 VPS 追加独立、非敏感别名，显式设置 HostName、User、Port、目标私钥 IdentityFile 与 `IdentitiesOnly yes`。本轮只提供配置指导，没有读取或修改用户 SSH config，也没有发起连接。

### 未完成门禁

- 尚待用户确认 VPS 实际授权的是现有 GitHub RSA 公钥还是独立 VPS 公钥；不得仅凭 agent 中存在 RSA key 假设其已写入目标 `authorized_keys`。仍须提供 VPS 别名和控制台核对的 ED25519 host-key fingerprint。

### 延期事项变化

- 无新增延期事项。

### 当前成熟度判断

SSH 客户端配置方式已明确，但目标别名、登录 identity 与服务器 host key 尚未闭合，仍不能安全发起首次连接。

## 本轮记录：2026-09-01（SSH agent 身份门禁复核）

### 已完成及证据

- 用户报告已向 ssh-agent 加载密钥并提供一条 SHA-256 fingerprint。本机现场复核确认 Windows `ssh-agent` 服务现为 Running，Codex 使用的 Windows OpenSSH `ssh-add` 可以访问该 agent。
- Codex 可见 agent 中唯一客户端密钥的 fingerprint 与用户本轮报告值不一致。该差异可能来自 Git Bash/SmartGit 与 Windows OpenSSH 的不同 agent、加载了另一把客户端密钥，或用户报告值实际为服务器 host-key fingerprint；在完成归类前没有尝试 SSH 连接，也没有删除或替换 agent 中现有密钥。

### 未完成门禁

- 用户须确认其报告 fingerprint 来自本机 `ssh-add -l` 还是 VPS 控制台的 `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`。若是客户端密钥，须使用 `C:\Windows\System32\OpenSSH\ssh-add.exe` 把目标私钥加载到 Codex 当前可见的 Windows agent，并确认列表出现对应 fingerprint。
- 仍缺少 SSH config alias 或等价的用户名/端口/本机私钥路径，以及由 VPS 控制台取得并独立核对的 ED25519 host-key fingerprint。上述信息闭合前不得探测端口、接受未知 host key 或发起登录。

### 延期事项变化

- 无新增延期事项；该差异是首次 SSH 信任建立的当前门禁，不改变目标机验收范围。

### 当前成熟度判断

Stage 1A 结论保持通过，但 SSH 接管尚未就绪。下一安全检查点是对齐客户端 agent key、服务器 host key 与 SSH alias 三个独立身份信息；不是尝试默认端口或绕过 host-key 检查。

## 本轮记录：2026-09-01（新目标机 Stage 1A 与 SSH 接管准备）

### 已完成及证据

- Stage 1A 证据显示 root UID 为 0；Debian 官方 trixie、updates、backports 和 security 索引刷新成功，`apt-get --simulate dist-upgrade` 为 0 upgraded/installed/removed/not-upgraded，apt hold 与 `dpkg --audit` 均无输出，failed systemd unit 仍为 0。
- `/run/reboot-required` 明确列出新的 Debian 13 内核包，而当前仍运行 6.12.105；这支持“软件包状态已无待升级，但必须先只读核对已安装内核与引导资产，再通过一次真实 reboot 建立升级后基线”，不能把 0 upgrades 误写为无需重启。
- UFW 已安装但 inactive；当前未启用或修改规则。Stage 1A 只更新 APT 索引并模拟升级，没有安装、删除或升级软件包，没有执行 reboot、DVT installer/apply、代理安装或主动流量。
- 用户询问由 Codex 直接通过密钥 SSH 连接并完成测试验证。当前 Windows 主机已确认 OpenSSH 9.5 客户端可用、用户 SSH config 存在；Windows OpenSSH agent 当前不可达。尚未读取或接收任何私钥、口令、SSH alias、端口或主机指纹，也尚未发起网络连接。

### 未完成门禁

- 首次连接前须由用户提供现有 SSH config alias，或仅提供登录用户名、真实 SSH 端口和本机私钥绝对路径；私钥内容与口令不得进入对话。带口令私钥应由用户在自己的终端预先加载到 ssh-agent。
- 必须通过服务商控制台取得 ED25519 SSH host-key fingerprint，并与网络侧 host key 交叉核对；不得用 `StrictHostKeyChecking=no` 或未经核对的 `accept-new` 绕过首次信任建立。
- 首次 SSH 只授权只读连接、身份/内核/引导/路由/恢复入口复核。真实 reboot、DVT apply、UFW、3X-UI、rollback、purge 和主动流量仍分别受控制台/快照、用途、维护窗口、业务和流量授权门禁约束。

### 延期事项变化

- 无新增延期事项。SSH 接管是目标机验收的执行方式变化，不扩大到全面生产加固或高流量研究。

### 当前成熟度判断

Stage 1A 为 `PASS`，目标机已达到升级后首次 reboot 前的只读核对条件。当前阻塞项是安全建立 SSH 主机信任和补齐人工恢复/授权信息；在此之前不能由 Codex 连接、重启或进入 DVT 写入阶段。

## 本轮记录：2026-09-01（新目标机 Stage 0 基线复核）

### 已完成及证据

- 已复核用户返回的 Stage 0 完整性摘要和日志 SHA-256。目标为 Debian 13.6、Linux 6.12.105、amd64、KVM、1 vCPU、1973 MiB RAM；根分区为约 20 GB ext4、约 18 GB 可用，符合 `debian13-1c2g` 资源档和默认 1024 MiB 项目 swap 的文件系统/空间前提。
- 目标当前为单 IPv4 默认路由，无全局 IPv6 或 IPv6 默认路由；IPv4/IPv6 policy rules 均为常规默认集合，没有自定义 rule、非 `main` 路由表或多默认路由证据。内核公布 `reno cubic bbr`，当前运行态为 `cubic`、默认及单一出口根 qdisc 为常规 `fq_codel`；该状态是可由 preflight 进一步审计的未调优基线，不是异常或已优化状态。
- 当前无活动 swap、无 fstab swap 行、failed systemd unit 为 0；profile 所需命令均存在。Stage 0 只创建了 root-only 证据目录和日志，没有执行 DVT installer、preflight、apply、sysctl/qdisc/swap 变更、代理安装、重启或主动流量。

### 未完成门禁

- 用户返回的摘录未包含 `id -u` 行，虽 root 提示符和 `/root` 证据写入强烈支持 root 身份，下一阶段仍应重新输出该值以闭合直接证据。
- 进入系统升级或 DVT 写入前，仍须由用户确认：未来生产机或可重装验收机、服务商控制台/救援入口、快照能力、真实 SSH 端口、500 Mbps 套餐口径、维护窗口及流量额度。当前技术基线可判为通过，但写入授权门禁尚未闭合。
- 下一相邻步骤仅为 Stage 1A：更新 APT 索引、检查 hold/dpkg 状态并模拟 `dist-upgrade`；必须先审阅其计划，不得在同一批命令中自动执行真实升级、autoremove 或 reboot。

### 延期事项变化

- 无新增延期事项。破坏性 rollback/purge、benchmark、probe、TcpQuality、HTB、性能 A/B/A、M17 虚假端口变更和 M18 故障注入仍不进入首次上线默认路径。

### 当前成熟度判断

该目标机已达到 rc.16 首次安装前的技术基线条件，Stage 0 结论为 `PASS_WITH_PENDING_OPERATOR_GATES`。当前还没有 installer、managed state、重启持久性、严格代理服务或真实业务证据；下一安全检查点是 APT 只读升级计划和人工恢复条件确认。

## 本轮记录：2026-09-01（新购 Debian 13 1C2G/500 Mbps 目标机验收规划）

### 已完成及证据

- 已基于当前 `master`、rc.16 固定 Release 契约、自动缓冲矩阵和逐机生命周期矩阵，形成新购 Debian 13、1 vCPU、2 GiB、500 Mbps 目标机的分阶段验收路线；当前资源应由总控识别为 `debian13-1c2g`，500 Mbps 自动 buffer 预期为 32 MiB。
- 该主机为全新安装且尚无项目 managed state，因此 rc.15→rc.16 的旧版 verify/rollback/purge、迁移 checkpoint 和两次迁移 reboot gate 不适用。适用主路径为只读基线、固定 Release 安装器、未安装状态 verify、preflight、apply、立即与重启后 verify、重复 apply、严格 3X-UI/Xray 验证、第二次重启、VLESS + REALITY + TCP 冒烟及业务期间 diagnose。
- 已将默认目标机验收、可重装测试机的破坏性 rollback/purge 扩展，以及需要授权 endpoint 和流量预算的 benchmark/probe/TcpQuality/HTB 研究通道分开；未把 M17 虚假端口变更或 M18 故障注入列为未来生产机的默认验收动作。

### 未完成门禁

- 本轮未连接或修改该 VPS，尚未取得 OS/内核、实际内存、磁盘与根文件系统、IPv4/IPv6、policy rules、默认路由、qdisc、swap、BBR/fq 能力、failed units 或 boot ID 的目标机只读证据；也未执行系统升级、安装器、preflight、apply、reboot、代理安装、业务连接或主动流量测试。
- 进入写入阶段前仍须确认服务商控制台或救援入口、快照能力、真实 SSH 端口、维护窗口、月流量额度，以及该机是未来生产机还是可随时重装的专用验收机。任一复杂 qdisc、自定义 policy rule、多默认路由、非 `main` table、外部 sysctl/swap 所有权冲突或空间不足都必须停在只读评审。
- 一台 1C2G/500 Mbps Debian 13 主机只能补充与其配置相符的 rc.16 目标机证据，不能替代 Debian 12、512 MiB、1 GiB、2C2G、XFS 或其他端口档位的 T1–T10 项目矩阵。

### 延期事项变化

- 无新增延期事项。benchmark、`dvt probe`、TcpQuality、HTB 和性能 A/B/A 继续只在有获授权 endpoint、预先批准的硬流量预算和明确性能主张时进入；全面生产加固仍是独立范围。

### 当前成熟度判断

rc.16 的仓库与公开发布完整性结论不变。新目标机使首次 Debian 13 1C2G/500 Mbps 运行验收具备环境条件，但当前仅完成操作规划，尚未达到任何目标机运行证据层级；下一安全检查点是 Stage 0 只读基线，而不是直接 apply、rollback 或公网测速。

## 本轮记录：2026-08-31（rc.16 实现、CI 与 Pre-release 闭环）

### 已完成及证据

- rc.16 已在不改变 17 项受管 sysctl、BBR + 根 `fq`、资源感知缓冲、流量预算和非持久 HTB 边界的前提下完成两项实现：benchmark 每个 iperf3 方向使用独立进程组、硬超时及 TERM→KILL 回收；`diagnose` 和 benchmark 增加 IPv4/IPv6 policy rule 与按需非 `main` 路由表只读证据。迁移器同时收紧为只接受 rc.1–rc.15→rc.16，不接受由更高版本降级。
- 本地最终门禁通过：六份 profile 与单一模板一致；23 份 Shell 的 `bash -n`；controller、完整静态和 HTB fixture；17/17 `SHA256SUMS`；worktree/staged whitespace；当前版本、固定 URL、旧当前引用和 `_TBD` 防回退扫描；新增内容的私钥、常见 token/key、本机绝对路径、UUID 和 IPv4 地址扫描均无命中。Windows 本地没有绕过 root-only fixture。
- PR [#14](https://github.com/alieismy/debian-vps-tuning/pull/14) 已合并，merge commit 为 `5fa68877961efb7f04cb036edda5fdc43fa4820d`。中间 CI 先后暴露 GNU `timeout --kill-after` 返回 `137` 的真实语义和 fixture 未使用变量的 ShellCheck `SC2034`；实现保留 `124/137` 边界并做最小 fixture 修复。最终 push Run [33388026734](https://github.com/alieismy/debian-vps-tuning/actions/runs/33388026734) 与 pull_request Run [33388030020](https://github.com/alieismy/debian-vps-tuning/actions/runs/33388030020) 均通过，覆盖生成/静态检查、Linux root installer 与 rc.16 预算/迁移/进程组 fixture、ShellCheck 0.11.0。
- CodeRabbit 仅声明审查到 `44927ecd686a062e2132471c25dad0c76c9e9ffb`，未覆盖最后一个仅替换未使用 loop counter 的提交；PR 没有 review、行内意见或 review thread。本轮如实保留该覆盖限制，没有将 pending 状态描述为批准或替代 CI/人工审计。
- annotated tag `v0.1.0-rc.16` 的 tag object 为 `4a29bbf65959eafc5b9fb132c18ac4bd215e9c74`，远端 peeled target 与 merge commit 均为 `5fa68877961efb7f04cb036edda5fdc43fa4820d`。已发布非 Draft 的 [GitHub Pre-release](https://github.com/alieismy/debian-vps-tuning/releases/tag/v0.1.0-rc.16)，19 个资产均为 `uploaded`。
- 公开匿名反向下载通过：`PUBLIC_REDOWNLOAD=PASS`、`API_DIGEST_MATCHES=19`、`MANIFEST_ENTRIES=17`、`RELEASE_ASSETS=19`；19 项下载字节逐项匹配 GitHub API SHA-256，重建 HTB 子目录后 17/17 manifest 资产全部通过。`SHA256SUMS` SHA-256 为 `e2766b5e5851ae7ef064f21c2fd630663a8f3bcbb737c830f1272826b0b27cb2`，`install.sh` 为 `83d4f739918309b7585c0a0b6be7ac09252512dd7516d0dc6044b058cd17a15d`，总控为 `9ba31b2c5caa8c11e8e99fb339d8e5a82752d0c998f6284c2eed4d22f5c6631c`；唯一临时目录已安全清理。

### 未完成门禁

- 本轮未连接或修改任何真实 VPS，未执行公网 iperf3、TcpQuality、HTB、rollback、reboot、apply 或生产变更。发布闭环不证明目标机真实 timeout/signal 行为、进程回收、复杂策略路由拓扑、迁移两次重启、控制台恢复、严格 3X-UI/Xray 验证、代理业务链路或性能改善。
- 自定义 policy rule 目前只触发只读证据和警告；rc.16 仍不支持以非 `main` table、fwmark、VRF、多 WAN 或多默认路由拓扑执行 apply。真实目标机使用前仍须按其拓扑独立评审。

### 延期事项变化

- 无新增延期事项。永久 HTB、通用 UDP、MTU、RPS/RFS、MSS Clamp、`initcwnd/initrwnd`、第三方内核、网络安全专项、全面生产加固和新的高流量性能 campaign 继续保持既有延期或未授权状态。
- 下一阶段须由用户另行决定；本轮不自动把项目切换到稳定版、目标 VPS 迁移验收或新的调优实现阶段，也不移动或修改已发布的 rc.16 tag 与 Release 资产。

### 当前成熟度判断

rc.16 的实现、生成资产、固定摘要、本地 fixture、Linux root CI、PR、annotated tag、Pre-release 和公开资产反向验证已经闭合，满足本阶段完成定义。该结论只达到仓库与公开发布完整性层级；目标 VPS 生命周期、重启持久性、真实业务链路和性能仍明确未验证。

## 本轮记录：2026-08-31（外部网络调优与 tcpfit 对比评审）

### 已完成及证据

- 已只读全量枚举外部 `VPS/脚本` 目录中的 38 份 Markdown 或 Shell 文件（20 份 Markdown、18 份 Shell）：27 份网络调优材料进入详细对照，3 份综合材料只抽取网络章节，8 份部署、安全、路由封锁、重装或滥用事件材料在检查实际内容后排除。两份 tcpfit README 字节完全相同，SHA-256 均为 `3B45C43E27A1ABC6C46DD8635073BC5ED5176D2447B749397F19C8EFB0116C8F`，未将其误计为两个独立实现。
- 已深读 tcpfit `0.5.6` 主脚本（SHA-256 `7B9C778A0431D06425B76705C2C398D9D40085F1754FBADA0CB3C01AE55CB0E5`）及配套文档。其 `flock` 串行化、固定版本自安装、receiver goodput、疑似 policer 重复采样、重传比例、`mq` 识别和测试中断清理具有工程价值；但实际管理 32 项 sysctl，默认 RTT 仍为固定 150 ms，流量预算只是提示，qdisc 快照与 rollback 不能完整恢复原参数和层级，`initcwnd/initrwnd 32` 会改写路由属性，自动 policer 归因也不能排除公共服务端、路径、CPU/steal、共享带宽和虚拟交换机噪声。因此不支持整体移植、永久 HTB 或扩张当前参数面。
- 已对照 NetShape `5.3.0`（SHA-256 `F5A295D0A1E7F642214DB1D729856A772B6BED4C72646FA7C39729FB0C33EAA5`）、NetPilot（SHA-256 `0A3BC8708372373D931949E3EA3D9F7D9EE4D71079315B01EC2E4BD2301C868F`）、v5/v6、`Bak` 历史脚本、PanStar、VMISS/Lightlayer、初始化/开荒材料和只读采集脚本。relay/landing 双腿 RTT 模型只对未来多跳拓扑有条件意义；NetPilot 的不完整备份/回退、按总内存百分比定缓冲、通用 UDP/RPS/RFS/MSS Clamp、可变 `main` 下载和仅凭内核版本判断 BBRv3，及历史参数包的固定大缓冲、超大 backlog、覆盖 `/etc/sysctl.conf`、固定 MTU 等做法均不适合当前项目。
- 当前项目已经覆盖或强于第三方材料中的 receiver goodput、重复采样与中位数、短窗口重传、`mq` 叶子计数、接口字节辅助指标、完整 qdisc JSON 与恢复后语义比较、资源感知 BDP 缓冲、受限实验性 HTB，以及 rc.15 原子流量 reservation/ledger 和未知流量保守结算。新增价值仅保留为两个条件候选：为 benchmark/iperf3 增加显式超时与子进程/进程组回收；在未来支持多默认路由、策略路由、VRF 或多 WAN 时补充 `ip -4/-6 rule show` 和非 main table 诊断。两者均不要求修改网络参数。
- 已对全部 18 份 Shell 文件执行只读 `bash -n`，18/18 退出码为 0；该证据只证明 Bash 语法可解析，不证明参数安全、回滚完整、目标 VPS 可运行或性能有效。已直接核对 Linux 6.12 `ip-sysctl.rst`、BBR 源码、iproute2 `tc-fq(8)`/`ip-route(8)` 和 Google BBRv3 `v3` 分支说明，确认 `tcp_adv_win_scale` 已废弃、`tcp_tw_reuse=1` 非保守默认、`fq maxrate` 是单流上限、`initcwnd/initrwnd` 是目的路由属性，以及主线内核版本号不能证明 BBRv3。

### 未完成门禁

- 本轮未执行任何第三方脚本，未连接或修改真实 VPS，未执行公网测速、iperf3、TcpQuality、HTB、apply、rollback 或 reboot；静态源码评审不能证明第三方工具或当前 rc.15 在目标 VPS 上的生命周期、重启持久性、严格代理链路或性能改善。
- 未形成目标机配对 A/B、固定端点多轮交替测试、业务症状或 qdisc backlog/drop 证据，因此不批准从第三方材料引入新 sysctl、固定 MTU、定制 fq 深度、`initcwnd/initrwnd`、永久 HTB、RPS/RFS、UDP 或 MSS Clamp。

### 延期事项变化

- 无新增延期事项。benchmark 子进程显式超时/回收仅在出现可复现挂起、孤儿进程或发布可靠性要求时重新纳入；策略路由诊断仅在项目明确支持多默认路由、策略路由、VRF 或多 WAN 时重新纳入；NetShape 双腿 RTT 模型仅在支持中转/落地多跳拓扑时重新评审。上述条件不构成当前阶段需求或实施授权。

### 当前成熟度判断

rc.15 的发布完整性和阶段成熟度判断不变。本轮评审支持继续保持现有 17 项受管 sysctl、资源感知 BDP 缓冲、根 `fq` 默认路线和 fail-closed 预算/恢复控制，不支持因外部脚本数量更多或宣传为“实测推导”而扩张参数面。目标 VPS 生命周期、重启、严格代理链路和真实业务性能仍未验证，本轮只读对比不提升这些证据层级。

## 本轮记录：2026-08-30（rc.15 实现、CI 与 Pre-release 闭环）

### 已完成及证据

- 项目控制面已切换到 `v0.1.0-rc.15` 阶段，并明确本阶段只实现共享流量预算、可恢复迁移、统一资产与发布闭环；永久 HTB、通用 UDP、真实 VPS 变更和公网性能 campaign 均未扩入。
- 新增 `dvt-traffic-budget.sh` 事务 ledger。benchmark、`dvt probe`、TcpQuality 和 HTB runner 在发流量前必须原子保留完整计划 payload；已知 sender bytes 按实际值提交，未知或失败按计划上界保守结算，余额不足时 fail-closed。账本同时保留协议开销和服务商计费口径未知边界。
- 新增 `dvt-migrate.sh` 持久 checkpoint/resume。checkpoint 固定并校验旧版 profile、目标 profile 和迁移器自身哈希，按旧版 rollback/purge、第一次 boot-ID gate、目标 preflight/apply、第二次 boot-ID gate、最终 verify 推进；工具不自动 reboot，也不替代控制台或业务验收。
- 总控、六份单模板生成 profile、installer、TcpQuality、probe、HTB runner、清单、README、CHANGELOG 和发布说明已统一为 `0.1.0-rc.15`。`SHA256SUMS` 管理资产由 15 项增至 17 项；Release 总资产为 19 项。
- 本地门禁通过：profile 再生成一致性、Bash 语法、17 项 `SHA256SUMS`、controller/static fixture、HTB fixture 和 `git diff --check`。Windows Git Bash 对 root-only `tests/rc15-check.sh` 按设计拒绝执行，没有将其冒充为本地通过。
- PR [#12](https://github.com/alieismy/debian-vps-tuning/pull/12) 合并提交为 `21177fe7943bbfe7592461ca532e0c5dc369efdb`。首轮 CI 的两条 `validate` 均因确定性的 ShellCheck `SC2015/SC2034` 失败；修复显式条件和 fixture 抑制后，两条新 `validate` 分别以 42 秒和 44 秒通过，覆盖固定 ShellCheck 0.11.0、Linux root installer lifecycle、预算超额/保守结算和迁移两次 boot gate fixture。
- CodeRabbit 仅留下针对首个提交范围的 `review in progress` 评论，没有形成 review、行内意见或 required check；本轮没有把该停滞状态描述为审查通过，也未用它替代 CI 和人工 diff 审计。
- annotated tag `v0.1.0-rc.15` 的远端 peeled target 已核对为合并提交 `21177fe7943bbfe7592461ca532e0c5dc369efdb`。已发布非 Draft 的 [GitHub Pre-release](https://github.com/alieismy/debian-vps-tuning/releases/tag/v0.1.0-rc.15)，19 个资产均为 `uploaded`。
- 公开匿名反向下载通过：`SHA256SUMS` 的 17 个逻辑资产全部逐项匹配；清单 SHA-256 为 `374e4b912b4beb8300a2bb0aeb4f16e364cdf33d19455fa44e12a5b8464f1da1`，installer SHA-256 为 `4c7798afd48478854ac0d3ac16197d73147464d95c8b4f1a35241dec8cf4e5fd`。验证临时目录已安全清理。

### 未完成门禁

- 本轮没有连接或修改任何真实 VPS，没有执行 rollback、reboot、apply、HTB、TcpQuality 或公网测速。rc.15 发布完整性不证明目标 VPS 的迁移、重启持久性、控制台恢复、严格 3X-UI/Xray 验证或真实代理业务链路通过。
- 流量 ledger 核算应用层 payload，不覆盖 TCP/IP、链路、重传及服务商计费差异；服务商面板剩余额度、维护窗口和独立测试机授权仍是运行前人工门禁。
- 目标 VPS 生命周期和真实业务验收可作为发布后验证项保留。是否选择低风险节点执行 rc.14→rc.15 checkpoint 迁移，须由用户另行授权；不得因 Pre-release 已发布而自动执行。

### 延期事项变化

- P1 共享流量 ledger、TcpQuality 硬预算和 P2 checkpoint/resume 迁移已从延期候选转为 rc.15 已实现、已通过 fixture/CI、已发布能力。
- 永久 HTB、通用 UDP 调参、网络安全专项、全面生产加固和新的高流量性能 campaign 继续保持既有延期/未授权状态。
- 无新增延期事项。CodeRabbit 停滞评论是本次 PR 的证据限制，不新增为项目功能或发布门禁。

### 当前成熟度判断

rc.15 当前阶段的代码、fixture、生成资产、固定摘要、PR/CI、annotated tag、Pre-release 和公开资产反向验证已经闭合，满足本阶段完成定义。目标 VPS 生命周期、重启和业务验收仍明确未验证，但按阶段规则可作为发布后事项保留。下一阶段应由用户在“低风险目标 VPS 迁移验收”“继续收敛声明式资源策略”或“稳定版门禁规划”等候选中另行决策；本轮不自动修改 `AGENTS.md` 进入下一阶段。

## 本轮记录：2026-08-29（项目级网络调优与分层测试方案）

### 已完成及证据

- 已全量枚举并只读检查 `VMISS/测试/htb-aggregate` 的 23 个文件和 `VMISS/测试/Core` 的 89 个文件、43 个目录；完成扩展名/大小盘点、重复 SHA-256 分组、21 个 JSON 可解析性检查、关键日志与归档内容提取。Core 的 89 个文件实际只有 50 个唯一摘要，包含根目录与 baseline 目录的重复副本。
- `htb-aggregate` 的旧 S4 A1/B1/A2 再次确认 B1 未启用 HTB，三个根 `fq` 窗口约产生 9.094/7.596/8.296 GB egress；`cap200.json` 的单流 10 秒上传为约 199.96 Mbps、0 sender retrans、host CPU 约 1.86%。1C2G v0.3.0 stage0 的 13 项清单重新计算均匹配，只证明短时 HTB 生命周期和根 `fq` 恢复。
- Core 的 rc.12 1C2G/200 Mbps 证据支持 preflight、apply、立即/重启后 verify、幂等、BBR + 根 `fq`、16 MiB buffer、项目 swap 和安装 3X-UI 后 strict NOFILE 验证。baseline manifest 声明的 46 项中，30 项在原位置匹配，13 项在 Core 根目录有摘要匹配副本，3 项 project-state snapshot 缺失，故本地副本不是完整独立证据包。
- Core 的 `htb200-reference-*`、closeout、probe 和 cap200 目录多为空目录或空层级；reference/sweep JSON 仅为 3/15 阶段计划，未保存 benchmark、runtime、manifest、`COMPLETED` 或分析结果。不得从目录名推断 reference 或 candidate sweep 已执行。Core 保存的旧 rate-sweep/HTB 脚本摘要也与当前 rc.14 仓库实现不同。
- 已结合 Basic 历史 29 次 TcpQuality、约 264.27 GB 日志窗口出站流量及路径/时段漂移，形成建议性技术方案 [Debian VPS 网络调优与测试策略](network-tuning-and-test-strategy.md)：推荐“单一入口 + 声明式资源策略 + 分层验证”，默认保持 BBR + 根 `fq`，HTB/TcpQuality 降为研究通道。
- 已按当前 rc.14 源码补充厂商预优化决策：运行时已有 BBR/fq 不等于持久化所有权清晰；对 `/etc/sysctl.conf` 中唯一、严格为 `bbr`/`fq` 的 root 普通文件，现有实现可事务化备份并接管；对 `/etc/sysctl.d`、重复定义、符号链接、非 root 或未知组合调优保持 fail-closed。厂商品牌不成为 profile 维度。
- 已明确跨版本可采用“受管清除旧版后安装最新版”，但必须由旧版固定 Release 按旧状态执行 verify、rollback/purge 和恢复检查；最新版不直接覆盖旧状态，也不以手工删除配置替代回滚。对可快速恢复且备份已验证的 VPS，干净重装 OS 后直接应用最新版是独立的简化路径。
- 用户已批准该方案，P0 控制面已实施：中英文 README、`docs/validation.md`、`docs/design-scope.md` 和四份 HTB SOP 已同步为“默认低流量生命周期与业务冒烟、主动性能实验研究专用”。现有 `preflight` 被明确为厂商基线零写入审计点，现有 `update` 保持只读计划入口，没有增加同义 action 或伪自动迁移。
- `tests/static-check.sh` 已增加文档效力防回退门禁，要求中英文默认路径、旧版固定 Release 清理契约、厂商基线例外和四份 HTB 研究材料的 `研究专用` 标记持续存在，并拒绝恢复旧 Basic “当前权威执行文档”状态。
- 最终本地验证通过：`git diff --check`、生成 profile 一致性、15 项 `SHA256SUMS`、controller fixture、HTB fixture、完整 `tests/static-check.sh` 和修改文档本地链接检查均通过。静态测试中的故意畸形 TcpQuality fixture 按预期输出 FAIL 后，整个 suite 以 0 退出。rc.14 总控、profile、伴随工具和 `SHA256SUMS` 均未修改。

### 未完成门禁

- 本轮没有连接或修改任何 VPS，没有执行测速、HTB、迁移、rollback、reboot、apply、发布或生产变更；VMISS Basic rc.11→rc.14 迁移继续暂停。
- P0 已完成，但 P1/P2 的统一流量 ledger、TcpQuality 硬预算、跨工具 fail-closed 默认值、声明式参数源和 checkpoint/resume 迁移编排尚未实现。它们会改变 Release 资产行为，必须进入下一候选版本，不能静默改写已发布 rc.14。
- 不再新增 `audit-only/keep-external` action：当前 `preflight` 已满足零写入审计，操作者可停在其后保持厂商配置；复杂或含糊的外部所有权继续阻断。
- L2 默认 50 MB、L3 单次 300 MB/窗口 600 MB 已获方向批准，但目前仍只是设计上限；只有由下一候选版本工具 fail-closed 强制后，才可声称是项目规范性硬门禁。
- 本机没有 `shellcheck`，因此本轮没有新增本地 ShellCheck 证据；固定 ShellCheck 与 Linux root 生命周期仍须由下一候选版本的既有 CI 门禁执行。

### 延期事项变化

- 既有“完整 HTB campaign 研究专用”已落地为控制文档和静态门禁；“跨工具硬流量上限”“单一总控/声明式资源表”和“checkpoint/resume 迁移编排”已获方向批准，但延期到下一候选版本实施和验证。
- 撤销“新增显式 audit-only action”候选：复用现有 `preflight` 更简单，且不产生重复命令面；兼容基线仍可事务化接管，复杂基线继续阻断。
- 无新增网络安全专项或全面生产加固事项；本轮没有扩大到服务商 policer 归因、通用 UDP 参数或永久 HTB 设计。

### 当前成熟度判断

项目级默认路线和 P0 文档效力已经闭合：业务 VPS 不再承担研究级公网实验，发布确定性验证、目标机生命周期、真实业务冒烟、症状诊断和研究实验已经分层并有静态防回退门禁。剩余高优先级工程主要是下一候选版本的硬预算、统一 ledger 和迁移编排，以及对应 Linux root/目标机验证；不能作为 rc.14 的原地修改。

## 本轮记录：2026-08-28（VMISS HTB 实验成本复盘与路线收敛）

### 已完成及证据

- 已只读复核 `VMISS/测试/Basic` 历史证据。`rc11-vmiss-basic-evidence-final-20260806.tar` 的 SHA-256 与随附清单一致，归档内为 S1b、S2 共 6 次 TcpQuality；按每次测试前后根 qdisc `Sent bytes` 差值重算，约产生 43.09 GB 出站流量。
- 同目录后来追加的 S3A–S3F、S4 证据合计为 29 次 TcpQuality；用相同口径逐日志重算约 264.27 GB（246.12 GiB）出站流量。该值尚不包含下载方向、失败尝试、协议开销、背景业务和服务商计费口径，因此支持用户所述“几百 GB”运营影响，但不能把全部额度消耗精确归因于这 264.27 GB。
- 现有完整 Basic SOP 还要求 HTB200 reference、180/190/195 sweep、A/B/A 和反向窗口；1C2G A/B/A SOP 又明确依赖已冻结候选。历史证据同时显示公共节点、时间窗口和路径波动足以显著影响结果，继续增加主动流量的边际证据价值不足以覆盖额度、时间和停机风险。
- 已确认仓库当前并非维护六套独立调优算法：六个 profile 由单一 `tools/profile-template.sh.in` 和 `tools/render_profiles.py` 生成，总控已按 Debian 主版本、CPU/内存档位自动选择，并将端口带宽作为显式输入。后续可进一步简化用户入口，但 OS 差异、资源边界、状态所有权和发布哈希仍须保留为可审计契约。

### 未完成门禁

- 此前准备的 rc.11 purge rollback 继续暂停；本轮没有执行目标 VPS 写入、rollback、reboot、rc.14 apply 或 HTB 流量。
- 当前不再把“VMISS Basic 1C1G / 200 Mbps HTB 完整实验”和“VMISS 1C2G / 200 Mbps 临时 HTB A/B/A”作为该 VPS 升级或日常验收门禁。只有在出现可复现的真实业务症状、明确需要形成 HTB 因果结论、使用独立高额度测试机并预先批准硬流量预算时，才重新评审是否执行。
- rc.11→rc.14 若继续，仍须保留状态所有权、固定资产完整性、可恢复入口、rollback 后复核、重启持久性和最终 verify 等安全不变量；可把它们自动编排成更短的迁移流程，但不能把“简化操作”解释为删除恢复和完整性门禁。

### 延期事项变化

- 新增候选：将完整 HTB campaign 标记为研究专用、非默认验收，并为所有主动测速增加跨阶段硬流量上限与自动停止机制；是否修改文档和工具等待用户批准。
- 新增候选：把外部使用面收敛为单一总控、单一规范引擎和小型声明式资源表，生成 profile 仅保留为发布兼容/审计资产；是否实施及兼容策略等待独立方案评审。

### 当前成熟度判断

当前证据足以停止在额度受限生产 VPS 上继续扩大 HTB 主动实验；项目应把重心转回低流量生命周期验证、重启持久性和真实业务冒烟。版本迁移是否继续由用户决定，HTB 因果研究不再作为其前置或后置默认门禁。

## 本轮记录：2026-08-28（VMISS Basic rollback 前最终门禁）

### 已完成及证据

- 同一 root-only 迁移目录的续跑检查完成，rc.11 profile 与 rc.14 总控再次通过固定 SHA-256；live state 与回滚前备份仍为同一 SHA-256，`LIVE_STATE_UNCHANGED=PASS`。
- `/swapfile-proxy` 的 state path、1024 MiB 大小、active、device `65025` 和 inode `16919` 与实际 regular file 完全一致，权限为 root:root/0600，swapon 和唯一 fstab 行均通过。采集时 swap 仅使用 268 KiB，`MemAvailable` 为 582288 KiB；按本轮运维安全门禁具备执行受管 swapoff 的容量余量。
- 当前 HTB state absent；sysctl 为 BBR + fq/16 MiB，`eth0` 为单一根 `fq`、class 为空且 drops/requeues/backlog 为 0；`proxy-vps-fq.service` 与 `x-ui.service` active，无 failed unit。
- 固定 rc.11 profile 最终 `verify` 通过、警告数 0；证据 state/qdisc/class 已闭合哈希，最终 `STAGE1_READINESS=PASS`、`RESUME_RC=0`。维护就绪技术门禁已通过。

### 未完成门禁

- 有状态 rc.11 `PURGE_CREATED_SWAP=1 rollback` 尚未执行。执行前仍需操作者实际确认 VMISS 控制台可用、第二 SSH 会话已建立、维护窗口生效且无更新/测速/备份；这些人工条件不能由主机日志替代。
- rollback 必须独立执行并停在即时复核：若失败，保留 state/swap/qdisc/服务现场且不做手工删除；若成功，确认 state、项目 swap、fstab 行和受管文件完成清理，qdisc/sysctl 恢复语义通过、x-ui/SSH/出口仍可用。第一次 reboot 仍须等待该复核结果，不能与 rollback 合并。
- rc.14 preflight/apply、第二次 reboot/verify、HTB v0.4.0 与 HTB200 reference 继续保持阻断。

### 延期事项变化

- 无新增延期事项；本轮仅推进已批准的版本迁移门禁。

### 当前成熟度判断

当前 VMISS Basic 已达到 rc.11 purge rollback 的技术开始条件，但尚未执行任何有状态迁移。项目下一安全检查点是 rollback 后即时复核，不是 rc.14 apply 或 HTB。

## 本轮记录：2026-08-28（VMISS Basic 维护就绪检查续跑）

### 已完成及证据

- 固定 rc.11 profile 与 rc.14 总控已预下载到独立 root-only 迁移目录并分别通过预期 SHA-256；rc.11 schema 3 `VERIFIED` state 已复制到证据目录，原件与副本 SHA-256 均为 `6ad01b9b64c82a409e8fd271e9d1850eca2cf59fd9dc5a4bcb734566f37bee33`，`cmp` 门禁通过。
- state 再次确认 `debian13-1c1g`、rc.11、200 Mbps；`/swapfile-proxy` 被状态声明为脚本创建、1024 MiB、active，并记录 device/inode。主机约 967 MiB RAM，采集时 `MemAvailable` 约 570 MiB，swap 仅使用约 268 KiB；这些数据支持继续完成只读就绪检查，但尚未完成文件所有权和最终 rc.11 verify 门禁。
- 首次就绪脚本在 `swapon --show --bytes --output=...` 处以 `PREP_RC=1` 停止。目标 util-linux `swapon` 不接受该 `--output` 组合；这是采集命令兼容性错误，不是 swap、主机或迁移失败。已将续跑命令修正为 `swapon --show=NAME,TYPE,SIZE,USED,PRIO --bytes`，不重用失败结论，也不重新下载已校验资产。

### 未完成门禁

- 须从现有迁移目录续跑并确认：当前 state 未漂移、swap device/inode/fstab/active 所有权一致、内存占用可接受、HTB inactive、根 qdisc/class 正常、服务与 failed units 正常、固定 rc.11 profile `verify` 通过，以及续跑日志与证据摘要闭合。
- `PREP_RC=1` 不授权 rollback。rc.11 purge rollback、回滚后复核和所有后续重启/apply/HTB 阶段继续保持阻断。

### 延期事项变化

- 无新增延期事项；本轮仅修正目标工具的命令行兼容性，不改变实验或迁移范围。

### 当前成熟度判断

固定资产与 state 备份门禁已通过，维护就绪检查因可修正的只读采集命令错误中断。当前应在同一证据根下续跑剩余检查；尚未达到有状态 rollback 门禁。

## 本轮记录：2026-08-28（VMISS Basic rc.14 update 门禁）

### 已完成及证据

- 用户已在当前 VMISS Basic 上使用固定 rc.14 总控执行显式 `update --target v0.1.0-rc.14`；总控资产 SHA-256 通过，最终 `UPDATE_RC=0`，完整日志 SHA-256 为 `45b1c40a23001d7af4e7e108215b4d1e31eb4c7786434149d3954174c81c5290`。
- update 重新识别出 Debian 13、1 vCPU、967 MiB、`debian13-1c1g`、当前 rc.11/schema 3 `VERIFIED`、200 Mbps；固定 rc.11 profile 下载并通过当前配置普通/严格服务验证，警告数为 0，x-ui 主进程及直接 Xray 子进程 NOFILE 均为 65536/65536。
- rc.14 固定 profile `debian13-1c1g-vps-tuning.sh` 的 update-preflight 通过，确认根 `fq`、活动 swap、16 MiB auto buffer、`eth0` 默认出口和 UFW 只读状态；预检警告数为 0，系统配置未修改。
- 固定迁移材料已由目标机输出确认：当前 rc.11 profile SHA-256 为 `354a0750eff7fd76910d91a2e71eab9e3936548314e551b11acb6c95b438af2d`，目标 rc.14 总控 SHA-256 为 `ce7668806ee0f3afb58aff18c2d6cdab8df58028d60390ba37e3ddf26b513248`，迁移继续保留 200 Mbps。

### 未完成门禁

- update 只授权准备维护迁移，不等于 rc.14 已安装。进入变更前仍须预下载并分别校验 rc.11 profile 与 rc.14 总控，保存回滚前 state/qdisc/sysctl/swap/服务证据，再次执行固定 rc.11 profile `verify`，确认项目 swap 所有权、实际 swap 使用量、可用内存、第二 SSH 会话和 VMISS 控制台救援入口。
- rc.11 `PURGE_CREATED_SWAP=1 rollback`、回滚后语义复核、第一次重启、rc.14 preflight/apply、第二次重启、普通/严格 verify 均未执行；任一步失败必须停止，不得跳过重启或直接越过状态门禁。
- rc.14 生命周期闭合前，HTB v0.4.0 和 HTB200 reference 继续保持阻断。

### 延期事项变化

- 无新增延期事项。update 输出的 UFW 规则属于当前只读环境证据；本轮不把防火墙治理扩展为独立安全专项，既有延期状态不变。

### 当前成熟度判断

当前 VMISS Basic 已通过 rc.11→rc.14 的只读兼容性门禁，下一安全检查点是维护窗口就绪与固定资产预置；尚未进入有状态 rollback 或 rc.14 apply，项目阶段不变。

## 本轮记录：2026-08-28（VMISS Basic 当前基线判定）

### 已完成及证据

- 已复核用户从当前 VMISS Basic 返回的只读基线：Debian 13、Linux 6.12.101、1 vCPU、约 968 MiB RAM、约 1 GiB swap、ext4、约 6.4 GB 可用空间；managed state 为 schema 3、`VERIFIED`、`0.1.0-rc.11`、`debian13-1c1g`、200 Mbps。
- 当前没有安装 `dvt`/Release 目录，没有 `/run/htb-aggregate-experiment/active.json`；`eth0` 为 IPv4/IPv6 默认出口，根 qdisc 为单一 `fq`、class 为空、qdisc drops/requeues/backlog 为 0，`proxy-vps-fq.service` 为 active。该证据只确认当前旧版运行状态，不替代 rc.11 固定资产的 `verify`。
- 已判定 rc.11 schema 3 是 rc.14 HTB v0.4.0 的硬阻断项；不能直接安装 v0.4.0、执行 smoke 或生成 HTB200 reference，也不能用 rc.14 `apply`/`reconfigure` 覆盖旧状态。
- 下一相邻门禁确定为：使用固定并校验的 rc.14 Release 总控执行显式 `update --target v0.1.0-rc.14` 只读升级检查，保存完整输出和退出码。本步骤只下载、校验并执行只读 current verify/target update-preflight，不授权 rollback、apply、重启或 HTB 流量。

### 未完成门禁

- rc.14 `update` 只读检查尚未执行，当前 rc.11 固定 Release 资产、当前 profile `verify` 和 rc.14 `update-preflight` 仍待输出确认。
- 只有 update 检查通过并核对其输出的固定 URL、SHA-256、profile、端口和迁移顺序后，才可另行进入有控制台保障的维护窗口；rc.11 verify、显式 swap purge rollback、第一次重启、rc.14 preflight/apply、第二次重启和严格 verify 均未执行。
- rc.14 生命周期闭合前，HTB v0.4.0 preflight/smoke、5 样本 HTB200 reference 和所有后续候选实验继续保持阻断。

### 延期事项变化

- 无新增延期事项。网络安全专项、全面生产加固、复杂测试工程和 CI 依赖维护的既有状态不变。

### 当前成熟度判断

当前 VMISS Basic 的旧版运行态健康条件基本满足，但管理基线仍停留在 rc.11/schema 3。项目下一安全检查点是 rc.14 只读 update 门禁；尚未进入目标机迁移、rc.14 生命周期或 HTB reference 阶段，项目阶段不变。

## 本轮记录：2026-08-28（VMISS Basic HTB 历史证据复核）

### 已完成及证据

- 已只读复核用户提供的 `htb-aggregate` 目录及其归档、独立 iperf3 结果和 1C2G stage0 证据，并与 rc.14 的 HTB v0.4.0 reference/candidate 契约对照；未连接或修改目标 VPS，未执行 qdisc、测速、安装、升级或持久化操作。
- `S4-HTB-20260810T141025Z.tar.gz` 中 A1/B1/A2 的 TcpQuality 批次均有旧版 `COMPLETED`，但所谓 B1 的 start 日志只到 preflight；负载前后均为 `state=INACTIVE`、单一根 `fq`、class 为空且 watchdog inactive。因此该归档不是有效 HTB190 B 阶段，不能用于聚合整形效果判断。
- 独立 `cap200.json` 记录了一次根 `fq` 下的单流、10 秒、200 Mbit/s iperf3 上行：sender 约 199.96 Mbit/s、sender retransmits 为 0、host CPU 约 1.86%；对应前后快照始终为根 `fq`，未启用 HTB。该结果只提供当时单次路径能力线索，不是 HTB200 reference 样本。
- `stage0-v030-20260816T102145Z` 的 13 项清单在本地重新计算 SHA-256 后全部匹配；日志证明旧 v0.3.0 在当时的 `debian13-1c2g` schema 4、200 Mbps 基线上完成 190 Mbit/s 的短时挂载、ACTIVE、watchdog、stop 和根 `fq` 恢复。smoke 期间 `overlimits=0` 且无测量负载，因此只证明旧版生命周期和恢复，不证明整形暴露或性能收益。
- 三组材料至少涉及 2026-08-10 的 1C1G 旧目标和 2026-08-16 的 1C2G 旧目标；文件内记录的目标地址也不等于用户本轮指定的当前目标。不能跨主机、profile、版本、时间和测试方法拼接成当前 VMISS Basic 的候选速率证据。

### 未完成门禁

- 当前目标仍缺少 rc.14 固定 Release、schema 4 `VERIFIED`、实际 `debian13-1c1g` 或 `debian13-1c2g` profile、200 Mbps 端口、单一根 `fq`、managed-state SHA-256 和 v0.4.0 执行器哈希的现场只读确认。
- 当前目标仍未完成 v0.4.0 的 preflight、10 秒 smoke 和恢复复核；旧 v0.3.0 smoke 不继承为 rc.14/v0.4.0 通过。
- 当前目标仍未形成 schema 3、5 样本的 HTB200 reference，也没有有效的测量、HTB 暴露和资源三类 gate；因此 180/190/195 candidate sweep、候选冻结、A/B/A、反向窗口、真实代理链路复验和永久整形均未获相邻阶段证据授权。

### 延期事项变化

- 无新增延期事项。网络安全专项、全面生产加固、复杂测试工程和 CI 依赖维护的既有状态不变。

### 当前成熟度判断

旧证据已完成真实性与适用性分层，但当前 VMISS Basic 尚未进入 rc.14 HTB 速率发现的目标机 reference 阶段。下一安全检查点是先确认当前目标身份和 rc.14 只读基线；通过后才执行 v0.4.0 smoke，再以全新目录获取 HTB200 reference。项目仍处于验证和文档闭环阶段，不满足阶段切换条件。

## 本轮记录：2026-08-28（rc.14 GitHub Pre-release 发布）

### 已完成及证据

- 已从中断点继续 rc.14 发布任务，在独立分支完成 28 个候选文件的本地生成一致性、Bash 语法、控制器/事务/恢复 fixture、HTB fixture、manifest、staged whitespace 及新增敏感模式检查；Windows 本地的 root installer 门禁按预期报告 `installer check requires root`，没有冒充通过。
- 已通过 PR #9 合并到 `master`。CodeRabbit 首轮实质评审提出英文 README 输出契约不同步和 rollback 菜单槽位未锁定两项意见；两项均经源码复核后修复，唯一 inline thread 已回复并解决。修复后的 push/PR CI、合并后 `master` CI 和 tag CI 均通过，覆盖 Ubuntu root installer lifecycle 与固定 ShellCheck 0.11.0；后续 CodeRabbit 状态为 `Review rate limited`，未作为第二轮实质评审证据。
- 已创建 annotated tag `v0.1.0-rc.14`，tag object 为 `aedee73b7b4d2f87d4f810e61b97eec866aa14c6`，解引用目标为 PR 合并提交 `a0ce7c5bdbedd903ec2f027b7041939f2b6242d7`；reviewed head、合并提交与 tag 的 tree 一致。
- 已发布非 Draft 的 GitHub Pre-release，共 17 项资产。公开反向下载后，资产名称和 `uploaded` 状态为 17/17，GitHub API SHA-256 与下载字节为 17/17；重建 GitHub 扁平化的 HTB 逻辑目录后，`SHA256SUMS` 中 15 项运行资产全部通过。
- 公开 `install.sh` 与 `SHA256SUMS` 直连下载最终均为 HTTP 200；SHA-256 分别为 `1aef3822996421b05e5055d87289502c0ddb01149454aa3ba27a825d40ecf909` 和 `4449dc8fe73e23020c8b2d38066435d7c3429ad821f43beac9ac8b965f1241de`。发布页正文与仓库发布说明一致，验证临时目录已清理。

### 未完成门禁

- 本次发布证明源码、生成资产、fixture、PR/CI、tag、Release 元数据和公开资产字节完整性；不证明 rc.14 在目标 VPS 上的首次安装、rc.13→rc.14 迁移、同值/100→200/200→500/500→200 重配置、故障恢复、重启持久性或真实代理链路。
- TcpQuality、真实 HTB 窗口和性能改善仍未取得 rc.14 最终哈希绑定的目标环境证据；Pre-release 发布不得替代这些运行与业务层门禁。
- GitHub Actions 成功作业对 `actions/checkout@v4` 报告 Node.js 20 弃用告警，并说明当前由 runner 强制使用 Node.js 24。该告警未造成 rc.14 CI 失败，但 workflow 依赖升级尚未评估或实施。

### 延期事项变化

- 新增“CI 依赖维护”延期候选：后续独立核对 `actions/checkout` 当前受支持 major、迁移影响和供应链边界；本轮不为消除非阻断告警临时改变已经通过并发布的 workflow。
- 网络安全专项、全面生产加固和复杂测试工程的既有延期状态不变；无其他新增延期事项。

### 当前成熟度判断

rc.14 的本地、Linux CI、PR/评审、完整性链和公开 Pre-release 发布闭环已经完成；项目仍处于验证和文档闭环阶段。当前主要缺口是目标 VPS 生命周期、重配置/恢复、重启持久性和真实业务链路，不满足阶段切换条件。

## 本轮记录：2026-08-28（验证与文档闭环工作指南）

### 已完成及证据

- 已依据当前 `AGENTS.md`、本备忘、`docs/validation.md`、rc.14 发布说明和 GitHub Actions 工作流，把后续闭环拆分为范围冻结、本地确定性门禁、Linux root lifecycle、完整性与发布资产、目标 VPS 功能、业务链路、证据审查和文档同步八个阶段。
- 已明确区分四种完成声明：本地候选可审查、Pre-release 可发布、核心功能已在目标 VPS 验证、稳定版可发布；后一级不得由前一级证据替代。
- 已确认性能改善不是 rc.14 带宽重配置功能的当前声明，因此 TcpQuality、HTB 和全量性能矩阵不应自动成为本轮阻塞项；只有准备发布相应性能结论时才升级为门禁。
- 本轮仅形成后续工作指南并更新备忘，没有执行新的代码修改、VPS 操作、网络流量测试、发布或生产变更。

### 未完成门禁

- rc.14 仍需按现有候选重新闭合固定 ShellCheck 0.11.0、Linux root installer lifecycle、最终完整性链、文档证据状态和 diff 自检。
- Release 资产反向下载、rc.13→rc.14 迁移、同值/100→200/200→500/500→200 重配置、重启持久性和真实代理链路仍缺少 rc.14 最终哈希绑定的目标环境证据。
- 是否进入 Pre-release、目标 VPS 验证或稳定版门禁，应由用户先确定本轮目标声明和可用测试环境；本备忘不构成执行授权。

### 延期事项变化

- 无新增延期类别。既有网络安全专项、全面生产加固和复杂测试工程仍保持“延期候选，未授权”。

### 当前成熟度判断

项目仍处于验证和文档闭环阶段。当前最优先事项是先关闭 rc.14 的本地与 Linux root 发布门禁，再按用户批准的声明层级选择最小目标 VPS 矩阵；尚未达到阶段切换条件。

## 本轮记录：2026-08-28

### 已完成及证据

- 已将“验证和文档闭环”规定为当前项目阶段，并明确其目标、范围优先级、延期登记、每轮更新和阶段提醒规则。
- 已为备忘建立固定路径和效力边界，避免将延期候选误解为已批准实施项。
- 本轮开始前正在收口 `dvt reconfigure --port <MBPS>` 候选：生成一致性、Bash 语法、controller fixture、六份 profile static fixture 和 HTB fixture 已在本地主机通过；这些结果仍不等于目标 VPS 运行验证。

### 未完成门禁

- `0.1.0-rc.14` 的最终 ShellCheck 0.11.0、完整性链复核、文档证据状态和最终 diff 自检尚未在本轮阶段规则变更后全部重新收口。
- Linux root installer lifecycle、公开 Release 资产反向下载以及目标 VPS 的带宽重配置、恢复、重启持久性和真实代理链路仍未验证；当前未创建 tag、GitHub Release，也未执行 VPS 变更。

### 延期事项

| 类别 | 发现或建议 | 当前依据 | 延期理由 | 重新评估触发条件 | 状态 |
|---|---|---|---|---|---|
| 网络安全专项 | 对 installer、Release 供应链、受管状态与恢复证据开展独立威胁建模和专项审计 | 当前项目已有固定摘要、文件所有权和事务恢复控制，但尚无独立安全专项结论 | 不直接阻断当前 rc.14 验证与文档闭环，展开后会改变工作重心 | 当前发布验证闭合，或发现可复现的供应链/权限/恢复安全缺陷 | 延期候选，未授权 |
| 全面生产加固 | 评估 SSH、主机防火墙、入侵防护、面板暴露面、备份与救援通道等生产基线 | 这些控制依赖实际服务商、网络拓扑、面板和运维边界，不属于现有调优 profile 的已批准管理面 | 需要独立威胁边界和目标环境授权，不能由调优项目顺带接管 | 用户决定进入生产加固阶段并提供目标边界与授权 | 延期候选，未授权 |
| 复杂测试工程 | 评估跨 Linux 环境的 root lifecycle 自动化、进程中断/掉电故障注入和真实 VPS 编排框架 | 当前已有静态与 fixture 门禁，但最终仍依赖 Linux root、目标 VPS 和重启后的分层证据 | 新建测试基础设施超出当前最小闭环；本阶段先完成已有门禁和人工目标机矩阵 | 现有验证矩阵基本闭合，且重复人工验证成本或遗漏风险成为主要瓶颈 | 延期候选，未授权 |
| CI 依赖维护 | 评估并升级 `actions/checkout@v4` 到当前受支持 major | rc.14 的 `master` 与 tag CI 成功，但 GitHub runner 报告 Node.js 20 弃用并临时强制使用 Node.js 24 | 不阻断当前候选，版本选择和迁移影响需依据届时官方 Action 文档独立核对 | GitHub 不再兼容当前版本、告警升级为失败，或进入下一次 CI 维护窗口 | 延期候选，未授权 |

### 当前成熟度判断

项目仍处于验证和文档闭环阶段。rc.14 候选仍有明确的本地最终门禁和目标环境证据缺口，尚未达到应切换到下一阶段的条件。本轮无其他新增延期事项。

## 本轮记录：2026-09-11（Ubuntu 支持可行性评估）

### 已完成及证据

- 只读复核当前 `master`/rc.17 工作树：项目正式契约仍是 Debian 12/13 amd64 的六份 profile。总控 `detect_profile_from()` 仅接受 `ID=debian` 和版本 12/13；profile 模板 `check_supported_os()` 及状态字段、`tools/render_profiles.py`、安装器资产清单、`dvt-migrate.sh` 的 profile 正则和 HTB wrapper 均存在 Debian 专属边界。GitHub Actions 的 `ubuntu-24.04` 仅是 CI runner，不构成 Ubuntu 目标机支持证据。
- 评估结论为“有条件可行，但不应并入 rc.17”：现有调优逻辑主要使用 Linux 通用的 `sysctl`、`iproute2`、`tc`、`systemd`、swap 和 `jq` 接口，静态上没有发现必须依赖 Debian 用户态的核心动作；但 Ubuntu 目标机的内核、qdisc、systemd-sysctl 加载、镜像/cloud-init、3X-UI/Xray、回滚和重启行为尚无本项目证据。
- 已核对 Ubuntu 官方生命周期页和发布目录（2026-09-11）：Ubuntu 22.04 LTS 标准安全维护至 2027-05，24.04 LTS 至 2029-05，26.04 LTS 已于 2026-04 发布、标准安全维护至 2031-05；当前 amd64 Server 镜像分别为 22.04.5、24.04.5 和 26.04.1。来源：`https://ubuntu.com/about/release-cycle`、`https://releases.ubuntu.com/`、`https://ubuntu.com/download/server`。

### 未完成门禁

- 尚未修改任何源码、profile、清单或文档契约；没有 Ubuntu 目标 VPS、安装/重启/回滚/代理业务或性能验收证据。不能把静态可移植性写成 Ubuntu 已支持。
- Ubuntu 支持若立项，至少需要重新设计发行版字段和状态兼容策略，扩展 controller/template/generator/installer/manifest、迁移正则、测试 fixture、README/设计范围/验证矩阵，并决定 HTB 研究面是否继续限定 Debian 13。每个纳入的 Ubuntu 版本都需要独立的 amd64、四个资源档边界、qdisc/sysctl/swap/systemd、迁移/恢复、重启和真实 VLESS + REALITY + TCP 证据。

### 延期事项变化

- 新增“Ubuntu 目标支持决策”延期候选：在 rc.17 源码、fixture、生成资产、文档和本地门禁闭合前，不扩展发行版矩阵。重新评估触发条件为用户批准新阶段并提供 Ubuntu 测试资源/目标边界；优先从 Ubuntu 24.04 LTS 试点，26.04 LTS 在首个点版本和依赖兼容性复核后纳入，22.04 LTS 仅在明确的存量兼容需求下考虑。无新增其他延期事项。

### 当前成熟度判断

Ubuntu 支持技术上有条件可行，产品和运行证据尚不足以承诺支持。当前阶段继续保持 Debian-only；Ubuntu 评估已形成决策输入，但不改变 rc.17 实现范围，也不授权目标 VPS 操作或发布。

## 本轮记录：2026-09-11（Debian-only rc.17 闭环复核）

### 已完成及证据

- 重新执行当前工作树的 Debian-only 门禁：`python tools/render_profiles.py --check`、全部目标脚本与测试脚本 `bash -n`、`bash tests/controller-check.sh`、`bash tests/static-check.sh`、`bash experiments/htb-aggregate/tests/static-check.sh` 和 `sha256sum -c SHA256SUMS` 均通过。静态套件最终输出为 `static checks passed for 6 scripts` 和 `HTB aggregate experiment static checks passed`。
- 复核实际 Git 状态：`v0.1.0-rc.17` 已指向合并提交 `6bed55333a6483a4c5efd899d9942e7df3ced088`；当前 `master`/`origin/master` 为后续文档同步提交 `6786fbe6f949ccb43428fb52c1c58e9ba542e897`。GitHub Actions 固定 run `34455870749`（rc.17 合并提交）为 `success`。
- 重新从公开 `v0.1.0-rc.17` Release 下载 19 个资产，逐项按清单复核通过；公开 `SHA256SUMS` 摘要为 `d44284ed010a5a9774fc104cea50a51bd209f8e0d1e57b9680cdf147e5bdc208`，公开 `install.sh` 摘要为 `4fd4dde90df4524d657623c4e22e355ab9adac70a703cff61a68e41e09007cbc`。临时下载目录已清理。

### 未完成门禁

- 本机 Windows 环境不是 Linux root，`tests/installer-check.sh` 返回 `installer check requires root`，`tests/rc17-check.sh` 返回 `[dvt-traffic-budget][FAIL] 必须以 root 运行`；这两项已由 rc.17 GitHub Actions 成功作业覆盖，本地不能重复宣称通过。
- rc.17 仍没有新增 Ubuntu 支持；目标 VPS 的 rc.17 首次安装、迁移/重配置、重启持久性、真实 VLESS + REALITY + TCP、HTB reference/A/B/A 和性能改善仍不是本轮本地复核所得证据。不得把 Release 或 CI 结果写成这些运行/业务门禁通过。

### 延期事项变化

- 无新增延期事项。Ubuntu 支持继续保持上一条记录的延期候选；目标 VPS 生命周期、真实业务和研究型 HTB 证据按既有矩阵继续登记，未获得新的执行授权。

### 当前成熟度判断

rc.17 的 Debian-only 源码、生成资产、静态 fixture、CI、tag、Pre-release 和公开资产完整性已复核闭合；项目仍处于验证和文档闭环阶段。当前剩余缺口属于目标环境和业务层证据，不改变 rc.17 的发行版范围，也不自动授权下一阶段或真实 VPS 操作。
