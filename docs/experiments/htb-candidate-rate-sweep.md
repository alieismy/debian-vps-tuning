# HTB 候选聚合速率发现 SOP

状态：实验性、非发布资产、非持久化。  
适用基线：Debian 13、`debian13-1c1g`/`debian13-1c2g`、rc.12 schema 4、`VERIFIED`、200 Mbps、根 `fq`。  
目标：在正式 HTB A/B/A 前，用重复基线和临时 `HTB + fq` 上传测试形成一个人工复核 shortlist。  
不证明：服务商存在 policer、代理业务改善、shortlist 是最优速率，或应建立持久化 HTB。

本流程吸收了 tcpfit v0.5.6 固定 commit
`67c0bdfb35dd98e86982600298237b6ecc08ebe4` 中“临时 HTB 聚合整形、以 receiver goodput
观察有效吞吐、疑似速率重复采样”的思路，但不使用其固定 MSS `loss_pct`、固定重传阈值、
全量 sysctl、`initcwnd 32`、超大 `fq` 队列或扫描后自动持久化。

## 1. 三个工具的效力边界

- `rate-sweep-plan.sh`：只输出 JSON；不读取目标机、不执行流量、不改 qdisc。
- `rate-sweep-run.sh`：经用户显式调用后产生高带宽上传流量，并在候选阶段临时执行
  `HTB rate=ceil=<rate> + fq`；所有状态切换委托现有 v0.3.0 HTB 执行器。
- `rate-sweep-analyze.sh`：只读解析已完成证据，输出描述性统计和人工复核 shortlist；
  不写系统状态，也不授权持久化。

默认计划使用 `150,170,180,190,195` Mbit/s，每个状态 3 个样本，先做 3 个根 `fq`
基线，再用正序/反序轮次交错候选速率，最后重复 3 个根 `fq` 基线。除首阶段外，每阶段至少
冷却 300 秒。默认共 21 个 benchmark；计划 JSON 会给出精确 payload 预算。默认参数的
payload 上界约为 5.84 GiB，不含 TCP/IP、链路层开销，也不等于服务商最终计费流量。

## 2. 开始门禁

只有全部满足才继续：

1. 已冻结 rc.12 apply、重启后 verify 和幂等证据；managed state 仍为 schema 4、
   `VERIFIED`、200 Mbps，profile 为 `debian13-1c1g` 或 `debian13-1c2g`。
2. v0.3.0 `htb-aggregate-experiment` 已按对应 SOP 完成 hash 校验、preflight 和 smoke-test。
3. 当前不存在 `/run/htb-aggregate-experiment/active.json`，根 qdisc 是单一 `fq`。
4. 已安装 `iperf3` 和 `jq`；脚本不会自动安装软件。
5. 已获得一个固定、明确授权的 iperf3 服务端；整个扫描固定 host、port、地址族和版本。
6. 扫描期间没有 apt/dpkg、备份、更新、TcpQuality、其他测速或可观测业务高峰。
7. 服务商剩余流量足以覆盖计划预算、协议开销、失败重试和实际计费口径。
8. 服务商控制台可用，已准备紧急命令 `tc qdisc replace dev eth0 root fq`，但只在受管
   `stop` 失败、已保存现场后使用。

任何一项不满足都停止。不要通过删除 `active.json` 绕过执行器的状态门禁。

## 3. 安装实验工具

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

实际 profile 脚本路径按目标机调整，但必须是与管理状态相符、固定 hash、root 所有且不能被
group/world 写入的 rc.12 standalone profile。不要使用可变分支 URL 直接执行脚本。

## 4. 生成并冻结计划

```bash
PLAN='/root/htb-rate-sweep-plan.json'
PLAN_TMP="${PLAN}.tmp"

/root/rate-sweep-plan.sh \
  --port-rate 200 \
  --rates 150,170,180,190,195 \
  --samples-per-state 3 \
  --cooldown-seconds 300 \
  --benchmark-seconds 10 \
  --omit-seconds 3 \
  --parallel 1 \
  --family 4 >"$PLAN_TMP"

jq -e '
  .mode == "candidate-rate-discovery-plan" and
  .scope.provider_port_mbit == 200 and
  .scope.direction == "upload" and
  .scope.persistent_shaping_authorized == false and
  .controls.automatic_candidate_persistence == false and
  .controls.minimum_cooldown_seconds >= 300 and
  (.stages | length) >= 10
' "$PLAN_TMP" >/dev/null
chmod 0600 "$PLAN_TMP"
mv -f -- "$PLAN_TMP" "$PLAN"
sha256sum "$PLAN"
jq '{rates_mbit,benchmark,controls,traffic_budget,stages}' "$PLAN"
```

计划生成器当前只接受 200 Mbps 和 100–199 Mbit/s 候选。这不是通用 VPS 限速器；其他端口
需要先扩展执行器的 profile/state/端口门禁和目标机 fixture，不能只放宽一个数字校验。

## 5. 执行扫描

把以下占位值替换为实际路径和获授权服务端。输出目录必须不存在，父目录必须是非符号链接
的真实目录：

```bash
SWEEP_DIR="/root/htb-rate-sweep-$(date -u +%Y%m%dT%H%M%SZ)"

/root/rate-sweep-run.sh \
  --plan /root/htb-rate-sweep-plan.json \
  --output-dir "$SWEEP_DIR" \
  --tuning-script /root/debian13-1c2g-vps-tuning.sh \
  --htb-tool /usr/local/sbin/htb-aggregate-experiment \
  --analyzer /root/rate-sweep-analyze.sh \
  --host '<AUTHORIZED_IPERF3_HOST>' \
  --port 5201
```

执行器每个候选阶段依次完成：

```text
root-fq preflight
→ HTB start
→ assert-active
→ profile benchmark upload
→ assert-active
→ HTB stop
→ root-fq postflight
```

基线阶段在 benchmark 前后都执行 root-fq preflight。任意 benchmark、ACTIVE gate、stop、
postflight、子证据 manifest 或最终 manifest 失败都会使扫描保持 `INCOMPLETE`，后续阶段不再
执行。收到 `INT`/`TERM` 或普通错误退出时，runner 只在它自己已启动 HTB 的情况下尝试受管
`stop`。

## 6. 中断或失败处理

先保存证据，再检查状态：

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

## 7. 结果检查

成功结束后：

```bash
test -f "$SWEEP_DIR/COMPLETED"
test ! -e "$SWEEP_DIR/INCOMPLETE"
(
  cd "$SWEEP_DIR"
  sha256sum -c SHA256SUMS
)

jq '{status,metric_contract,baseline,rates,review_shortlist,
     required_manual_review,next_gate,interpretation,traffic_budget}' \
  "$SWEEP_DIR/sweep-analysis.json"

/root/rate-sweep-analyze.sh "$SWEEP_DIR" \
  >"/root/htb-rate-sweep-analysis-recheck.json"
```

`review_shortlist.rate_mbit` 的含义严格限定为：

- 首尾基线的 receiver goodput 与 sender retransmits/GiB 的 median±MAD 区间重叠；
- 该速率的重传统计上界低于基线离散区间下界；
- receiver goodput 位于本轮最佳有效吞吐的观察离散范围内；
- 该速率所有样本的本地 active qdisc drop 都为 0；
- 满足条件的最高速率。

这是故意严格的描述性 shortlist，不是显著性检验或生产建议。MAD 为 0、样本很少、基线漂移、
公共服务端负载或背景流量都可能使 shortlist 为空或产生误导。必须逐项复核原始 iperf3 JSON、
sender/host-wide 重传、CPU softirq/steal、softnet、接口、qdisc backlog/requeues、地址族、路由、
endpoint 和工具 hash。

每个阶段的 `socket-metrics.txt` 在 benchmark 窗口内按秒采样 `ss -tinH state established`，但
只保留 `rtt`、`rto`、`mss`、`cwnd`、`ssthresh`、`bytes_retrans`、`retrans`、`reordering`、
`rwnd_limited`、`sndbuf_limited` 等白名单 TCP_INFO token。它不会写入 socket header、源/目的
地址、端口、PID、进程名或 inode；指标仍可能包含同机背景 TCP 连接，只用于辅助归因，不是
iperf3 流级唯一标识。

`qdisc overlimits` 证明 HTB 在执行整形，不等于丢包；本地 qdisc drop 为 0 也不能排除下游
policer、宿主 vSwitch 或远端路径丢包。分析器不使用固定 MSS，不计算 packet loss percentage，
也不使用固定 `0.1%` 一类全局重传阈值。

## 8. 后续门禁

只有人工复核确认扫描有效，才把 shortlist 冻结为一个候选并使用现有
`experiment-plan.sh` 生成独立：

```text
A1 fq → B1 HTB candidate → A2 fq
另一个可比窗口：B2 HTB candidate → A3 fq → B3 HTB candidate
```

完整 A/B/A 仍需固定 endpoint、工具 hash、地址族、方向、参数和时间窗。候选速率验证通过前
不测试 `burst/cburst`；速率结论关闭后，若仍有证据指向微突发，再固定 rate 单独比较当前
`burst/cburst` 与约 4 ms 候选。扫描、A/B/A 或 burst 实验均不自动授权持久化 HTB。

## 9. 隐私边界

证据包含用户提供的 iperf3 host、时间、boot ID、run ID、profile、脚本 hash、路由和接口
计数。`socket-metrics.txt` 不含 endpoint/process 字段，但不能据此跳过整个证据目录的脱敏。
对外共享前必须脱敏可反查的主机、地址、时间和服务端信息，同时保留工具版本、hash、速率、
地址族、样本顺序和指标口径。原始证据目录保持 root-only，不放入公共 Git 仓库。
