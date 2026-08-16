# VMISS 1C2G / 200 Mbps 临时 HTB A/B/A 实验 SOP

状态：待目标机执行  
适用版本：`debian-vps-tuning 0.1.0-rc.12`、HTB 执行器 `0.3.0`  
目标：比较根 `fq` 基线（A）与 `HTB 190 Mbit/s + fq` 聚合整形（B）对吞吐、重传和时延的影响。  
边界：只改变 `eth0` 出站 qdisc；不改 sysctl、路由、防火墙、代理服务或持久化配置。

## 1. 已冻结基线与证据边界

本 SOP 只适用于已经完成 rc.12 生命周期验证的以下目标类别：

- Debian 13.6（trixie），Linux `6.12.101+deb13-cloud-amd64`，KVM；
- 1 vCPU、约 1974 MiB RAM、15 GB ext4；
- 套餐上限 200 Mbps，默认路由接口唯一且为 `eth0`；
- `/var/lib/proxy-vps-tuning/state.json` 为 schema 4、`VERIFIED`、
  `script_version=0.1.0-rc.12`、`profile.id=debian13-1c2g`、
  `network.port_speed_mbps=200`；
- 运行态为 BBR、根 `fq`、`tcp_rmem=4096 131072 16777216`、
  `tcp_wmem=4096 65536 16777216`，且 `proxy-vps-fq.service` active。

冻结证据证明调优基线已经持久化并通过重启后验证与幂等复核；它不证明 HTB 实验、TcpQuality、代理业务或 190 Mbit/s 候选已经通过。不得把旧 1C1G SOP 的 v0.2.1 日志、哈希或结果并入本轮证据。

## 2. 强制停止条件

满足任一条件立即停止本轮；若 B 阶段已启动，先执行 `htb-aggregate-experiment stop`：

- SSH 不稳定，或没有服务商控制台作为失联恢复入口；
- 活动业务、更新、测速或包管理进程无法冻结；
- state/profile/端口、sysctl、接口或根 qdisc 与第 1 节不一致；
- 执行器哈希不匹配，或 `/run/htb-aggregate-experiment/active.json` 已存在；
- smoke-test 未完整恢复为单一根 `fq`；
- A1、B1、A2 使用了不同测试资产、参数、节点集合或方向；
- B1 的 `assert-active`、watchdog、HTB class 或 `fq` 叶子门禁失败；
- 丢包、时延、CPU、软中断、OOM、业务错误或连接可用性出现不可接受恶化。

`stop` 会验证活动状态与受管 state 的 profile/hash 绑定。若绑定漂移，它会拒绝按旧状态自动覆盖 qdisc；此时保留现场，并从服务商控制台按第 8 节执行人工恢复。

## 3. 安装并校验 v0.3.0 执行器

不要在已有活动实验状态时替换执行器。将仓库中的文件上传到 `/root/htb-aggregate-experiment.sh` 后执行：

```bash
test ! -e /run/htb-aggregate-experiment/active.json
install -o root -g root -m 0755 \
  /root/htb-aggregate-experiment.sh \
  /usr/local/sbin/htb-aggregate-experiment

EXPECTED_HTB_SHA256='12a6552558fcf742b2250402845731d0dfc200f135bc686b0c45d7d032d9ffec'
printf '%s  %s\n' "$EXPECTED_HTB_SHA256" \
  /usr/local/sbin/htb-aggregate-experiment | sha256sum -c -

/usr/local/sbin/htb-aggregate-experiment preflight
```

只有输出同时包含 `profile=debian13-1c2g`、200 Mbit、单一根 `fq` 和 managed-state SHA-256 时才继续。

## 4. 建立独立证据目录并冻结计划

```bash
export EXP_DIR='/root/vmiss-1c2g-htb-evidence/A1-B1-A2-attempt1'
install -d -o root -g root -m 0700 "$EXP_DIR"

bash /root/debian-vps-tuning/experiments/htb-aggregate/experiment-plan.sh \
  --candidate-rate 190 \
  --repeat-cycles 1 \
  --cooldown-seconds 300 \
  --control-rate none >"$EXP_DIR/experiment-plan.json"

jq -e '.mode == "read-only-plan" and
  .candidate.rate_mbit == 190 and
  .candidate.repeat_cycles == 1 and
  (.candidate.stages | map(.label)) == ["A1-fq","B1-htb-candidate","A2-fq"] and
  .controls.minimum_cooldown_seconds == 300' \
  "$EXP_DIR/experiment-plan.json" >/dev/null
```

在开始 A1 前，固定 TcpQuality commit、rootfs SHA-256、节点快照、测试方向、轮数、并发、包长和间隔。任何一个输入不能固定，本轮不得作为受控 A/B/A。

## 5. 10 秒可逆 smoke gate

```bash
run_smoke_gate() (
  set -Eeuo pipefail
  local smoke_log="$EXP_DIR/smoke-test.log" smoke_rc
  set +e
  /usr/local/sbin/htb-aggregate-experiment smoke-test \
    --rate 190 --hold-seconds 10 2>&1 | tee "$smoke_log"
  smoke_rc=${PIPESTATUS[0]}
  set -e
  [ "$smoke_rc" -eq 0 ]
  grep -Fq 'smoke-test=PASS' "$smoke_log"
  /usr/local/sbin/htb-aggregate-experiment preflight \
    >"$EXP_DIR/post-smoke-preflight.log" 2>&1
)

if run_smoke_gate; then
  printf 'SMOKE_GATE=PASS\n'
else
  printf 'SMOKE_GATE=FAIL\n' >&2
  exit 1
fi
```

smoke-test 只证明短时切换、watchdog 和恢复链路通过，不证明性能改善。

## 6. A1/B1/A2 执行函数

先把已冻结参数写成 Bash 数组，例如 `FROZEN_ARGUMENTS=(...)`。以下函数在三个 stage 中复用同一数组；不得在 stage 之间改变参数。

```bash
run_one_block() (
  set -Eeuo pipefail
  local label="$1"
  local block_dir="$EXP_DIR/$label"
  install -d -o root -g root -m 0700 "$block_dir"
  date -u +%Y-%m-%dT%H:%M:%SZ >"$block_dir/start-utc.txt"
  uname -a >"$block_dir/uname.txt"
  uptime >"$block_dir/uptime-before.txt"
  sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc \
    net.ipv4.tcp_rmem net.ipv4.tcp_wmem >"$block_dir/sysctl.txt"
  tc -s -d qdisc show dev eth0 >"$block_dir/qdisc-before.txt"
  tc -s -d class show dev eth0 >"$block_dir/class-before.txt"

  [ "${#FROZEN_ARGUMENTS[@]}" -gt 0 ]
  /root/tcpquality/runTcpQuality "${FROZEN_ARGUMENTS[@]}" \
    >"$block_dir/tcpquality.log" 2>&1

  uptime >"$block_dir/uptime-after.txt"
  tc -s -d qdisc show dev eth0 >"$block_dir/qdisc-after.txt"
  tc -s -d class show dev eth0 >"$block_dir/class-after.txt"
  date -u +%Y-%m-%dT%H:%M:%SZ >"$block_dir/end-utc.txt"
)

run_b1_htb() (
  set -Eeuo pipefail
  local B1_START_LOG="$EXP_DIR/B1-start.log"
  local B1_AFTER_LOG="$EXP_DIR/B1-after.log"
  local b1_active=0
  cleanup_b1() {
    if [ "$b1_active" -eq 1 ]; then
      /usr/local/sbin/htb-aggregate-experiment stop \
        2>&1 | tee -a "$B1_AFTER_LOG" || true
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
  [ "$B1_START_RC" -eq 0 ]
  b1_active=1
  /usr/local/sbin/htb-aggregate-experiment assert-active --rate 190 \
    2>&1 | tee -a "$B1_START_LOG"
  run_one_block B1-htb-candidate
  /usr/local/sbin/htb-aggregate-experiment assert-active --rate 190 \
    2>&1 | tee -a "$B1_AFTER_LOG"
  /usr/local/sbin/htb-aggregate-experiment stop \
    2>&1 | tee -a "$B1_AFTER_LOG"
  b1_active=0
  /usr/local/sbin/htb-aggregate-experiment preflight \
    2>&1 | tee -a "$B1_AFTER_LOG"
  trap - EXIT INT TERM
)
```

执行顺序：

```bash
run_one_block A1-fq
sleep 300
run_b1_htb
sleep 300
run_one_block A2-fq
```

不得因为 B1 看起来较好而跳过 A2。A2 是识别时段、节点和宿主漂移的必要控制点。

## 7. 结果判定

分别比较 A1、B1、A2 的：

- 有效吞吐与单/多流吞吐；
- TCP 重传数、重传率及方向；
- RTT/排队时延的中位数和尾部；
- `tc -s` 的 dropped、overlimits、requeues、backlog；
- CPU、load、软中断、OOM 和业务错误。

只有 A1 与 A2 足够一致，且 B1 的改善超过测量波动、没有引入不可接受副作用，才能认为 190 Mbit/s 候选值得进入另一个可比窗口的反向复验。一次 `A1 → B1 → A2` 不能授权持久化 HTB，也不能直接推出 180 Mbit/s 更优。

## 8. 回退与收尾

正常回退：

```bash
/usr/local/sbin/htb-aggregate-experiment stop
/usr/local/sbin/htb-aggregate-experiment preflight
```

只有在工具因状态漂移拒绝 stop、且已通过服务商控制台确认目标接口仍为 `eth0` 时，才人工恢复：

```bash
tc qdisc replace dev eth0 root fq
tc -s -d qdisc show dev eth0
tc -s -d class show dev eth0
systemctl is-active proxy-vps-fq.service
```

不要手工删除 `/run/htb-aggregate-experiment/active.json`。先保存该文件、`start-trace.log`、qdisc/class 输出和 managed state 哈希，完成事故对账后再决定状态清理。

最终生成证据清单：

```bash
find "$EXP_DIR" -type f -print0 | sort -z | xargs -0 sha256sum \
  >"$EXP_DIR/SHA256SUMS"
chmod -R go-rwx "$EXP_DIR"
```

本 SOP 的仓库静态检查不替代目标 VPS 的 smoke gate、A/B/A 运行或真实业务验收。
