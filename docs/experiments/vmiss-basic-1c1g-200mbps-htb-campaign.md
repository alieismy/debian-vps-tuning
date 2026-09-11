# VMISS Basic 1C1G / 200 Mbps HTB 完整实验 SOP

状态：研究专用协议；默认不执行；本轮 Basic HTB200 reference 已完成并关闭，candidate sweep/A/B/A 未执行
适用版本：当前实现候选为 `debian-vps-tuning 0.1.0-rc.17`、HTB 执行器 `0.4.0`；本文保留的 rc.13 命令块仅作历史协议参考
适用套餐：Debian 13、1 vCPU、约 1 GiB RAM、10 GB 系统盘、200 Mbps 端口、500 GB 月流量

> **效力变更：本文不再是业务 VPS 的升级、发布或日常验收入口。** 历史执行已经证明完整
> TcpQuality/HTB campaign 会消耗远高于普通生命周期验证的流量，且公共路径和时段混杂使
> 边际因果证据有限。只有明确需要验证聚合出口整形机制、改用独立高额度测试机、已授权
> endpoint，并在执行前批准完整硬流量预算和停止条件时，才可重新评审本文。不得在当前
> 配额受限 VMISS Basic 上按本文继续 reference、sweep 或 A/B/A。

2026-09-11 的 Basic 运行已在独立归档中完成三次 HTB200 单流 IPv4 reference：sender 约
187–190 Mbit/s，sender retransmits 和主机级 `TcpRetransSegs` 增量均为 0，HTB root/FQ
leaf drops/requeues 均为 0，HTB root `overlimits` 为正；endpoint closeout 已停止并清理
临时 server/observer unit、TCP/5201 listener、`iperf3` 进程和临时 UFW 规则。该证据只证明
固定 HTB200 reference 的运行与证据完整性，不证明相对默认 `fq` 的因果收益或真实代理业务
改善。由于 reference 已满足停止条件，180/190/195 candidate sweep 不再执行；Core、default-fq
对照、A/B/A 和持久 HTB 均未获授权。

本文后续章节描述的是在未来重新授权时使用的完整研究协议，不构成当前执行指令；其中
历史 rc.13/state 绑定、endpoint 示例和预算表不得直接套用于 rc.17 或任何生产 VPS。

本 SOP 把此前分散的 `HTB200 reference → 180/190/195 candidate sweep → A/B/A → 反向窗口`
合并为一条有阶段门禁的研究链。它只在研究条件获重新批准后作为该类实验入口。
[旧版 VMISS Basic HTB A/B/A 文档](vmiss-basic-200mbps-htb-aba.md)只保留 v0.2.1 历史证据，
不得再用作当前 rc.17 执行说明。

## 1. 结论边界

本实验只检验以下机制假设：在相同 rc.13 sysctl、BBR 和叶子 `fq` 下，把 200 Mbps 出口的
聚合发送速率短时压到略低于服务商端口上限，是否能减少疑似端口 policer、宿主 vSwitch
或上游队列附近的重传，同时保留可接受吞吐。

实验不会证明服务商一定部署了 policer，也不会把公共 iperf3 或 TcpQuality 结果等同于
VLESS + REALITY + TCP 业务体验。即使两个窗口和业务复验均有利，本轮最多支持“候选速率
进入有限、可回退的业务试运行”；**不授权创建开机持久 HTB，不修改 sysctl、路由、防火墙、
3X-UI/Xray 或项目管理状态。**

HTB 仅作用于 `eth0` 出站，包括该接口上的 IPv4 和 IPv6。下载方向的远端 sender 重传不能
归因给本机 egress HTB。`fq maxrate` 是每 flow 上限，不是聚合接口整形，不能替代本实验。
机制语义参见 [tc-htb(8)](https://man7.org/linux/man-pages/man8/tc-htb.8.html) 和
[tc-fq(8)](https://man7.org/linux/man-pages/man8/tc-fq.8.html)。

## 2. 阶段状态机和授权门禁

```text
rc.17 VERIFIED/root fq
  → HTB200 reference（本轮实际 3 样本）
    → 稳定且可接受：停止，不扫描低速率（本轮已关闭）
    → 测量/资源/HTB 暴露无效：停止，诊断后用全新证据目录重来
    → 有效但仍支持继续检验：人工确认
      → 180/190/195 candidate sweep
        → shortlist 为空或证据漂移：停止
        → 人工冻结一个候选
          → 独立 A1/B1/A2 窗口
            → 首窗无效或无改善：停止
            → 首窗有一致信号：另一个可比时段单独生成 B2/A3/B3
              → 两窗不一致：停止或另立新实验
              → 两窗一致：真实 VLESS + REALITY + TCP 临时复验
                → 仅形成有限试运行建议；持久化仍需另行授权
```

每个门禁只授权紧邻的下一步。不能因为整套 SOP 已经存在，就在 reference 结束后自动继续；
也不能把 `--ack-reference-reviewed` 解释为永久整形授权。

## 3. 强制停止与恢复条件

出现任一情况立即停止；若 HTB 已启动，先保留现场，再调用受管 `stop`：

- 没有可用的 VMISS 控制台，或 SSH 已出现异常；
- `/var/lib/proxy-vps-tuning/state.json` 不是 rc.13 schema 4、`VERIFIED`、
  `debian13-1c1g`、200 Mbps；
- 当前接口不是唯一默认出口 `eth0`，或根 qdisc 不是单一 `fq`；
- 调优 profile 的只读 `verify`、HTB preflight、10 秒 smoke 或 SHA-256 任一失败；
- 活动业务、apt/dpkg、备份、更新、TcpQuality、其他测速或磁盘任务不能冻结；
- VMISS 面板剩余流量、计费周期或实际增量不清楚；
- 任一样本测量窗口无效、HTB 未实际暴露、CPU/softnet/接口资源门禁失败；
- watchdog、ACTIVE、stop、root-fq 恢复或证据清单失败；
- 发生 OOM、连接中断、业务错误、异常时延、磁盘逼近保留线或不可接受流量增长。

正常恢复：

```bash
/usr/local/sbin/htb-aggregate-experiment status || true
/usr/local/sbin/htb-aggregate-experiment stop
/usr/local/sbin/htb-aggregate-experiment preflight
```

如果受管 `stop` 因 state/profile/hash 漂移拒绝执行，不要删除
`/run/htb-aggregate-experiment/active.json`。先从 VMISS 控制台保存以下现场：

```bash
cp -a /run/htb-aggregate-experiment \
  "/root/htb-runtime-failure-$(date -u +%Y%m%dT%H%M%SZ)"
sha256sum /var/lib/proxy-vps-tuning/state.json
tc -j -s -d qdisc show dev eth0 | jq .
tc -j -s -d class show dev eth0 | jq .
```

只有已从控制台重新确认接口仍为 `eth0`、且受管恢复确实不可用时，才做数据面应急恢复：

```bash
tc qdisc replace dev eth0 root fq
tc -s -d qdisc show dev eth0
tc -s -d class show dev eth0
systemctl is-active proxy-vps-fq.service
```

该命令只恢复根 `fq`，不会修复受管 runtime state；事故对账完成前不要清理 state 文件。

## 4. 流量、磁盘和维护窗口预算

### 4.1 速率发现预算

默认 `10 s + 3 s omit`、短时 HTB 上限下的 iperf payload 上界为：

| 阶段 | 组成 | payload 上界 | 占 500 GB 套餐 |
|---|---:|---:|---:|
| Basic reference | 5 × HTB200 | 1.625 GB（约 1.51 GiB） | 约 0.33% |
| candidate sweep | 首尾 HTB200 各 3 次，180/190/195 各 3 次 | 4.704375 GB（约 4.38 GiB） | 约 0.94% |
| 一次成功的速率发现合计 | reference + sweep | 6.329375 GB（约 5.89 GiB） | 约 1.27% |

该预算不含 TCP/IP/链路层开销、失败重试、背景业务和服务商计费差异。P1 reference 暴露不足
后每重做一次 P2/P4 reference，最多再增加 1.625 GB payload。每个阶段前后都要在 VMISS 面板
记录剩余流量和实际增量；面板方向或计费口径与本表不一致时，以面板为准并停止扩展实验。

无失败、无人工停顿时，P1 reference 的协议内最短排程约为 21 分钟（4 次 300 秒冷却加
5 × 13 秒测试），candidate sweep 约为 73 分钟（14 次冷却加 15 × 13 秒测试），合计约
94 分钟；profile verify、qdisc 门禁、服务端等待和人工检查会进一步增加时间。不得为压缩
维护窗口缩短 300 秒冷却或并行运行 stage。

### 4.2 TcpQuality 与 10 GB 磁盘边界

历史一次旧版 B1 TcpQuality stage 处理过约 3.389 GB HTB egress；六个正式 stage 粗略外推约
20.3 GB，但这是旧样本，不是当前流量保证。必须按 VMISS 面板逐 stage 校准，不能用该数字
替代当前证据。把该旧样本外推与一次无重试速率发现相加约为 26.7 GB、约占 500 GB 的
5.3%；仍不含协议开销、业务复验、背景业务和失败重试。任一面板实测明显偏离时停止使用
外推值。

rc.13 固定 rootfs 归档本身约 140.7 MB，运行还会生成 CSV、日志和 debug archive。10 GB
系统盘不适合无检查地连续保留多轮证据。本 SOP 采用 2 GiB 可用空间作为每个 TcpQuality
stage 开始前的保守停止线；这是一条运行政策，不是上游空间保证。执行：

```bash
df -PB1 /root
AVAILABLE_BYTES="$(df -PB1 /root | awk 'NR == 2 {print $4}')"
test "$AVAILABLE_BYTES" -ge 2147483648
du -sb /root/tcpquality-pinned-* 2>/dev/null || true
```

A1 完成后用 `du -sb` 记录单 stage 实际大小，据此估算剩余五个 stage；若预计会把可用空间
压到 1 GiB 以下，先把已经闭合且通过 SHA-256 的证据安全移出 VPS，再开始下一窗口。不得
为了腾空间删除唯一一份未回传原始证据。

### 4.3 人工维护门禁

开始前在 VMISS 面板确认并在本地记录：当前 UTC/本地时间、计费周期、500 GB 套餐剩余量、
系统盘占用、控制台可登录、无计划维护。以下目录只存本次实验，不包含账户或面板凭据：

为避免把 `set -e` 留在日常 SSH shell，先在主 shell 中单独运行 `bash --noprofile --norc`，
确认已进入一个本次 campaign 专用的嵌套 Bash，再执行下面和后续代码块。每个代码块单独
执行并检查终态；不要把多个阶段一次性粘贴。专用 shell 中执行：

```bash
set -Eeuo pipefail
umask 077
CAMPAIGN_ROOT="/root/vmiss-basic-htb-campaign-$(date -u +%Y%m%dT%H%M%SZ)"
install -d -o root -g root -m 0700 "$CAMPAIGN_ROOT"
printf 'utc\tstage\tpanel_remaining_gb\tdisk_available_bytes\toperator_note\n' \
  >"$CAMPAIGN_ROOT/operator-gates.tsv"
```

每次运行前后手工追加一行，不把 VMISS 账号、IP、订单号或其他敏感信息写入公共仓库。

## 5. 冻结 rc.13 基线和稳定 HTB 执行器

以下命令假定 rc.13 已通过固定 Release 安装。不要从 `master`、`latest` 或可变 URL 取脚本：

```bash
DVT_BIN='/usr/local/bin/dvt'
DVT_ROOT="$(readlink -f /usr/local/lib/debian-vps-tuning/current)"
STATE_FILE='/var/lib/proxy-vps-tuning/state.json'
HTB_TOOL='/usr/local/sbin/htb-aggregate-experiment'

test -x "$DVT_BIN"
test -d "$DVT_ROOT"
test -f "$DVT_ROOT/SHA256SUMS"
(cd "$DVT_ROOT" && sha256sum -c SHA256SUMS)

jq -e '
  .schema_version == 4 and .script_version == "0.1.0-rc.13" and
  .state == "VERIFIED" and .profile.id == "debian13-1c1g" and
  .network.port_speed_mbps == 200
' "$STATE_FILE" >/dev/null

"$DVT_BIN" verify
ip -4 route show default
ip -6 route show default
tc -j -s -d qdisc show dev eth0 | jq .
tc -j -s -d class show dev eth0 | jq .
```

`dvt htb` 不会在只读 preflight 中隐式安装执行器。确认没有活动实验后，从同一固定 Release
显式安装，并用 Release manifest 反向校验：

```bash
test ! -e /run/htb-aggregate-experiment/active.json
EXPECTED_HTB_SHA256="$(
  awk '$2 == "experiments/htb-aggregate/htb-aggregate-experiment.sh" {print $1}' \
    "$DVT_ROOT/SHA256SUMS"
)"
[[ "$EXPECTED_HTB_SHA256" =~ ^[0-9a-f]{64}$ ]]

install -o root -g root -m 0755 \
  "$DVT_ROOT/experiments/htb-aggregate/htb-aggregate-experiment.sh" \
  "$HTB_TOOL"
printf '%s  %s\n' "$EXPECTED_HTB_SHA256" "$HTB_TOOL" | sha256sum -c -
bash -n "$HTB_TOOL"

"$DVT_BIN" htb preflight
"$DVT_BIN" htb smoke --rate 190 --hold-seconds 10
"$DVT_BIN" htb preflight
```

smoke 只证明短时切换、watchdog 和恢复链路可用，不证明 190 Mbit/s 有性能收益。活动实验期间
禁止替换 `$HTB_TOOL`、`$DVT_ROOT` 或 managed state。

## 6. 固定 InterServer LAX endpoint

InterServer 当前官方 [Speed Test](https://www.interserver.net/speedtest/) 页面（2026-08-21
复核）公开 `lax.speedtest.is.cc` 和 iperf3 端口 `5201–5209`。因此使用 5209 不再要求另取
书面授权作为 blocker，但仍限于短时、有限、合理的共享测试。官方页面变化、服务端拒绝、
繁忙或不稳定时必须停止。

只解析一次 IPv4 并冻结；整个 reference、sweep 和速率发现复核不得静默换 IP、端口或地址族：

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

ENDPOINT_FILE="$CAMPAIGN_ROOT/iperf-endpoint.json"
test ! -e "$ENDPOINT_FILE"
jq -n \
  --arg dns "$IPERF_DNS" \
  --arg ipv4 "$IPERF_HOST" \
  --argjson port "$IPERF_PORT" \
  --arg utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{schema_version:1,dns:$dns,ipv4:$ipv4,port:$port,family:4,resolved_utc:$utc}' \
  >"$ENDPOINT_FILE"
chmod 0600 "$ENDPOINT_FILE"
sha256sum "$ENDPOINT_FILE"
```

若 endpoint 在序列中失效，保留 `INCOMPLETE` 和现场，结束整轮；不得把另一个 IP 的样本拼入
原计划。

## 7. HTB200 reference：Basic 使用 5 个样本

### 7.1 P1 初始 reference

```bash
IPERF_HOST="$(jq -er '.ipv4' "$ENDPOINT_FILE")"
IPERF_PORT="$(jq -er '.port' "$ENDPOINT_FILE")"
RATE_PARALLEL=1
REF_DIR="$CAMPAIGN_ROOT/rate-reference-p1"
test ! -e "$REF_DIR"

"$DVT_BIN" htb reference \
  --host "$IPERF_HOST" \
  --server-port "$IPERF_PORT" \
  --output-dir "$REF_DIR" \
  --samples 5 \
  --cooldown-seconds 300 \
  --seconds 10 \
  --omit 3 \
  --parallel "$RATE_PARALLEL" \
  --family 4 \
  --minimum-rate-exposure-percent 90 \
  --minimum-cpu-idle-percent 5 \
  --maximum-cpu-steal-percent 5
```

完成后先验清单，再看分析：

```bash
test -f "$REF_DIR/COMPLETED"
test ! -e "$REF_DIR/INCOMPLETE"
(cd "$REF_DIR" && sha256sum -c SHA256SUMS)

jq '{schema_version,status,measurement_gate,shaping_exposure_gate,resource_gate,
     reference,review_shortlist,next_gate,traffic_budget}' \
  "$REF_DIR/sweep-analysis.json"

jq -e '
  .schema_version == 3 and .plan_mode == "reference-screen" and
  .status == "REVIEW_REQUIRED" and
  .measurement_gate.valid == true and
  .shaping_exposure_gate.valid == true and
  .resource_gate.valid == true and
  .persistence_authorized == false
' "$REF_DIR/sweep-analysis.json" >/dev/null
```

每个样本必须同时满足：receiver 测量窗口有效、`qdisc_overlimits_delta > 0`、sender goodput
至少达到冻结 rate 的 90%、CPU idle 不低于 5%、CPU steal 不高于 5%、softnet drop 和
time_squeeze 均不增长、接口 drop/error 不增长。`overlimits` 证明 HTB 实际延迟了流量，不是
丢包或重传。

### 7.2 P1 暴露不足时的 P2/P4 重试规则

只有 `measurement_gate.valid == true`、`resource_gate.valid == true`，且唯一失败原因是
`shaping_exposure_gate`，才可以提高 iperf 并发。必须保留 P1，新建完整 P2 reference：

```bash
RATE_PARALLEL=2
REF_DIR="$CAMPAIGN_ROOT/rate-reference-p2"
test ! -e "$REF_DIR"

"$DVT_BIN" htb reference \
  --host "$IPERF_HOST" --server-port "$IPERF_PORT" \
  --output-dir "$REF_DIR" --samples 5 --cooldown-seconds 300 \
  --seconds 10 --omit 3 --parallel "$RATE_PARALLEL" --family 4 \
  --minimum-rate-exposure-percent 90 \
  --minimum-cpu-idle-percent 5 --maximum-cpu-steal-percent 5
```

P2 仍只有 HTB 暴露不足且资源正常时，才能以同样方式建立全新 P4 计划和目录，把
`RATE_PARALLEL=4`、目录名改为 `rate-reference-p4`。不得就地修改 plan、删除失败样本或把
P1/P2/P4 拼成五个“通过样本”。P4 仍不暴露，或任一并发出现 CPU/softnet/interface 异常，
结束速率发现；公共 endpoint 或 1 vCPU 资源不足以支持这个实验设计。

### 7.3 reference 后的人工停止点

reference 全部门禁通过后仍不能自动扫低速率。人工检查原始 iperf3 JSON、sender
`retransmits_per_gib`、host-wide `TcpRetransSegs`、RTT/cwnd、qdisc drops/requeues/backlog、
节点/路由和时间趋势：

- HTB200 已稳定、重传可接受：记录“停止”，保持根 `fq`；这是成功缩小问题，不是失败。
- HTB200 仍反复高重传，但没有 CPU steal、softnet、接口、endpoint 或背景业务等更强解释：
  记录继续决定，才进入 candidate sweep。
- 证据冲突或原因不清：停止并换窗口重做 reference，不进入 sweep。

## 8. 180/190/195 candidate sweep

候选扫描必须使用最终通过的 `$REF_DIR` 和相同 `$RATE_PARALLEL`。以下命令会再次验证 reference
`COMPLETED`、总清单和三类 gate；`--ack-reference-reviewed` 仅表示操作者已经完成上节复核：

```bash
SWEEP_DIR="$CAMPAIGN_ROOT/rate-sweep-180-190-195-p${RATE_PARALLEL}"
test ! -e "$SWEEP_DIR"

"$DVT_BIN" htb sweep \
  --host "$IPERF_HOST" \
  --server-port "$IPERF_PORT" \
  --reference-evidence "$REF_DIR" \
  --ack-reference-reviewed \
  --rates 180,190,195 \
  --output-dir "$SWEEP_DIR" \
  --samples 3 \
  --cooldown-seconds 300 \
  --seconds 10 \
  --omit 3 \
  --parallel "$RATE_PARALLEL" \
  --family 4 \
  --minimum-rate-exposure-percent 90 \
  --minimum-cpu-idle-percent 5 \
  --maximum-cpu-steal-percent 5
```

检查：

```bash
test -f "$SWEEP_DIR/COMPLETED"
test ! -e "$SWEEP_DIR/INCOMPLETE"
(cd "$SWEEP_DIR" && sha256sum -c SHA256SUMS)

REF_MANIFEST_SHA256="$(sha256sum "$REF_DIR/SHA256SUMS" | awk '{print $1}')"
REF_ANALYSIS_SHA256="$(sha256sum "$REF_DIR/sweep-analysis.json" | awk '{print $1}')"
grep -Fxq "evidence_manifest_sha256=${REF_MANIFEST_SHA256}" "$REF_DIR/COMPLETED"
grep -Fxq "analysis_sha256=${REF_ANALYSIS_SHA256}" "$REF_DIR/COMPLETED"
REF_COMPLETED_SHA256="$(sha256sum "$REF_DIR/COMPLETED" | awk '{print $1}')"

jq '{schema_version,status,measurement_gate,shaping_exposure_gate,resource_gate,
     source_reference_gate,reference,rates,review_shortlist,next_gate,
     interpretation,traffic_budget}' \
  "$SWEEP_DIR/sweep-analysis.json"

jq -e \
  --arg manifest "$REF_MANIFEST_SHA256" \
  --arg analysis "$REF_ANALYSIS_SHA256" \
  --arg completed "$REF_COMPLETED_SHA256" '
  .schema_version == 3 and .status == "REVIEW_REQUIRED" and
  .measurement_gate.valid == true and
  .shaping_exposure_gate.valid == true and
  .resource_gate.valid == true and
  .source_reference_gate.external_reference_required == true and
  .source_reference_gate.review_acknowledged == true and
  .source_reference_gate.evidence_manifest_sha256 == $manifest and
  .source_reference_gate.analysis_sha256 == $analysis and
  .source_reference_gate.completed_marker_sha256 == $completed and
  .persistence_authorized == false
' "$SWEEP_DIR/sweep-analysis.json" >/dev/null
```

任一 gate 无效都会得到 `REVIEW_BLOCKED` 和空 shortlist。有效时，shortlist 仍只是描述性筛选：
候选 sender 重传离散上界低于 HTB200 reference 离散下界、吞吐处于本轮最佳候选的观察离散
范围、全部窗口/HTB 暴露/资源门禁通过。小样本、MAD 为 0、首尾 reference 漂移和公共服务端
负载都可能误导，不构成统计显著性或最优性证明。

人工复核后才冻结候选。示例中的 `190` 必须替换为实际批准值，并与 shortlist 一致：

```bash
SHORTLIST_RATE="$(jq -er '.review_shortlist.rate_mbit | select(. != null)' \
  "$SWEEP_DIR/sweep-analysis.json")"
APPROVED_CANDIDATE_RATE='190'
test "$APPROVED_CANDIDATE_RATE" = "$SHORTLIST_RATE"
case "$APPROVED_CANDIDATE_RATE" in 180|190|195) ;; *) exit 1 ;; esac

CANDIDATE_DECISION="$CAMPAIGN_ROOT/candidate-decision.json"
test ! -e "$CANDIDATE_DECISION"
SWEEP_MANIFEST_SHA256="$(sha256sum "$SWEEP_DIR/SHA256SUMS" | awk '{print $1}')"
SWEEP_ANALYSIS_SHA256="$(sha256sum "$SWEEP_DIR/sweep-analysis.json" | awk '{print $1}')"
SWEEP_COMPLETED_SHA256="$(sha256sum "$SWEEP_DIR/COMPLETED" | awk '{print $1}')"
ENDPOINT_SHA256="$(sha256sum "$ENDPOINT_FILE" | awk '{print $1}')"
jq -n \
  --argjson rate "$APPROVED_CANDIDATE_RATE" \
  --argjson parallel "$RATE_PARALLEL" \
  --arg endpoint_file "$ENDPOINT_FILE" \
  --arg endpoint_sha256 "$ENDPOINT_SHA256" \
  --arg reference_dir "$REF_DIR" \
  --arg reference_manifest_sha256 "$REF_MANIFEST_SHA256" \
  --arg reference_analysis_sha256 "$REF_ANALYSIS_SHA256" \
  --arg reference_completed_sha256 "$REF_COMPLETED_SHA256" \
  --arg sweep_dir "$SWEEP_DIR" \
  --arg sweep_manifest_sha256 "$SWEEP_MANIFEST_SHA256" \
  --arg sweep_analysis_sha256 "$SWEEP_ANALYSIS_SHA256" \
  --arg sweep_completed_sha256 "$SWEEP_COMPLETED_SHA256" \
  --arg utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{schema_version:2,status:"MANUALLY_FROZEN_FOR_ABA",rate_mbit:$rate,
    parallel:$parallel,
    endpoint:{file:$endpoint_file,sha256:$endpoint_sha256},
    reference:{directory:$reference_dir,evidence_manifest_sha256:$reference_manifest_sha256,
      analysis_sha256:$reference_analysis_sha256,completed_marker_sha256:$reference_completed_sha256},
    sweep:{directory:$sweep_dir,evidence_manifest_sha256:$sweep_manifest_sha256,
      analysis_sha256:$sweep_analysis_sha256,completed_marker_sha256:$sweep_completed_sha256},
    utc:$utc,persistence_authorized:false}' \
  >"$CANDIDATE_DECISION"
chmod 0600 "$CANDIDATE_DECISION"
```

shortlist 为空、首尾 reference 不可比较或人工不接受候选时，结束本轮并保持根 `fq`。

## 9. 两个正式窗口必须分开生成

### 9.0 新 SSH 会话或新维护窗口的恢复门禁

Shell 变量和函数不会跨 SSH 连接保存。每次重连或开始另一个窗口时，先从操作者的私有记录
填入本轮**精确** campaign 路径；不得用 `ls | tail` 猜“最新目录”。以下函数重新验证
candidate decision 绑定的 endpoint、reference 和 sweep，随后重新冻结 rc.13 与稳定执行器：

和首次运行一样，先从主 SSH shell 单独启动 `bash --noprofile --norc`，再在该专用嵌套 shell
中单独执行本代码块。任一命令失败时嵌套 shell 会退出；此时回到主 shell 保存现场，不得从
失败行后面继续。

```bash
set -Eeuo pipefail
umask 077
CAMPAIGN_ROOT='/root/vmiss-basic-htb-campaign-YYYYMMDDTHHMMSSZ'
CANDIDATE_DECISION="$CAMPAIGN_ROOT/candidate-decision.json"
DVT_BIN='/usr/local/bin/dvt'
DVT_ROOT="$(readlink -f /usr/local/lib/debian-vps-tuning/current)"
HTB_TOOL='/usr/local/sbin/htb-aggregate-experiment'

test -d "$CAMPAIGN_ROOT"
test -f "$CANDIDATE_DECISION"
jq -e '
  .schema_version == 2 and .status == "MANUALLY_FROZEN_FOR_ABA" and
  (.rate_mbit == 180 or .rate_mbit == 190 or .rate_mbit == 195) and
  (.parallel == 1 or .parallel == 2 or .parallel == 4) and
  .persistence_authorized == false
' "$CANDIDATE_DECISION" >/dev/null

verify_decision_file() {
  local path="$1" expected="$2"
  test -f "$path"
  test "$(sha256sum "$path" | awk '{print $1}')" = "$expected"
}

ENDPOINT_FILE="$(jq -er '.endpoint.file' "$CANDIDATE_DECISION")"
REF_DIR="$(jq -er '.reference.directory' "$CANDIDATE_DECISION")"
SWEEP_DIR="$(jq -er '.sweep.directory' "$CANDIDATE_DECISION")"
CANDIDATE_RATE="$(jq -er '.rate_mbit' "$CANDIDATE_DECISION")"
RATE_PARALLEL="$(jq -er '.parallel' "$CANDIDATE_DECISION")"

case "$(readlink -f "$ENDPOINT_FILE")" in "$CAMPAIGN_ROOT"/*) ;; *) exit 1 ;; esac
case "$(readlink -f "$REF_DIR")" in "$CAMPAIGN_ROOT"/*) ;; *) exit 1 ;; esac
case "$(readlink -f "$SWEEP_DIR")" in "$CAMPAIGN_ROOT"/*) ;; *) exit 1 ;; esac

verify_decision_file "$ENDPOINT_FILE" \
  "$(jq -er '.endpoint.sha256' "$CANDIDATE_DECISION")"
verify_decision_file "$REF_DIR/SHA256SUMS" \
  "$(jq -er '.reference.evidence_manifest_sha256' "$CANDIDATE_DECISION")"
verify_decision_file "$REF_DIR/sweep-analysis.json" \
  "$(jq -er '.reference.analysis_sha256' "$CANDIDATE_DECISION")"
verify_decision_file "$REF_DIR/COMPLETED" \
  "$(jq -er '.reference.completed_marker_sha256' "$CANDIDATE_DECISION")"
verify_decision_file "$SWEEP_DIR/SHA256SUMS" \
  "$(jq -er '.sweep.evidence_manifest_sha256' "$CANDIDATE_DECISION")"
verify_decision_file "$SWEEP_DIR/sweep-analysis.json" \
  "$(jq -er '.sweep.analysis_sha256' "$CANDIDATE_DECISION")"
verify_decision_file "$SWEEP_DIR/COMPLETED" \
  "$(jq -er '.sweep.completed_marker_sha256' "$CANDIDATE_DECISION")"
(cd "$REF_DIR" && sha256sum -c SHA256SUMS)
(cd "$SWEEP_DIR" && sha256sum -c SHA256SUMS)

(cd "$DVT_ROOT" && sha256sum -c SHA256SUMS)
EXPECTED_HTB_SHA256="$(
  awk '$2 == "experiments/htb-aggregate/htb-aggregate-experiment.sh" {print $1}' \
    "$DVT_ROOT/SHA256SUMS"
)"
printf '%s  %s\n' "$EXPECTED_HTB_SHA256" "$HTB_TOOL" | sha256sum -c -
"$DVT_BIN" verify
"$DVT_BIN" htb preflight
```

在该 shell 中继续执行第 10 节的变量与函数定义块。开始反向窗口时必须重新执行本节和第 10
节，不能假定首窗 shell、变量或函数仍然有效。

### 9.1 首窗 A1 → B1 → A2

```bash
CANDIDATE_RATE="$(jq -er '.rate_mbit' "$CANDIDATE_DECISION")"
WINDOW1_ID="basic-aba-$(date -u +%Y%m%dT%H%M%SZ)"
WINDOW1_PLAN="$CAMPAIGN_ROOT/${WINDOW1_ID}-plan.json"
test ! -e "$WINDOW1_PLAN"

"$DVT_BIN" htb aba-plan \
  --window-id "$WINDOW1_ID" \
  --window-order aba \
  --candidate-rate "$CANDIDATE_RATE" \
  --cooldown-seconds 300 \
  --control-rate none >"$WINDOW1_PLAN"

jq -e --arg id "$WINDOW1_ID" --argjson rate "$CANDIDATE_RATE" '
  .schema_version == 2 and .mode == "read-only-plan" and
  .window.id == $id and .window.order == "aba" and
  .window.evidence_directory_must_be_new == true and
  .candidate.rate_mbit == $rate and
  (.candidate.stages | map(.label)) ==
    ["A1-fq","B1-htb-candidate","A2-fq"] and
  .controls.exactly_one_window_per_plan == true and
  .controls.persistent_shaping_authorized == false
' "$WINDOW1_PLAN" >/dev/null
```

### 9.2 反向窗 B2 → A3 → B3

本命令不能与首窗连续执行。只有首窗数据、清单、A1/A2 可比性和 B1 信号已经人工关闭后，
在另一个可比时段使用新的 operator invocation、window ID、plan 和证据目录：

```bash
WINDOW2_ID="basic-bab-$(date -u +%Y%m%dT%H%M%SZ)"
WINDOW2_PLAN="$CAMPAIGN_ROOT/${WINDOW2_ID}-plan.json"
test ! -e "$WINDOW2_PLAN"

"$DVT_BIN" htb aba-plan \
  --window-id "$WINDOW2_ID" \
  --window-order bab \
  --candidate-rate "$CANDIDATE_RATE" \
  --cooldown-seconds 300 \
  --control-rate none >"$WINDOW2_PLAN"

jq -e --arg id "$WINDOW2_ID" '
  .schema_version == 2 and .window.id == $id and .window.order == "bab" and
  (.candidate.stages | map(.label)) ==
    ["B2-htb-candidate","A3-fq","B3-htb-candidate"] and
  .controls.opposite_order_requires_distinct_window_id == true
' "$WINDOW2_PLAN" >/dev/null
```

一个 plan 只包含一个三阶段窗口。不得恢复旧 `--repeat-cycles 2`，也不得让两个窗口共用目录。

## 10. 固定 TcpQuality 资产和单 stage 执行函数

rc.13 使用 TcpQuality `v1.00013`、commit
`73606e2460bde21bb2e253842971f8ca8c9eb51c` 和固定 amd64 rootfs。先按 README 完成 pinned
目录准备；wrapper 会再次校验全部固定哈希。正式 B stage 的 40 分钟 watchdog 与历史单轮约
22 分钟耗时之间没有容纳三轮的余量，因此 **每个 stage 必须显式使用
`TCPQUALITY_RUNS=1`**。需要更多重复性时，重复完整窗口，不能把一个 B stage 改为三轮。

```bash
TQ_HARNESS="$DVT_ROOT/tcpquality-evidence.sh"
TQ_PIN_DIR='/root/tcpquality-pinned-73606e2460bde21bb2e253842971f8ca8c9eb51c'
TQ_COMMIT='73606e2460bde21bb2e253842971f8ca8c9eb51c'
TQ_ROOTFS_SHA256='c624b5cc611b7177c42608110024764e59dfd0a88150257137ae4e6d7f9f9d18'

test -x "$TQ_HARNESS"
test -d "$TQ_PIN_DIR"
(cd "$TQ_PIN_DIR" && sha256sum -c SHA256SUMS)
```

定义公共采集函数。它不负责决定 stage 顺序，也不会自动开始下一段：

```bash
record_stage_state() {
  local phase="$1" output="$2"
  {
    printf 'phase=%s\nutc=%s\n' "$phase" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    uname -a
    uptime
    free -h
    df -h /root
    sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc \
      net.ipv4.tcp_rmem net.ipv4.tcp_wmem
    ip -4 route show default
    ip -6 route show default
    nstat -az
    tc -s -d qdisc show dev eth0
    tc -s -d class show dev eth0
  } >"$output"
}

run_tcpquality_once() (
  set -Eeuo pipefail
  local label="$1" window_root="$2"
  local stage_root="$window_root/$label"
  local tq_dir="$stage_root/tcpquality"
  local available_bytes

  test ! -e "$stage_root"
  install -d -o root -g root -m 0700 "$stage_root"
  available_bytes="$(df -PB1 /root | awk 'NR == 2 {print $4}')"
  test "$available_bytes" -ge 2147483648
  record_stage_state pre "$stage_root/host-pre.txt"

  env \
    TCPQUALITY_PIN_DIR="$TQ_PIN_DIR" \
    TCPQUALITY_EVIDENCE_DIR="$tq_dir" \
    TCPQUALITY_COMMIT="$TQ_COMMIT" \
    TCPQUALITY_ROOTFS_SHA256="$TQ_ROOTFS_SHA256" \
    TCPQUALITY_MODE='local-evidence' \
    TCPQUALITY_ACK_TRANSIENT_FIREWALL=1 \
    TCPQUALITY_RUNS=1 \
    TCPQUALITY_DELAY_SECONDS=0 \
    TCPQUALITY_COUNT=30 \
    TCPQUALITY_PACKET_SIZE=0 \
    TCPQUALITY_PARALLEL=16 \
    bash "$TQ_HARNESS" >"$stage_root/harness-console.log" 2>&1

  test -f "$tq_dir/COMPLETED"
  test ! -e "$tq_dir/INCOMPLETE"
  (cd "$tq_dir" && sha256sum -c SHA256SUMS)
  record_stage_state post "$stage_root/host-post.txt"
  du -sb "$stage_root" >"$stage_root/size-bytes.txt"
)

run_a_stage() (
  set -Eeuo pipefail
  local label="$1" window_root="$2"
  "$DVT_BIN" verify
  "$DVT_BIN" htb preflight
  run_tcpquality_once "$label" "$window_root"
  "$DVT_BIN" htb preflight
)

run_b_stage() (
  set -Eeuo pipefail
  local label="$1" window_root="$2" rate="$3"
  local b_active=0
  local stage_control="$window_root/${label}-htb-control.log"

  cleanup_b_stage() {
    if [ "$b_active" -eq 1 ]; then
      "$HTB_TOOL" stop >>"$stage_control" 2>&1 || true
    fi
  }
  trap cleanup_b_stage EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  "$DVT_BIN" verify
  "$DVT_BIN" htb preflight
  "$HTB_TOOL" start --rate "$rate" >"$stage_control" 2>&1
  b_active=1
  "$HTB_TOOL" assert-active --rate "$rate" >>"$stage_control" 2>&1
  run_tcpquality_once "$label" "$window_root"
  "$HTB_TOOL" assert-active --rate "$rate" >>"$stage_control" 2>&1
  "$HTB_TOOL" stop >>"$stage_control" 2>&1
  b_active=0
  "$DVT_BIN" htb preflight >>"$stage_control" 2>&1
  trap - EXIT INT TERM
)
```

`local-evidence` 不上传公开报告或 debug bundle，但固定上游 `--all` 会产生真实网络流量、加载
临时 eBPF 探针，并创建/删除目标 iptables/ip6tables 计数链。`TCPQUALITY_ACK_TRANSIENT_FIREWALL=1`
只表示已接受该已审计运行边界，不表示防火墙恢复一定成功；wrapper 或 stage 失败时保留现场。

## 11. 执行首窗 A1/B1/A2

为首窗新建父目录；stage 子目录由函数原子地拒绝覆盖：

```bash
WINDOW1_ROOT="$CAMPAIGN_ROOT/windows/$WINDOW1_ID"
test ! -e "$WINDOW1_ROOT"
install -d -o root -g root -m 0700 "$WINDOW1_ROOT"
cp -a "$WINDOW1_PLAN" "$WINDOW1_ROOT/experiment-plan.json"
cp -a "$CANDIDATE_DECISION" "$WINDOW1_ROOT/candidate-decision.json"
(cd "$WINDOW1_ROOT" &&
  sha256sum experiment-plan.json candidate-decision.json >window-inputs.sha256)
```

每段开始前先手工确认 VMISS 面板流量、磁盘、控制台、业务空闲和无并行测试，并把值追加到
`operator-gates.tsv`。实际顺序：

```bash
run_a_stage A1-fq "$WINDOW1_ROOT"

sleep 300
# 再做人工空闲/面板/磁盘门禁，确认通过后才执行：
run_b_stage B1-htb-candidate "$WINDOW1_ROOT" "$CANDIDATE_RATE"

sleep 300
# 再做人工空闲/面板/磁盘门禁，确认根 fq 已恢复后才执行：
run_a_stage A2-fq "$WINDOW1_ROOT"
```

不能因 B1 看起来较好而跳过 A2。若 B1 TcpQuality 超过 watchdog、stage 后
`assert-active` 失败、`stop` 失败或根 `fq` 未恢复，B1 无效，整个窗口不得进入效果判定。

## 12. 首窗判读和反向窗执行

首窗先验证每个 stage 的 `COMPLETED`/`SHA256SUMS`，再按共同逻辑节点比较 A1、B1、A2：

- `retransmission-evidence.tsv` 中只有 `ebpf_seq`、`ebpf_skb`、`tcp_info_getsockopt` 或
  `tcp_info_ss` 可作为流级证据；`nstat`/`MEASUREMENT_DEGRADED` 不得当作该测速流重传率；
- 使用实际分母和方向比较流级重传，不把旧工具的整机 `TcpRetransSegs` 与 rc.13 比例串接；
- 检查 `node-drift.tsv`，只在共同逻辑节点上做主比较，IP/节点变化另行标注；
- 比较有效吞吐、重传、RTT/尾延迟、qdisc drops/overlimits/requeues/backlog、CPU、softnet、
  OOM 和 VMISS 面板流量；
- A1 与 A2 必须足够一致。B1 的改善必须大于 A1/A2 内部漂移，且没有吞吐或资源副作用。

首窗不满足这些条件就停止。满足时，按第 9.2 节在另一个可比时段单独生成反向计划，然后：

```bash
WINDOW2_ROOT="$CAMPAIGN_ROOT/windows/$WINDOW2_ID"
test ! -e "$WINDOW2_ROOT"
install -d -o root -g root -m 0700 "$WINDOW2_ROOT"
cp -a "$WINDOW2_PLAN" "$WINDOW2_ROOT/experiment-plan.json"
cp -a "$CANDIDATE_DECISION" "$WINDOW2_ROOT/candidate-decision.json"
(cd "$WINDOW2_ROOT" &&
  sha256sum experiment-plan.json candidate-decision.json >window-inputs.sha256)

run_b_stage B2-htb-candidate "$WINDOW2_ROOT" "$CANDIDATE_RATE"
sleep 300
# 人工门禁后：
run_a_stage A3-fq "$WINDOW2_ROOT"
sleep 300
# 人工门禁后：
run_b_stage B3-htb-candidate "$WINDOW2_ROOT" "$CANDIDATE_RATE"
```

反向窗的开始时间不能仅紧接首窗；它需要新的、可比较维护窗口。顺序反转只能降低趋势偏差，
不能消除公共节点、运营商路径、宿主负载或日内变化。若两窗方向不一致，不得挑选有利窗口。

## 13. 两窗联合判定

候选进入真实业务复验至少需要：

1. 两个窗口全部 stage、清单、ACTIVE/watchdog/恢复门禁通过；
2. A1/A2 和 A3 的根 `fq` 基线没有不可解释漂移；
3. B1、B2、B3 在共同节点和相同指标口径上呈一致改善，而不是单个热点节点偶然变化；
4. 改善大于相邻 A 状态波动，sender/receiver 吞吐没有不可接受下降；
5. 本地 qdisc drops 为 0，CPU/steal、softnet、接口、OOM 和磁盘正常；
6. VMISS 面板实际流量与计划和重试记录可对账。

最强反证是：相同时间趋势或公共测速节点负载也能产生“B 看起来更好”。A/B/A 与反向窗口
降低但不能消除这种混杂。因此结论只能是“候选值得做真实业务临时复验”，不是因果证明，
更不是永久部署批准。

## 14. 真实 VLESS + REALITY + TCP 临时复验

先在根 `fq` 下执行严格代理验证：

```bash
REQUIRE_PROXY_SERVICE=1 PROXY_SERVICE_UNITS='x-ui.service' "$DVT_BIN" verify
"$DVT_BIN" htb preflight
```

从同一受控客户端固定节点、协议、地址族、测试对象、时长和时间窗，先采集根 `fq`，再临时
启动候选 HTB，最后恢复根 `fq` 复验。每种状态至少记录 1、3、5、10 并发下的成功率、连接
建立时间、吞吐、RTT/尾延迟、断流、客户端错误、Xray/3X-UI 错误和目标机资源。客户端测试
命令取决于实际业务工具，必须随证据冻结；TcpQuality 不经过代理链，不能替代本节。

候选阶段仍使用 watchdog 和 cleanup。以下函数启动候选后最多等待 30 分钟；在它等待期间，
从受控客户端完成已经冻结的业务矩阵并返回服务器按 Enter。超时、SSH 中断或命令失败都会
进入 cleanup；40 分钟 watchdog 仍是第二层恢复：

```bash
run_business_candidate_window() (
  set -Eeuo pipefail
  local business_log="$CAMPAIGN_ROOT/business-htb-control.log"
  local business_active=0 confirmation
  cleanup_business_htb() {
    if [ "$business_active" -eq 1 ]; then
      "$HTB_TOOL" stop >>"$business_log" 2>&1 || true
    fi
  }
  trap cleanup_business_htb EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  "$HTB_TOOL" start --rate "$CANDIDATE_RATE" >"$business_log" 2>&1
  business_active=1
  "$HTB_TOOL" assert-active --rate "$CANDIDATE_RATE" >>"$business_log" 2>&1

  printf '请在受控客户端完成固定的 1/3/5/10 并发矩阵；30 分钟内完成后按 Enter：'
  IFS= read -r -t 1800 confirmation

  "$HTB_TOOL" assert-active --rate "$CANDIDATE_RATE" >>"$business_log" 2>&1
  "$HTB_TOOL" stop >>"$business_log" 2>&1
  business_active=0
  "$DVT_BIN" htb preflight >>"$business_log" 2>&1
  trap - EXIT INT TERM
)

run_business_candidate_window

REQUIRE_PROXY_SERVICE=1 PROXY_SERVICE_UNITS='x-ui.service' "$DVT_BIN" verify
```

真实业务阶段一旦超过 40 分钟 watchdog 窗口，必须拆成多个独立、每次都完整恢复的短窗口，
不能延长或取消自动回滚来容纳长测试。

## 15. 永久化决策边界

本仓库当前没有“把 shortlist 一键写成永久 HTB”的入口，这是有意的安全边界。以下任一情况
都维持 rc.13 根 `fq`：shortlist 为空、窗口无效、两窗不一致、改善未超过 A 漂移、吞吐/业务
恶化、资源异常或面板流量不可对账。

如果两窗和真实业务都稳定有利，仍需另行提交持久化变更授权，并单独设计：开机顺序、
`proxy-vps-fq.service` 所有权冲突、systemd unit、失败回退、升级/rollback、重启验收、状态
schema、监控、流量额度和取消条件。不得在本 SOP 末尾直接创建持久 unit 或修改 profile。

## 16. 证据封存与脱敏

窗口关闭后，先确认不存在活动 HTB，再生成 campaign 总清单：

```bash
"$DVT_BIN" htb status || true
"$DVT_BIN" htb preflight

(
  cd "$CAMPAIGN_ROOT"
  find . -type f ! -path './SHA256SUMS' ! -path './SHA256SUMS.tmp' -print0 |
    sort -z |
    xargs -0 sha256sum >SHA256SUMS.tmp
  test -s SHA256SUMS.tmp
  mv -f SHA256SUMS.tmp SHA256SUMS
  sha256sum -c SHA256SUMS
)
chmod -R go-rwx "$CAMPAIGN_ROOT"
```

原始证据可能包含公网地址、节点地址、时间、路由、boot ID、服务名和业务错误。公开前必须
脱敏非必要基础设施标识，但保留版本、工具/计划/证据 SHA-256、速率、地址族、样本顺序、
指标定义和失败状态。静态仓库验证不能替代本 SOP 的目标 VPS、VMISS 面板、真实 TcpQuality
和 VLESS + REALITY + TCP 运行证据。
