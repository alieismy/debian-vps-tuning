# 验证说明

## 证据分层

验证结果必须分为：

1. 本地静态检查；
2. 同源模板与六个操作系统/内存变体的一致性；
3. 目标 VPS 运行、重启和回滚；
4. 3X-UI/Xray 与客户端业务连接。

前三项不能相互替代。静态检查通过不证明 BBR、qdisc、swap、重启持久性或代理连接成功。

## 总控入口验证矩阵

`debian-vps-tuning.sh` 只负责选择、校验和调用，但它决定最终执行哪一份 root 脚本，因此必须独立验证。控制器通过不代表目标 profile 或 VPS 生命周期通过。

| ID | 场景 | 预期结果 | 当前状态 |
|---|---|---|---|
| C1 | Debian 12/13，1 vCPU，384/512/767 MiB | 选择对应 `1c512m` profile，资源档 `1C512MB` | fixture 通过 |
| C2 | Debian 12/13，1 vCPU，768/1024/1535 MiB | 选择对应 `1c1g` profile，资源档 `1C1GB` | fixture 通过 |
| C3 | Debian 12/13，1 vCPU，1536/2048 MiB | 选择兼容 `1c2g` profile，资源档 `1C2GB` | fixture 通过 |
| C4 | Debian 12/13，2 vCPU，1536/2048 MiB | 选择兼容 `1c2g` profile，资源档 `2C2GB` | fixture 通过 |
| C5 | 非 Debian、非 amd64、超范围内存、2C512、2C1G 或 3C2G | 返回不支持，不调用 profile | fixture 通过 |
| C6 | 交互带宽直接 Enter | 使用 200 Mbps | fixture 通过 |
| C7 | `--port` 和 `PORT_SPEED_MBPS` | 只接受 100–1000，显式参数优先 | fixture 通过 |
| C8 | 清单缺失、重复条目、哈希不匹配 | 返回完整性错误，不调用 profile | fixture 通过 |
| C9 | curl 失败、404、超时或中断 | 返回下载错误，不回退其他来源 | fixture 通过；目标 VPS 的真实下载失败路径未注入 |
| C10 | profile 返回非零 | 控制器返回同一退出码 | fixture 通过 |
| C11 | `guided` | preflight 通过后询问；N/Enter 不 apply | rc.9 Debian 13 1C1G/1000 Mbps 的确认后 apply 路径通过；拒绝路径 fixture 通过 |
| C12 | 菜单 `apply` | 再次确认；N/Enter 不 apply | 目标 VPS 待测 |
| C13 | 无 TTY 且无 action | 返回 usage，不等待输入 | 目标 Linux 待测 |
| C14 | 状态档位与检测档位不一致 | 阻断，不自动换 profile | fixture 通过；目标 VPS 待测 |
| C15 | 固定 rc.12 Release assets | 下载清单和唯一 profile，SHA-256 通过 | 本地 fixture 通过；Release 尚未创建，发布后须从公开地址重下载并复核九个资产 |
| C16 | 已安装状态下无 `--port`/环境变量地重复 `apply` | 复用状态中的端口带宽；显式参数仍优先；无效状态值阻断 | fixture 通过；目标 VPS 待测 |
| C17 | `diagnose` | 默认 5 秒前后采样；输出 TCP/softnet、整机 CPU、接口和可识别 ethtool 错误增量；读取 qdisc、队列、RPS/XPS/IRQ、Xray sockopt 和代理进程 CPU time/RSS/线程/FD；无系统配置写入、无主动流量、无进程命令行 | CPU/接口增量 fixture 与结构检查通过；目标 VPS 待测 |
| C18 | `benchmark` 未提供 host、无 iperf3、无效端口/时长/预热/并行/地址族/run ID，或输出目录非绝对路径/已经存在 | 明确拒绝；不覆盖旧证据，不安装软件、不改防火墙、不选择公共服务器 | 参数和输出目录 fixture 通过；目标 VPS 待测 |
| C19 | 用户授权的 `benchmark` | 仅向指定 iperf3 服务端执行 upload/download/both；并行 1–4；可固定 IPv4/IPv6；每方向保存原始 JSON、sender 吞吐/重传/每 GiB 重传、host-wide TCP/接口增量；校验 sender/receiver 实际秒数、bytes/seconds/bitrate 算术及跨端字节容差；qdisc 存在 leaf 时用 leaf、否则用 root；以 `INCOMPLETE → COMPLETED` 提交总结果及哈希链；采集 PASS 与窗口可分析性分离 | schema 2 有效窗口、脱敏的异常 receiver 窗口、空/损坏 JSON、缺失/负计数器、mq leaf 和 manifest 失败终态 fixture 通过；目标 VPS 待测 |
| C20 | `update` 自动发现/`--target` | 同一 `major.minor` 内，rc 通道可选更高 rc 或稳定版，稳定通道排除 prerelease；显式目标允许跨线或 prerelease；拒绝降级和重复升级 | 版本优先级、稳定/rc 通道、非法版本 fixture 通过；GitHub API 真实查询待测 |
| C21 | `update` 只读升级检查 | 校验当前/目标资产，当前 verify、目标 `UPDATE_PREFLIGHT=1 preflight` 通过后输出固定 URL、哈希、端口和人工迁移顺序；不得调用 rollback/purge/apply/reboot | 调用顺序 fixture 与真实 `check_preflight_state` 状态矩阵通过；目标 VPS 只读 update 待测 |
| C22 | `/etc/sysctl.d` 等外部文件以相同值重复定义受管 key | `preflight`/`apply` 阻断；已安装状态的独立 `verify` 返回非零；`diagnose` 只读报告；项目自身文件及其符号链接不误报 | 同值冲突、受管文件别名和外部别名去重 fixture 通过；目标 VPS 负向注入不在生产机执行 |
| C23 | 旧总控与新版本 `SHA256SUMS`/profile 同目录 | 返回完整性错误，提示可能混用不同 Release 并要求独立目录；不得联网回退或修改系统 | 混合版本目录 fixture 通过；Debian 13 rc.9→rc.10 实测安全拒绝并通过隔离目录恢复 |
| C24 | `diagnose`/`benchmark` 在 `INT`/`TERM` 或其他异常中断 | 返回非零/对应信号退出码；临时模式只清理本次 root-only 目录，持久化 benchmark 默认保留含 stage/exit code 的 `INCOMPLETE`；只有完整提交才存在 `COMPLETED`；不触碰状态或系统配置 | manifest 失败终态 fixture 与 trap 结构检查通过；信号和目标 VPS 待测 |
| C25 | 固定 TcpQuality 证据工具 | commit、三个脚本哈希、rootfs 哈希和固定目录清单均一致；拒绝覆盖；每轮恰好一个 CSV；节点响应通过 12 列 TSV schema；保存节点/CSV 哈希、漂移、实际 URL、原始日志和最终清单；任一关键步骤失败即停止；不调用本项目 apply | pinned 校验失败、节点 schema/漂移和静态只读门禁通过；完整 rootfs 目标 VPS 待测 |
| C26 | 厂商 `/etc/sysctl.conf` 唯一且相同值的 `fq`/`bbr` 基线 | `preflight` 零写入并报告 `PASS_WITH_PROVIDER_SYSCTL_TRANSFER`；`apply` 提交 schema 4 状态后完整备份并原子迁移；`verify` 校验原始/迁移后哈希；`rollback` 恢复原文件和安装前运行值；外部修改时拒绝覆盖并保留 `DEGRADED` | 只读分类、迁移/恢复、外部修改拒绝和 schema 3 仅限 update-preflight fixture 通过；Debian 12/13 目标 VPS 生命周期待测 |
| C27 | benchmark 流量预算 | 显式 `BENCHMARK_RATE_CAP_MBPS` 优先，否则只使用合法管理状态的端口上限；按 `(seconds+omit)×方向数` 计算 payload 上界并写入元数据；该变量不向 iperf3 注入 pacing，真实限速必须由实验拓扑另行保证；无可信 cap 时报告不可估算；非法 cap 阻断 | 显式 cap、无 cap、非法 cap、单/双方向公式和持久化元数据 fixture 通过；计费流量、真实吞吐和实际限速不由该静态预算证明 |
| C28 | HTB 实验排程生成器 | 只输出 JSON；支持首轮 A/B/A、可选反向第二周期、至少 300 秒冷却及候选结论关闭后的低速 A/C/A；不得执行 qdisc、流量或持久化 | 两周期、单周期、180 Mbit/s 控制、非法冷却和非法控制速率 fixture 通过；目标机执行仍按独立 SOP 门禁 |
| C29 | HTB v0.4.0 执行器基线绑定 | 只接受 rc.12 schema 4、`VERIFIED`、200 Mbps 的 Debian 13 1C1G/1C2G；允许临时 100–200 Mbit/s，其中 200 仅用于端口额定 reference；活动状态保存实际 profile 和 managed-state SHA-256；profile/state 漂移、旧版本、超过端口或其他端口必须拒绝继续 | 两个允许 profile、100/200 边界及 profile/schema/version/port/hash/201 负向 fixture 通过；1C2G v0.4.0 目标机 smoke/A/B/A 待执行 |
| C30 | HTB reference/candidate 只读计划 | 默认 `reference-screen` 只生成 2–5 个 HTB200 样本且拒绝 `--rates`；显式 `candidate-sweep` 只接受 3–8 个唯一 100–199 Mbit/s 候选，在首尾生成相同 HTB200 reference 并正序/反序扫描；每阶段 `rate_cap_mbit == rate_mbit`，预算按实际 HTB rate/ceil 求和；不读取主机、不执行流量 | 默认 HTB200 reference、180/190/195 和自定义候选计划、schema 2、实际 HTB 预算公式及 mode/端口/重复/越界速率/样本/冷却负向 fixture 通过 |
| C31 | HTB reference/candidate runner | 要求 root 所有且 group/world 不可写的固定计划、profile、HTB 工具和分析器；只对显式 endpoint 执行 upload；每个 reference/candidate 阶段均执行 preflight→start→ACTIVE→benchmark→ACTIVE→stop→postflight，并记录 HTB 实际限速和恢复状态；失败即停并尝试受管恢复；按秒保存只含 TCP_INFO 白名单 token 的 socket 指标，不输出 endpoint/PID/进程名；不安装软件、不持久化 | Bash/schema 2 计划、mock HTB200 preflight/start/双 ACTIVE/benchmark/stop/postflight、子证据 hash、socket 隐私负向 fixture 和文档门禁通过；真实 iperf3、信号中断、watchdog 和目标 VPS qdisc 恢复待测 |
| C32 | HTB reference/candidate 分析 | 校验每阶段 COMPLETED、benchmark manifest、结果 hash 和 schema 2 测量窗口；主吞吐使用有效窗口的 sender Mbit/s，重传使用 sender retransmits/GiB，receiver 仅作交叉核对；任一无效窗口输出 `REVIEW_BLOCKED` 且 shortlist 为空；有效候选按 median/MAD 描述，不假设 MSS、不计算丢包率、不使用固定全局阈值 | 合成 `REVIEW_REQUIRED` shortlist、脱敏异常 receiver 窗口传播为 `REVIEW_BLOCKED`、缺失 COMPLETED 负向 fixture 通过；真实样本统计解释和跨窗口复验待测 |

本地检查入口：

```bash
bash tests/controller-check.sh
bash tests/static-check.sh
shellcheck -x \
  debian-vps-tuning.sh \
  debian12-1c512m-vps-tuning.sh \
  debian12-1c1g-vps-tuning.sh \
  debian12-1c2g-vps-tuning.sh \
  debian13-1c512m-vps-tuning.sh \
  debian13-1c1g-vps-tuning.sh \
  debian13-1c2g-vps-tuning.sh \
  tcpquality-evidence.sh \
  experiments/htb-aggregate/htb-aggregate-experiment.sh \
  experiments/htb-aggregate/experiment-plan.sh \
  experiments/htb-aggregate/rate-sweep-plan.sh \
  experiments/htb-aggregate/rate-sweep-run.sh \
  experiments/htb-aggregate/rate-sweep-analyze.sh \
  tests/static-check.sh \
  tests/controller-check.sh
bash experiments/htb-aggregate/tests/static-check.sh
```

发布前必须从 draft Release 下载总控、六份 profile、TcpQuality 证据工具和清单共九个资产，在与仓库不同的临时目录执行 `sha256sum -c SHA256SUMS`，再分别验证本地模式和缺少同目录 profile 时的远程模式。Release 尚未上传资产时，不得把远程下载测试标为通过。

## 首发目标机矩阵

下表是必须取得证据的目标矩阵，不是已经完成的测试结果。没有真实 VPS 回填证据前，不得把状态改为“通过”。

| ID | 系统 | 资源 | 磁盘/根文件系统 | 端口 | 内核基线 | 定位 | 状态 |
|---|---|---|---:|---:|---|---|---|
| T1 | Debian 12 | 1C1G | 10 GB / XFS | 200 Mbps | `6.1.0-51-cloud-amd64` | 主力/首要门槛 | rc.8 退出、rc.10 apply、重启严格 verify、重复 apply 通过；最终修复哈希待目标机复核 |
| T2 | Debian 12 | 1C2G | 15 GB / XFS | 200 Mbps | `6.1.0-51-cloud-amd64` | 主力/首要门槛 | 旧状态经 rc.8 profile 退出、rc.10 apply、重启严格 verify、重复 apply 通过；最终修复哈希待目标机复核 |
| T3 | Debian 13 | 1C1G | 约 10 GB / ext4 | 200 Mbps | `6.12.100+deb13-cloud-amd64` | 系统兼容 | rc.11 preflight/apply、立即与重启 verify、幂等门禁及固定 TcpQuality S1/S2 通过；rc.12 最终哈希待测 |
| T4 | Debian 13 | 1C2G | 15 GB / ext4 | 200 Mbps | `6.12.101+deb13-cloud-amd64` | 系统兼容 | rc.12 profile 哈希绑定的 preflight/apply、立即与重启后 verify、重复 apply 通过；代理与 HTB A/B/A 待执行 |
| T5 | Debian 12/13 | 1C1G | 10 GB / XFS 或 ext4 | 100 Mbps | 以实机为准 | 低带宽边界 | Debian 12 v5→rc.10 路径通过；Debian 13 rc.12 本地候选完成错误参数拒绝、purge、apply、重启 verify 和幂等门禁；最终修复哈希及严格代理验证待复核 |
| T6 | Debian 13 | 1C1G | 容量未采集 / ext4 | 1000 Mbps | `6.12.100+deb13-amd64` | 高带宽边界 | rc.9 完整退出和 swap 所有权迁移、rc.10 apply、重启严格 verify、BBR/fq/swap、重复 apply 通过；最终修复哈希待目标机复核 |
| T7 | Debian 12 | 2C2G | 以实机为准 | 200 Mbps | `6.1.x`，以实机为准 | 2C2G 资源契约 | 待执行 |
| T8 | Debian 13 | 2C2G | 以实机为准 | 200 Mbps | `6.12.x`，以实机为准 | 2C2G 系统兼容 | 待执行 |
| T9 | Debian 12 | 1C512MB | 以实机为准 | 200 Mbps | `6.1.x`，以实机为准 | 最小内存边界 | 待执行 |
| T10 | Debian 13 | 1C512MB | 以实机为准 | 200 Mbps | `6.12.x`，以实机为准 | 最小内存系统兼容 | 待执行 |

T1、T2 必须通过才能发布首个稳定版；T3、T4 是 Debian 13 稳定版门槛；T5、T6 用于确认 100–1000 Mbps 输入边界，不能用 200 Mbps 的结果代替。T7、T8 用于证明同一 `1c2g` 兼容 profile 在 2 vCPU 下的完整生命周期；T9、T10 用于证明 512 MiB 的缓冲截断、journald、swap 和 3X-UI 生命周期。本地 fixture 不能替代目标机证据。

上述目标机结果绑定测试时日志中的具体版本与 SHA-256。rc.12 不改变 rc.11 写入的 sysctl/qdisc/swap/journald/NOFILE 参数，但增加 schema 4 和厂商 sysctl 归属迁移，脚本版本和哈希也已改变，不能继承为 rc.12 目标机通过结论。当前环境没有目标 VPS 的 SSH 凭据，rc.12 最终哈希的生命周期、迁移/回滚、持久化 benchmark 和独立 TcpQuality 工具复核不能由本地 fixture 冒充，作为 Pre-release 的后续确认项保留。

## rc.12 自动缓冲矩阵

该矩阵验证的是输入算法和资源上限，不是吞吐结论。目标 RTT 为 200 ms；512M/1G/2G 的自动目标分别为 1×/1.25×/1.5×BDP，再向上取 16/32/64 MiB 档。

| 资源档 | 100 Mbps | 200 Mbps | 500 Mbps | 1000 Mbps | fixture |
|---|---:|---:|---:|---:|---|
| 1C512MB | 16 MiB | 16 MiB | 16 MiB | 16 MiB + 截断警告 | 1000 Mbps 通过；其余待补 |
| 1C1GB | 16 MiB | 16 MiB | 16 MiB | 32 MiB | 100 Mbps 目标机候选通过；500/1000 Mbps fixture 通过；200 待补 |
| 1C2GB/2C2GB | 16 MiB | 16 MiB | 32 MiB | 64 MiB | 200/500/1000 Mbps 通过；100 待补 |
| 2C2GB | 16 MiB | 16 MiB | 32 MiB | 64 MiB | 与 1C2GB 共用算法；控制器 CPU fixture 通过，目标机待测 |

rc.12 保持 rc.11/rc.10 的该矩阵。对 500/1000 Mbps 的 2G 档，rc.10–rc.12 与 rc.9 的配置可能不同，必须先通过只读 update 检查，再人工执行 rollback → reboot → preflight → apply → reboot → verify 建立新状态，不得把旧版本的 verify 结果记作当前版本。200 Mbps 主力档的数值虽不变，rc.12 的结构化 benchmark、TcpQuality 证据工具和迁移路径仍需独立运行验证。

## 每台目标机的生命周期矩阵

每一行都要分别在 T1–T10 回填“通过/失败/不适用”、执行时间、脚本 SHA-256 和脱敏证据路径。任一失败都应保留退出码和错误输出。

| 阶段 | 操作 | 关键判据 | T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| M0 | 基线采集 | OS、内核、CPU、内存、根文件系统、磁盘、双栈、qdisc、swap 可追溯 | 待执行 | 待执行 | 待执行 | rc.12 通过 | 待执行 | 部分完成，磁盘容量与地址未采集 | 待执行 | 待执行 | 待执行 | 待执行 |
| M1 | 未安装状态执行 `verify` | 退出码 5；提示先运行 `preflight`/`apply`；无系统写入 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M2 | `preflight` | 退出码 0；识别资源档和文件系统；无系统写入 | 待执行 | rc.7 通过 | 待执行 | rc.12 通过（含厂商 sysctl 迁移门禁） | rc.12 修正前候选通过 | rc.9 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M3 | `apply` | 退出码 0；状态为 `VERIFIED`；含 NOFILE drop-in，swap/qdisc 符合预期 | 待执行 | rc.7 通过 | 待执行 | rc.12 通过 | rc.12 修正前候选通过 | rc.9 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M4 | 立即 `verify` | 退出码 0；sysctl、qdisc、journald、swap、drop-in 一致 | 待执行 | rc.7 通过 | 待执行 | rc.12 通过 | rc.12 修正前候选通过 | rc.9 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M5 | 重启后 `verify` | 退出码 0；BBR、fq、sysctl、swap 持久 | 待执行 | rc.7 通过 | 待执行 | rc.12 通过 | rc.12 修正前候选通过 | rc.9 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M6 | 重复 `apply` | 退出码 0；报告无需重复写入；无重复 fstab/unit | 待执行 | rc.7 通过 | 待执行 | rc.12 通过 | rc.12 修正前候选通过 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M7 | 安装 3X-UI 后严格验证 | `REQUIRE_PROXY_SERVICE=1 verify` 通过；x-ui/Xray 运行时 NOFILE ≥ 65536 | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | rc.9 安装后及再次重启后通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M8 | VLESS + REALITY + TCP | IPv4/IPv6 按实际能力建立连接；连续传输无异常 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M9 | 普通 `rollback` | 恢复 qdisc/sysctl，删除 drop-in；脚本 swap 默认保留；状态可追溯 | 待执行 | rc.7 实际恢复通过；rc.8 后置验证待复测 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M10 | 回滚后重启 | `status` 正确；无残留 unit/sysctl/journald/drop-in | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M11 | 显式 purge | `swapoff` 成功才删除 swap/fstab 行；失败时保留证据 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M12 | 业务负载期间 `diagnose` | 采样窗口内记录 TCP/softnet/CPU/接口/ethtool 增量、qdisc 前后计数、队列/IRQ、Xray sockopt 和代理进程资源；无配置写入 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M13 | 授权 iperf3 benchmark | 单流优先；固定服务端、地址族、有效时长、预热、run ID 和新输出目录；上传/下载分别保存原始 JSON、sender 吞吐/重传/每 GiB 重传、host-wide TCP/接口与 qdisc 增量；结果 PASS、`COMPLETED` 存在、`INCOMPLETE` 不存在且两层哈希可复算；确认不当作代理业务结果 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |

状态初始化还必须覆盖 jq 构造器失败路径：状态 JSON 未成功提交时，不得创建 sysctl、journald、helper、unit 或 x-ui drop-in；脚本应删除本次进程创建的 qdisc 快照、JSON 临时文件和空状态目录，并明确报告“未写入系统配置”。

状态兼容性测试必须使用 Debian 12 的 jq 1.6 语义，至少覆盖：0 字节、仅空白、`null`、缺字段对象、多个连续 JSON 对象、jq 编译失败、jq 转换失败和有效单对象。任何无效输入都不得覆盖既有状态。不能只用 jq 1.7/1.8 的 `-e` 空输入退出码证明兼容。

rc.2 空状态的 `recover` 必须拒绝一般损坏 JSON、有效状态、仍存在项目文件、脚本 swap/fstab 行、活动 fq helper 或 qdisc 不一致；成功时只能把状态目录改名隔离，不能删除证据。

已有任何管理状态时，`preflight` 不得输出可直接应用的“通过”：`VERIFIED`/`APPLIED` 应引导执行 `verify` 或先回滚，`SWAP_RETAINED` 应引导显式 purge，其他事务状态应要求先完成 `rollback`。

独立 `preflight` 的状态阻断不得破坏重复 `apply`：相同参数且状态为 `VERIFIED` 时，`apply` 必须进入验证后无写入返回；参数不同或事务状态不允许时才阻断。

sysctl 校验应比较归一化后的字段值：内核通过 `sysctl -n` 返回的连续空格或制表符只用于显示对齐，不构成配置差异；字段数量或任一字段数值变化仍必须失败。NOFILE 审计必须把 `/proc/<PID>/limits` 的 soft/hard 两列分别输出，不能受脚本全局 `IFS` 影响。未安装 3X-UI 时，已托管 drop-in + 无服务属于正常待安装状态；安装后必须验证 `LimitNOFILESoft`、`LimitNOFILE`、主进程和直接 Xray 子进程，任一运行时 soft 或 hard limit 低于 65536 都失败。

事务阶段顺序必须为 `PREPARED → APPLYING → APPLIED → VERIFIED`。`APPLYING` 必须在首个系统文件写入前提交。`PREPARED`、`ROLLBACK_PENDING` 或 `DEGRADED` 只有在项目文件均不存在、外部 swap 未被脚本接管、当前 qdisc 与快照语义一致且原始 sysctl 已恢复时，才允许直接清理残留状态。

## qdisc 回归矩阵

自定义 qdisc 测试应在可恢复的测试 VPS 或控制台可救援环境执行。测试前后保存 `tc -j qdisc show`；比较 `kind`、`handle`、`parent` 和 `options`，不能只看 qdisc 名称。

| ID | 初始拓扑 | apply 预期 | rollback 预期 | 状态 |
|---|---|---|---|---|
| Q1 | 根 `fq`，含非默认参数 | 不执行 replace，参数不变 | 不执行 replace，参数不变 | 待执行 |
| Q2 | 根 `fq_codel`，仅含受支持参数 | 切换为 `fq` | 按快照恢复 `fq_codel` 参数 | 待执行 |
| Q3 | 根 `mq`，叶子全为自定义 `fq` | 不替换任何叶子 | 不替换任何叶子 | 待执行 |
| Q4 | 根 `mq`，叶子混合 `fq`/`fq_codel` | 只替换 `fq_codel` 叶子 | 原 `fq` 不动，恢复原 `fq_codel` | 待执行 |
| Q5 | HTB/TBF/CAKE 或未知层次 | `preflight` 阻断，无写入 | 不适用 | 待执行 |
| Q6 | 根 `fq_codel`，`tc` 显示 `limit 10240p`，JSON 时间比整毫秒少 1 微秒 | 切换为 `fq` | 用纯整数 `limit 10240` 恢复；±1 微秒视为语义一致 | 待执行 |
| Q7 | 默认参数、无附加层次的根 `pfifo_fast` | 切换为 `fq` | 恢复根 `pfifo_fast` 并通过语义比较 | fixture 通过；目标机待执行 |
| Q8 | 自定义参数或带附加层次的 `pfifo_fast` | `preflight` 阻断，无写入 | 不适用 | fixture 通过；目标机待执行 |

## 业务性能矩阵

调优脚本不自动生成流量。应使用受控客户端和固定 VLESS + TCP + REALITY 配置，在相同路由时段记录至少三次测试；保留中位数以及异常值，不只保存最好结果。

| 并发 | 目标 | 必记指标 | 通过判据 |
|---:|---|---|---|
| 1 | 单连接起速与稳定吞吐 | 首包/握手时间、5 s/30 s 吞吐、重传、CPU、RSS | 无连接失败；与未调优基线相比不得出现可重复的明显退化 |
| 3 | 一般低并发 | 每连接吞吐、聚合吞吐、p50/p95 RTT、重传、softnet drop/time_squeeze | 三连接持续可用，无队列丢包持续增长 |
| 5 | 典型峰值 | 聚合吞吐、公平性、p95 RTT、CPU steal/system、Xray RSS | 五连接无异常断开；512M 档无 OOM/持续 swap thrash |
| 10 | 设计上限 | 成功连接数、聚合吞吐、p95/p99 RTT、重传、CPU、内存、swap | 10 个连接均建立并持续传输；无 OOM、服务重启或系统失联 |

四个资源档至少各取得 200 Mbps/200 ms 目标下的 1、3、5、10 并发证据。100、500、1000 Mbps 或其他自定义端口值用于带宽边界扩展；高 BDP 线路还要记录实际 RTT 和 profile 是否发生缓冲截断。不同 VPS 的吞吐绝对值不能直接互相替代。

## TcpQuality 重复测试协议

TcpQuality 只作为外部线路观察，不作为 sysctl、qdisc、3X-UI 或代理体验的单独验收。一次测试序列开始前必须固定并保存：

- TcpQuality commit SHA、`runTcpQuality.sh` 和 `runTcpQuality-core.sh` 的 SHA-256；
- 完整命令行以及显式 `-c`、`-s`、`-p` 和运行模式；参数语义必须绑定固定 commit。commit `5d1f85a6b8916b73ec0389dbc9b4ed4aa27dae01` 的 `-s 0` 是标准无负载 TCP SYN；
- VPS boot ID、内核、profile 脚本 SHA-256、管理状态和 `PORT_SPEED_MBPS`/RTT/BUF_MAX；
- IPv4/IPv6 默认路由、测试开始/结束时间和当前版本 `diagnose` 脱敏日志；
- 报告 ID、debug bundle 和可获得的机器可读结果；只有远程图片时必须标记不可复算。

rc.12 的 `tcpquality-evidence.sh` 必须使用预先固定的本地目录、rootfs SHA-256 和尚不存在的证据目录；每轮保存唯一 CSV、通过固定 schema 校验的 `all`/`tos` 节点前后快照、节点/CSV 哈希、逻辑节点增删、节点 IP 变化、主机状态和最终 `SHA256SUMS`。成功批次必须存在 `COMPLETED` 且不存在 `INCOMPLETE`。节点快照不一致不自动删除证据，但变化节点不得直接进入同节点配对结论；固定本地资产不等于固定远端节点、测速端点、运营商路径或测试时段。

一次 smoke 或同日配对序列至少重复 3 次；要形成性能结论，同一配置还应覆盖低负载、白天和晚高峰，每个时段至少重复 5 次。比较中位数、P95 和异常节点复现率，不比较单次最佳值；工具 commit、节点集合、参数、VPS、内核、profile 或业务负载任一变化都应开始新的序列。即使固定 commit，远端测试节点和运营商路径仍可能变化，不能把时间先后直接解释为脚本因果。

## 已取得的目标机证据

2026-08-16，一台脱敏的 Debian 13.6、1 vCPU、1974 MiB、15 GB ext4、200 Mbps、内核 `6.12.101+deb13-cloud-amd64` 目标机，使用 `debian13-1c2g` rc.12 profile（SHA-256 `4381df00360eea2c0396184c40cb4157d12bd79f204eebdaf06069df609f4f1f`）完成只读 preflight、厂商 `/etc/sysctl.conf` 中 `fq`/`bbr` 归属迁移、apply、立即 verify、重启后 boot ID/受管文件哈希复核和重复 apply 幂等门禁。终态为 schema 4 `VERIFIED`、BBR、根 `fq`、16 MiB TCP 缓冲上限、活动项目 swap 和 active `proxy-vps-fq.service`。该证据覆盖 T4 的 M0、M2–M6；未执行未安装状态 M1、代理严格验证、真实业务、benchmark 或 HTB A/B/A，不得上推为这些阶段通过。

2026-08-02，Debian 12 1C1G、1000 Mbps 目标机使用 rc.6 完成受控空状态恢复，随后 `preflight` 通过。`apply` 已写入并切换到 fq，但 `verify` 把 `tcp_rmem`/`tcp_wmem` 的制表符对齐误判为值不一致，因此事务按设计自动回滚；日志确认“回滚完成，管理状态已清理”。这证明 recover 和该次失败回滚路径通过，不代表 M3 apply 通过，也不代表 rc.7 已在目标机通过。

2026-08-02，Debian 12 1C2G、200 Mbps、已有外部 `/swapfile-3xui` 的目标机使用 SHA-256 `8c241f3a5c58ab34c5d7286621ab52e2552dd17cdeaa4aa1c46137c17d53d7e4` 的 rc.7 完成干净迁移、preflight、apply、立即/重启后 verify、重复 apply、严格 3X-UI verify、rollback、回滚后重启、重新 apply 和最终重启后严格 verify。rollback 立即恢复为功能参数一致的 `fq_codel`，内核自动分配 `handle 8001:`，时间字段回显比快照少 1 微秒；重启后恢复为原始 `handle 0:`、`target 4999`、`interval 99999`。外部 swap 始终保留，x-ui/Xray 始终活动。该证据证明 rc.7 实际生命周期成功，同时暴露其恢复命令后缺少删除状态前语义复核；rc.8 已修复但尚未取得目标机运行证据。

2026-08-03，Debian 13 1C1G、929 MiB、1000 Mbps、ext4、内核 `6.12.100+deb13-amd64` 的目标机使用固定 `v0.1.0-rc.9` Release 总控入口，自动选择 `debian13-1c1g-vps-tuning.sh`，profile SHA-256 为 `9fd70c593b83d41337c6dfcada737855ce583e8bc3451ee8bb5952db850c81c6`。安全引导、preflight、首次 apply 和立即验证均为退出码 0、警告 0；安装 3X-UI 前重启后联网 verify 通过，`proxy-vps-fq.service` 为 loaded/active/enabled，BBR、默认 fq、`eth0` 实际根 fq 和 1024 MiB `/swapfile-proxy` 均保持。安装 3X-UI 后严格 verify 通过，再次重启后严格 verify 仍通过；新 `x-ui.service` 主进程和直接 Xray 子进程 NOFILE soft/hard 均为 65536/65536。该证据覆盖 T6 的 M2–M5、M7 和固定 Release 真实下载，不覆盖 M0 完整基线、M1、M6、M8–M11，也不证明业务性能。

2026-08-06，一台脱敏的 Debian 13 1C1G、200 Mbps、ext4、内核 `6.12.100+deb13-cloud-amd64` 目标机完成 rc.11 `preflight`、apply 后语义与受管文件哈希门禁、重启后 verify 和重复执行幂等门禁。相同固定 TcpQuality commit/rootfs 和 `-c 30 -s 0 -p 16 --all` 参数下，调优前 S1 与调优后 S2 各保存三轮文本、CSV 和节点快照。该证据证明 rc.11 生命周期与采集流程可执行；由于 S1/S2 时点不同、远端节点可变化且没有同时段随机交错对照，不能把组间差异识别为 rc.11 的因果性能收益，也不能替代 rc.12 最终哈希验证。

2026-08-07，一台脱敏的 Debian 13 1C1G、967 MiB、100 Mbps、10 GB ext4、内核 `6.12.101+deb13-cloud-amd64` 目标机运行 rc.12 本地候选。已有 500 Mbps 状态时，`apply --port 100` 在系统写入前以退出码 4 拒绝；随后普通 rollback 恢复原 qdisc 并保留项目 swap，显式 `PURGE_CREATED_SWAP=1 rollback` 完成清理。按 100 Mbps 重新执行后，重启后 `verify` 与重复 `apply`/`verify` 均返回 0；运行值为 BBR + fq，1024 MiB 项目 swap 活动，失败 unit 为 0。服务商 minimal 镜像原本不存在 `/etc/sysctl.conf`，preflight、apply 和重启均未创建该文件，状态记录迁移为 `NOT_REQUIRED`。该运行暴露了“参数不一致时请先 rollback”提示会诱导不必要普通回滚，以及不存在文件却记录 `0/0/000` 占位所有权的问题；修正会改变 profile 哈希，因此本记录只作为缺陷复现和修正前候选证据，不能替代最终候选的哈希绑定复核。3X-UI 尚未安装，M7/M8 未覆盖。

qdisc 快照往返测试必须区分显示单位和命令输入：不得把文本输出的 `p` 后缀拼入 `limit`；`memory_limit` 使用 `tc -j` 返回的原始字节整数。`target`、`interval` 和 `ce_threshold` 可容忍 ±1 微秒回显量化差异。快照 `handle 0:` 与内核自动分配的 classless qdisc handle 视为等价；显式非零 handle、kind、parent、root 及其他 options 仍严格比较。恢复命令成功后还必须执行后置语义比较；不一致时保留状态和快照并进入 `DEGRADED`。

## 每台 VPS 的验收顺序

```text
基线采集
→ 总控脚本安全引导/独立 preflight
→ 总控脚本确认后 apply
→ verify
→ reboot
→ verify
→ 重复 apply
→ 安装/启动 3X-UI v3.4.2
→ REQUIRE_PROXY_SERVICE=1 verify
→ VLESS/REALITY 客户端连接
→ rollback
→ reboot
→ status
```

控制器目标机证据必须额外保存：控制器版本、固定 Release tag、自动档位、所选文件名、端口带宽、打印的 SHA-256、底层 action 和最终退出码。使用总控入口不得替代对同一 profile 的独立脚本回归；二者至少各执行一次 preflight、apply、verify 和 rollback。

## 必须保存的脱敏证据

```bash
cat /etc/os-release
uname -a
free -m
df -h /
findmnt -n -o FSTYPE /
ip -br address
ip -4 route show default
ip -6 route show default
sysctl net.ipv4.tcp_available_congestion_control
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.default_qdisc
tc -j qdisc show
swapon --show
systemctl status proxy-vps-fq.service --no-pager
systemctl show x-ui.service -p LoadState -p ActiveState -p MainPID -p LimitNOFILE -p LimitNOFILESoft
ufw status verbose
```

不要上传密码、UUID、REALITY 私钥、API Token、TLS 私钥或未脱敏配置。

## 通过条件

- 所有命令退出码符合文档；
- `apply` 后关键验证全部通过；
- 重启后 BBR、fq、sysctl 和 swap 状态保持；
- 重复 `apply` 不产生重复 fstab 行或漂移文件；
- UFW 规则和代理配置不被修改；
- 先调优、后安装 3X-UI 时不需要额外重启；若 apply 时 x-ui 已活动，脚本不主动重启，必须在人工重启服务或主机后再通过严格验证；
- `x-ui.service` 和直接 Xray 子进程运行时 NOFILE soft/hard limit 均不低于 65536；
- VLESS + REALITY + TCP 可以实际建立连接；
- 回滚只删除本项目管理的文件；
- 回滚失败时状态和证据保留；
- 普通回滚保留 swap，显式 purge 只在 `swapoff` 成功后删除。
- 原本已经是 `fq` 的根或 `mq` 叶子在 apply/rollback 后保持原有参数；
- XFS 根文件系统允许创建 swap，已知不适用或未知文件系统只警告并跳过；
- 1/3/5/10 并发业务矩阵无连接失败、OOM、意外服务重启或持续增长的 softnet/qdisc 丢包。

## 失败路径

至少覆盖：四个资源档边界、512M 自动缓冲截断和显式越界拒绝、已有 swap、同名非项目 swap 文件、XFS、已知不适用和未知根文件系统、磁盘不足、sysctl 冲突、厂商相同值 `fq`/`bbr` 的只读分类、事务迁移、故障恢复、外部修改拒绝、schema 3 只读升级兼容、同名非项目 unit/drop-in、带自定义参数的根 `fq`、常规和非常规 `pfifo_fast`、`mq` 下混合 `fq`/`fq_codel` 叶子、qdisc 快照仅 `refcnt` 不同、qdisc 时间回显相差 1 微秒、`fq_codel limit` 文本输出带 `p`、`noqueue`、复杂 qdisc、双栈不同默认网卡、未安装项目状态时执行 `verify`、已有 `DEGRADED` 状态时执行 `preflight`、0 字节/空白/多文档状态、状态 JSON 构造器编译失败、状态转换失败、rc.2 空状态 recover、状态提交前应用中断、`DEGRADED` 无活动配置恢复、调优后尚未安装 3X-UI、停止的 `x-ui.service`、NOFILE 低于 65536、缺失的 Xray 子进程、应用中断、`swapoff` 失败、`/etc/fstab` 过滤或原子替换失败，以及已安装非默认带宽下的重复 `apply`。
