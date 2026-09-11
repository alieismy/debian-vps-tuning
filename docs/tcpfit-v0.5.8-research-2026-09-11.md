# `Kylin010/tcpfit` v0.5.8 研究与 rc.17 吸收评估

研究日期：2026-09-11（Asia/Singapore）
研究模式：`rd-research` 技术与开源研究 + 配置与基础设施研究
研究对象：<https://github.com/Kylin010/tcpfit>
研究边界：只读检查远端说明、固定提交源码、发布资产和语法；不运行第三方 root 脚本，不连接目标 VPS，不产生公网测速流量，不修改本项目网络参数。

## 研究问题与当前基线

本次只回答：

1. `tcpfit` 当前版本实际实现了哪些有价值的网络调优、测量、整形、安装和回滚机制？
2. 哪些机制与本项目 `v0.1.0-rc.17` 的 17 项受管 sysctl、资源感知 BDP buffer、默认 `BBR + fq`、schema 4 managed state、预算 ledger、脱敏证据和非持久 HTB 研究面相容？
3. 哪些内容只能作为条件实验，哪些内容应明确拒绝吸收？

本项目当前阶段只允许形成 rc.17 本地候选和本地门禁闭环；提交、推送、tag、Release、真实 VPS 变更和新的公网流量测试均不在本轮授权内。

## 来源冻结与可复现证据

| 项目 | 证据 |
|---|---|
| 当前提交 | `main` = `76331588af487a973d3445a1bf8bba7037d566ca`；`v0.5.8` tag 指向同一提交 |
| 发布时间 | GitHub Releases API 的 `v0.5.8`，`2026-09-10T22:38:34Z`，非 draft、非 prerelease；release `immutable=false` |
| 主要脚本 | `tcpfit.sh` SHA-256 `3a4d720bf7acb5b77eb24708ca17b6b42487628eefbdcb982e62454c2287358e` |
| 安装器 | `install.sh` SHA-256 `8a521bcc2f89c336fba239d7b722cede8638ac9df06b28eb8be1536a22fd5085` |
| 发布清单 | `SHA256SUMS` 同时列出 `tcpfit.sh` 与 `install.sh`；GitHub asset digest 与下载字节一致 |
| 本地复核 | `bash -n tcpfit.sh`、`bash -n install.sh`、`python -m py_compile orchestrator/fleet.py` 均通过；仓库没有等价的运行时测试套件 |

固定来源链接：[`v0.5.8` commit](https://github.com/Kylin010/tcpfit/tree/76331588af487a973d3445a1bf8bba7037d566ca)、[`tcpfit.sh`](https://github.com/Kylin010/tcpfit/blob/76331588af487a973d3445a1bf8bba7037d566ca/tcpfit.sh)、[`install.sh`](https://github.com/Kylin010/tcpfit/blob/76331588af487a973d3445a1bf8bba7037d566ca/install.sh)。README 的 PPPoE 实测和其他性能数字是维护者声明；本轮没有在相同目标环境复现。

## 机制分析

### 1. 并发、异常回收和状态保护

脚本用 `/var/lock/tcpfit.lock` 和 `flock` 串行化调优、扫描、存档和 qdisc 操作（`tcpfit.sh` 约 L83–132），扫描过程对自己的 `iperf3`/`timeout` 进程做中断回收。参数校验放在快照和系统写入前，`tc` 速率通过统一的数值归一化函数读取，避免 `1Gbit` 等显示形式破坏判断。

这些是可靠的工程细节，但 rc.17 已有更强的边界：独立 lock、`setsid` 进程组、硬超时、TERM→KILL、`INCOMPLETE`、共享流量 reservation/ledger、失败保守结算、`tc -j` qdisc 快照和后置语义验证。因此适合转成回归检查项，不适合复制实现或扩大状态模型。

### 2. BDP 与 sysctl 参数推导

`calc_bdp`、`calc_buf_max` 和 `calc_buf_default`（约 L504–701）以带宽、RTT、RAM 和用途角色推导 buffer；默认 RTT 仍为固定 `150 ms`，buffer 上限约为 `2 × BDP + 2 MiB`，再受 RAM/32、256 MiB 上限和 4 MiB 下限约束。`cmd_tune` 实际写入 32 项 sysctl（约 L1488–1670），包含 `tcp_slow_start_after_idle=0`、`tcp_tw_reuse=1`、`tcp_fin_timeout=15`、`vm.min_free_kbytes`、`fs.file-max`、端口范围、`netdev` budget/backlog 和 `tcp_mem` 等；它还尝试设置 `initcwnd/initrwnd=32`。

资源感知和 BDP 公式有解释价值，但参数集合和默认 RTT 与本项目不同。固定 RTT 不能证明“每台机器实测”，宽 sysctl 集合会扩大所有权、兼容性和回滚边界；`initcwnd/initrwnd` 是默认路由属性而不是普通 sysctl。rc.17 的 17 项集合和现有 buffer 矩阵应保持不变。

### 3. policer 扫描、goodput 和整形语义

`sweep` 先做不限速基线，按 receiver goodput、sender retransmission/GiB 和重复 loss spike 判断候选拐点；结果可表达 `NO_KNEE`、`OUT_OF_RANGE`、`ABOVE_CAP`、对端过慢和脏路径等不可判定状态（约 L2208–2650）。脚本正确区分：HTB class 的 `rate/ceil` 是聚合出口上限，FQ `maxrate` 是单流 pacing；整形拓扑是 HTB root → class → FQ leaf（约 L1893–2000）。

这套语义与 rc.17 的研究面相容，但本项目已经把它放进更严格的 schema 3 phase summary、root/leaf qdisc health、正 `overlimits`、测量窗口、资源门禁和 `REVIEW_REQUIRED`/`REVIEW_BLOCKED` 分层。`tcpfit` 自身只做流量估算（`traffic_report`），没有本项目的原子 ledger、未知量保守结算或固定证据清单。因此只吸收“goodput 与归一化重传以及不可判定终态”的测试思想；不替换现有 analyzer，也不从其推荐速率、margin 或 burst 公式推导生产参数。

### 4. qdisc、路由窗口和 PPPoE

v0.5.8 修复了默认路由无 `via` 时按字段位置误取网卡的问题：`route_field`/`route_set_initcwnd` 按 `dev`、`via` 关键字解析并保留原路由 token（约 L417–466）。当存在 `/etc/ppp/ip-up.d` 时，`write_ppp_hook` 写入只匹配调优接口的钩子，在 PPP 重拨后恢复 qdisc 和 `initcwnd`（约 L1859–1892）。这是本次相对 v0.5.7 的主要实质新增。

本项目的 `default_route_ifaces` 已按 `dev` 关键字发现 IPv4/IPv6 默认路由，因而“无 `via` 的字段位置 bug”本身已被吸收；当前 profile 不管理 `initcwnd/initrwnd`，也没有 PPPoE 目标需求。若未来明确支持 PPP/PPPoE，钩子思路可以作为条件设计输入，但必须补上受管文件哈希、所有权、状态 schema、重拨 fixture、回滚和 Linux root 生命周期证据。当前不进入 rc.17。

`tcpfit` 的 qdisc 保存主要依赖 `tc qdisc show` 文本首行（约 L2027–2105），恢复时按有限分支重建；它不能达到本项目 `tc -j` 数值快照、复杂拓扑阻断、root/leaf 语义比较和恢复后哈希门禁的完整性要求。

### 5. 监测、遥测、安装和多机编排

脚本启动时默认向 `https://tcpfit.spacevps.cc/ping?v=<version>` 后台发送匿名计数请求，只有设置 `TCPFIT_NO_TELEMETRY=1` 或创建 `no-telemetry` 文件才关闭（约 L887–929）。这不是本项目需要的证据，也会引入额外外联和隐私审查边界。

README/安装器的一键路径下载可变 `main` 分支脚本；`install.sh` 虽然 release 提供 `SHA256SUMS`，但 agent 模式并不固定 release tag 或在安装前校验清单。`cmd_update` 后续更新才尝试从 release asset 下载并校验 `tcpfit.sh`，取不到清单时仍会退回版本号校验（约 L2779–2840）。这与本项目固定 Release、外层 installer 摘要、内置清单、原子 current 链接和篡改拒绝直接冲突。

`orchestrator/fleet.py` 明确标注“未上线、未在真实环境验证”，默认关闭 host key 校验、把密码作为命令参数传给 `sshpass`，并发推送未绑定项目的 agent；它没有本项目的固定资产、目标机 checkpoint、共享预算、回滚和脱敏证据契约。

## 吸收决策矩阵

| 外部机制 | 证据状态 | rc.17 判断 | 决策 |
|---|---|---|---|
| `flock`、参数先验、进程组回收、统一速率解析 | 源码实现；未运行第三方脚本 | rc.17 已有更强等价控制 | 已覆盖；仅保留为回归审计清单 |
| receiver goodput + retransmission/GiB + loss-spike 复测 | 源码实现；未在本项目目标机复现 | 对 HTB 研究解释有帮助，但必须受 rc.17 endpoint、ledger、窗口和 `REVIEW_*` 门禁约束 | 条件实验；不改默认行为 |
| `NO_KNEE`/`OUT_OF_RANGE`/`ABOVE_CAP` 终态 | 源码实现 | 与现有 fail-closed 语义同方向 | 已覆盖；不复制命名或状态文件 |
| `HTB rate=ceil` + FQ leaf 语义分离 | 源码实现，且符合 Linux `tc` 语义 | rc.17 已有非持久 HTB 和 root/leaf schema 3 | 已覆盖；不吸收参数包 |
| 无 `via` 默认路由的关键字解析 | v0.5.8 源码与 release 说明 | 本项目默认路由发现已按 `dev` 解析 | 已覆盖；补 PPP fixture 需另立需求 |
| PPP `ip-up` qdisc/initcwnd 恢复钩子 | 源码实现；README 为维护者实测声明 | 仅对明确 PPP/PPPoE 拓扑有意义，会扩大状态/所有权/生命周期 | 条件候选；延期，不进 rc.17 |
| 32 项 sysctl、固定 RTT、`initcwnd/initrwnd`、netdev/连接参数 | 源码实现；性能数字未复现 | 超出 17 项受管集合，改变默认策略和回滚面 | 拒绝吸收 |
| 持久 HTB/FQ `limit`/`flow_limit`/burst/cburst 参数 | 源码实现；无本项目 A/B/A 证据 | 与非持久 HTB 和“不得自动持久化”边界冲突 | 拒绝作为默认；仅保留实验对照 |
| `traffic_report` 估算、公共 iperf3 自动选点、自动装包 | 源码实现 | 不能替代共享 ledger、授权 endpoint 和预算上界 | 拒绝吸收 |
| 可变 `main` 安装、自更新降级校验、默认遥测 | 源码实现与 release 资产 | 供应链、外联和证据边界弱于本项目 | 拒绝吸收 |
| `fleet.py` 多机编排 | 源码实现但自称未上线 | 不满足固定资产、host key、凭据、checkpoint、回滚和脱敏要求 | 拒绝吸收 |

## 结论与重新评估条件

当前没有足够证据支持把 `tcpfit` 的完整脚本、32 项参数、固定经验值或持久 HTB 直接并入 rc.17。最有价值的部分已经以更严格的形式存在于本项目：参数与拓扑的 fail-closed 验证、receiver/sender 分层、HTB/FQ 语义区分、schema 3 root/leaf 计数、socket 脱敏和共享流量 ledger。

本轮唯一值得登记的新增条件候选是 PPP/PPPoE 重拨后的受管 qdisc 恢复。重新启动该候选必须同时满足：

1. 需求明确把 PPP/PPPoE 纳入支持拓扑，并定义多 PPP 链路、默认路由切换和 hook 归属；
2. 形成带哈希和所有权的 hook/状态设计，不把路由 token 或外部文件当作可盲写输入；
3. 增加无 `via`、多路径拒绝、重拨、hook 中断和回滚 fixture，并在 Linux root 环境验证重拨后的 `fq`/qdisc 语义；
4. 取得独立授权后再决定是否修改 profile、生成资产、schema 和发布门禁。

在上述条件出现前，rc.17 保持现有 17 项 sysctl、资源感知 buffer、默认 `BBR + fq`、非持久 HTB、预算 ledger、schema 4 managed state 和证据分层；本轮不修改网络实现，不运行第三方脚本，不执行目标 VPS 或公网测速。
