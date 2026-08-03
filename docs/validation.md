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
| C15 | 固定 rc.10 Release assets | 下载清单和唯一 profile，SHA-256 通过 | 本地 fixture 通过；发布后须从公开地址重下载并复核八个资产 |
| C16 | 已安装状态下无 `--port`/环境变量地重复 `apply` | 复用状态中的端口带宽；显式参数仍优先；无效状态值阻断 | fixture 通过；目标 VPS 待测 |
| C17 | `diagnose` | 默认 5 秒前后采样；TCP/softnet 为十进制增量；读取 qdisc、队列、RPS/XPS/IRQ、ethtool 和 Xray sockopt；无系统配置写入、无主动流量 | 静态检查通过；目标 VPS 待测 |
| C18 | `benchmark` 未提供 host、无 iperf3、无效范围 | 明确拒绝；不安装软件、不改防火墙、不选择公共服务器 | 静态检查通过；目标 VPS 待测 |
| C19 | 用户授权的 `benchmark` | 仅向指定 iperf3 服务端执行 upload/download/both；并行 1–4；输出 JSON 与计数增量；保留 iperf3 退出码语义 | 目标 VPS 待测 |
| C20 | `update` 自动发现/`--target` | 同一 `major.minor` 内，rc 通道可选更高 rc 或稳定版，稳定通道排除 prerelease；显式目标允许跨线或 prerelease；拒绝降级和重复升级 | 版本优先级、稳定/rc 通道、非法版本 fixture 通过；GitHub API 真实查询待测 |
| C21 | `update` 只读升级检查 | 校验当前/目标资产，当前 verify、目标 `UPDATE_PREFLIGHT=1 preflight` 通过后输出固定 URL、哈希、端口和人工迁移顺序；不得调用 rollback/purge/apply/reboot | 调用顺序 fixture 与真实 `check_preflight_state` 状态矩阵通过；目标 VPS 只读 update 待测 |
| C22 | 外部 sysctl 文件以相同值重复定义受管 key | `preflight`/`apply` 阻断；已安装状态的独立 `verify` 返回非零；`diagnose` 只读报告；项目自身文件及其符号链接不误报 | 同值冲突、受管文件别名和外部别名去重 fixture 通过；目标 VPS 负向注入不在生产机执行 |
| C23 | 旧总控与新版本 `SHA256SUMS`/profile 同目录 | 返回完整性错误，提示可能混用不同 Release 并要求独立目录；不得联网回退或修改系统 | 混合版本目录 fixture 通过；Debian 13 rc.9→rc.10 实测安全拒绝并通过隔离目录恢复 |

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
  tests/static-check.sh \
  tests/controller-check.sh
```

发布前必须从 draft Release 下载总控、六份 profile 和清单共八个资产，在与仓库不同的临时目录执行 `sha256sum -c SHA256SUMS`，再分别验证本地模式和缺少同目录 profile 时的远程模式。Release 尚未上传资产时，不得把远程下载测试标为通过。

## 首发目标机矩阵

下表是必须取得证据的目标矩阵，不是已经完成的测试结果。没有真实 VPS 回填证据前，不得把状态改为“通过”。

| ID | 系统 | 资源 | 磁盘/根文件系统 | 端口 | 内核基线 | 定位 | 状态 |
|---|---|---|---:|---:|---|---|---|
| T1 | Debian 12 | 1C1G | 10 GB / XFS | 200 Mbps | `6.1.0-51-cloud-amd64` | 主力/首要门槛 | rc.8 退出、rc.10 apply、重启严格 verify、重复 apply 通过；最终修复哈希待目标机复核 |
| T2 | Debian 12 | 1C2G | 15 GB / XFS | 200 Mbps | `6.1.0-51-cloud-amd64` | 主力/首要门槛 | 旧状态经 rc.8 profile 退出、rc.10 apply、重启严格 verify、重复 apply 通过；最终修复哈希待目标机复核 |
| T3 | Debian 13 | 1C1G | 以实机为准 | 200 Mbps | `6.12.100+deb13-cloud-amd64` | 系统兼容 | 待执行 |
| T4 | Debian 13 | 1C2G | 以实机为准 | 200 Mbps | `6.12.100+deb13-cloud-amd64` | 系统兼容 | 待执行 |
| T5 | 与脚本匹配的 Debian 版本 | 1C1G | 10 GB | 100 Mbps | 以实机为准 | 低带宽边界 | Debian 12 v5→rc.10、重启严格 verify、重复 apply 通过；最终修复哈希待目标机复核 |
| T6 | Debian 13 | 1C1G | 容量未采集 / ext4 | 1000 Mbps | `6.12.100+deb13-amd64` | 高带宽边界 | rc.9 完整退出和 swap 所有权迁移、rc.10 apply、重启严格 verify、BBR/fq/swap、重复 apply 通过；最终修复哈希待目标机复核 |
| T7 | Debian 12 | 2C2G | 以实机为准 | 200 Mbps | `6.1.x`，以实机为准 | 2C2G 资源契约 | 待执行 |
| T8 | Debian 13 | 2C2G | 以实机为准 | 200 Mbps | `6.12.x`，以实机为准 | 2C2G 系统兼容 | 待执行 |
| T9 | Debian 12 | 1C512MB | 以实机为准 | 200 Mbps | `6.1.x`，以实机为准 | 最小内存边界 | 待执行 |
| T10 | Debian 13 | 1C512MB | 以实机为准 | 200 Mbps | `6.12.x`，以实机为准 | 最小内存系统兼容 | 待执行 |

T1、T2 必须通过才能发布首个稳定版；T3、T4 是 Debian 13 稳定版门槛；T5、T6 用于确认 100–1000 Mbps 输入边界，不能用 200 Mbps 的结果代替。T7、T8 用于证明同一 `1c2g` 兼容 profile 在 2 vCPU 下的完整生命周期；T9、T10 用于证明 512 MiB 的缓冲截断、journald、swap 和 3X-UI 生命周期。本地 fixture 不能替代目标机证据。

上述 rc.10 目标机结果绑定测试时日志中的具体 SHA-256。发布前最后两项 Major 仅改变冲突检测、错误说明、文档和测试，不改变写入的 sysctl/qdisc/swap/NOFILE 参数；重新生成后的最终哈希仍须执行本地定向回归。由于当前环境没有这些 VPS 的 SSH 凭据，最终哈希的目标机复核不能由本地 fixture 冒充，作为 Pre-release 的后续确认项保留。

## rc.10 自动缓冲矩阵

该矩阵验证的是输入算法和资源上限，不是吞吐结论。目标 RTT 为 200 ms；512M/1G/2G 的自动目标分别为 1×/1.25×/1.5×BDP，再向上取 16/32/64 MiB 档。

| 资源档 | 100 Mbps | 200 Mbps | 500 Mbps | 1000 Mbps | fixture |
|---|---:|---:|---:|---:|---|
| 1C512MB | 16 MiB | 16 MiB | 16 MiB | 16 MiB + 截断警告 | 1000 Mbps 通过；其余待补 |
| 1C1GB | 16 MiB | 16 MiB | 16 MiB | 32 MiB | 500/1000 Mbps 通过；100/200 待补 |
| 1C2GB/2C2GB | 16 MiB | 16 MiB | 32 MiB | 64 MiB | 200/500/1000 Mbps 通过；100 待补 |
| 2C2GB | 16 MiB | 16 MiB | 32 MiB | 64 MiB | 与 1C2GB 共用算法；控制器 CPU fixture 通过，目标机待测 |

对 500/1000 Mbps 的 2G 档，rc.10 与 rc.9 的配置可能不同，必须先通过只读 update 检查，再人工执行 rollback → reboot → preflight → apply → reboot → verify 建立新状态，不得把 rc.9 的 verify 结果记作 rc.10。200 Mbps 主力档的数值虽不变，rc.10 的诊断、TFO 可见性、benchmark 和 update 仍需独立运行验证。

## 每台目标机的生命周期矩阵

每一行都要分别在 T1–T10 回填“通过/失败/不适用”、执行时间、脚本 SHA-256 和脱敏证据路径。任一失败都应保留退出码和错误输出。

| 阶段 | 操作 | 关键判据 | T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| M0 | 基线采集 | OS、内核、CPU、内存、根文件系统、磁盘、双栈、qdisc、swap 可追溯 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 部分完成，磁盘容量与地址未采集 | 待执行 | 待执行 | 待执行 | 待执行 |
| M1 | 未安装状态执行 `verify` | 退出码 5；提示先运行 `preflight`/`apply`；无系统写入 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M2 | `preflight` | 退出码 0；识别资源档和文件系统；无系统写入 | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | rc.9 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M3 | `apply` | 退出码 0；状态为 `VERIFIED`；含 NOFILE drop-in，swap/qdisc 符合预期 | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | rc.9 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M4 | 立即 `verify` | 退出码 0；sysctl、qdisc、journald、swap、drop-in 一致 | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | rc.9 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M5 | 重启后 `verify` | 退出码 0；BBR、fq、sysctl、swap 持久 | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | rc.9 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M6 | 重复 `apply` | 退出码 0；报告无需重复写入；无重复 fstab/unit | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M7 | 安装 3X-UI 后严格验证 | `REQUIRE_PROXY_SERVICE=1 verify` 通过；x-ui/Xray 运行时 NOFILE ≥ 65536 | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | rc.9 安装后及再次重启后通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M8 | VLESS + REALITY + TCP | IPv4/IPv6 按实际能力建立连接；连续传输无异常 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M9 | 普通 `rollback` | 恢复 qdisc/sysctl，删除 drop-in；脚本 swap 默认保留；状态可追溯 | 待执行 | rc.7 实际恢复通过；rc.8 后置验证待复测 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M10 | 回滚后重启 | `status` 正确；无残留 unit/sysctl/journald/drop-in | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M11 | 显式 purge | `swapoff` 成功才删除 swap/fstab 行；失败时保留证据 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M12 | 业务负载期间 `diagnose` | 采样窗口内记录 TCP/softnet 增量、qdisc 前后计数、队列/IRQ 与 Xray sockopt；无配置写入 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M13 | 授权 iperf3 benchmark | 单流优先；保存服务端位置、方向、吞吐、重传、CPU/softnet/qdisc 增量；确认不当作代理业务结果 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |

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

## 已取得的目标机证据

2026-08-02，Debian 12 1C1G、1000 Mbps 目标机使用 rc.6 完成受控空状态恢复，随后 `preflight` 通过。`apply` 已写入并切换到 fq，但 `verify` 把 `tcp_rmem`/`tcp_wmem` 的制表符对齐误判为值不一致，因此事务按设计自动回滚；日志确认“回滚完成，管理状态已清理”。这证明 recover 和该次失败回滚路径通过，不代表 M3 apply 通过，也不代表 rc.7 已在目标机通过。

2026-08-02，Debian 12 1C2G、200 Mbps、已有外部 `/swapfile-3xui` 的目标机使用 SHA-256 `8c241f3a5c58ab34c5d7286621ab52e2552dd17cdeaa4aa1c46137c17d53d7e4` 的 rc.7 完成干净迁移、preflight、apply、立即/重启后 verify、重复 apply、严格 3X-UI verify、rollback、回滚后重启、重新 apply 和最终重启后严格 verify。rollback 立即恢复为功能参数一致的 `fq_codel`，内核自动分配 `handle 8001:`，时间字段回显比快照少 1 微秒；重启后恢复为原始 `handle 0:`、`target 4999`、`interval 99999`。外部 swap 始终保留，x-ui/Xray 始终活动。该证据证明 rc.7 实际生命周期成功，同时暴露其恢复命令后缺少删除状态前语义复核；rc.8 已修复但尚未取得目标机运行证据。

2026-08-03，Debian 13 1C1G、929 MiB、1000 Mbps、ext4、内核 `6.12.100+deb13-amd64` 的目标机使用固定 `v0.1.0-rc.9` Release 总控入口，自动选择 `debian13-1c1g-vps-tuning.sh`，profile SHA-256 为 `9fd70c593b83d41337c6dfcada737855ce583e8bc3451ee8bb5952db850c81c6`。安全引导、preflight、首次 apply 和立即验证均为退出码 0、警告 0；安装 3X-UI 前重启后联网 verify 通过，`proxy-vps-fq.service` 为 loaded/active/enabled，BBR、默认 fq、`eth0` 实际根 fq 和 1024 MiB `/swapfile-proxy` 均保持。安装 3X-UI 后严格 verify 通过，再次重启后严格 verify 仍通过；新 `x-ui.service` 主进程和直接 Xray 子进程 NOFILE soft/hard 均为 65536/65536。该证据覆盖 T6 的 M2–M5、M7 和固定 Release 真实下载，不覆盖 M0 完整基线、M1、M6、M8–M11，也不证明业务性能。

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

至少覆盖：四个资源档边界、512M 自动缓冲截断和显式越界拒绝、已有 swap、同名非项目 swap 文件、XFS、已知不适用和未知根文件系统、磁盘不足、sysctl 冲突、同名非项目 unit/drop-in、带自定义参数的根 `fq`、常规和非常规 `pfifo_fast`、`mq` 下混合 `fq`/`fq_codel` 叶子、qdisc 快照仅 `refcnt` 不同、qdisc 时间回显相差 1 微秒、`fq_codel limit` 文本输出带 `p`、`noqueue`、复杂 qdisc、双栈不同默认网卡、未安装项目状态时执行 `verify`、已有 `DEGRADED` 状态时执行 `preflight`、0 字节/空白/多文档状态、状态 JSON 构造器编译失败、状态转换失败、rc.2 空状态 recover、状态提交前应用中断、`DEGRADED` 无活动配置恢复、调优后尚未安装 3X-UI、停止的 `x-ui.service`、NOFILE 低于 65536、缺失的 Xray 子进程、应用中断、`swapoff` 失败、`/etc/fstab` 过滤或原子替换失败，以及已安装非默认带宽下的重复 `apply`。
