# Debian VPS 网络调优与测试策略

文档类型：技术方案

状态：已批准；P0 控制文档已实施，P1/P2 行为变更进入下一候选版本

适用范围：本项目支持的 Debian 12/13 amd64、1C512MB、1C1GB、1C2GB 和 2C2GB VPS

证据截止：2026-08-29（Asia/Singapore）

## 1. 背景与目标

本项目已经在多台 VMISS、VMRack 及其他 VPS 上形成了生命周期、TcpQuality、iperf3 和临时
HTB 证据。既有验证证明脚本的状态事务、BBR、根 `fq`、socket buffer、swap、NOFILE 和
重启持久性能够工作，也暴露了两个需要纠正的方向：

1. 把研究级公网性能实验扩展到配额受限业务 VPS，会消耗大量流量和人工时间，但不一定
   增加可用于调优决策的因果证据；
2. 发布验证、单机升级验收、真实业务验收和网络机制研究曾被放在同一条路径上，导致每台
   VPS 承担了超出其运行目标的测试成本。

本方案的目标是：

- 维持安全、可回退、资源感知的 TCP 调优基线；
- 对用户只暴露一个总控入口，避免把生成 profile 误解为多套独立算法；
- 以零流量或低流量验证覆盖绝大多数版本升级和目标机验收；
- 只在真实业务症状和明确研究决策需要下启用主动性能测试；
- 用跨工具累计预算、自动停止和证据完整性阻止再次发生流量额度耗尽；
- 严格区分生命周期成功、主机网络状态、直连 benchmark、代理业务和生产性能结论。

本方案不以证明某一家服务商存在 policer 为目标，也不承诺通过通用 sysctl 消除公网路径、
运营商、远端节点、虚拟交换机或服务商调度造成的重传。

## 2. 已检查证据与结论边界

### 2.1 VMISS Basic 1C1G / 200 Mbps

- `rc11-vmiss-basic-evidence-final-20260806.tar` 包含 S1b、S2 共 6 次 TcpQuality；按每次测试
  前后 `eth0` 根 qdisc `Sent bytes` 差值重算，约产生 43.09 GB 出站流量。
- 同一 Basic 证据目录后来追加至 29 次 TcpQuality，日志窗口合计约 264.27 GB
  （246.12 GiB）出站流量。该值不包含下载、失败尝试、协议开销、背景业务或服务商计费差异。
- S3C–S3F 的 12 个窗口中，本地 qdisc drop 增量均为 0，但主机重传密度、节点和时段差异
  明显。证据更支持公网路径、远端节点和时间窗口是重要变量，不能把变化唯一归因于主机
  调优参数。
- 一次后续 HTB190 B1 确实产生约 3.389 GB egress 和正 `overlimits`，证明聚合整形实际
  工作；但缺少完整 A2 和同窗比较，不能证明性能改善。

最高证据层级：rc.11 生命周期和多轮线路观察可执行；临时 HTB 生命周期部分通过；没有形成
可授权永久 HTB 的因果结论。

### 2.2 `htb-aggregate` 目录

- `S4-HTB-20260810T141025Z.tar.gz` 中 A1、B1、A2 的 TcpQuality 批次都标记完成，但 B1 的
  HTB start 日志只到 preflight，负载前后均为 `state=INACTIVE`、根 `fq`、class 为空、
  watchdog inactive。该 B1 实际仍在 `fq` 下运行，是无效 HTB B 阶段。
- 这三个仍为根 `fq` 的窗口分别产生约 9.094、7.596、8.296 GB egress；重传增量随时间
  下降，进一步说明相邻公网窗口也可能自然漂移，不能把阶段名称当作变量已生效的证据。
- `cap200.json` 是一次根 `fq` 下、单流、10 秒、200 Mbps cap 的 IPv4 上传：sender
  约 199.96 Mbps、sender retransmits 为 0、host CPU 约 1.86%。它证明该主机、该路径和
  该时点能在不使用 HTB 的情况下接近额定速率；不证明所有时段都没有 policer，也不是
  HTB200 reference。
- `stage0-v030-20260816T102145Z` 的 13 项本地清单全部通过重新计算的 SHA-256。v0.3.0
  在 1C2G/200 Mbps 旧基线上完成 HTB190 短时挂载、ACTIVE、watchdog、stop 和根 `fq`
  恢复；smoke 没有测量负载且 `overlimits=0`，只证明生命周期和恢复。

最高证据层级：旧 HTB 工具的安装、ACTIVE、自动恢复和手工恢复可执行；没有形成 HTB 性能
收益证据。

### 2.3 VMISS Core 1C2G / 200 Mbps

- 目标机为 Debian 13、1 vCPU、约 1974 MiB RAM、15 GB ext4。rc.12 完成 preflight、
  厂商 sysctl 归属迁移、apply、立即 verify、重启后 verify 和重复 apply 幂等验证。
- 终态为 schema 4 `VERIFIED`、BBR、根 `fq`、16 MiB socket buffer 上限、1 GiB 项目
  swap；安装 3X-UI 后 strict verify 证明 x-ui 主进程和直接 Xray 子进程 NOFILE
  soft/hard 均为 65536/65536。
- `vmiss-1c2g-rc12-baseline/SHA256SUMS` 声明 46 个文件。本地有 30 个位于原相对位置并匹配；
  另有 13 个拆放在 Core 根下且摘要匹配；3 个 `project-state-snapshot` 文件缺失。因此该复制
  目录能够支持主要运行事实，但不是完整可独立复算的原始证据包。
- `htb-v040-smoke200` 证明当时 v0.4.0 能以 HTB200 + `fq` 启动、通过 ACTIVE 检查并恢复
  根 `fq`；没有承载 benchmark，不能说明性能。
- `htb200-reference-*`、candidate 目录只留下空目录骨架；reference 与 sweep JSON 是计划，
  没有 benchmark、runtime、manifest、`COMPLETED` 或分析结果。三样本 reference 的计划
  payload 上界为 0.975 GB，15 阶段 sweep 的计划上界为 4.704375 GB，但不能写成已经执行。
- Core 保存的 rate-sweep 和 HTB 脚本哈希与当前 rc.14 仓库实现不同，历史工具行为不能直接
  证明当前工具版本。

最高证据层级：rc.12 的 1C2G 生命周期、重启持久性、幂等和 3X-UI 严格验证通过；旧 HTB
smoke 通过；HTB200 reference、candidate sweep、A/B/A 和真实代理性能均未通过。

## 3. 关键架构判断

1. **BBR + 根 `fq` 是目标状态，不等于必须覆盖厂商配置。** 当前证据没有支持把持久 HTB、
   `fq maxrate`、TBF、CAKE 或其他整形加入所有 profile；已经由单一、可审计的厂商配置
   正确持久化时，应先决定配置所有权，再决定接管或保持现状。
2. **HTB 是研究工具，不是基础调优。** 只有需要验证额定端口附近的聚合出口 policer，且
   对永久整形存在真实决策时，才使用临时 `HTB + fq`。
3. **服务商名称不是 profile 维度。** VMISS、VMRack 或其他服务商共用相同主机基线；服务商
   差异通过端口值、RTT、文件系统、现有配置所有权和运行证据处理，不派生品牌脚本。
4. **CPU 不直接推导 TCP 参数。** CPU 数只参与支持范围、资源档和诊断；没有 softnet、IRQ、
   队列和真实瓶颈证据时，不写 RPS/RFS/XPS、IRQ affinity 或 busy polling。
5. **磁盘不直接推导 TCP 参数。** 文件系统和可用空间只决定 swap、日志、证据保留与回退
   可行性，不改变 BBR 或 TCP buffer 公式。
6. **UDP 必须工作负载感知。** 机器资源和带宽不足以推导通用 UDP 优化；只有明确的 QUIC、
   WireGuard、Hysteria、TUIC 或 UDP 转发负载及 socket/PPS/MTU 证据，才建立独立模块。
7. **发布验证不等于每台 VPS 重跑性能矩阵。** 确定性行为在本地 fixture/专用 root 环境验证；
   业务 VPS 只验证该机迁移和真实业务可用性。

## 4. 候选方案

### 4.1 方案 A：每台 VPS 执行完整性能和 HTB 实验

每次版本升级后执行 TcpQuality 多轮、HTB200 reference、180/190/195 sweep、A/B/A 和反向
窗口。

优点是每台主机都有大量独立数据；缺点是流量和时间成本最高，公网变量仍难控制，失败重试
会扩大成本，而且研究结果未必能转化为持久配置。Basic 的 264.27 GB 历史已经证明该路线不
适合配额业务 VPS。

### 4.2 方案 B：完全动态单脚本，只做 apply/verify

把所有 profile 删除，仅按 OS、CPU、内存、端口和磁盘现场计算，升级后只执行 apply/verify，
不保留发布 profile、状态所有权和代表性运行验证。

优点是用户操作最少；缺点是支持边界、可审计性、离线完整性、跨版本恢复和故障定位都会
变弱。磁盘、CPU 和 UDP 也不能可靠地统一映射为网络参数。该路线把复杂性藏入一个大公式，
不适合作为生产默认。

### 4.3 方案 C：单一入口 + 声明式资源策略 + 分层验证

对用户保留一个总控；内部以一个规范引擎和小型资源策略表处理 OS/资源差异，生成 profile
仅作为不可变 Release、离线安装和审计资产。发布使用专用环境验证确定性行为；每台业务 VPS
只做低流量生命周期和真实代理冒烟；主动 benchmark 与 HTB 进入独立、显式、有硬预算的
诊断/研究通道。

该方案保留恢复和完整性安全边界，同时显著减少流量、时间和逐机重复劳动。

## 5. 方案比较与推荐

| 维度 | 方案 A：逐机完整实验 | 方案 B：完全动态最简 | 方案 C：分层验证 |
|---|---|---|---|
| 日常流量成本 | 很高 | 最低 | 低 |
| 日常人工时间 | 很高 | 最低 | 低 |
| 公网因果识别 | 中，仍受路径影响 | 无 | 仅在专用研究通道形成 |
| 生命周期可靠性 | 中，测试多但易混层 | 低至中 | 高 |
| 回退和完整性 | 可保留 | 容易弱化 | 完整保留 |
| 用户复杂度 | 高 | 低 | 低 |
| 发布可审计性 | 中 | 低 | 高 |
| 配额业务 VPS 适用性 | 不适用 | 有风险 | 适用 |
| 退出路径 | 停止实验 | 恢复 profile 契约 | 降级为生命周期验收或转专用研究机 |

**推荐方案 C，置信度高。** 依据是三组目标机证据一致表明生命周期验证能够提供稳定、低流量
的主机配置证明，而主动公网测试的成本和时段/路径混杂远高于其默认决策价值。方案 A 只保留
为研究模式；方案 B 的单入口思想被吸收，但不删除声明式支持边界和状态契约。

## 6. 推荐架构

```text
用户
  │
  ▼
单一总控 dvt / debian-vps-tuning.sh
  │
  ├── 主机事实规范化
  │     OS/架构、CPU、内存、端口、RTT、文件系统、磁盘、swap、qdisc、状态所有权
  │
  ├── 单一规范引擎
  │     preflight / apply / verify / diagnose / reconfigure / rollback / recover
  │
  ├── 声明式资源策略
  │     Debian 12/13 × 512M/1G/2G 的上限、日志、swap 和兼容边界
  │
  ├── Release 生成资产
  │     六份 profile，仅用于固定哈希、离线分发、审计和兼容
  │
  └── 独立实验面
        bounded probe / benchmark / TcpQuality / transient HTB
        默认不可达，必须显式授权、预算和独立证据目录
```

### 6.1 厂商预优化与配置所有权

运行时观察到 BBR 或根 `fq`，只证明当前值，不证明它由哪个文件持久化、重启后是否仍然
有效，也不证明不存在多个配置所有者。`preflight` 必须同时检查运行值、持久化来源、文件
类型与所有者、重复定义、根 qdisc 结构和现有受管状态，再选择以下路径：

| 当前基线 | 默认处理 | 理由 |
|---|---|---|
| 未配置 BBR/fq，且没有外部冲突 | 由项目写入并成为唯一所有者 | 路径清晰，可验证和回滚 |
| `/etc/sysctl.conf` 中各有一条、值严格为 `bbr`/`fq`、普通 root 文件 | 事务化备份并转移所有权，再由项目持久化 | 当前 rc.16 继续支持此窄范围迁移，rollback 可恢复厂商原文件 |
| 位于 `/etc/sysctl.d/*.conf`、重复定义、符号链接、非 root 文件、值不同或包含未知组合调优 | fail-closed，不自动合并或覆盖 | 无法可靠判断优先级、意图和完整回退边界 |
| 已存在其他版本的项目受管状态 | 进入跨版本迁移，不按厂商基线处理 | 旧版本状态包含原值、qdisc、swap 和备份所有权 |

因此，不按 VMISS、VMRack 或其他厂商品牌分支。厂商默认值已经满足需求，且用户只需要
BBR/fq 时，可以保持厂商配置、不安装本项目；需要本项目管理 buffer、swap、journald、
NOFILE、状态验证和回滚时，再进行唯一所有权接管。不得让厂商文件和项目文件长期共同定义
同一 sysctl key。

后续可增加显式的 `audit-only/keep-external` 模式，用于只核验外部配置而不接管；在该模式
实现前，复杂或含糊的厂商基线仍应阻断 `apply`，而不是猜测性清理。

### 6.2 默认 TCP 基线

- 保持 BBR + 根 `fq`；已有受支持的根 `fq` 不重建。
- socket buffer 继续使用 `端口带宽 × 目标 RTT` 的 BDP 推导，并受内存档硬上限约束：

| 资源档 | 100 Mbps | 200 Mbps | 500 Mbps | 1000 Mbps |
|---|---:|---:|---:|---:|
| 1C512MB | 16 MiB | 16 MiB | 16 MiB | 16 MiB，报告截断 |
| 1C1GB | 16 MiB | 16 MiB | 16 MiB | 32 MiB |
| 1C2GB/2C2GB | 16 MiB | 16 MiB | 32 MiB | 64 MiB |

- 保留当前受管 swap、journald、NOFILE、状态事务、qdisc 快照和恢复机制，但不把这些系统
  可靠性设置宣传成已证明的吞吐提升。
- `tcp_fastopen=3` 只代表内核能力；Xray listener 是否显式启用必须独立验证。
- 不默认新增 `fq maxrate`、持久 HTB、`initcwnd/initrwnd`、`tcp_slow_start_after_idle=0`、
  手工 `tcp_mem`、统一 1 MiB socket default、RPS/RFS/XPS 或 IRQ affinity。

### 6.3 统一入口与 profile 边界

- 用户不选择 `debian13-1c1g-vps-tuning.sh` 等 profile；只运行总控或 `dvt`。
- 总控自动识别 OS、架构、CPU 和内存档，端口带宽由用户或已有状态显式提供。
- 六份生成 profile 暂不删除，因为它们仍承担固定 Release hash、离线安装、旧版 rollback 和
  审计职责；后续可把其参数源收敛为 schema 化的声明式表。
- 不建立 VMISS、VMRack 等服务商品牌变体。

### 6.4 跨版本迁移

同一版本、同一 profile 的端口变化使用 `reconfigure`。跨版本可以“清除旧版后安装最新版”，
但“清除”必须由旧版固定 Release 根据自身状态执行受管 rollback/purge，而不是手工删除配置
文件、unit、状态目录或 swap，也不能让最新版直接覆盖旧版状态。在线业务 VPS 采用：

```text
旧版 verify
→ 旧版 rollback/purge
→ 恢复语义检查
→ reboot
→ 最新版 preflight/apply
→ reboot
→ 最新版 verify
→ 严格代理验证和业务冒烟
```

旧版清理是必要的，因为只有旧版脚本理解其状态 schema、原始 sysctl、qdisc 快照、厂商
配置备份和项目创建的 swap。当前 rc.16 因而有意拒绝直接接管其他版本状态。`purge` 也只应
删除状态证明由项目创建、且能够安全停用的资源。

这条路径不附带 TcpQuality、HTB reference 或 A/B/A。rc.15 已实现带 checkpoint/resume 的
`migrate` 编排入口，自动完成资产、状态、旧版回退、boot ID 和目标生命周期等机器可判定
门禁；控制台可用、维护窗口和不可恢复风险仍由人工确认。对于一次性或可快速恢复、业务和配置备份已经验证的 VPS，干净重装 OS 后直接执行
最新版 `preflight/apply` 是更简单的第二条受支持路径。

若旧状态缺失、损坏，或来自没有可靠状态契约的早期脚本，最新版不得充当通用卸载器。此时
应先保存只读证据，再使用对应旧版恢复逻辑、经审查的人工清理，或直接干净重装。

## 7. 分层测试策略

### L0：本地确定性验证，每个候选版本必做

零公网测试流量，覆盖：

- 六份 profile 生成一致性、Bash 语法和固定 ShellCheck；
- OS/CPU/内存/端口边界 fixture；
- 状态 schema、原子写、所有权、完整性和混合 Release 拒绝；
- qdisc 快照、恢复语义、未知拓扑 fail-closed；
- swap、NOFILE、update、reconfigure、recover、rollback 故障注入；
- HTB 工具的纯 fixture 生命周期和恢复；
- 文档、manifest、Release 资产反向校验。

L0 失败即阻断发布，不用目标 VPS 测速弥补。

### L1：专用 root 生命周期验证，按变更触发

使用可重装、可控制台救援、不承载业务的环境；不执行公网性能测试。至少覆盖：

- Debian 12 和 Debian 13；
- 512 MiB、1 GiB、2 GiB 三种资源语义；
- preflight、apply、立即 verify、reboot verify、重复 apply；
- 严格代理 NOFILE；
- rollback/purge/reboot 和一个受控失败恢复路径。

文档或哈希变化不重跑整个矩阵。只有模板、资源算法、状态事务、qdisc、swap、迁移或 OS
兼容性变化时，才运行受影响组合。

### L2：每台业务 VPS 的默认验收

不执行合成大流量。只验证：

1. 脱敏基线：OS、内核、资源、磁盘、swap、路由、qdisc、状态和服务；
2. 固定 Release 完整性与 preflight；
3. apply/迁移后的立即 verify；
4. reboot 后 verify；
5. x-ui/Xray strict verify；
6. 少量真实代理业务：DNS、TLS/REALITY、常用站点、小文件和短连接；
7. 5–30 秒只读 `diagnose`，确认没有 OOM、服务重启、接口错误、qdisc drop 持续增长或
   softnet 异常增量。

默认业务冒烟累计传输上限为 50 MB/主机/变更窗口；超过必须升级为 L3 并显式授权。

### L3：症状触发的有预算诊断

只在出现可复现业务症状或网络算法实质变化时执行。要求：

- 固定用户控制或获授权的 endpoint、方向、地址族、run ID 和证据目录；
- 先采集被动诊断，再决定是否生成主动流量；
- 单流优先，固定字节数优先于固定秒数，避免 1 Gbps 主机按相同时长消耗更多流量；
- 单次 payload 硬上限 300 MB，整个变更窗口硬上限 600 MB；
- 默认不自动重试，失败后先诊断原因；
- 必须同时记录精确 sender bytes、sender retransmits、吞吐、CPU、接口、softnet 和 qdisc；
- 结果只回答是否存在明显退化，不自动授权 HTB 或宣称代理业务性能提升。

rc.15 的四条主动流量入口已接入同一 root-only ledger；仍须先在计划阶段确认协议和服务商
计费余量，不能把本地 payload 上限解释为服务商面板的精确扣费值。

### L4：研究级公网实验

只使用独立高额度或不计流量、可重装、无业务的测试机。进入条件：

- 已有真实业务问题和明确待决问题，例如“是否需要永久聚合整形”；
- L2/L3 证据排除了明显主机资源、配置和服务故障；
- 用户预先批准总字节、最长时间、最大失败次数和停止条件；
- 服务商面板剩余额度可核对，预算覆盖双向计费、协议开销和失败余量；
- 每个阶段验证变量实际生效，`COMPLETED`、manifest、ACTIVE/恢复和分析结果完整；
- 公共节点、时段、IPv4/IPv6 和真实代理路径结论分开。

HTB 研究顺序仍可采用 reference → candidate → A/B/A → 反向窗口，但任何前置结论已足以
停止时立即结束，不以完成既定序列为目标。TcpQuality `--all` 不作为默认工具；需要多节点线路
研究时单独批准流量预算。

## 8. 变更触发矩阵

| 变更类型 | L0 | L1 | L2 | L3/L4 |
|---|---|---|---|---|
| 仅文档、说明或 manifest 重签 | 必做相关检查 | 不做 | 不做 | 不做 |
| 控制器选择或 Release 分发变化 | 必做 | 安装生命周期抽样 | 代表机轻量验收 | 不做 |
| sysctl/buffer 公式变化 | 必做全矩阵 | 受影响资源档 | 代表业务机轻量验收 | 有退化症状才做 L3 |
| qdisc/swap/状态事务变化 | 必做故障注入 | 受影响生命周期与恢复 | 代表机轻量验收 | 不默认做性能 |
| 内核或 Debian 主版本变化 | 必做兼容检查 | 新环境完整生命周期 | 代表机轻量验收 | 有症状才做 L3 |
| 服务商换路由或用户报告性能问题 | 不一定 | 不一定 | 先做被动诊断 | 明确授权后做 L3 |
| 准备发布永久 HTB 性能主张 | 必做 HTB fixture | 专用测试机恢复 | 不在业务机试错 | 必须完成 L4 |

## 9. 流量预算和自动停止契约

主动测试工具必须共享同一变更窗口预算，而不是各自只计算单次 payload：

```text
窗口预算 = benchmark + probe + TcpQuality + HTB reference/sweep
         + upload + download + 已失败阶段 + 已批准重试
```

最低契约：

- 计划阶段输出总预算、方向、计费假设和最坏上界；
- runner 在每阶段前检查剩余本地预算，并在达到上限前拒绝启动；
- 实际 sender/receiver bytes 持久化到统一 ledger；
- 失败阶段仍计入预算；
- runner 不因阶段失败自动重新执行；
- provider 面板无法 API 化时仍保留人工额度门禁，但不能替代本地硬上限；
- 超预算、证据目录不完整、变量未生效、恢复失败、服务异常、OOM、接口错误或 qdisc drop
  异常增长时立即停止；
- 测试结束后验证 state、sysctl、qdisc、服务和 watchdog 已恢复。

## 10. 验收与证据分层

| 结论 | 最低证据 |
|---|---|
| Release 可分发 | L0、公开资产和摘要链完整 |
| 调优脚本生命周期可用 | L1 的 apply/reboot/verify/rollback 证据 |
| 某台 VPS 升级成功 | 该机 L2 生命周期和严格服务验证 |
| 某台 VPS 真实代理可用 | 该机 L2 真实代理冒烟 |
| 没有明显性能退化 | 同机、同路径、有预算的 L3 对照 |
| HTB 候选值得复验 | 完整 HTB reference/candidate 窗口，不含无效 B 阶段 |
| 永久 HTB 有因果收益 | 独立 L4 A/B/A、反向窗口及真实代理路径复验 |
| 所有服务商都应使用某参数 | 多服务商、多时段、同方法的独立证据；当前尚不存在 |

较低证据层级不得继承为较高层结论。目录名、`PASS` 文本、unit active、单次 benchmark 或
工具 smoke 都不能替代变量生效检查和业务验收。

## 11. 实施优先级

### P0：立即收敛默认流程

- 将完整 Basic HTB campaign、1C2G A/B/A 和 TcpQuality 多轮协议标记为研究专用；
- README 和每台 VPS 验收顺序默认只指向 L2；
- 停止把 HTB/TcpQuality 作为版本迁移门禁；
- 当前 VMISS Basic 若继续 rc.11→rc.14，只走跨版本迁移和 L2。

### P1：实现硬预算和统一证据 ledger（rc.15 已实现）

- 为 benchmark、probe、TcpQuality 和 HTB runner 增加共享字节预算；
- 失败不自动重试，预算不足 fail-closed；
- 把空目录、缺 manifest、变量未生效和恢复不完整统一标记为 `REVIEW_BLOCKED`。

### P2：简化入口和迁移（rc.15 已实现 checkpoint/resume）

- 参数源收敛为声明式资源表，继续从单一模板生成不可变 profile；
- 增加带 checkpoint/resume 的迁移编排，减少人工微门禁；
- 复用现有只读 `preflight` 作为厂商基线 audit/keep-external 决策点，不增加同义 action；
- 保留旧版固定资产执行 rollback 的兼容面。

### P3：建立专用研究环境

- 只有准备发布性能或永久 HTB 主张时，才配置高额度测试 VPS 和受控 endpoint；
- 研究证据与业务 VPS 证据分库存放，不再把公共节点结果混入生命周期验收。

## 12. 风险、缓解和退出路径

| 风险 | 缓解 | 退出路径 |
|---|---|---|
| 轻量验收漏掉特定公网性能问题 | 真实业务冒烟 + 被动 diagnose；症状触发 L3 | 进入有预算单机诊断 |
| 单一模板缺陷影响所有 profile | 声明式上限、全矩阵 fixture、代表性 L1 | 回退固定 Release |
| 跨版本 rollback 导致远程失联 | 控制台、第二 SSH、阶段 checkpoint、恢复语义检查 | 旧版恢复或干净重装 |
| 预算工具与服务商计费不一致 | 本地硬上限 + 面板余量 + 双向/开销保守系数 | 提前停止，不继续候选实验 |
| 不使用默认 HTB 后仍有重传 | 保留 root `fq`，按节点/路径/时段诊断 | 专用 L4 验证后再决策 |
| UDP 负载被 TCP 基线遗漏 | 按应用和协议建立独立需求与证据 | 保持内核默认，不做通用 UDP 改参 |

## 13. 实施决定与剩余工程

用户已批准本方案，当前实施决定如下：

1. P0 已实施：README、验证矩阵、设计边界和四份 HTB SOP 已明确默认低流量路径及研究效力；
2. 不新增 `audit-only/keep-external` action；现有 `preflight` 已提供零写入审计，操作者可停在
   审计后保持厂商配置；
3. 不把自动跨版本迁移伪装成单次命令；现有 `update` 继续负责只读校验和计划，旧版固定资产
   负责 rollback/purge，重启边界保留；后续 checkpoint/resume 只自动化机器可判定步骤；
4. 统一流量 ledger、TcpQuality 硬预算和跨工具 fail-closed 默认值会改变 Release 资产行为，
   必须进入下一候选版本，不得静默改写已经发布并固定哈希的 rc.14；
5. L2 50 MB、L3 单次 300 MB/窗口 600 MB 在工具能够准确记账前只作为设计上限，不冒充
   已强制门禁；现有 `probe` 必须显式 `--plan-only` 和 `--budget-mib`，HTB/TcpQuality 默认不执行；
6. P3 只有在准备发布性能或永久整形主张时启动，不为当前业务 VPS 分配或消耗测试资源。

在下一候选版本的硬预算实现、fixture、Linux root 生命周期和公开资产完整性闭合前，不得声称
P1/P2 工具行为已经交付。现有 HTB 文档仅作为研究材料，不应在配额业务 VPS 上执行。
