# VMISS Basic 200 Mbps：临时 HTB 聚合整形 A/B/A 实验

> 适用脚本：`htb-aggregate-experiment.sh` v0.2.1。v0.1.0 在首次 S4 中于 `start` 后自动回滚，但 SOP 没有捕获 stderr 和左侧流水线退出码，导致实际为根 `fq` 的中段被错误地继续命名为 B1。v0.2.0 的 smoke-test 进一步确认 HTB 运行时配置正确，但其 class JSON 校验只识别 `kind/classid`，没有兼容目标 iproute2 的 `class/handle` 字段，因而误判后安全回滚；同版 SOP 的 `set -e` 又在失败检查时终止了交互 shell。旧归档必须保留为失败证据；不得继续使用 v0.1.0、v0.2.0 或原 `S4-HTB` 目录。

> 实验排程由独立的只读 `experiment-plan.sh` v0.1.0 生成。它只输出 JSON，不读取或修改目标机 qdisc、sysctl、路由、服务或流量。这样可以增加可选复验和低速控制点，而不改变已有真实 smoke/B1 证据所绑定的 v0.2.1 执行脚本哈希。

## 1. 实验目的与边界

本实验验证以下单一命题：

> 在 TCP 参数、业务状态、测试工具和节点逻辑集合不变的条件下，将 VMISS Basic 的总出口从未整形状态限制到 190 Mbit/s，能否减少按出站字节归一化的 TCP 重传，同时保持可接受的吞吐、延迟和 CPU 状态。

它不用于证明商家一定使用 policer，也不以“公网 TCP 重传为 0”为验收目标。

已确认的目标基线：

- Debian 13，内核 `6.12.100+deb13-cloud-amd64`；
- 1 vCPU、967 MiB，服务商套餐上限 200 Mbps；
- IPv4、IPv6 默认路由均为 `eth0`；
- BBR + 根 `fq`；
- `tcp_rmem = 4096 131072 16777216`；
- `tcp_wmem = 4096 65536 16777216`；
- 没有现存 HTB/TBF/class/filter；
- `proxy-vps-fq.service` 管理开机后的根 `fq`；
- S3C～S3F 中，本地 `fq` 丢包为 0；S3F 晚高峰的主机级重传密度显著升高。

实验只修改 `eth0` 的运行时 egress qdisc：

```text
eth0 root HTB 1:
└── class 1:10 rate=190mbit ceil=190mbit
    └── fq 10:
```

不修改 sysctl、路由、防火墙、IPv6 地址、3X-UI/Xray、systemd 持久配置或调优项目状态。HTB 同时约束经 `eth0` 发出的 IPv4 和 IPv6；不处理入口流量。

Linux `HTB` 是基于 token bucket 的出口整形器；`default` 类接收未分类流量。叶子 `fq` 保留本地流的分离和 TCP pacing。`fq maxrate` 是每个 flow 的上限，不是多流共享的总出口上限，因此本实验不采用别人的 `fq maxrate 330mbit` 作为聚合限速器。参见 [tc-htb(8)](https://man7.org/linux/man-pages/man8/tc-htb.8.html)、[tc-fq(8)](https://man7.org/linux/man-pages/man8/tc-fq.8.html) 和 [tc(8)](https://man7.org/linux/man-pages/man8/tc.8.html)。

## 2. 固定实验参数

| 参数 | 值 | 理由 |
|---|---:|---|
| 套餐上限 | 200 Mbps | 项目状态和既有 S3 基线 |
| B1 聚合速率 | 190 Mbit/s | 套餐上限的 95%，先验证小幅留量是否足够 |
| `ceil` | 190 Mbit/s | 禁止从父类借用，保证总出口上限明确 |
| `burst` | 262144 bytes | 约等于 190 Mbit/s 下 11 ms 数据；兼顾 HTB 定时精度和突发抑制 |
| `cburst` | 32768 bytes | 限制以接口速度瞬时释放的 token |
| `quantum` | 15140 bytes | 单类场景下不参与类间公平性，只避免按高 rate/r2q 得到过大的默认 quantum |
| 叶子队列 | `fq` 默认参数 | 保留与 S3 相同的 per-flow pacing，不引入额外 AQM 变量 |
| 自动回滚 | 40 分钟 | 单次 TcpQuality 约 22 分钟，预留状态采集时间 |

190 Mbit/s 不是永久推荐值。只有 B1 完成并分析后，才决定是否需要 180 Mbit/s 的第二速率阶段。

## 3. 状态机和恢复保证

```text
INACTIVE --smoke-test--> ACTIVE(5–30 秒) --> STOPPED(root fq)
INACTIVE --start--> PREPARED --逐阶段 tc replace+拓扑验证+watchdog--> ACTIVE
ACTIVE   --stop-->  STOPPED(root fq)
ACTIVE   --40 min--> STOPPED(root fq)
ACTIVE   --reboot--> proxy-vps-fq.service 恢复 root fq
```

脚本状态只写入 `/run/htb-aggregate-experiment`，不会跨重启持久化。它具有以下保护：

- 只接受 `VERIFIED/debian13-1c1g/200-Mbps` 项目状态；
- 只接受 IPv4/IPv6 默认路由均指向 `eth0`；
- 启动前必须是单一根 `fq`，且没有 class；
- 应用 HTB 后必须匹配 `1:` → `1:10` → `10:fq`；
- `root-htb`、`class-1-10`、`leaf-fq`、`topology-verify`、`watchdog` 和 `state-commit` 分阶段记录；
- 启动失败时先保存 qdisc/class 文本和 JSON，再恢复根 `fq`；
- 自动建立 40 分钟 transient systemd rollback timer；
- 停止前再次验证 boot ID、状态哈希和当前 HTB 拓扑；
- 当前拓扑被其他程序修改时拒绝盲目覆盖；
- 正常停止后恢复为项目管理的根 `fq`。

`tc qdisc replace` 接近原子替换单个节点，但建立 HTB 根、class 和叶子仍是连续操作，切换瞬间可能有极短的数据包扰动。执行前应确认服务商控制台或救援入口可用。

## 4. 更新脚本、预检和短时 smoke-test

把仓库中的 v0.2.1 脚本重新上传到 VPS。不得假定旧文件已被覆盖，安装后必须核对本文发布的 SHA-256：

```bash
install -o root -g root -m 0700 \
  ./htb-aggregate-experiment.sh \
  /usr/local/sbin/htb-aggregate-experiment

bash -n /usr/local/sbin/htb-aggregate-experiment
sha256sum /usr/local/sbin/htb-aggregate-experiment
printf '%s  %s\n' \
  '5b0bd160205f9408514d067e9faeb229f58b800f40e39412b9e221929772ca1a' \
  '/usr/local/sbin/htb-aggregate-experiment' | sha256sum -c -

/usr/local/sbin/htb-aggregate-experiment preflight \
  2>&1 | tee /root/htb-preflight-v021-$(date -u +%Y%m%dT%H%M%SZ).log
```

必须看到：

```text
preflight=PASS interface=eth0 provider_port=200Mbit root=fq
```

任一项不符立即停止，不手工修改主机去迎合门禁。

### 4.1 完整实验前的 10 秒 smoke-test

smoke-test 会应用 190 Mbit/s HTB、执行 ACTIVE 联合门禁、保持 10 秒，然后自动恢复根 `fq`。它不运行 TcpQuality，不替代 A1/B1/A2：

```bash
SMOKE_LOG="/root/htb-smoke-v021-$(date -u +%Y%m%dT%H%M%SZ).log"

run_smoke_gate() (
  set +e
  set -o pipefail

  /usr/local/sbin/htb-aggregate-experiment smoke-test \
    --rate 190 --hold-seconds 10 \
    2>&1 | tee "$SMOKE_LOG"
  SMOKE_RC=${PIPESTATUS[0]}
  set +o pipefail
  printf 'SMOKE_RC=%s\n' "$SMOKE_RC"
  [ "$SMOKE_RC" -eq 0 ] || return 1

  for marker in \
    'start_stage=root-htb action=PASS' \
    'start_stage=class-1-10 action=PASS' \
    'start_stage=leaf-fq action=PASS' \
    'active-check=PASS' \
    'start=PASS' \
    'stop=PASS' \
    'smoke-test=PASS'; do
    grep -Fq "$marker" "$SMOKE_LOG" || return 1
  done

  set -o pipefail
  /usr/local/sbin/htb-aggregate-experiment preflight \
    2>&1 | tee -a "$SMOKE_LOG"
  PREFLIGHT_RC=${PIPESTATUS[0]}
  set +o pipefail
  [ "$PREFLIGHT_RC" -eq 0 ] || return 1
  grep -Fq 'preflight=PASS' "$SMOKE_LOG" || return 1

  cp -a /run/htb-aggregate-experiment/start-trace.log \
    "/root/htb-smoke-start-trace-v021-$(date -u +%Y%m%dT%H%M%SZ).log" || return 1
)

if run_smoke_gate; then
  SMOKE_GATE_RC=0
  printf 'SMOKE_GATE=PASS log=%s\n' "$SMOKE_LOG"
else
  SMOKE_GATE_RC=$?
  printf 'SMOKE_GATE=FAIL rc=%s log=%s；不要进入 A1。\n' \
    "$SMOKE_GATE_RC" "$SMOKE_LOG" >&2
fi
```

必须同时看到：

```text
start_stage=root-htb action=PASS
start_stage=class-1-10 action=PASS
start_stage=leaf-fq action=PASS
active-check=PASS ... rate=190Mbit root=htb class=1:10 leaf=fq watchdog=active
start=PASS ... aggregate_rate=190Mbit
stop=PASS ... restored=root-fq
smoke-test=PASS ... restored=root-fq
preflight=PASS ... root=fq
SMOKE_RC=0
SMOKE_GATE=PASS
```

任何一项缺失，都不得进入 A1。保存完整 `$SMOKE_LOG`，并立即保存失败诊断：

```bash
cp -a /run/htb-aggregate-experiment/start-trace.log \
  "/root/htb-start-trace-v021-$(date -u +%Y%m%dT%H%M%SZ).log" 2>/dev/null || true
cp -a /run/htb-aggregate-experiment/failure-qdisc.json \
  "/root/htb-failure-qdisc-v021-$(date -u +%Y%m%dT%H%M%SZ).json" 2>/dev/null || true
cp -a /run/htb-aggregate-experiment/failure-class.json \
  "/root/htb-failure-class-v021-$(date -u +%Y%m%dT%H%M%SZ).json" 2>/dev/null || true
/usr/local/sbin/htb-aggregate-experiment status 2>&1 | tee -a "$SMOKE_LOG"
```

### 4.2 生成并冻结实验排程

排程生成器不执行测试和系统变更。默认生成两个相反顺序的周期：首个窗口为 `A1 → B1 → A2`，第二个可比窗口为 `B2 → A3 → B3`；每个 stage 仍只运行一次测量，重复来自不同窗口和相反顺序，避免把同窗紧邻运行误当成独立样本。

```bash
PLAN_TOOL=/root/debian-vps-tuning-v0.1.0-rc.12-local/experiments/htb-aggregate/experiment-plan.sh
EVIDENCE_PARENT=/root/rc11-vmiss-basic-evidence/S4-HTB-attempt2
PLAN_JSON="${EVIDENCE_PARENT}/experiment-plan-190.json"

bash -n "$PLAN_TOOL"
mkdir -p "$EVIDENCE_PARENT"
sha256sum "$PLAN_TOOL" | tee "${PLAN_JSON}.tool.sha256"
bash "$PLAN_TOOL" \
  --candidate-rate 190 \
  --repeat-cycles 2 \
  --cooldown-seconds 300 \
  --control-rate none >"${PLAN_JSON}.tmp"
jq -e '
  .mode == "read-only-plan" and
  (.plan_tool_sha256 | test("^[0-9a-f]{64}$")) and
  .candidate.rate_mbit == 190 and
  .candidate.repeat_cycles == 2 and
  (.candidate.stages | length) == 6 and
  .controls.minimum_cooldown_seconds == 300 and
  .controls.automatic_execution == false and
  .controls.persistent_shaping_authorized == false
' "${PLAN_JSON}.tmp" >/dev/null
chmod 0600 "${PLAN_JSON}.tmp"
mv -f "${PLAN_JSON}.tmp" "$PLAN_JSON"
sha256sum "$PLAN_JSON" | tee "${PLAN_JSON}.sha256"
```

如果本次只获准完成首个 A/B/A 窗口，显式使用 `--repeat-cycles 1`。这只会缩短排程，不会降低 A2 的必要性。`repeat-cycles=2` 也不授权自动进入第二窗口：只有首个窗口数据完整、归档哈希通过、节点漂移可接受并完成分析后，才能在另一天进入反向周期。

计划 JSON 是控制输入，不是执行器。必须由操作者逐段执行本文门禁；不得根据 JSON 自动循环调用 `start`、TcpQuality 或 `stop`。

## 5. 首个晚高峰窗口 A1 → B1 → A2

建议在北京时间约 20:40 开始，整个序列保持没有 3X-UI 业务流量、下载、备份或系统更新。每一段只运行一次 TcpQuality，避免原先连续三轮和 60 秒间隔带来的顺序混杂。

以下固定变量沿用 S3C～S3F。执行前重新核对本地文件和固定依赖哈希；不要直接信任旧会话中的哈希。

```bash
HARNESS=/root/debian-vps-tuning-v0.1.0-rc.12-local/tcpquality-evidence.sh
PIN_DIR=/root/rc11-vmiss-basic-evidence/tcpquality-pinned-5d1f85a6b8916b73ec0389dbc9b4ed4aa27dae01
EVIDENCE_PARENT=/root/rc11-vmiss-basic-evidence/S4-HTB-attempt2
COMMIT=5d1f85a6b8916b73ec0389dbc9b4ed4aa27dae01
ROOTFS_SHA256=db92956873d674e65a573721ec6a3db4995f7cf648f61954380e0bfa53ce71a1

test -x "$HARNESS"
test -d "$PIN_DIR"
sha256sum "$HARNESS"
(cd "$PIN_DIR" && sha256sum -c SHA256SUMS)
mkdir -p "$EVIDENCE_PARENT"
```

### 5.1 空闲门禁

每段开始前执行：

```bash
date -Is
uptime
pgrep -af 'runTcpQuality|zstatic|nping' || true
ss -Htan state established | wc -l
tc -s -d qdisc show dev eth0
tc -s -d class show dev eth0
```

开始条件：

- 没有 TcpQuality/nping 残留进程；
- 没有已知大流量业务；
- `load1` 接近当前空闲基线，建议不高于 `0.20`；
- 上一段结束至少 5 分钟；
- A1/A2 是根 `fq`，B1 是经过脚本验证的 HTB 拓扑。

### 5.2 通用单次采集函数

```bash
run_one_block() (
  local block="$1" evidence_dir launcher runner_rc
  evidence_dir="${EVIDENCE_PARENT}/${block}"
  launcher="${EVIDENCE_PARENT}/${block}.launcher.log"
  test ! -e "$evidence_dir" || {
    printf 'evidence directory exists: %s\n' "$evidence_dir" >&2
    return 1
  }

  set +e
  env \
    TCPQUALITY_PIN_DIR="$PIN_DIR" \
    TCPQUALITY_EVIDENCE_DIR="$evidence_dir" \
    TCPQUALITY_COMMIT="$COMMIT" \
    TCPQUALITY_ROOTFS_SHA256="$ROOTFS_SHA256" \
    TCPQUALITY_RUNS=1 \
    TCPQUALITY_DELAY_SECONDS=300 \
    TCPQUALITY_COUNT=30 \
    TCPQUALITY_PACKET_SIZE=0 \
    TCPQUALITY_PARALLEL=16 \
    bash "$HARNESS" 2>&1 | tee "$launcher"
  runner_rc=${PIPESTATUS[0]}
  set -e
  printf 'tcpquality_launcher_exit=%s\n' "$runner_rc" | tee -a "$launcher"
  [ "$runner_rc" -eq 0 ] || return "$runner_rc"
  grep -Fq '[PASS] evidence_dir=' "$launcher"
  test -f "${evidence_dir}/COMPLETED"
  test ! -e "${evidence_dir}/INCOMPLETE"
)
```

`TCPQUALITY_DELAY_SECONDS=300` 对单次运行不会产生轮间等待，只把实验意图写入摘要；真正的段间冷却由人工门禁控制。

### 5.3 A1：无 HTB 基线

```bash
set -o pipefail
/usr/local/sbin/htb-aggregate-experiment preflight 2>&1 | tee "${EVIDENCE_PARENT}/A1-preflight-$(date -u +%Y%m%dT%H%M%SZ).log"
run_one_block "A1-fq-$(date -u +%Y%m%dT%H%M%SZ)"
```

完成后检查 `COMPLETED`、`SHA256SUMS` 和 launcher `[PASS]`。失败则保留 `INCOMPLETE`，停止本晚实验。

### 5.4 B1：190 Mbit/s HTB

先完成至少 5 分钟冷却和空闲门禁，然后定义并执行以下受控函数。函数在独立子 shell 中运行；正常失败、`Ctrl-C`、`TERM` 或 TcpQuality 异常退出都会触发 `EXIT` 清理，并立即尝试恢复根 `fq`。40 分钟 watchdog 只是第二层保护：

```bash
run_b1_htb() (
  set -Eeuo pipefail
  local tag B1_START_LOG B1_BEFORE_LOG B1_AFTER_LOG B1_STOP_LOG B1_TRACE_LOG
  local B1_START_RC B1_CHECK_RC B1_RUN_RC B1_AFTER_RC B1_STOP_RC
  local b1_active=0

  tag="$(date -u +%Y%m%dT%H%M%SZ)"
  B1_START_LOG="${EVIDENCE_PARENT}/B1-htb-start-${tag}.log"
  B1_BEFORE_LOG="${EVIDENCE_PARENT}/B1-htb-before-${tag}.log"
  B1_AFTER_LOG="${EVIDENCE_PARENT}/B1-htb-after-${tag}.log"
  B1_STOP_LOG="${EVIDENCE_PARENT}/B1-htb-stop-${tag}.log"
  B1_TRACE_LOG="${EVIDENCE_PARENT}/B1-htb-start-trace-${tag}.log"

  cleanup_b1() {
    if [ "$b1_active" -eq 1 ]; then
      printf '[B1-CLEANUP] 正在恢复根 fq。\n' >&2
      set +e
      /usr/local/sbin/htb-aggregate-experiment stop \
        2>&1 | tee -a "$B1_STOP_LOG"
      set -e
    fi
  }
  trap cleanup_b1 EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  set +e
  /usr/local/sbin/htb-aggregate-experiment start --rate 190 \
    2>&1 | tee "$B1_START_LOG"
  B1_START_RC=${PIPESTATUS[0]}
  set -e
  if [ "$B1_START_RC" -ne 0 ] || ! grep -Fq 'start=PASS' "$B1_START_LOG"; then
    printf '[B1-FAIL] start_rc=%s；拒绝运行 TcpQuality。\n' "$B1_START_RC" >&2
    /usr/local/sbin/htb-aggregate-experiment status 2>&1 | tee -a "$B1_START_LOG" || true
    return 1
  fi
  b1_active=1
  cp -a /run/htb-aggregate-experiment/start-trace.log "$B1_TRACE_LOG"

  set +e
  /usr/local/sbin/htb-aggregate-experiment assert-active --rate 190 \
    2>&1 | tee "$B1_BEFORE_LOG"
  B1_CHECK_RC=${PIPESTATUS[0]}
  set -e
  if [ "$B1_CHECK_RC" -ne 0 ] || ! grep -Fq 'active-check=PASS' "$B1_BEFORE_LOG"; then
    printf '[B1-FAIL] ACTIVE 前置门禁失败；拒绝运行 TcpQuality。\n' >&2
    return 1
  fi
  /usr/local/sbin/htb-aggregate-experiment status \
    2>&1 | tee -a "$B1_BEFORE_LOG"

  set +e
  run_one_block "B1-htb190-${tag}"
  B1_RUN_RC=$?
  set -e
  if [ "$B1_RUN_RC" -ne 0 ]; then
    printf '[B1-FAIL] TcpQuality exit=%s；立即恢复 fq。\n' "$B1_RUN_RC" >&2
    return "$B1_RUN_RC"
  fi

  set +e
  /usr/local/sbin/htb-aggregate-experiment assert-active --rate 190 \
    2>&1 | tee "$B1_AFTER_LOG"
  B1_AFTER_RC=${PIPESTATUS[0]}
  set -e
  if [ "$B1_AFTER_RC" -ne 0 ] || ! grep -Fq 'active-check=PASS' "$B1_AFTER_LOG"; then
    printf '[B1-FAIL] ACTIVE 后置门禁失败；本段不得记为有效 B1。\n' >&2
    return 1
  fi
  /usr/local/sbin/htb-aggregate-experiment status \
    2>&1 | tee -a "$B1_AFTER_LOG"

  set +e
  /usr/local/sbin/htb-aggregate-experiment stop 2>&1 | tee "$B1_STOP_LOG"
  B1_STOP_RC=${PIPESTATUS[0]}
  set -e
  [ "$B1_STOP_RC" -eq 0 ]
  b1_active=0
  grep -Fq 'stop=PASS' "$B1_STOP_LOG"
  grep -Fq 'state=INACTIVE' "$B1_STOP_LOG"
  grep -Fq 'qdisc fq ' "$B1_STOP_LOG"
  if grep -Fq 'class htb ' "$B1_STOP_LOG"; then
    printf '[B1-FAIL] stop 后仍存在 HTB class。\n' >&2
    return 1
  fi

  trap - EXIT INT TERM
  printf '[B1-PASS] start/ACTIVE-before/TcpQuality/ACTIVE-after/stop 全部门禁通过。\n'
)

set -o pipefail
run_b1_htb
```

启动后应立即确认：

- 根为 `htb 1:`；
- class 为 `1:10`，`rate` 和 `ceil` 都是 190 Mbit/s；
- 叶子为 `fq 10:`；
- watchdog timer 为 `active`；
- SSH 和代理管理连接没有明显异常。

B1 后 `HTB overlimits` 大于 0 表示整形器实际限制过发送，不是丢包；`qdisc drops` 大于 0 则需要作为失败风险记录。

### 5.5 A2：回滚后复验

确认停止输出为 `restored=root-fq`，再完成至少 5 分钟冷却：

```bash
/usr/local/sbin/htb-aggregate-experiment preflight 2>&1 | tee "${EVIDENCE_PARENT}/A2-preflight-$(date -u +%Y%m%dT%H%M%SZ).log"
run_one_block "A2-fq-$(date -u +%Y%m%dT%H%M%SZ)"
```

A2 是必要的。如果 A2 也比 A1 大幅改善，说明测试期间网络路径本身可能转好，不能把 B1 的结果全部归因于 HTB。

### 5.6 可选复验与低速控制点

首个窗口完成并通过完整性检查后，按已冻结计划在另一个可比时段执行反向顺序：

| Stage | qdisc 条件 | 目的 |
|---|---|---|
| B2 | HTB 190 Mbit/s | 把候选条件移到窗口开头，降低顺序偏差 |
| A3 | 根 `fq` | 反向周期中的基线控制 |
| B3 | HTB 190 Mbit/s | 检查候选结果能否在同一窗口回归 |

每段之间仍至少冷却计划中的 `minimum_cooldown_seconds`，并重新执行空闲、进程、默认路由和 qdisc 门禁。不得把 `TCPQUALITY_RUNS` 调大来代替跨窗口复验；紧邻运行共享路径、缓存、负载和时间趋势，不是独立样本。

只有 190 Mbit/s 的 `A1/B1/A2` 和可选 `B2/A3/B3` 已完成归档、比较并关闭结论后，才可以为机制辨别单独生成较低速率控制计划。例如：

```bash
bash "$PLAN_TOOL" \
  --candidate-rate 190 \
  --repeat-cycles 2 \
  --cooldown-seconds 300 \
  --control-rate 180 >"${EVIDENCE_PARENT}/experiment-plan-190-control-180.json"
```

低速控制必须在新的窗口按 `A-control-before → C1-htb-control → A-control-after` 执行。它回答的是“进一步留量是否出现剂量响应”，不是自动推荐 180 Mbit/s，更不授权持久化。不得在同一晚看到 190 结果不理想后立即连续扫描多个速率。

## 6. 立即停止条件

出现以下任一情况，立即停止当前段并保存证据：

- SSH 明显失稳或控制台连接异常；
- HTB 拓扑与脚本预期不符；
- watchdog timer 未 active；
- qdisc 出现持续增长的 drops 或 backlog；
- CPU/load 明显失控，测试进程没有正常退出；
- TcpQuality 失败、CSV 不完整或节点清单无法保存；
- 测试期间出现不可控业务流量；
- IPv4/IPv6 默认接口发生变化；
- 远端节点漂移使 A1/B1/A2 没有可比较的共同集合。

正常回滚：

```bash
/usr/local/sbin/htb-aggregate-experiment stop
```

只有脚本无法运行、且已经确认当前就是本实验的 `htb 1:` 拓扑时，才使用紧急回滚：

```bash
tc qdisc replace dev eth0 root fq
tc -s -d qdisc show dev eth0
tc -s -d class show dev eth0
/usr/local/sbin/htb-aggregate-experiment stop
```

最后一条 `stop` 在看到已经恢复的单一根 `fq` 时不会再次替换队列，只关闭残留状态和自动回滚 timer。若当前既不是实验 HTB，也不是单一根 `fq`，脚本仍会拒绝覆盖。

重启同样会让 `proxy-vps-fq.service` 恢复根 `fq`，但重启不是首选回滚方式。

## 7. 数据验收和判断规则

### 7.1 每段完整性门禁

- `COMPLETED` 存在且 `INCOMPLETE` 不存在；
- `successful_runs=1`、`batch_result=PASS`；
- 内部 `sha256sum -c SHA256SUMS` 通过；
- 恰好一个新 CSV，398 行且状态全部为 `OK`；
- before/after 节点清单和 drift 文件存在；
- 记录测试前后 qdisc/class、`nstat`、链路计数和时间；
- A1/A2 的 qdisc 是根 `fq`；B1 是固定 HTB 拓扑。
- 已保存计划 JSON 及 SHA-256，实际 stage 顺序、速率和冷却时间与计划一致；
- 第二周期存在时，B2/A3/B3 必须使用与第一周期相同的固定 harness、节点逻辑、参数和证据 schema；
- 低速控制存在时，必须有独立 A/C/A 三段，且计划明确 `requires_candidate_result_closed=true`。

### 7.2 主要评价指标

按优先级比较：

1. `TcpRetransSegs delta / qdisc egress GiB`；
2. `TCPFastRetrans`、`TCPLostRetransmit` 增量及其每 GiB 密度；
3. 共同逻辑节点和共同 IP 集合中的 CSV 回程重传分布；
4. 上海联通、广东电信、广东移动、北京电信的变化；
5. 国内回程有效吞吐、中位数和尾部；
6. IPv4 与 IPv6 丢包分别变化；
7. HTB overlimits、qdisc drops/backlog；
8. CPU、softnet dropped/time_squeeze 和 load。

不要把 `TCPSACKReorder` 直接当成真实丢包率；不要把 CSV 重传合计与主机全局计数混为同一统计口径。

### 7.3 初步判定

由于第一晚只有 A1/B1/A2 各一个样本，以下只是进入复验的门槛，不是永久配置验收：

- **候选有效：** B1 的归一化重传密度同时低于 A1、A2，改善幅度约 30% 或以上；主要热点线路方向一致；本地 qdisc drops 为 0；没有异常 CPU/延迟代价。
- **无明显效果：** 重传改善小于约 15%，或只改善单个漂移节点，或 A1/A2 本身差异大于 B1 相对变化。
- **负收益：** B1 重传不降反升，出现 qdisc drops/backlog，或业务吞吐/延迟代价不可接受。
- **不可判定：** 节点漂移过大、网络状态在 A1 到 A2 间单向变化、数据不完整或存在背景负载。

候选有效后，应换一天执行计划中的反向顺序 `B2 → A3 → B3`，降低测试顺序偏差。只有跨日、双顺序结果一致，才讨论是否做 190 Mbit/s 持久化。190 无效但没有负收益时，先分析并关闭 190 的证据，再决定是否另建 `A → C(180) → A` 控制窗口；不能在同一晚连续试多个速率直到偶然得到理想结果。

## 8. 打包与回传

```bash
cd /root/rc11-vmiss-basic-evidence
test -d S4-HTB-attempt2
tar -czf "S4-HTB-attempt2-$(date -u +%Y%m%dT%H%M%SZ).tar.gz" S4-HTB-attempt2
sha256sum S4-HTB-attempt2-*.tar.gz
```

将归档下载到 Windows 后：

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath '.\S4-HTB-attempt2-<UTC时间>.tar.gz'
```

Windows 与 VPS 的 SHA-256 必须一致。归档应包含冻结的计划 JSON 及其哈希、已执行 stage 的证据目录、A 段 preflight，以及每个 HTB 段的 start/before/after/stop 日志。首个窗口至少包含 A1、B1、A2；只有实际执行后才加入 B2/A3/B3 或低速控制材料。不得覆盖或删除首个失败的 `S4-HTB` 归档；不要在确认 attempt2 归档完整和哈希一致前删除 VPS 端证据。
