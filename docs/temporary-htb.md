# 临时 HTB 速率阶梯实验

适用：未发布的 `0.2.0-rc.1` 完整候选 bundle。入口为 `dvt htb-sweep`，是 tcpfit 重构路线的第二阶段实现；普通、不修改 qdisc 的测量继续使用 [`dvt measure`](automatic-measurement.md)。当前验证状态以[验证说明](validation.md)为准。第一阶段 `d650709` 的真实 VPS 证据不能证明本入口的整形与恢复已经在 VPS 验收。

## 行为与适用范围

HTB（分层令牌桶）限制所选接口的**全部出向流量**，包括其他连接、IPv4/IPv6 和 SSH；不是只限制本次 iperf3。用户必须显式提供接口、上下界和 application cap，且 `1 <= lower < upper < rate-cap <= 10000`。`rate-cap` 是 iperf3 发送目标的上限与预算依据；正式样本目标取当前 HTB 速率的 110%，且不超过 cap。`lower/upper` 是本轮临时整形区间，均不代表套餐速率或持久配置建议。

按 Linux 能力检查，不用发行版名称、架构、CPU/RAM 档位或套餐带宽表限制本入口。依赖沿用普通测量；整形还需要 root、可用的 HTB/fq 和完整可恢复的 tc JSON。**只接受无 class/filter 的单一 root fq**；mq、clsact、ingress、额外对象或未知 fq 选项均在写入前拒绝。此时仍可使用普通 `measure`。旧 `dvt htb` 研究协议及受管配置支持范围保持原样。

Ubuntu 24.04 的 iproute2 6.1 尚无 class JSON；本入口严格解析其 HTB 文本中的 rate/ceil，并保留整行参数用于漂移核验。未知 class 文本仍拒绝。iperf3 建议使用 3.18 或已包含相应修复的版本：[ESnet 3.18 发布说明](https://github.com/esnet/iperf/blob/2a2984488d6de8f7a2d1f5938e03ca7be57e227c/RELNOTES.md)记录限速测试 CPU 过高问题修复（#1741/#1743）；本轮 runner 的 3.16 在 1 Mbps 下实测约 100.7% sender CPU，正确触发 `CPU_PRESSURE` 并在整形前停止。程序不会自动安装或升级用户主机的依赖。

保存并恢复 fq 的 limit、flow_limit、buckets、orphan_mask、quantum、initial_quantum、rate、pacing、时间、horizon 及可识别的 bands/priomap/weights 参数；不只恢复默认 `fq`。原 root handle 为 `0:` 时，内核可能分配新的非零 handle；仅该接口的单一 fq 允许此语义等价，参数必须一致。未知参数拒绝，不静默丢弃。

2026-09-28 的[首轮单机验收](temporary-htb-acceptance-2026-09-28.md)发现目标 iproute2 6.15.0 的 `weights` 参数解析问题，导致原候选自动恢复失败。当前修复在开始事务前，通过无 `dev`、末尾 `help` 的命令验证完整恢复语法，优先标准语法，仅在实际解析器确认接受时使用限定兼容形式，并将参数保存在 checkpoint。固定 `f08fd8c` 的[后续复验](temporary-htb-retest-2026-09-28.md)已通过真实 tc 正常事务及公共路径 SIGINT/SIGTERM 自动恢复；完整 sweep 的正常 CLI 完成报告、有效拐点与业务效果仍未验收。

## 计划和执行

先查看离线计划（以下接口名和参数为示例）：

```bash
bash debian-vps-tuning.sh htb-sweep --interface eth0 \
  --lower 10 --upper 20 --rate-cap 25 --fine-step 1 --plan-only
```

执行前确认业务可接受整个接口限速，并准备控制台恢复路径。执行资产、输出父目录及其恢复材料必须由 root 控制；不自动安装依赖，不更改 sysctl，不创建持久服务。使用新的私有输出目录和已规划的共享账本窗口：

```bash
dvt htb-sweep --interface eth0 --lower 10 --upper 20 --rate-cap 25 \
  --family 4 --budget-mib 600 --max-duration 300 \
  --ledger /root/dvt-traffic/htb-window.json --window-id htb-check-01 \
  --output-dir /root/dvt-htb-check-01
```

非交互执行使用 `--yes` 确认所展示的接口影响、服务和预算。省略 `--host` 时复用公共目录与有预算自动选点；选点的 1 Mbps 协议短测在原 qdisc 下进行，选定出口必须与已确认接口相同，随后才进入事务。不可通过换节点拼接一次扫描。公共服务仍可能繁忙、不可达或容量不足。

默认每档三次、每次五秒。低档首部控制后运行上界 reference，再运行最多五档粗扫；只有有效样本确认了重复重传上升，才在相邻区间最多增加三档二分精扫，随后执行上界和低档尾部控制。`--fine-step` 是停止精扫的区间宽度，最多三档的预算边界可能使实际分辨率较粗。

沿用 `burst=262144 bytes`、`cburst=32768 bytes`、`quantum=15140 bytes`。为减少低速短窗的入队积压，正式样本按上述逐档 offered rate 发送，write block 最多为该档 50 ms 数据量且不超过 128 KiB；不改变 socket buffer。原生及目标验证状态见[采样修正记录](temporary-htb-sampling-2026-09-28.md)。短窗口、路径或资源条件仍可能使样本失效；无有效结果是允许的结果，不能自动延长时间或提高预算补测。

每个样本的预留按固定 application cap 计算，包含选点、失败和超时余量。计划最坏预留包含全部三档精扫，但执行仍逐次预留、成功按 sender bytes 结算、失败保守结算。额度不足或时间到达时停止并恢复；协议、重传和其他业务流量不属于该 payload 账本。

## 恢复契约

1. 在任何 `tc` 写入前保存原拓扑、完整 fq 恢复参数、boot ID、网络命名空间和 ifindex，冻结当前 `recovery.py` 并记录摘要。
2. 每接口加锁并登记 checkpoint；独立 watchdog（恢复看护进程）确认就绪后才允许创建 HTB。仅修改带本次 handle 的 root、class 与 fq leaf。
3. 每档前后核对实际 HTB rate/ceil、默认 class、拓扑及参数。检测到额外 filter、外部拓扑或参数变化时停止，不盲目覆盖。
4. 正常结束、预算/时间停止或单次 SIGINT/SIGTERM 时，先回收本次采集进程，再恢复并复核 fq；独立看护在 owner 消失或期限到达时接手。期限到达先 TERM owner，并留最多八秒供清理；仍未恢复且 PID/starttime 仍匹配时 KILL 本次 owner 后接手，避免被冻结的 owner 长期持锁。看护不是 systemd 服务，不保证对抗整个进程树被杀、内核故障、掉电或重启。
5. 恢复成功记为 `RESTORED` 并清除活动登记，保留 checkpoint。失败记为 `RECOVERY_REQUIRED`，保留现场，禁止把报告标为 `COMPLETED`。同接口的新实验不能绕过未恢复 checkpoint。

原进程已经退出、恢复材料及接口身份仍可核验时，可使用本次冻结的恢复程序：

```bash
python3 /root/dvt-htb-check-01/htb-transaction/recovery.py recover \
  /root/dvt-htb-check-01/htb-transaction
```

恢复仍拒绝外部对象/参数、摘要或身份不符；再次调用不能绕过第一次的拒绝。此时应通过控制台依据 `original.json`、`state.json` 和 `watchdog.log` 核对原因。不要删除 checkpoint、活动登记或账本来伪造恢复/结算。owner 遭 SIGKILL 时可能留下尚未结算的流量占用；恢复 qdisc 不等于账本已经结清。

## 结果与证据

沿用普通测量的有效窗口、receiver goodput、重传/GiB 和资源/路径门禁，并要求样本实际暴露于 `htb-fq`、root overlimits 增长及相对于 HTB 速率的足够负载。上界 reference 的吞吐或重复重传类别发生首尾漂移时，不输出候选区间。没有重传上升不能证明不存在 policer；观察到上升也不能归因于服务商。

新报告 schema 为 `dvt.htb-measurement/1`，区分“实验曾临时改变 qdisc”和“结束时已观察到恢复”。`dvt report` 核验摘要并要求有选定端点的 HTB 报告包含 `RESTORED` 证据。中断或恢复失败保留 `INCOMPLETE`；离线报告拒绝把它当完成。输出不提供持久整形推荐，不修改 BDP 输入，不宣称性能或业务验收。

原生回归入口 `sudo bash tests/temporary-htb-check.sh` 只修改测试自己创建的两个 network namespace/veth，运行真实 `tc` 与 iperf3，所有数据流量均留在 runner 内；不得把这一入口的通过写成真实 VPS 已验收。
