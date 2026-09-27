# rc.19 真实 probe 离线兼容性核验操作单

状态：采集步骤按合并提交 `a5e90d388f5fc1ac6545080649c003baf1fce8ec` 与 rc.17 tag 核对；分析器 0.1.1 的 rc.17 兼容增量已通过 PR #19 合并并纳入 rc.19 Pre-release。2026-09-27 替换对端已形成一份真实完整上传 probe，本地完整性与 rc.17 格式兼容核验通过；用户确认该路径代表主要 VPS 出向方向，同一证据的离线结论为 `KEEP_CURRENT_CEILING`。对端临时 iperf3 无监听、本次新增的 UFW 规则已删除；被测端新窗口两笔记录均已结算、无未结算预留。具体证据见[项目阶段备忘](project-memo.md)最新记录。

本次采集与收尾已经完成。第 3–8 节保留当时的复现和排障步骤，**不是当前待执行命令**；尤其第 4A–4F 节是旧对端故障的历史诊断，第 5 节的旧窗口预算不足且示例输出目录已使用，不能原样重跑。只有出现新的明确验证需求并核对对端、授权、账本和目录状态后，才能重新制定采集计划。

## 0. 本次实际环境：先做这一节

用户实际输出已确认 Debian 13.7、内核 `6.12.107+deb13-cloud-amd64`、dvt `v0.1.0-rc.17`、`debian13-1c1g`、1 vCPU/967 MiB、声明端口 200 Mbps、目标 RTT 200ms、buffer 上限 16 MiB；status/verify 均退出 0，状态 VERIFIED，验证无警告。运行输出为 BBR、主接口根 fq，iperf3 3.18 已安装。限定目录查找没有返回 probe-result.json，不能据此断言整机没有其他证据。误输入 `--version~` 后的失败不是版本故障，正常命令已成功。

用户有自己控制的 iperf3 对端，允许新采集总流量不超过 **100GB**。该额度是总上限，不是目标用量；须考虑两端计费口径、协议开销及本窗口已有用量，GB 与工具 MiB 不能直接混用。首次计划仍只需约 188MB payload。

**本次 VPS 保持 rc.17，采集与离线分析已经完成。** 仓库分析器 0.1.1 允许 rc.17/rc.18/rc.19，仍要求同一 VERIFIED 版本、脚本、boot 和网络上下文及完整摘要链；旧 0.1.0 分析器仍拒绝 rc.17。不要修改证据版本字段，也无需仅为这次离线分析向 VPS 复制或安装 rc.19 Shell 文件。

源码对照确认 rc.17/rc.18 的 probe、资源 profile 定义及模板从 `softnet_snapshot()` 到 benchmark 末尾的采集/汇总区域完全相同；用户 profile 脚本摘要也匹配 rc.17 tag。合成回归之外，已有一份真实 rc.17/iperf3 3.18 上传证据通过格式兼容核验；不外推到其他方向或版本。下列盘点命令保留供复查，用户已完成时无需重复查找。

在被测 VPS 的现有 SSH 管理会话运行 `sudo -i` 进入 root，然后执行以下只读盘点。命令不运行 iperf3 客户端，不改变调优参数。`status/verify` 会使用既有锁文件；完整输出只在私有渠道保存。

```bash
cat /etc/os-release
uname -r
command -v dvt
dvt --version
if command -v jq >/dev/null 2>&1; then
  if [ -f /var/lib/proxy-vps-tuning/state.json ]; then
    jq '{state,script_version,profile,
      network:(.network | {port_speed_mbps,target_rtt_ms,buffer_max_bytes})}' \
      /var/lib/proxy-vps-tuning/state.json
  else
    printf 'NO_MANAGED_STATE\n'
  fi
else
  printf 'MISSING_JQ\n'
fi
dvt status
printf 'status_exit=%s\n' "$?"
dvt verify
printf 'verify_exit=%s\n' "$?"
if command -v iperf3 >/dev/null 2>&1; then
  iperf3 --version
else
  printf 'MISSING_IPERF3\n'
fi
for search_root in /root /var/tmp /var/lib/proxy-vps-tuning; do
  if [ -d "$search_root" ]; then
    find "$search_root" -maxdepth 5 -type f -name probe-result.json -print
  fi
done
date -u +%Y-%m-%dT%H:%M:%SZ
```

`profile.id` 就是所需的 profile。把版本、profile、上述两个退出码和是否找到 probe 路径反馈给本任务即可；不要提供 SSH 密钥。查找只覆盖三个常用目录的五层深度，没有输出不代表整台机器绝对没有历史证据；如果以前使用过其他 `--output-dir`，只补查那个明确路径。

- **找到真实目录：** 先用第 6–7 节校验、私有导出，由本地分析器 0.1.1 核验，不重测。
- **没有真实目录：** 本次前置盘点已通过，按第 4–5 节采集；100GB 授权无需重复请求，增加 VPS 配置变更或超过额度才需另行确认。
- **发现状态/verify 异常：** 保留错误，先解释该异常；不运行 rollback、apply 或迁移来“修好以便测试”。

若后续确需升级，rc.18 与 rc.19 都有独立 Pre-release；迁移涉及 checkpoint、旧配置回滚及两次重启，属于独立的 VPS 配置变更，不包含在本次流量授权内。等 profile、状态及维护条件明确后再形成针对该主机的迁移操作单；不直接粘贴 README 中固定到其他版本的历史示例。

## 1. 本次要验证什么

目标是确认真实 `dvt probe` 产出的清单、原始 iperf3 JSON、元数据和重复样本能被 `tools/calibrate_probe.py` 正确处理。先使用已有真实证据；没有证据时，新采集须具备已确认的对端、业务症状或测试目的、维护时段及预算。本轮对端控制权和 100GB 预算已有用户确认，不重复请求；具体执行仍受第 0 节版本条件约束，其他读者不能把本操作单当作自己的测速授权。

第 3–5 节适用于 rc.17/rc.18/rc.19 的受支持主机；分析器须使用含 rc.17 增量的本地 0.1.1。受管状态 VERIFIED 且核验通过时保持 VPS 安装不变。未安装、版本更早、状态不符或依赖缺失时停止，先提供检查结果；不要为采样直接 apply、迁移、重启或混用新旧脚本。

这是兼容性核验，不是服务商带宽、限速器拐点、缓冲收益或 Xray 业务验收。测试通过也不会自动应用参数。现有[网络测试策略](network-tuning-and-test-strategy.md)不把主动 probe 作为日常、升级或发布默认门禁。

## 2. 路径选择与准备信息

| 情况 | 执行路径 |
|---|---|
| 已有可信来源的完整 probe 目录 | 跳到第 6 节校验、打包，再用分析器 0.1.1 离线核验 rc.17/rc.18/rc.19 证据；不用重测 |
| 只有单个 iperf3 JSON 或旧合成 demo | 不满足输入契约；保留原文件，不补字段或重建清单 |
| 没有真实证据，但有获准对端和明确采集预算 | 依次执行第 3–8 节 |
| 没有对端、预算或合适维护窗口 | 只做第 3 节；主动采集保持待办 |

准备两台机器：被测 VPS 运行 `dvt probe`，独立的已授权 iperf3 服务端接收连接。分析工作站为 Windows PowerShell 7 + Python 3.10+，使用完整仓库中的分析器及 `tools/render_profiles.py`。同一 VPS 回环测试不能代表外部路径。

先记录：Debian/内核、dvt 版本、profile、声明套餐带宽、iperf3 版本、对端是否自有或获准、IPv4/IPv6、测试方向、窗口预算。公开反馈不包含地址、主机名、boot ID、SSH 凭据或原始完整日志。

## 3. 被测 VPS：前置检查，不产生 probe 流量

登录已有 SSH 管理会话，保留另一条 SSH 会话。若不是 root，先单独执行 `sudo -i` 并等待提示符返回，再逐段检查。不要在整段粘贴命令的开头启动另一个 `bash`。任何检查失败都应停止，不继续执行采集步骤。

```bash
umask 077
cat /etc/os-release
uname -r
command -v dvt
dvt --version
for cmd in jq iperf3 setsid timeout tar sha256sum; do command -v "$cmd"; done
iperf3 --version
jq '{state,script_version,profile,network}' /var/lib/proxy-vps-tuning/state.json
jq -e '.state == "VERIFIED" and
  (.script_version == "0.1.0-rc.17" or .script_version == "0.1.0-rc.18" or .script_version == "0.1.0-rc.19") and
  (.network.port_speed_mbps >= 100 and .network.port_speed_mbps <= 1000)' \
  /var/lib/proxy-vps-tuning/state.json >/dev/null
dvt status
dvt verify
date -u +%Y-%m-%dT%H:%M:%SZ
```

核对控制器和受管状态版本相同，profile 符合当前硬件，声明带宽符合套餐，系统时间正确。`status/verify` 不应用调优参数，但会获取进程锁及写锁诊断信息；如锁冲突，等待合法持锁任务结束，不删锁、不杀不明进程。任何依赖、完整性、状态或 verify 错误均应停止并保留报错；不要手改 state.json 绕过。

没有 `dvt` 或 iperf3 时，本单不自动安装。先确认实际安装方式和软件包变更范围；如果已有兼容真实证据，分析工作站无需在 VPS 补装任何工具。

## 4. iperf3 对端：仅在新采集获准后准备

以下是首次采集时准备旧对端的历史步骤，相关临时服务和规则已撤销。对端仅需 iperf3，不要求安装/升级 dvt。用户当时确认对端为 Debian 13 / 2 GiB、套餐流量 1000GB，UFW active；当时提供的规则中没有 TCP 5201。套餐总流量不等于当前剩余额度，也不扩大当次 100GB 授权或 256 MiB 采集窗口。若以后新采集，须重新核对实际对端和云端访问控制，不能沿用当时的现场状态。

在**对端 VPS**已有 SSH 会话执行（非 root 时对需要权限的命令加 sudo）：

```bash
cat /etc/os-release
command -v iperf3
iperf3 --version
ss -ltnp 'sport = :5201'
command -v ufw
command -v firewall-cmd
command -v nft
```

命令位置检查可能因工具未安装返回非零，不是网络故障。端口已有服务时先确认是否是获准的 iperf3，不杀进程或重复启动。如果 iperf3 缺失且对端确为 Debian/Ubuntu，需要安装软件包时才执行 `apt-get update` 和 `apt-get install --no-install-recommends iperf3`；若询问是否作为 daemon 自动运行，选 No，本次使用前台临时服务。该安装属于用户在对端执行的软件包变更，Agent 未执行；不要只为此次测试做全系统升级。

**云端防火墙/安全组：** 若服务商启用了实例外部访问控制，在其实际绑定到对端实例/网卡的安全组或防火墙中添加一条临时入站允许规则：IPv4、TCP、目标端口 5201、来源为被测 VPS 的公网出站 IPv4 `/32`；描述可用 `dvt-probe-temp`。来源不是对端 IP，不使用 `0.0.0.0/0`。若有 NAT/SNAT，使用真实出口地址；出站受限时还需按现有规则允许返回流量。具体页面和无状态 ACL 的返回方向规则依服务商而定，不假设存在统一界面。

**仅当对端 UFW 已启用：** 先看状态和既有规则，再添加精确来源规则。替换下面的 `REPLACE_WITH_TEST_VPS_EGRESS_IPV4`；它不是 iperf3 对端地址。

```bash
ufw status verbose
ufw status numbered
ufw allow proto tcp from REPLACE_WITH_TEST_VPS_EGRESS_IPV4/32 to any port 5201 comment 'dvt-probe-temp'
ufw status numbered
```

只有第一条显示 `Status: active` 才执行添加。若为 inactive，不执行 `ufw enable`；它可能改变 SSH 可达性，而且 UFW inactive 不证明其他主机防火墙不存在。若未安装 UFW，或使用 firewalld/原生 nftables，先提供防火墙类型，再生成适配现有规则的命令；不执行 flush/reset、不临时关闭整个防火墙。若添加时提示规则已存在，记录为既有规则，测试后不能删除它。

规则准备后，在**对端**单独终端前台运行 IPv4 服务：

```bash
iperf3 -s -4 -p 5201
```

预期显示 `Server listening on 5201`。保留此终端，不加 `-1`（需要重复三个连接），也无需 `-D` 后台运行或开机自启。另一个对端 SSH 窗口用 `ss -ltnp 'sport = :5201'` 确认 LISTEN。需要限制本机绑定地址时可用 `-B`，但必须是实际本机地址；云 NAT 场景不能直接绑定不属于网卡的公网地址。IPv6 测试需单独改服务绑定、来源规则和客户端 family，不混入同一目录。

先前操作单包含一次裸 TCP 建连检查。它已经证明当时 TCP 可达，但不发送 iperf3 cookie，可能使服务端打印 `unable to receive cookie` 后重新监听；不能作为协议测试成功。本次用户已执行过，停止重复该探测。若出现测量前超时，按下方第 4A 节执行受同一账本约束的协议验证，不重复完整 probe。

**测试后撤销：** 在自己启动的临时 iperf3 终端按 Ctrl+C，确认对应监听结束。撤销云端本次新增规则；若 UFW 规则确实是本次新增，按相同来源删除：

```bash
ufw delete allow proto tcp from REPLACE_WITH_TEST_VPS_EGRESS_IPV4/32 to any port 5201
ufw status numbered
```

核对删除提示的规则确是本次 5201/来源 `/32` 再确认；不删除原先就存在的规则、不停止共享 iperf3 服务、不修改 SSH 规则。Debian/Ubuntu 安装的软件包可保留，卸载另行决定。

## 4A. 首样本超时后的单次低流量协议验证

仅适用于本次已知现场：首次 probe 在 05:38:36–05:38:56 UTC 超时，原 ledger 已保守记账 187500000 bytes、无未结算预留、剩余 80935456 bytes。对端 06:02:27 UTC 的 iperf3 进程运行 09:23，推算启动约为 05:53:04，晚于旧失败样本；当前 S+、LISTEN、无已建立连接，不能倒推出旧时刻状态。没有证据证明当时完全没有其他 iperf3 进程，也不能把 kernel 或 buffer 当作根因。

保留当前对端前台服务和本次来源受限规则，在另一窗口查看测试时输出。被测端只做一次原生协议验证，使用现有 `dvt benchmark` 的 1 Mbps cap、单流、单向、5 秒、omit 0、原 20 秒硬超时；计划 payload 625000 bytes（约 0.596 MiB）。`dvt probe` 最低 cap 为 100 Mbps，所以本次使用其底层既有 benchmark 入口，不修改生产工具的范围，也不使用预算 bypass。

以下命令会立即产生受限测试流量，没有 probe 的再次确认提示。它沿用原 256 MiB ledger/window，不能改成新账本或删除原记录；输出目录和 run-id 为新的诊断用途，已有同名结果时停止，不覆盖。将 host 占位符替换为实际对端地址。

```bash
env BENCHMARK_HOST=REPLACE_WITH_AUTHORIZED_HOST BENCHMARK_PORT=5201 BENCHMARK_SECONDS=5 BENCHMARK_OMIT_SECONDS=0 BENCHMARK_PHASE_TIMEOUT_SECONDS=20 BENCHMARK_PARALLEL=1 BENCHMARK_IP_FAMILY=4 BENCHMARK_DIRECTION=upload BENCHMARK_RATE_CAP_MBPS=1 BENCHMARK_ENFORCE_RATE_CAP=1 BENCHMARK_RUN_ID=rc17-protocol-check-01 BENCHMARK_OUTPUT_DIR=/root/dvt-benchmark-protocol-20260924-01 DVT_TRAFFIC_BUDGET_BYPASS=0 DVT_TRAFFIC_LEDGER=/var/lib/proxy-vps-tuning/traffic-ledgers/rc17-probe-compat-20260924.json DVT_TRAFFIC_WINDOW_ID=rc17-probe-compat-20260924 DVT_TRAFFIC_BUDGET_BYTES=268435456 dvt benchmark
```

成功只证明当前对端条件下该低速协议测试及证据采集通过，不证明旧故障根因已确定，也不是完整 probe，不交给校准器充当重复样本。若再失败，保留这次终端的 warning/error 和对端同期日志，不自动重试。读取新目录的结果：

```bash
jq '{status,exit_code,benchmark:(.metadata.benchmark|{seconds,omit_seconds,phase_timeout_seconds,parallel,rate_cap_enforced,rate_cap_per_stream_bps}),upload:.phases.upload}' /root/dvt-benchmark-protocol-20260924-01/benchmark-result.json
```

结果文件不存在时提供终端报错，不补文件。诊断完成后回传两端同期输出，再决定后续完整 probe 的预算安排；当前剩余量依然不足以再跑 187500000 bytes 的完整 probe，不自行清零或另开窗口绕过历史。

## 4B. 已建立测试流，但服务端接收空闲超时

2026-09-24 的低流量诊断与原首样本不同：两端测试流端口匹配、客户端已有 `test_start`，约 1.008 秒区间记录 131072 bytes 和 5 次 retransmits；服务端报 `idle timeout for receiving data`，客户端报 `control socket has closed unexpectedly`，底层退出码为 1。原始 JSON 有重复区间且没有完整 end，不能累加为接收量，也不能作为有效校准样本。

核对 ESnet [3.18 接收超时默认值](https://github.com/esnet/iperf/blob/3.18/src/iperf_api.h#L69)为 120000 ms；[服务端实现](https://github.com/esnet/iperf/blob/3.18/src/iperf_server_api.c#L581)在开始监听时初始化 `last_receive_time`，测试开始不重新初始化，只有接收块计数增加后更新。[TCP 接收函数](https://github.com/esnet/iperf/blob/3.18/src/iperf_tcp.c#L56)调用循环读取块的 `Nread_no_select`。因此长时间监听后遇到首块接收延迟，可能把监听等待计入接收超时。这是源码支持的假设，尚不能认定为本机根因；重传也支持数据或 ACK 路径停滞这一备选解释。低速发送与块读取可能放大现象，但不能据此认定所有 1 Mbps 测试都会失败。

下一步只改变服务端监听等待时间，测试参数保持不变，不延长超时或修改内核、防火墙、MTU。先在被测端读取当前 ledger，确认 OPEN、无未结算预留、剩余至少 625000 bytes；新诊断的结算情况以实际输出为准，不能沿用上次余额。确认新目录不存在，并预先准备下方客户端命令。

```bash
jq '{status,budget_bytes,reserved_bytes,accounted_bytes,remaining_bytes:(.budget_bytes-.reserved_bytes-.accounted_bytes),last_entry:.entries[-1]}' /var/lib/proxy-vps-tuning/traffic-ledgers/rc17-probe-compat-20260924.json
test ! -e /root/dvt-benchmark-protocol-20260924-02 && test ! -L /root/dvt-benchmark-protocol-20260924-02 && printf 'NEW_OUTPUT_PATH_OK\n'
```

对端只在此前前台 `iperf3 -s -4 -p 5201` 的窗口按 Ctrl+C，停止自己启动的临时测试服务；用 `ss -ltnp 'sport = :5201'` 确认没有其他监听者。有其他监听者时停止，不 killall。重新执行 `date -u +%Y-%m-%dT%H:%M:%SZ` 和 `iperf3 -s -4 -p 5201`；出现监听提示后，建议 30 秒内在另一台被测 VPS 执行准备好的命令。超过此时间则先重新启动临时服务再测试，不在等待数分钟后执行。

```bash
env BENCHMARK_HOST=REPLACE_WITH_AUTHORIZED_HOST BENCHMARK_PORT=5201 BENCHMARK_SECONDS=5 BENCHMARK_OMIT_SECONDS=0 BENCHMARK_PHASE_TIMEOUT_SECONDS=20 BENCHMARK_PARALLEL=1 BENCHMARK_IP_FAMILY=4 BENCHMARK_DIRECTION=upload BENCHMARK_RATE_CAP_MBPS=1 BENCHMARK_ENFORCE_RATE_CAP=1 BENCHMARK_RUN_ID=rc17-protocol-check-02 BENCHMARK_OUTPUT_DIR=/root/dvt-benchmark-protocol-20260924-02 DVT_TRAFFIC_BUDGET_BYPASS=0 DVT_TRAFFIC_LEDGER=/var/lib/proxy-vps-tuning/traffic-ledgers/rc17-probe-compat-20260924.json DVT_TRAFFIC_WINDOW_ID=rc17-probe-compat-20260924 DVT_TRAFFIC_BUDGET_BYTES=268435456 dvt benchmark
```

计划量仍为 625000 bytes；只执行一次，保留服务端同期输出。成功仅支持监听等待时间相关假设，不排除瞬态网络恢复，更不证明根因彻底解决；若仍失败，读取原始结果并转入有界的两端包头/连接状态观察，不连续重试。账本历史、100GB 总授权边界和临时服务/来源限定 UFW 规则的清理方式不变。Agent 未远程执行这些步骤。

## 4C. 测试正常结束但接收统计为零：两端同步观察

现场第 02 次诊断：服务端 06:21:20 UTC 启动，客户端 06:21:30 开始，约 5 秒测试正常结束；发送统计 262144 bytes、28 次 retransmits，接收 bytes/bps 均为 0，原始 error=null。rc.17 的 summary 校验要求 received.bytes > 0，因此产生 `invalid summary fields`、最终 FAIL/5。这不是 JSON 语法错误，不能通过放宽校验把它变成有效样本。重新启动服务消除了本次提前超时，但不足以解释或解决数据异常，也不能单次证明旧故障根因。

候选解释按当前证据排序：数据或 ACK 路径停滞；接收进程未完成读取或统计；低速发送/块读取节奏的影响。接收统计为零不证明内核一字节未收，发送 write 统计也不等于交付。需要比较数据流的 TCP sequence/ACK、窗口与重传，不能只看控制连接或用两个接口抓到的包数量判断丢包（GSO/GRO 可改变可见分段）。

下一次测试保持 1 Mbps/5 秒/20 秒硬上限及原账本，只增加两端观测。准备四个 SSH 窗口：被测端运行命令和抓包各一个，对端运行临时服务和抓包各一个。先在两台机器分别执行 `command -v tcpdump`；缺少工具则先停止，不在无观测条件下重复测速。沿用第 4B 节账本检查，确认 OPEN、reserved=0、remaining>=625000；新 benchmark 输出目录换为 `/root/dvt-benchmark-protocol-20260924-03`，必须不存在。

先停止自己此前开启的临时前台 iperf3（Ctrl+C），核对 TCP 5201 没有其他监听者。两端抓包各使用新的私有目录，下面命令在 subshell 内运行，目录存在即停止，不覆盖。替换 `REPLACE_WITH_PEER_IPV4`：被测端填对端地址，对端填被测端地址。两台都执行；命令同时显示并记录包头文本和 tcpdump 自身统计，不使用 `-w`、`-A` 或 `-X`，不导出 payload 或协议 cookie。

```bash
(
  umask 077
  mkdir -m 700 /root/dvt-protocol-capture-20260924-03 &&
  env TZ=UTC timeout --signal=INT --kill-after=3s 60s tcpdump -p -i any -nn -tttt -S -K -s 128 -c 2000 'ip and host REPLACE_WITH_PEER_IPV4 and tcp port 5201' 2>&1 | tee /root/dvt-protocol-capture-20260924-03/headers.txt
)
```

两端出现 `listening on any` 后，在服务窗口重新启动 `iperf3 -s -4 -p 5201`，随后立即在被测端执行下面单次命令。必须在两端抓包仍运行时完成；60 秒或 2000 包上限只限制观测，不增加流量。若准备时间耗尽或 tcpdump 报错，不无观测补测，先回传状态。

```bash
env BENCHMARK_HOST=REPLACE_WITH_AUTHORIZED_HOST BENCHMARK_PORT=5201 BENCHMARK_SECONDS=5 BENCHMARK_OMIT_SECONDS=0 BENCHMARK_PHASE_TIMEOUT_SECONDS=20 BENCHMARK_PARALLEL=1 BENCHMARK_IP_FAMILY=4 BENCHMARK_DIRECTION=upload BENCHMARK_RATE_CAP_MBPS=1 BENCHMARK_ENFORCE_RATE_CAP=1 BENCHMARK_RUN_ID=rc17-protocol-check-03 BENCHMARK_OUTPUT_DIR=/root/dvt-benchmark-protocol-20260924-03 DVT_TRAFFIC_BUDGET_BYPASS=0 DVT_TRAFFIC_LEDGER=/var/lib/proxy-vps-tuning/traffic-ledgers/rc17-probe-compat-20260924.json DVT_TRAFFIC_WINDOW_ID=rc17-probe-compat-20260924 DVT_TRAFFIC_BUDGET_BYTES=268435456 dvt benchmark
```

回传两个 headers.txt（明确客户端/服务端归属，含末尾 dropped by kernel）、服务端同期日志，以及新 raw 的 error/test_start/sum_sent/sum_received 摘要。包头文本仍含双方地址与端口，只在本次私有诊断中使用，不提交公共仓库。观察到包出现在一端而另一端没有时，须先检查捕获是否覆盖、是否丢包及 offload 差异，不能直接认定服务商过滤；若服务端持续 ACK 而 iperf 统计仍为零，再收窄到接收/统计路径。Agent 尚未执行远程观测，不改变 UFW、sysctl、MTU、qdisc 或版本。完成后 Ctrl+C 停止自己的临时服务，并按前文规则清理本次新增的来源限定 UFW 放行；保留诊断文件与账本。

## 4D. 包头证实部分数据已确认，先定位本机与外部路径

第 03 次双端文本完整解析：客户端 108 条、服务端 111 条，与各自 footer 一致，均报告 dropped by kernel=0。按测试流端口、TCP sequence/ACK、TSval/TSecr 与 SACK 对齐，不按两端包数判断丢包；两端时钟有偏差，不能直接相减计算单向延迟。

- 去掉测试流 37-byte cookie 后，最终累计 ACK 对应 73848 bytes 测试数据；最后 SACK 还声明收到相对区间 [75296,86880)，但 [73848,75296) 仍有一个 1448-byte 缺口。接收窗口持续非零，因此不是完全没有收到数据或零窗口卡住。
- 数据流服务端记录 37 条纯 ACK，客户端为 25 条；精确包头比较有 12 条服务端已发 ACK 未出现在客户端文本中。这是本次观测缺失数，不是链路丢包率。服务端 SACK 与重传/重复确认共同支持传输推进存在异常；尚不能定位为云厂商、防火墙、物理链路或虚拟网卡故障。
- 原始结果为发送 131072 bytes、54 次 retransmits、接收统计 0、error=null。iperf3 3.18 的 TCP 接收路径循环读取 131072-byte 块后才更新统计，且仅在 TEST_RUNNING 状态计数；本次累计确认量不足一个块，零应用统计与“部分数据已经被 TCP 接受”相容。未跟踪接收线程，仍不是完整的进程级根因证明。末尾 FIN/RST 出现在测试结束之后，不作为初始失败原因。

下一步暂停主动测速，两台 VPS 分别执行同一只读采集块。已知本次双方抓包接口为 eth0；执行前分别运行 `id -u`（应为 `0`）和 `ip -br link show dev eth0`（应显示该接口）。如果 `/root/dvt-path-readonly-20260924-04/state.txt` 已存在，先回传已有文件，不重跑、不覆盖；若目录存在但文件缺失，停下说明现状。新私有目录不存在时才运行下方采集块。命令只读网络状态并保存本地文本，不安装依赖或更改系统配置。个别工具缺失或 filter 不存在时保留错误并继续其余采集，不把缺失工具当作“无规则”。

```bash
(
  umask 077
  mkdir -m 700 /root/dvt-path-readonly-20260924-04 || exit 1
  set +e
  {
    printf '\n[utc]\n'
    date -u +%Y-%m-%dT%H:%M:%SZ
    printf '\n[ufw]\n'
    ufw status verbose
    printf '\n[iptables-backend]\n'
    iptables --version
    printf '\n[nft-ruleset]\n'
    nft -a list ruleset
    printf '\n[iptables-ipv4-counters]\n'
    iptables-save -c
    printf '\n[link]\n'
    ip -s -d link show dev eth0
    printf '\n[qdisc]\n'
    tc -s -d qdisc show dev eth0
    printf '\n[class]\n'
    tc -s -d class show dev eth0
    printf '\n[root-filters]\n'
    tc -s -d filter show dev eth0 root
    printf '\n[ingress-filters]\n'
    tc -s -d filter show dev eth0 ingress
    printf '\n[egress-filters]\n'
    tc -s -d filter show dev eth0 egress
    printf '\n[offload-features]\n'
    ethtool -k eth0
  } > /root/dvt-path-readonly-20260924-04/state.txt 2>&1
  cat /root/dvt-path-readonly-20260924-04/state.txt
)
```

回传时标明客户端/对端归属；规则可能含其他服务地址，仅用于私有诊断，不提交公开仓库。用户已说明厂商为 VMISS、未启用控制台安全组及 DDoS 清洗、带宽限制为 200 Mbps；这尚未经过控制台独立核实，也不证明平台没有默认策略。静态规则和累计计数不能证明某规则在第 03 次测试中命中；据具体规则再选择最窄的计数差分或定向观测。未定位前不关闭 UFW、不改 MTU/BBR、不禁用 offload，也不先升级 dvt/iperf3 或扩大测速预算。

## 4E. 两端静态快照后的单次速率对照

2026-09-26 用户提供的两端 `state.txt` 均显示 UFW active、默认入站 deny/出站 allow；对端存在只允许被测端访问 TCP 5201 的临时入站规则，其累计计数为 7 个包。双方接口为 virtio `eth0`、MTU 1500、root `fq`、链路 RX/TX errors 与 dropped 均为 0；`tc` class/filter 查询为空。对端 `fq` 的 `dropped 52`、`horizon_drops 4` 是长期累计数，与第 03 次测试没有同期差分，不能归因于本次 iperf3。Fail2ban 的 nft 规则只匹配 SSH 22。UFW 的 conntrack established 接受路径与既有双端 TCP ACK 相符；静态快照不能证明第 03 次所有包通过。

由于双端抓包已确认部分测试数据和 ACK 到达，但 1 Mbps/5 秒的 131072-byte 数据块未完成，下一步只把测试速率从 1 Mbps 改为 10 Mbps，其他参数保持一致，计划 payload 为 6250000 bytes（约 5.96 MiB）。此试验区分低速节奏/块完成问题与跨速率持续传输故障；即使成功也不能据此认定路径完全无丢包或直接进入生产调优。仍使用原 ledger/window，不清零失败的保守记账。

被测端先核对原账本为 OPEN、reserved=0、剩余至少 6250000 bytes，且新输出目录不存在：

```bash
jq '{status,budget_bytes,reserved_bytes,accounted_bytes,remaining_bytes:(.budget_bytes-.reserved_bytes-.accounted_bytes),last_entry:.entries[-1]}' /var/lib/proxy-vps-tuning/traffic-ledgers/rc17-probe-compat-20260924.json
test ! -e /root/dvt-benchmark-rate-20260926-04 && test ! -L /root/dvt-benchmark-rate-20260926-04 && printf 'NEW_OUTPUT_PATH_OK\n'
```

对端确认临时来源限定的 UFW 5201 规则仍存在，并在自己运行的前台 iperf3 窗口按 Ctrl+C。`ss -ltnp 'sport = :5201'` 应无其他监听者；再运行 `iperf3 -s -4 -p 5201`。服务出现监听提示后尽量在 30 秒内执行下面唯一一次测试。若规则已清理，先停止并核对，不临时开放 Anywhere。若 5201 被其他进程占用，先停止，不 killall。

```bash
env BENCHMARK_HOST=REPLACE_WITH_AUTHORIZED_HOST BENCHMARK_PORT=5201 BENCHMARK_SECONDS=5 BENCHMARK_OMIT_SECONDS=0 BENCHMARK_PHASE_TIMEOUT_SECONDS=20 BENCHMARK_PARALLEL=1 BENCHMARK_IP_FAMILY=4 BENCHMARK_DIRECTION=upload BENCHMARK_RATE_CAP_MBPS=10 BENCHMARK_ENFORCE_RATE_CAP=1 BENCHMARK_RUN_ID=rc17-rate-check-04 BENCHMARK_OUTPUT_DIR=/root/dvt-benchmark-rate-20260926-04 DVT_TRAFFIC_BUDGET_BYPASS=0 DVT_TRAFFIC_LEDGER=/var/lib/proxy-vps-tuning/traffic-ledgers/rc17-probe-compat-20260924.json DVT_TRAFFIC_WINDOW_ID=rc17-probe-compat-20260924 DVT_TRAFFIC_BUDGET_BYTES=268435456 dvt benchmark
```

仅执行一次。回传服务端同期输出与客户端终端的失败/完成摘要，并读取：

```bash
jq '{status,exit_code,upload:.phases.upload}' /root/dvt-benchmark-rate-20260926-04/benchmark-result.json
jq '{error:(.error // null),test_start:.start.test_start,sum_sent:.end.sum_sent,sum_received:.end.sum_received}' /root/dvt-benchmark-rate-20260926-04/upload.iperf3.json
```

成功只证明在该次条件下接收端形成有效统计，后续仍须检查 retransmits 和接收速率；失败则停止，依据新症状决定是否进行更窄的包头/规则计数差分。当前快照无证据支持更改 UFW、MTU、offload、qdisc、BBR 或升级工具。

## 4F. 10 Mbps 对照结果与停测点

第 04 次对照的客户端原始 iperf3 JSON：目标为 10 Mbps/5 秒/单流上传，`test_start` 存在、`error=null`，但 `sum_sent.bytes=262144`、`sum_sent.bits_per_second≈419295`、`retransmits=54`，`sum_received.bytes=0`。dvt 拒绝零接收统计，最终 FAIL/5；输出目录有 `INCOMPLETE`、无 `COMPLETED`。本地对提供的文件检查：SHA256SUMS 中 18 项全匹配，清单自身摘要与结果 JSON 一致。这证明失败证据文件一致，不证明该 benchmark 有效。客户端 TCP 计数增量包含 54 次 retransmits、21 次 lost retransmit、6 次 timeout；eth0 RX/TX errors/dropped、softnet dropped/time_squeeze 与 root fq dropped 增量均为 0。

与第 03 次 1 Mbps 对照相比，速率提高十倍未得到有效接收统计，且第 04 次实际发送仍约 0.419 Mbps。仅由 1 Mbps 过低造成失败的解释不成立；发送目标是应用 pacing 参数，不是实际链路速率。当前仍不能从客户端文件判定第 04 次对端收到的具体字节数，也不能确认该次服务端错误或最终账本结算。停止重复同条件测速与完整 probe。

下一步仅取现有只读信息：对端第 04 次（约 2026-09-26 14:43 UTC）前台 iperf3 的同期输出；被测端原账本最新状态。服务端前台输出若已丢失，标注“不可取得”，不要为了补日志重新测速。账本可运行：

```bash
jq '{status,budget_bytes,reserved_bytes,accounted_bytes,remaining_bytes:(.budget_bytes-.reserved_bytes-.accounted_bytes),last_entry:.entries[-1]}' /var/lib/proxy-vps-tuning/traffic-ledgers/rc17-probe-compat-20260924.json
```

第 04 次测试前已知 `remaining_bytes=79060456`，但之后的实际 ledger 未提供；保守结算是否发生及当前余额须以上述输出为准。服务端日志收到后，再决定是否需要更窄的路径观察或方向对照。不得把失败目录交给离线校准器作为完整 probe。

## 4G. 更换已授权对端后的独立受限验证（2026-09-27）

用户改用另一台自控 iperf3 对端；这是新的端到端路径，不是第 04 次失败的无条件重试。先按第 3–4 节核对被测端 VERIFIED、实际出口 IPv4、对端 iperf3/UFW/云侧规则与服务商流量余量。对端的 dvt rc.16 不需要为接收 iperf3 流量而升级；不要修改任一机器的 sysctl、qdisc 或受管状态。

原窗口 `rc17-probe-compat-20260924` 的已记账量必须保留。先只读确认原 ledger 无未结算预留并记录当前 `accounted_bytes`；它的剩余额度已不足以容纳最小完整 probe。新对端是用户明确授权的另一场测试，可使用独立的 `rc17-alt-peer-20260927` 窗口和 256 MiB ledger，但新窗口不豁免原窗口的用量，也不提高用户授权的总流量上限。新窗口首次运行前确认文件和输出目录均不存在；若已存在，停止核对，不能覆盖或另换名字规避账本。

先只做一次 10 Mbps、5 秒、单流 IPv4 上传的受账本约束 benchmark，计划 payload `6250000` bytes。它用于确认 iperf3 会话、数据到达和结果文件闭合；需要 `COMPLETED`、`status=PASS`、upload receiver bytes 大于 0，且没有原始 iperf3 error。还须人工复核接收吞吐、重传和服务端日志；若再次出现明显低速或大量重传，即使 `PASS` 也停止，不运行完整 probe。冒烟通过复核后核对同一 ledger 为 OPEN、`reserved_bytes=0`、`remaining_bytes≥187500000`，再按第 5 节的参数运行一次 100 Mbps、三样本、每样本 5 秒上传 probe，计划 payload `187500000` bytes。两次命令必须指向同一个新 ledger/window/budget；第 5–8 节示例中的旧窗口和目录名须替换为本次实际值。

预算是应用 payload 计划值，不包括协议开销、重传和服务商计费差异。任一步失败即保留 `INCOMPLETE` 与保守账本记录，不重试、不清零、不把失败目录交给离线校准器。成功目录按第 6–8 节完整校验、私有导出并用本地 0.1.1 分析器只读核验；单一路径兼容通过不能证明 tcpfit 的 policer 拐点、缓冲收益或代理业务性能。

本次实际结果：新对端一次冒烟和三次 probe 均形成有效接收统计，三次 probe 的接收中位数约 99.989 Mbps、发送端重传均为 0。完整证据已通过本地校准器 0.1.1 的 rc.17 格式/摘要契约。初次未确认路径代表性时报告 `INSUFFICIENT_EVIDENCE`；用户随后明确确认主要 VPS 出向路径代表性，在**同一份证据**上重跑离线分析后得到 `KEEP_CURRENT_CEILING`，候选上限与当前值同为 16 MiB，不需修改。候选 target RTT 20 ms 是工具下限，负载期间实测最小 RTT 中位数为 0.844 ms；100 Mbps 限速采样不能证明 200 Mbps 套餐上限或限速器拐点。旧对端故障原因仍未知；无需为取得更高吞吐或自动整形结论继续测速。对端服务和临时 UFW 规则已按用户输出收尾；被测端窗口 `reserved_bytes=0`，两笔记录均 `COMMITTED`，工具 payload 记账合计 193855488 bytes，剩余 74579968 bytes。旧失败账本应继续保留，不因新窗口成功而清零。

## 5. 被测 VPS：先计划，确认预算后才采集

建议首次仅检验上传方向：100 Mbps、单流、3 个样本、每样本 5 秒、无预热。预计 payload：

`100 × 125000 × 5 × 3 = 187500000 bytes ≈ 178.81 MiB`。

示例账本窗口为 256 MiB（268435456 bytes），一次采集预算充足，远低于本轮已授权的 100GB 总上限；结果使用本地分析器 0.1.1 核验。业务流量、协议开销、重传和服务商计费差异不包含在该数值中，iperf3 pacing 和账本也不是物理链路硬限流。须同时查看服务商剩余额度并留出这些开销。此选择用于控制兼容性采集成本，不用于推导套餐容量或 policer。

同一维护窗口内所有主动流量工具必须共享同一个 ledger、window-id 和预算。已有窗口时，把下面变量替换为它的真实值，并先核对剩余预算；不能另建账本绕过已用额度。没有既有窗口且新窗口已获批准时，首次运行会创建 ledger，无需手写 JSON。

在现有 root 提示符下运行下面的独立单行命令。将 `REPLACE_WITH_AUTHORIZED_HOST` 替换为自控对端的实际地址，5201 替换为它的监听端口。IPv6 则把 family 4 改为 6。不要复制提示符、反斜杠转义的下划线或 `&#x20;` 等富文本标记。

以下两条命令是首次采集时的历史示例，不得原样重跑：旧窗口 `rc17-probe-compat-20260924` 已有保守记账，剩余额度不足以容纳同规模 probe，示例输出目录也已使用。若将来确有新采集需求，须先核对共享窗口的实际 ledger、已用与剩余额度，并使用尚不存在的新输出目录；不删除原目录或账本。

```bash
dvt probe --host REPLACE_WITH_AUTHORIZED_HOST --server-port 5201 --rate-cap 100 --samples 3 --seconds 5 --omit 0 --parallel 1 --direction upload --family 4 --budget-mib 256 --ledger /var/lib/proxy-vps-tuning/traffic-ledgers/rc17-probe-compat-20260924.json --window-id rc17-probe-compat-20260924 --output-dir /root/dvt-probe-compat-20260924-upload-01 --plan-only
```

预期显示 `planned payload: 187500000 bytes`，不会创建采集目录或产生测速流量。注意 `--plan-only` 在账本 reserve 前返回，**不能证明账本剩余预算、端点可达性或接收端授权**。现有账本的版本、窗口和预算必须匹配当前安装及参数；不匹配时停止，不升级或删除账本。

确认对端、时段、应用预算和计费余量后，才执行下面这一步，它会产生主动 TCP 流量并写入证据和账本：

```bash
dvt probe --host REPLACE_WITH_AUTHORIZED_HOST --server-port 5201 --rate-cap 100 --samples 3 --seconds 5 --omit 0 --parallel 1 --direction upload --family 4 --budget-mib 256 --ledger /var/lib/proxy-vps-tuning/traffic-ledgers/rc17-probe-compat-20260924.json --window-id rc17-probe-compat-20260924 --output-dir /root/dvt-probe-compat-20260924-upload-01
```

交互提示再次核对计划后输入 `y`；本单保留此确认，不加 `--yes`。上传指被测 VPS 向对端发送数据；测量时间合计约 15 秒，连接和快照会增加总耗时。期间不改配置、不重启、不运行其他测速或 HTB 实验。终端出现错误、连接失败或业务受影响时停止；不要自动重试。

第一次不需要下载或双向测试。后续若确需下载证据，另行核算同一窗口余量、使用新的 output-dir，保持 ledger 不变。当前 256 MiB 示例窗口通常不足以完成第二次同规模采集。不能只改 direction 为 both：其计划 payload 变为 375000000 bytes（约 357.63 MiB），会超过本例窗口。

## 6. VPS：核验完成状态、打包并记录传输摘要

本次新采集后，先单独执行 `OUT='/root/dvt-probe-compat-20260924-upload-01'`。已有证据或更改了输出目录时，改为实际完整目录，不得指向合成 demo。不要依赖前一会话中的 OUT 变量。以下检查失败均停止。清单校验只证明文件内部一致，采集来源仍须由操作者确认。

```bash
test -d "$OUT"
test -f "$OUT/probe-result.json"
test -f "$OUT/COMPLETED"
test ! -e "$OUT/INCOMPLETE"
(cd "$OUT" && sha256sum -c SHA256SUMS)
for sample_dir in "$OUT"/sample-*; do
  test -d "$sample_dir"
  test -f "$sample_dir/COMPLETED"
  test ! -e "$sample_dir/INCOMPLETE"
  (cd "$sample_dir" && sha256sum -c SHA256SUMS)
done
jq '{schema_version,probe_version,status,profile,
  samples:(.samples|length),aggregates}' "$OUT/probe-result.json"
ARCHIVE="${OUT}.tar.gz"
test ! -e "$ARCHIVE"
test ! -L "$ARCHIVE"
tar -czf "$ARCHIVE" -C "$(dirname "$OUT")" "$(basename "$OUT")"
sha256sum "$ARCHIVE"
printf 'archive=%s\n' "$ARCHIVE"
```

本例应有 3 个 sample 子目录、3 条 upload 行；`download` aggregate 为 null 是正常的。顶层 `REVIEW_REQUIRED` 表示待复核；`REVIEW_BLOCKED` 仍可保存并离线分析，但不能当作有效调优建议。不要改 JSON、marker、mtime 或摘要来让验证通过；不得把 `INCOMPLETE` 改名为 `COMPLETED`。

如刚采集过，再用 `jq` 查看第 5 节所指定账本的汇总，确认保留/结算情况。失败或中断可能按计划量记账，未结算 reservation 仍占额度；不手动清零。原目录和压缩包可能含地址、路径和路由信息，按私有诊断证据保存，不上传公开 Issue。

## 7. Windows：下载、校验、解包

使用你现有且能够读取该归档的 SSH/SFTP 管理方式复制。下列 PowerShell 7 示例假设已配置相应 SSH Host alias 和归档读取权限；不要为方便下载开放 root 登录、修改 SSH 认证或把目录改成 world-readable。若普通管理账号不能读取 `/root`，由管理员将归档复制到该账号可读的私有目录，再调整远端路径。

```powershell
$SshTarget = 'REPLACE_WITH_EXISTING_SSH_ALIAS'
$RemoteArchive = '/root/REPLACE_WITH_RUN_NAME.tar.gz'
$RunName = 'REPLACE_WITH_RUN_NAME'
$ExpectedArchiveSha = 'REPLACE_WITH_SHA256_FROM_VPS'
$ReviewDir = Join-Path 'D:\Evidence' $RunName
if (Test-Path -LiteralPath $ReviewDir) { throw '请使用新的接收目录，避免覆盖已有证据' }
New-Item -ItemType Directory -Path $ReviewDir -ErrorAction Stop | Out-Null
$Archive = Join-Path $ReviewDir ($RunName + '.tar.gz')
scp "${SshTarget}:$RemoteArchive" $Archive
if ($LASTEXITCODE -ne 0) { throw '下载失败' }
if ((Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash -ine $ExpectedArchiveSha) {
    throw '传输摘要不符，停止解包和分析'
}
tar -tzf $Archive
if ($LASTEXITCODE -ne 0) { throw '压缩包目录读取失败' }
```

确认清单只有预期的相对顶层目录及其文件，没有意外绝对路径、`..` 或链接条目后解包。只解包自己从上述流程取得且摘要一致的归档。

```powershell
$ExtractDir = Join-Path $ReviewDir 'extracted'
New-Item -ItemType Directory -Path $ExtractDir -ErrorAction Stop | Out-Null
tar -xzf $Archive -C $ExtractDir
if ($LASTEXITCODE -ne 0) { throw '解包失败' }
$Evidence = Join-Path $ExtractDir $RunName
if (-not (Test-Path -LiteralPath (Join-Path $Evidence 'probe-result.json'))) {
    throw '证据目录层级不正确'
}
```

也可以只把私有完整目录的本地路径交给本任务，由 Agent 执行以下只读核验；无需粘贴原始 JSON 或 SSH 凭据。

## 8. Windows：离线运行，区分兼容与候选结论

在本项目完整源码目录运行。用 `git rev-parse HEAD` 记录分析器所在提交；若工作树有未提交改动，再结合 `git status --short` 和 `Get-FileHash tools/calibrate_probe.py` 绑定实际字节。`python --version` 应为 Python 3.10+。rc.17 必须使用分析器 0.1.1，原合并提交的 0.1.0 不支持；不必在 VPS 安装 Python。

第一次不加 `--representative-path`，只核对完整性和真实格式兼容性。下列命令沿用第 7 节 PowerShell 变量，输出放在证据目录之外，并核对分析前后文件摘要：

```powershell
git rev-parse HEAD
python --version
function Get-ProbeFileHashes([string]$Root) {
    Get-ChildItem -LiteralPath $Root -File -Recurse -Force |
        Sort-Object FullName | ForEach-Object {
            $_.FullName.Substring($Root.Length) + ' ' +
                (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
}
$Before = @(Get-ProbeFileHashes $Evidence)
$Report = Join-Path $ReviewDir 'calibration-compatibility.json'
$ErrorReport = Join-Path $ReviewDir 'calibration-compatibility.stderr.txt'
if ((Test-Path -LiteralPath $Report) -or (Test-Path -LiteralPath $ErrorReport)) {
    throw '报告已存在，请使用新的报告名'
}
python tools/calibrate_probe.py --evidence $Evidence --path-label path-a > $Report 2> $ErrorReport
$AnalyzerExit = $LASTEXITCODE
$After = @(Get-ProbeFileHashes $Evidence)
if (Compare-Object $Before $After) { throw '输入文件集合或摘要发生变化' }
"Analyzer exit code: $AnalyzerExit"
if ($AnalyzerExit -ne 0) {
    Get-Content -LiteralPath $ErrorReport
} else {
    $Result = Get-Content -LiteralPath $Report -Raw | ConvertFrom-Json
    $Result | Select-Object status,configuration_changed,source_script_version,profile,observed_age_hours
    $Result.directions | Select-Object direction,samples,decision,issues,
        candidate_target_rtt_ms,candidate_buffer_max_bytes
}
```

| 观察 | 结论与下一步 |
|---|---|
| 退出 0，JSON 可读，原文件摘要未变 | 该目录通过输入契约；这一次真实格式兼容性核验完成 |
| `PATH_REPRESENTATIVENESS_NOT_ACKNOWLEDGED` | 首次不加代表性确认的预期结果，不是兼容性失败 |
| `SENDER_RTT_UNAVAILABLE` / 无效窗口 / 漂移等 | 输入可读但证据不足；保留结果，查实际字段和环境，不自动重新测速 |
| `EVIDENCE_TIME_OUTSIDE_POLICY` | 老证据仍可用于格式兼容性，不能据此形成当前建议；不改时间戳 |
| 退出 2、没有完整 JSON | 完整性或契约不满足；提供 stderr、版本及完整目录，先分析原因 |
| 其他退出码或 Python/命令缺失 | 执行环境未就绪，不能报告校准器兼容性结论 |

只有确认该对端代表拟评估的路径时，才以**同一份证据**再次离线运行，增加 `--representative-path` 并写另一个新报告；不会新增网络测试。默认时效 24 小时，历史证据可在有理由时显式使用 `--max-age-hours 168`（最大 7 天），但不能借此声称旧路径代表当前路径。无需为取得非空候选而强行确认代表性。

候选状态及 RTT/BDP 含义以[实测校准说明](measured-calibration.md)为准。`EXPERIMENT_CANDIDATE` 只是后续单变量实验输入；本单不提供 apply/reconfigure 指令，也不开始 HTB、重启或全生命周期验证。

## 9. 中断、保留及回传内容

主动 probe 期间业务受影响可按 Ctrl+C；保留完整输出目录和账本，检查 `INCOMPLETE` 及 `pgrep -a iperf3` 的本地输出。不要使用 `pkill iperf3` 或手删锁文件；若观察到遗留进程，先核对本次 PID/进程组再处理。脚本的超时及回收门禁有 CI 证据，但目标机信号中断仍不在本次已验证范围内。

本流程未调整 sysctl、qdisc 或受管参数，因此没有调优配置回滚步骤。只需停止本次临时 iperf3 服务，撤销自己新增的临时规则；保留证据与预算记账，不自动删除。若自行额外安装过依赖或改变防火墙，按该项变更自己的恢复方案处理。

回传本任务：实际 dvt/iperf3 版本、profile、采集方向/次数、是否完整、原始目录本地路径、分析器退出码和报告路径。可以先只提供第 3 节脱敏检查结果；对端地址和凭据无需公开。Agent 随后核对真实输入、异常原因和 CPU/队列上下文，记录最高已达到的证据层级；不会自动应用候选。
