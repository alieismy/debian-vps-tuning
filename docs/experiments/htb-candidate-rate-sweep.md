# HTB200 参考筛查与候选聚合速率发现 SOP

状态：实验性、非发布资产、非持久化。

适用基线：Debian 13、`debian13-1c1g`/`debian13-1c2g`、rc.12 schema 4、
`VERIFIED`、200 Mbps、静态根 `fq`。

目标：先用重复 HTB200 reference 判断额定端口附近的测量与重传是否稳定；只有人工确认仍需
降低速率时，再以相同 `HTB + fq` 拓扑扫描 180/190/195 Mbit/s，并形成受限的人工复核
shortlist。

不证明：服务商存在 policer、代理业务改善、shortlist 是最优速率，或应建立持久化 HTB。

执行顺序：**本 SOP 是当前实验入口。** 未先完成本文的 HTB200 reference，且在必要时完成
candidate sweep 并人工冻结一个候选速率，不得开始
[VMISS 1C2G / 200 Mbps 临时 HTB A/B/A 实验](vmiss-1c2g-200mbps-htb-aba.md)。

本流程吸收 tcpfit v0.5.6 固定 commit
`67c0bdfb35dd98e86982600298237b6ecc08ebe4` 中“临时 HTB 聚合整形、重复采样疑似速率”的
思路，但不使用其固定 MSS `loss_pct`、固定重传阈值、全量 sysctl、`initcwnd 32`、超大
`fq` 队列或扫描后自动持久化。吞吐主指标使用经过窗口校验的 iperf3 sender Mbit/s；
receiver goodput 只作交叉核对。

## 1. 工具与两阶段边界

- `rate-sweep-plan.sh`：只输出 schema 2 JSON；不读取目标机、不执行流量、不改 qdisc。
- `rate-sweep-run.sh`：经用户显式调用后产生高带宽上传流量；每个 reference/candidate 阶段
  都临时执行 `HTB rate=ceil=<rate> + fq`，状态切换委托 v0.4.0 HTB 执行器。
- `rate-sweep-analyze.sh`：只读解析已完成证据，输出 `REVIEW_REQUIRED` 或
  `REVIEW_BLOCKED`；不写系统状态，也不授权持久化。

流程分为两个相互独立的证据目录：

1. 默认 `reference-screen`：3 个 HTB200 样本，只回答“额定 200 Mbit/s 下是否已足够稳定，
   以及测量窗口是否可信”。默认 payload 上界约 0.91 GiB。
2. 显式 `candidate-sweep`：HTB200 起始 reference 3 个样本、180/190/195 正反序各 3 轮、
   HTB200 结束 reference 3 个样本，共 15 个 benchmark；默认 payload 上界约 4.38 GiB。

预算按各阶段实际 HTB class rate/ceil 计算。`BENCHMARK_RATE_CAP_MBPS` 仍只负责把同一预算
写入 benchmark metadata；真正的阶段流量上限来自 HTB，不是 iperf3 pacing。两种模式都不再
把无限速根 `fq` 当作对照数据，因此候选之间除 rate/ceil 外保持相同 qdisc 拓扑。

## 2. 开始门禁

只有全部满足才继续：

1. 已冻结 rc.12 apply、重启后 verify 和幂等证据；managed state 仍为 schema 4、
   `VERIFIED`、200 Mbps，profile 为 `debian13-1c1g` 或 `debian13-1c2g`。
2. v0.4.0 `htb-aggregate-experiment` 已按对应 SOP 完成固定 hash 校验、preflight 和
   10 秒 smoke-test；当前工具 SHA-256 以仓库和上传时现场计算结果为准。
3. 当前不存在 `/run/htb-aggregate-experiment/active.json`，根 qdisc 是单一 `fq`。
4. 已安装 `iperf3` 和 `jq`；脚本不会自动安装软件。
5. 已获得一个固定、明确授权的 iperf3 服务端；同一阶段固定 host、port、地址族和版本。
6. 扫描期间没有 apt/dpkg、备份、更新、TcpQuality、其他测速或可观察到的业务高峰。
7. 服务商剩余流量足以覆盖计划预算、协议开销、失败重试和实际计费口径。
8. 服务商控制台可用，已准备紧急命令 `tc qdisc replace dev eth0 root fq`，但只在受管
   `stop` 失败且已保存现场后使用。

任何一项不满足都停止。不要通过删除 `active.json` 绕过执行器的状态门禁。

### 2.1 固定本轮 iperf3 endpoint

本轮使用之前已成功建立 iperf3 会话的洛杉矶测试点 `lax.speedtest.is.cc:5209`。它是第三方
公共服务，之前可连接不保证当前仍可用、空闲或允许长时间测试；开始前仍应确认其当前使用
规则。不要硬编码以前解析到的 IP。先解析一次 IPv4，把结果冻结到 root-only JSON；后续
reference 和 candidate 必须读取同一文件，不得重新解析后静默换节点：

```bash
IPERF_DNS='lax.speedtest.is.cc'
IPERF_PORT=5209
IPERF_HOST="$(
  getent ahostsv4 "$IPERF_DNS" |
    awk '$2 == "STREAM" {print $1; exit}'
)"

test -n "$IPERF_HOST"
[[ "$IPERF_HOST" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
ip -4 route get "$IPERF_HOST"

ENDPOINT_FILE='/root/htb-iperf-endpoint.json'
ENDPOINT_TMP="${ENDPOINT_FILE}.tmp"
test ! -e "$ENDPOINT_FILE"
test ! -e "$ENDPOINT_TMP"

jq -n \
  --arg dns "$IPERF_DNS" \
  --arg ipv4 "$IPERF_HOST" \
  --argjson port "$IPERF_PORT" \
  --arg resolved_utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{schema_version:1,dns:$dns,ipv4:$ipv4,port:$port,
    family:4,resolved_utc:$resolved_utc}' >"$ENDPOINT_TMP"
chmod 0600 "$ENDPOINT_TMP"
mv -f -- "$ENDPOINT_TMP" "$ENDPOINT_FILE"

jq . "$ENDPOINT_FILE"
```

若 `getent` 无结果、路由源地址/接口异常，或该 IP 无法建立 iperf3 会话，停止并保留现场；
不得在已经开始的序列中临时改用另一个服务端。runner 的 `session-meta.json` 会记录实际传入的
IP/port；root-only endpoint JSON 另行保留 DNS 和解析时间。二者都不能自动证明第三方服务
稳定或获得了持久使用授权。

## 3. 安装并固定实验工具

在仓库目录确认工作树和工具内容后，将四个实验脚本上传到目标机。目标机执行：

```bash
install -o root -g root -m 0755 \
  /root/debian-vps-tuning/experiments/htb-aggregate/rate-sweep-plan.sh \
  /root/rate-sweep-plan.sh
install -o root -g root -m 0755 \
  /root/debian-vps-tuning/experiments/htb-aggregate/rate-sweep-run.sh \
  /root/rate-sweep-run.sh
install -o root -g root -m 0755 \
  /root/debian-vps-tuning/experiments/htb-aggregate/rate-sweep-analyze.sh \
  /root/rate-sweep-analyze.sh

bash -n /root/rate-sweep-plan.sh
bash -n /root/rate-sweep-run.sh
bash -n /root/rate-sweep-analyze.sh
sha256sum \
  /root/rate-sweep-plan.sh \
  /root/rate-sweep-run.sh \
  /root/rate-sweep-analyze.sh \
  /usr/local/sbin/htb-aggregate-experiment \
  /root/debian13-1c2g-vps-tuning.sh
```

实际 profile 路径按目标机调整，但必须是与管理状态相符、固定 hash、root 所有且不能被
group/world 写入的 rc.12 standalone profile。不要使用可变分支 URL 直接执行脚本。

## 4. 阶段一：生成 HTB200 reference 计划

```bash
REF_PLAN='/root/htb200-reference-plan.json'
REF_PLAN_TMP="${REF_PLAN}.tmp"

/root/rate-sweep-plan.sh \
  --mode reference-screen \
  --port-rate 200 \
  --samples-per-state 3 \
  --cooldown-seconds 300 \
  --benchmark-seconds 10 \
  --omit-seconds 3 \
  --parallel 1 \
  --family 4 >"$REF_PLAN_TMP"

jq -e '
  .schema_version == 2 and
  .mode == "reference-screen" and
  .scope.provider_port_mbit == 200 and
  .reference_rate_mbit == 200 and
  .rates_mbit == [] and
  .traffic_budget.enforced_by == "htb-class-rate-and-ceil" and
  (.stages | length) == 3 and
  all(.stages[];
    .condition == "reference-htb" and
    .rate_mbit == 200 and
    .rate_cap_mbit == 200 and
    .traffic_cap_enforced_by == "htb-class-rate-and-ceil")
' "$REF_PLAN_TMP" >/dev/null
chmod 0600 "$REF_PLAN_TMP"
mv -f -- "$REF_PLAN_TMP" "$REF_PLAN"
sha256sum "$REF_PLAN"
jq '{mode,reference_rate_mbit,benchmark,controls,traffic_budget,stages}' "$REF_PLAN"
```

`reference-screen` 不接受 `--rates`。这是故意设置的门禁，防止“先做参考筛查”和“已经批准
低速候选扫描”被合并成一次隐式授权。

## 5. 阶段一：执行与判读

输出目录必须不存在，父目录必须是非符号链接的真实目录。先从冻结文件读取 endpoint：

```bash
ENDPOINT_FILE='/root/htb-iperf-endpoint.json'
IPERF_HOST="$(jq -er '.ipv4' "$ENDPOINT_FILE")"
IPERF_PORT="$(jq -er '.port' "$ENDPOINT_FILE")"
ip -4 route get "$IPERF_HOST"

REF_DIR="/root/htb200-reference-$(date -u +%Y%m%dT%H%M%SZ)"

/root/rate-sweep-run.sh \
  --plan "$REF_PLAN" \
  --output-dir "$REF_DIR" \
  --tuning-script /root/debian13-1c2g-vps-tuning.sh \
  --htb-tool /usr/local/sbin/htb-aggregate-experiment \
  --analyzer /root/rate-sweep-analyze.sh \
  --host "$IPERF_HOST" \
  --port "$IPERF_PORT"
```

每个阶段都执行同一链路：

```text
root-fq preflight
→ HTB start (rate=ceil=200)
→ assert-active
→ profile benchmark upload
→ assert-active
→ HTB stop
→ root-fq postflight
```

完成后检查：

```bash
test -f "$REF_DIR/COMPLETED"
test ! -e "$REF_DIR/INCOMPLETE"
(cd "$REF_DIR" && sha256sum -c SHA256SUMS)

jq '{status,measurement_gate,metric_contract,reference,
     review_shortlist,required_manual_review,next_gate,traffic_budget}' \
  "$REF_DIR/sweep-analysis.json"
```

阶段一停止条件：

- `status == "REVIEW_BLOCKED"`：保存证据，不运行候选扫描。先核对
  `measurement_gate.invalid_samples` 和原始 iperf3 JSON；新建证据目录重测，禁止原目录覆盖。
- `status == "REVIEW_REQUIRED"` 且 HTB200 的 sender 吞吐、`retransmits_per_gib`、CPU、
  softnet、接口和 qdisc 证据可接受：停止，不因“预先计划过 180/190/195”而继续。
- `status == "REVIEW_REQUIRED"`，测量有效但 HTB200 重传反复偏高，且没有 CPU steal、
  softnet drop、接口错误、服务端漂移等更强替代解释：记录人工授权后，才进入阶段二。

## 6. 阶段二：生成并执行 180/190/195 候选扫描

阶段二必须使用新的计划和输出目录：

```bash
ENDPOINT_FILE='/root/htb-iperf-endpoint.json'
IPERF_HOST="$(jq -er '.ipv4' "$ENDPOINT_FILE")"
IPERF_PORT="$(jq -er '.port' "$ENDPOINT_FILE")"
ip -4 route get "$IPERF_HOST"

SWEEP_PLAN='/root/htb-candidate-180-190-195-plan.json'
SWEEP_PLAN_TMP="${SWEEP_PLAN}.tmp"

/root/rate-sweep-plan.sh \
  --mode candidate-sweep \
  --port-rate 200 \
  --rates 180,190,195 \
  --samples-per-state 3 \
  --cooldown-seconds 300 \
  --benchmark-seconds 10 \
  --omit-seconds 3 \
  --parallel 1 \
  --family 4 >"$SWEEP_PLAN_TMP"

jq -e '
  .schema_version == 2 and
  .mode == "candidate-sweep" and
  .reference_rate_mbit == 200 and
  .rates_mbit == [180,190,195] and
  .traffic_budget.enforced_by == "htb-class-rate-and-ceil" and
  (.stages | length) == 15 and
  all(.stages[];
    .rate_cap_mbit == .rate_mbit and
    .traffic_cap_enforced_by == "htb-class-rate-and-ceil")
' "$SWEEP_PLAN_TMP" >/dev/null
chmod 0600 "$SWEEP_PLAN_TMP"
mv -f -- "$SWEEP_PLAN_TMP" "$SWEEP_PLAN"
sha256sum "$SWEEP_PLAN"
jq '{mode,rates_mbit,benchmark,controls,traffic_budget,stages}' "$SWEEP_PLAN"

SWEEP_DIR="/root/htb-candidate-180-190-195-$(date -u +%Y%m%dT%H%M%SZ)"

/root/rate-sweep-run.sh \
  --plan "$SWEEP_PLAN" \
  --output-dir "$SWEEP_DIR" \
  --tuning-script /root/debian13-1c2g-vps-tuning.sh \
  --htb-tool /usr/local/sbin/htb-aggregate-experiment \
  --analyzer /root/rate-sweep-analyze.sh \
  --host "$IPERF_HOST" \
  --port "$IPERF_PORT"
```

计划生成器只接受 200 Mbps provider port；reference 固定为 200，candidate 只接受 3–8 个
唯一的 100–199 Mbit/s 整数。这不是通用 VPS 限速器；其他端口需要先扩展执行器的
profile/state/端口门禁和目标机 fixture，不能只放宽一个数字校验。

## 7. 中断或失败处理

任意 benchmark、ACTIVE gate、stop、postflight、子证据 manifest 或最终 manifest 失败都会
保留 `INCOMPLETE`，后续阶段不再执行。收到 `INT`/`TERM` 或普通错误退出时，runner 只在
它自己已启动 HTB 时尝试受管 `stop`。先保存证据，再检查状态：

```bash
test -e /run/htb-aggregate-experiment/active.json && \
  cp -a /run/htb-aggregate-experiment \
    "/root/htb-rate-sweep-runtime-failure-$(date -u +%Y%m%dT%H%M%SZ)"

/usr/local/sbin/htb-aggregate-experiment status || true
tc -j -s -d qdisc show dev eth0 | jq .
tc -j -s -d class show dev eth0 | jq .
```

若受管 state 和 managed-state 绑定仍有效，优先执行：

```bash
/usr/local/sbin/htb-aggregate-experiment stop
/usr/local/sbin/htb-aggregate-experiment preflight
```

只有 `stop` 无法执行且服务商控制台仍可用时，才根据现场使用：

```bash
tc qdisc replace dev eth0 root fq
tc -s -d qdisc show dev eth0
```

手工恢复根 `fq` 只恢复数据面，不会修复或删除受管 state。不要把“SSH 仍可连接”当作状态
和证据已经一致。

## 8. 候选结果检查

```bash
test -f "$SWEEP_DIR/COMPLETED"
test ! -e "$SWEEP_DIR/INCOMPLETE"
(cd "$SWEEP_DIR" && sha256sum -c SHA256SUMS)

jq '{status,measurement_gate,metric_contract,reference,rates,review_shortlist,
     required_manual_review,next_gate,interpretation,traffic_budget}' \
  "$SWEEP_DIR/sweep-analysis.json"

/root/rate-sweep-analyze.sh "$SWEEP_DIR" \
  >"/root/htb-candidate-analysis-recheck.json"
```

任何样本窗口无效时，分析器保留原始报告值但输出 `REVIEW_BLOCKED`，并强制
`review_shortlist.rate_mbit == null`。不得删除坏样本后继续排名。

窗口全部有效且首尾 HTB200 reference 的 sender Mbit/s 与 sender retransmits/GiB 的
median±MAD 区间均重叠时，每个候选仅获得以下描述性 flags：

- sender retransmits/GiB 的候选离散上界低于 HTB200 reference 离散下界；
- sender Mbit/s 位于本轮最佳候选的观察离散范围内；
- 所有 receiver 测量窗口通过校验；
- 所有本地 active qdisc drop 样本为 0。

`review_shortlist.rate_mbit` 只是同时满足这些条件的最高候选速率，不是显著性检验或生产
建议。MAD 为 0、样本很少、reference 漂移、公共服务端负载或背景流量都可能使 shortlist
为空或产生误导。必须逐项复核原始 iperf3 JSON、sender/host-wide 重传、CPU
softirq/steal、softnet、接口、qdisc backlog/requeues、地址族、路由、endpoint 和工具 hash。

每阶段的 `socket-metrics.txt` 在 benchmark 窗口内按秒采样
`ss -tinH state established`，但只保留 `rtt`、`rto`、`mss`、`cwnd`、`ssthresh`、
`bytes_retrans`、`retrans`、`reordering`、`rwnd_limited`、`sndbuf_limited` 等白名单
TCP_INFO token。它不会写入 socket header、源/目的地址、端口、PID、进程名或 inode；指标
仍可能包含同机背景 TCP 连接，只用于辅助归因，不是 iperf3 流级唯一标识。

`qdisc overlimits` 证明 HTB 在执行整形，不等于丢包；本地 qdisc drop 为 0 也不能排除下游
policer、宿主 vSwitch 或远端路径丢包。分析器不使用固定 MSS，不计算 packet loss
percentage，也不使用固定 `0.1%` 一类全局重传阈值。

## 9. 后续门禁

只有人工复核确认候选扫描有效，才把一个 shortlist 速率冻结为候选并使用现有
`experiment-plan.sh` 生成独立正式 A/B/A：

```text
A1 fq → B1 HTB candidate → A2 fq
另一个可比窗口：B2 HTB candidate → A3 fq → B3 HTB candidate
```

这里的正式 A/B/A 仍回答“部署 HTB 相对静态根 fq 是否改善”，因此与前置的同拓扑速率发现
不是同一个实验问题。它必须固定 endpoint、工具 hash、地址族、方向、参数和可比较时间窗。
候选速率验证通过前不测试 `burst/cburst`；速率结论关闭后，若仍有证据指向微突发，再固定
rate 单独比较当前 `burst/cburst` 与约 4 ms 候选。reference screen、candidate sweep、
A/B/A 或 burst 实验均不自动授权持久化 HTB。

## 10. 隐私边界

证据包含用户提供的 iperf3 host、时间、boot ID、run ID、profile、脚本 hash、路由和接口
计数。`socket-metrics.txt` 不含 endpoint/process 字段，但不能据此跳过整个证据目录的脱敏。
对外共享前必须脱敏可反查的主机、地址、时间和服务端信息，同时保留工具版本、hash、速率、
地址族、样本顺序和指标口径。原始证据目录保持 root-only，不放入公共 Git 仓库。
