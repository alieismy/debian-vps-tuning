# 项目阶段备忘

文档性质：资料性状态与延期事项记录
当前阶段：rc.15 有预算诊断与可恢复迁移实现和发布（已完成，待下一阶段决策）
更新日期：2026-08-30（Asia/Singapore）

本文件是 `AGENTS.md` 指定的唯一项目阶段备忘入口，用于记录每轮对话工作的闭环状态，以及当前阶段不主动展开的后续候选事项。它不构成需求批准、生产变更授权、发布授权或下一阶段启动决定；控制规则以 [项目级 AGENTS.md](../AGENTS.md) 为准，具体验证事实以 [验证矩阵](validation.md) 和对应发布说明为准。

## 本轮记录：2026-08-30（rc.15 实现、CI 与 Pre-release 闭环）

### 已完成及证据

- 项目控制面已切换到 `v0.1.0-rc.15` 阶段，并明确本阶段只实现共享流量预算、可恢复迁移、统一资产与发布闭环；永久 HTB、通用 UDP、真实 VPS 变更和公网性能 campaign 均未扩入。
- 新增 `dvt-traffic-budget.sh` 事务 ledger。benchmark、`dvt probe`、TcpQuality 和 HTB runner 在发流量前必须原子保留完整计划 payload；已知 sender bytes 按实际值提交，未知或失败按计划上界保守结算，余额不足时 fail-closed。账本同时保留协议开销和服务商计费口径未知边界。
- 新增 `dvt-migrate.sh` 持久 checkpoint/resume。checkpoint 固定并校验旧版 profile、目标 profile 和迁移器自身哈希，按旧版 rollback/purge、第一次 boot-ID gate、目标 preflight/apply、第二次 boot-ID gate、最终 verify 推进；工具不自动 reboot，也不替代控制台或业务验收。
- 总控、六份单模板生成 profile、installer、TcpQuality、probe、HTB runner、清单、README、CHANGELOG 和发布说明已统一为 `0.1.0-rc.15`。`SHA256SUMS` 管理资产由 15 项增至 17 项；Release 总资产为 19 项。
- 本地门禁通过：profile 再生成一致性、Bash 语法、17 项 `SHA256SUMS`、controller/static fixture、HTB fixture 和 `git diff --check`。Windows Git Bash 对 root-only `tests/rc15-check.sh` 按设计拒绝执行，没有将其冒充为本地通过。
- PR [#12](https://github.com/alieismy/debian-vps-tuning/pull/12) 合并提交为 `21177fe7943bbfe7592461ca532e0c5dc369efdb`。首轮 CI 的两条 `validate` 均因确定性的 ShellCheck `SC2015/SC2034` 失败；修复显式条件和 fixture 抑制后，两条新 `validate` 分别以 42 秒和 44 秒通过，覆盖固定 ShellCheck 0.11.0、Linux root installer lifecycle、预算超额/保守结算和迁移两次 boot gate fixture。
- CodeRabbit 仅留下针对首个提交范围的 `review in progress` 评论，没有形成 review、行内意见或 required check；本轮没有把该停滞状态描述为审查通过，也未用它替代 CI 和人工 diff 审计。
- annotated tag `v0.1.0-rc.15` 的远端 peeled target 已核对为合并提交 `21177fe7943bbfe7592461ca532e0c5dc369efdb`。已发布非 Draft 的 [GitHub Pre-release](https://github.com/alieismy/debian-vps-tuning/releases/tag/v0.1.0-rc.15)，19 个资产均为 `uploaded`。
- 公开匿名反向下载通过：`SHA256SUMS` 的 17 个逻辑资产全部逐项匹配；清单 SHA-256 为 `374e4b912b4beb8300a2bb0aeb4f16e364cdf33d19455fa44e12a5b8464f1da1`，installer SHA-256 为 `4c7798afd48478854ac0d3ac16197d73147464d95c8b4f1a35241dec8cf4e5fd`。验证临时目录已安全清理。

### 未完成门禁

- 本轮没有连接或修改任何真实 VPS，没有执行 rollback、reboot、apply、HTB、TcpQuality 或公网测速。rc.15 发布完整性不证明目标 VPS 的迁移、重启持久性、控制台恢复、严格 3X-UI/Xray 验证或真实代理业务链路通过。
- 流量 ledger 核算应用层 payload，不覆盖 TCP/IP、链路、重传及服务商计费差异；服务商面板剩余额度、维护窗口和独立测试机授权仍是运行前人工门禁。
- 目标 VPS 生命周期和真实业务验收可作为发布后验证项保留。是否选择低风险节点执行 rc.14→rc.15 checkpoint 迁移，须由用户另行授权；不得因 Pre-release 已发布而自动执行。

### 延期事项变化

- P1 共享流量 ledger、TcpQuality 硬预算和 P2 checkpoint/resume 迁移已从延期候选转为 rc.15 已实现、已通过 fixture/CI、已发布能力。
- 永久 HTB、通用 UDP 调参、网络安全专项、全面生产加固和新的高流量性能 campaign 继续保持既有延期/未授权状态。
- 无新增延期事项。CodeRabbit 停滞评论是本次 PR 的证据限制，不新增为项目功能或发布门禁。

### 当前成熟度判断

rc.15 当前阶段的代码、fixture、生成资产、固定摘要、PR/CI、annotated tag、Pre-release 和公开资产反向验证已经闭合，满足本阶段完成定义。目标 VPS 生命周期、重启和业务验收仍明确未验证，但按阶段规则可作为发布后事项保留。下一阶段应由用户在“低风险目标 VPS 迁移验收”“继续收敛声明式资源策略”或“稳定版门禁规划”等候选中另行决策；本轮不自动修改 `AGENTS.md` 进入下一阶段。

## 本轮记录：2026-08-29（项目级网络调优与分层测试方案）

### 已完成及证据

- 已全量枚举并只读检查 `VMISS/测试/htb-aggregate` 的 23 个文件和 `VMISS/测试/Core` 的 89 个文件、43 个目录；完成扩展名/大小盘点、重复 SHA-256 分组、21 个 JSON 可解析性检查、关键日志与归档内容提取。Core 的 89 个文件实际只有 50 个唯一摘要，包含根目录与 baseline 目录的重复副本。
- `htb-aggregate` 的旧 S4 A1/B1/A2 再次确认 B1 未启用 HTB，三个根 `fq` 窗口约产生 9.094/7.596/8.296 GB egress；`cap200.json` 的单流 10 秒上传为约 199.96 Mbps、0 sender retrans、host CPU 约 1.86%。1C2G v0.3.0 stage0 的 13 项清单重新计算均匹配，只证明短时 HTB 生命周期和根 `fq` 恢复。
- Core 的 rc.12 1C2G/200 Mbps 证据支持 preflight、apply、立即/重启后 verify、幂等、BBR + 根 `fq`、16 MiB buffer、项目 swap 和安装 3X-UI 后 strict NOFILE 验证。baseline manifest 声明的 46 项中，30 项在原位置匹配，13 项在 Core 根目录有摘要匹配副本，3 项 project-state snapshot 缺失，故本地副本不是完整独立证据包。
- Core 的 `htb200-reference-*`、closeout、probe 和 cap200 目录多为空目录或空层级；reference/sweep JSON 仅为 3/15 阶段计划，未保存 benchmark、runtime、manifest、`COMPLETED` 或分析结果。不得从目录名推断 reference 或 candidate sweep 已执行。Core 保存的旧 rate-sweep/HTB 脚本摘要也与当前 rc.14 仓库实现不同。
- 已结合 Basic 历史 29 次 TcpQuality、约 264.27 GB 日志窗口出站流量及路径/时段漂移，形成建议性技术方案 [Debian VPS 网络调优与测试策略](network-tuning-and-test-strategy.md)：推荐“单一入口 + 声明式资源策略 + 分层验证”，默认保持 BBR + 根 `fq`，HTB/TcpQuality 降为研究通道。
- 已按当前 rc.14 源码补充厂商预优化决策：运行时已有 BBR/fq 不等于持久化所有权清晰；对 `/etc/sysctl.conf` 中唯一、严格为 `bbr`/`fq` 的 root 普通文件，现有实现可事务化备份并接管；对 `/etc/sysctl.d`、重复定义、符号链接、非 root 或未知组合调优保持 fail-closed。厂商品牌不成为 profile 维度。
- 已明确跨版本可采用“受管清除旧版后安装最新版”，但必须由旧版固定 Release 按旧状态执行 verify、rollback/purge 和恢复检查；最新版不直接覆盖旧状态，也不以手工删除配置替代回滚。对可快速恢复且备份已验证的 VPS，干净重装 OS 后直接应用最新版是独立的简化路径。
- 用户已批准该方案，P0 控制面已实施：中英文 README、`docs/validation.md`、`docs/design-scope.md` 和四份 HTB SOP 已同步为“默认低流量生命周期与业务冒烟、主动性能实验研究专用”。现有 `preflight` 被明确为厂商基线零写入审计点，现有 `update` 保持只读计划入口，没有增加同义 action 或伪自动迁移。
- `tests/static-check.sh` 已增加文档效力防回退门禁，要求中英文默认路径、旧版固定 Release 清理契约、厂商基线例外和四份 HTB 研究材料的 `研究专用` 标记持续存在，并拒绝恢复旧 Basic “当前权威执行文档”状态。
- 最终本地验证通过：`git diff --check`、生成 profile 一致性、15 项 `SHA256SUMS`、controller fixture、HTB fixture、完整 `tests/static-check.sh` 和修改文档本地链接检查均通过。静态测试中的故意畸形 TcpQuality fixture 按预期输出 FAIL 后，整个 suite 以 0 退出。rc.14 总控、profile、伴随工具和 `SHA256SUMS` 均未修改。

### 未完成门禁

- 本轮没有连接或修改任何 VPS，没有执行测速、HTB、迁移、rollback、reboot、apply、发布或生产变更；VMISS Basic rc.11→rc.14 迁移继续暂停。
- P0 已完成，但 P1/P2 的统一流量 ledger、TcpQuality 硬预算、跨工具 fail-closed 默认值、声明式参数源和 checkpoint/resume 迁移编排尚未实现。它们会改变 Release 资产行为，必须进入下一候选版本，不能静默改写已发布 rc.14。
- 不再新增 `audit-only/keep-external` action：当前 `preflight` 已满足零写入审计，操作者可停在其后保持厂商配置；复杂或含糊的外部所有权继续阻断。
- L2 默认 50 MB、L3 单次 300 MB/窗口 600 MB 已获方向批准，但目前仍只是设计上限；只有由下一候选版本工具 fail-closed 强制后，才可声称是项目规范性硬门禁。
- 本机没有 `shellcheck`，因此本轮没有新增本地 ShellCheck 证据；固定 ShellCheck 与 Linux root 生命周期仍须由下一候选版本的既有 CI 门禁执行。

### 延期事项变化

- 既有“完整 HTB campaign 研究专用”已落地为控制文档和静态门禁；“跨工具硬流量上限”“单一总控/声明式资源表”和“checkpoint/resume 迁移编排”已获方向批准，但延期到下一候选版本实施和验证。
- 撤销“新增显式 audit-only action”候选：复用现有 `preflight` 更简单，且不产生重复命令面；兼容基线仍可事务化接管，复杂基线继续阻断。
- 无新增网络安全专项或全面生产加固事项；本轮没有扩大到服务商 policer 归因、通用 UDP 参数或永久 HTB 设计。

### 当前成熟度判断

项目级默认路线和 P0 文档效力已经闭合：业务 VPS 不再承担研究级公网实验，发布确定性验证、目标机生命周期、真实业务冒烟、症状诊断和研究实验已经分层并有静态防回退门禁。剩余高优先级工程主要是下一候选版本的硬预算、统一 ledger 和迁移编排，以及对应 Linux root/目标机验证；不能作为 rc.14 的原地修改。

## 本轮记录：2026-08-28（VMISS HTB 实验成本复盘与路线收敛）

### 已完成及证据

- 已只读复核 `VMISS/测试/Basic` 历史证据。`rc11-vmiss-basic-evidence-final-20260806.tar` 的 SHA-256 与随附清单一致，归档内为 S1b、S2 共 6 次 TcpQuality；按每次测试前后根 qdisc `Sent bytes` 差值重算，约产生 43.09 GB 出站流量。
- 同目录后来追加的 S3A–S3F、S4 证据合计为 29 次 TcpQuality；用相同口径逐日志重算约 264.27 GB（246.12 GiB）出站流量。该值尚不包含下载方向、失败尝试、协议开销、背景业务和服务商计费口径，因此支持用户所述“几百 GB”运营影响，但不能把全部额度消耗精确归因于这 264.27 GB。
- 现有完整 Basic SOP 还要求 HTB200 reference、180/190/195 sweep、A/B/A 和反向窗口；1C2G A/B/A SOP 又明确依赖已冻结候选。历史证据同时显示公共节点、时间窗口和路径波动足以显著影响结果，继续增加主动流量的边际证据价值不足以覆盖额度、时间和停机风险。
- 已确认仓库当前并非维护六套独立调优算法：六个 profile 由单一 `tools/profile-template.sh.in` 和 `tools/render_profiles.py` 生成，总控已按 Debian 主版本、CPU/内存档位自动选择，并将端口带宽作为显式输入。后续可进一步简化用户入口，但 OS 差异、资源边界、状态所有权和发布哈希仍须保留为可审计契约。

### 未完成门禁

- 此前准备的 rc.11 purge rollback 继续暂停；本轮没有执行目标 VPS 写入、rollback、reboot、rc.14 apply 或 HTB 流量。
- 当前不再把“VMISS Basic 1C1G / 200 Mbps HTB 完整实验”和“VMISS 1C2G / 200 Mbps 临时 HTB A/B/A”作为该 VPS 升级或日常验收门禁。只有在出现可复现的真实业务症状、明确需要形成 HTB 因果结论、使用独立高额度测试机并预先批准硬流量预算时，才重新评审是否执行。
- rc.11→rc.14 若继续，仍须保留状态所有权、固定资产完整性、可恢复入口、rollback 后复核、重启持久性和最终 verify 等安全不变量；可把它们自动编排成更短的迁移流程，但不能把“简化操作”解释为删除恢复和完整性门禁。

### 延期事项变化

- 新增候选：将完整 HTB campaign 标记为研究专用、非默认验收，并为所有主动测速增加跨阶段硬流量上限与自动停止机制；是否修改文档和工具等待用户批准。
- 新增候选：把外部使用面收敛为单一总控、单一规范引擎和小型声明式资源表，生成 profile 仅保留为发布兼容/审计资产；是否实施及兼容策略等待独立方案评审。

### 当前成熟度判断

当前证据足以停止在额度受限生产 VPS 上继续扩大 HTB 主动实验；项目应把重心转回低流量生命周期验证、重启持久性和真实业务冒烟。版本迁移是否继续由用户决定，HTB 因果研究不再作为其前置或后置默认门禁。

## 本轮记录：2026-08-28（VMISS Basic rollback 前最终门禁）

### 已完成及证据

- 同一 root-only 迁移目录的续跑检查完成，rc.11 profile 与 rc.14 总控再次通过固定 SHA-256；live state 与回滚前备份仍为同一 SHA-256，`LIVE_STATE_UNCHANGED=PASS`。
- `/swapfile-proxy` 的 state path、1024 MiB 大小、active、device `65025` 和 inode `16919` 与实际 regular file 完全一致，权限为 root:root/0600，swapon 和唯一 fstab 行均通过。采集时 swap 仅使用 268 KiB，`MemAvailable` 为 582288 KiB；按本轮运维安全门禁具备执行受管 swapoff 的容量余量。
- 当前 HTB state absent；sysctl 为 BBR + fq/16 MiB，`eth0` 为单一根 `fq`、class 为空且 drops/requeues/backlog 为 0；`proxy-vps-fq.service` 与 `x-ui.service` active，无 failed unit。
- 固定 rc.11 profile 最终 `verify` 通过、警告数 0；证据 state/qdisc/class 已闭合哈希，最终 `STAGE1_READINESS=PASS`、`RESUME_RC=0`。维护就绪技术门禁已通过。

### 未完成门禁

- 有状态 rc.11 `PURGE_CREATED_SWAP=1 rollback` 尚未执行。执行前仍需操作者实际确认 VMISS 控制台可用、第二 SSH 会话已建立、维护窗口生效且无更新/测速/备份；这些人工条件不能由主机日志替代。
- rollback 必须独立执行并停在即时复核：若失败，保留 state/swap/qdisc/服务现场且不做手工删除；若成功，确认 state、项目 swap、fstab 行和受管文件完成清理，qdisc/sysctl 恢复语义通过、x-ui/SSH/出口仍可用。第一次 reboot 仍须等待该复核结果，不能与 rollback 合并。
- rc.14 preflight/apply、第二次 reboot/verify、HTB v0.4.0 与 HTB200 reference 继续保持阻断。

### 延期事项变化

- 无新增延期事项；本轮仅推进已批准的版本迁移门禁。

### 当前成熟度判断

当前 VMISS Basic 已达到 rc.11 purge rollback 的技术开始条件，但尚未执行任何有状态迁移。项目下一安全检查点是 rollback 后即时复核，不是 rc.14 apply 或 HTB。

## 本轮记录：2026-08-28（VMISS Basic 维护就绪检查续跑）

### 已完成及证据

- 固定 rc.11 profile 与 rc.14 总控已预下载到独立 root-only 迁移目录并分别通过预期 SHA-256；rc.11 schema 3 `VERIFIED` state 已复制到证据目录，原件与副本 SHA-256 均为 `6ad01b9b64c82a409e8fd271e9d1850eca2cf59fd9dc5a4bcb734566f37bee33`，`cmp` 门禁通过。
- state 再次确认 `debian13-1c1g`、rc.11、200 Mbps；`/swapfile-proxy` 被状态声明为脚本创建、1024 MiB、active，并记录 device/inode。主机约 967 MiB RAM，采集时 `MemAvailable` 约 570 MiB，swap 仅使用约 268 KiB；这些数据支持继续完成只读就绪检查，但尚未完成文件所有权和最终 rc.11 verify 门禁。
- 首次就绪脚本在 `swapon --show --bytes --output=...` 处以 `PREP_RC=1` 停止。目标 util-linux `swapon` 不接受该 `--output` 组合；这是采集命令兼容性错误，不是 swap、主机或迁移失败。已将续跑命令修正为 `swapon --show=NAME,TYPE,SIZE,USED,PRIO --bytes`，不重用失败结论，也不重新下载已校验资产。

### 未完成门禁

- 须从现有迁移目录续跑并确认：当前 state 未漂移、swap device/inode/fstab/active 所有权一致、内存占用可接受、HTB inactive、根 qdisc/class 正常、服务与 failed units 正常、固定 rc.11 profile `verify` 通过，以及续跑日志与证据摘要闭合。
- `PREP_RC=1` 不授权 rollback。rc.11 purge rollback、回滚后复核和所有后续重启/apply/HTB 阶段继续保持阻断。

### 延期事项变化

- 无新增延期事项；本轮仅修正目标工具的命令行兼容性，不改变实验或迁移范围。

### 当前成熟度判断

固定资产与 state 备份门禁已通过，维护就绪检查因可修正的只读采集命令错误中断。当前应在同一证据根下续跑剩余检查；尚未达到有状态 rollback 门禁。

## 本轮记录：2026-08-28（VMISS Basic rc.14 update 门禁）

### 已完成及证据

- 用户已在当前 VMISS Basic 上使用固定 rc.14 总控执行显式 `update --target v0.1.0-rc.14`；总控资产 SHA-256 通过，最终 `UPDATE_RC=0`，完整日志 SHA-256 为 `45b1c40a23001d7af4e7e108215b4d1e31eb4c7786434149d3954174c81c5290`。
- update 重新识别出 Debian 13、1 vCPU、967 MiB、`debian13-1c1g`、当前 rc.11/schema 3 `VERIFIED`、200 Mbps；固定 rc.11 profile 下载并通过当前配置普通/严格服务验证，警告数为 0，x-ui 主进程及直接 Xray 子进程 NOFILE 均为 65536/65536。
- rc.14 固定 profile `debian13-1c1g-vps-tuning.sh` 的 update-preflight 通过，确认根 `fq`、活动 swap、16 MiB auto buffer、`eth0` 默认出口和 UFW 只读状态；预检警告数为 0，系统配置未修改。
- 固定迁移材料已由目标机输出确认：当前 rc.11 profile SHA-256 为 `354a0750eff7fd76910d91a2e71eab9e3936548314e551b11acb6c95b438af2d`，目标 rc.14 总控 SHA-256 为 `ce7668806ee0f3afb58aff18c2d6cdab8df58028d60390ba37e3ddf26b513248`，迁移继续保留 200 Mbps。

### 未完成门禁

- update 只授权准备维护迁移，不等于 rc.14 已安装。进入变更前仍须预下载并分别校验 rc.11 profile 与 rc.14 总控，保存回滚前 state/qdisc/sysctl/swap/服务证据，再次执行固定 rc.11 profile `verify`，确认项目 swap 所有权、实际 swap 使用量、可用内存、第二 SSH 会话和 VMISS 控制台救援入口。
- rc.11 `PURGE_CREATED_SWAP=1 rollback`、回滚后语义复核、第一次重启、rc.14 preflight/apply、第二次重启、普通/严格 verify 均未执行；任一步失败必须停止，不得跳过重启或直接越过状态门禁。
- rc.14 生命周期闭合前，HTB v0.4.0 和 HTB200 reference 继续保持阻断。

### 延期事项变化

- 无新增延期事项。update 输出的 UFW 规则属于当前只读环境证据；本轮不把防火墙治理扩展为独立安全专项，既有延期状态不变。

### 当前成熟度判断

当前 VMISS Basic 已通过 rc.11→rc.14 的只读兼容性门禁，下一安全检查点是维护窗口就绪与固定资产预置；尚未进入有状态 rollback 或 rc.14 apply，项目阶段不变。

## 本轮记录：2026-08-28（VMISS Basic 当前基线判定）

### 已完成及证据

- 已复核用户从当前 VMISS Basic 返回的只读基线：Debian 13、Linux 6.12.101、1 vCPU、约 968 MiB RAM、约 1 GiB swap、ext4、约 6.4 GB 可用空间；managed state 为 schema 3、`VERIFIED`、`0.1.0-rc.11`、`debian13-1c1g`、200 Mbps。
- 当前没有安装 `dvt`/Release 目录，没有 `/run/htb-aggregate-experiment/active.json`；`eth0` 为 IPv4/IPv6 默认出口，根 qdisc 为单一 `fq`、class 为空、qdisc drops/requeues/backlog 为 0，`proxy-vps-fq.service` 为 active。该证据只确认当前旧版运行状态，不替代 rc.11 固定资产的 `verify`。
- 已判定 rc.11 schema 3 是 rc.14 HTB v0.4.0 的硬阻断项；不能直接安装 v0.4.0、执行 smoke 或生成 HTB200 reference，也不能用 rc.14 `apply`/`reconfigure` 覆盖旧状态。
- 下一相邻门禁确定为：使用固定并校验的 rc.14 Release 总控执行显式 `update --target v0.1.0-rc.14` 只读升级检查，保存完整输出和退出码。本步骤只下载、校验并执行只读 current verify/target update-preflight，不授权 rollback、apply、重启或 HTB 流量。

### 未完成门禁

- rc.14 `update` 只读检查尚未执行，当前 rc.11 固定 Release 资产、当前 profile `verify` 和 rc.14 `update-preflight` 仍待输出确认。
- 只有 update 检查通过并核对其输出的固定 URL、SHA-256、profile、端口和迁移顺序后，才可另行进入有控制台保障的维护窗口；rc.11 verify、显式 swap purge rollback、第一次重启、rc.14 preflight/apply、第二次重启和严格 verify 均未执行。
- rc.14 生命周期闭合前，HTB v0.4.0 preflight/smoke、5 样本 HTB200 reference 和所有后续候选实验继续保持阻断。

### 延期事项变化

- 无新增延期事项。网络安全专项、全面生产加固、复杂测试工程和 CI 依赖维护的既有状态不变。

### 当前成熟度判断

当前 VMISS Basic 的旧版运行态健康条件基本满足，但管理基线仍停留在 rc.11/schema 3。项目下一安全检查点是 rc.14 只读 update 门禁；尚未进入目标机迁移、rc.14 生命周期或 HTB reference 阶段，项目阶段不变。

## 本轮记录：2026-08-28（VMISS Basic HTB 历史证据复核）

### 已完成及证据

- 已只读复核用户提供的 `htb-aggregate` 目录及其归档、独立 iperf3 结果和 1C2G stage0 证据，并与 rc.14 的 HTB v0.4.0 reference/candidate 契约对照；未连接或修改目标 VPS，未执行 qdisc、测速、安装、升级或持久化操作。
- `S4-HTB-20260810T141025Z.tar.gz` 中 A1/B1/A2 的 TcpQuality 批次均有旧版 `COMPLETED`，但所谓 B1 的 start 日志只到 preflight；负载前后均为 `state=INACTIVE`、单一根 `fq`、class 为空且 watchdog inactive。因此该归档不是有效 HTB190 B 阶段，不能用于聚合整形效果判断。
- 独立 `cap200.json` 记录了一次根 `fq` 下的单流、10 秒、200 Mbit/s iperf3 上行：sender 约 199.96 Mbit/s、sender retransmits 为 0、host CPU 约 1.86%；对应前后快照始终为根 `fq`，未启用 HTB。该结果只提供当时单次路径能力线索，不是 HTB200 reference 样本。
- `stage0-v030-20260816T102145Z` 的 13 项清单在本地重新计算 SHA-256 后全部匹配；日志证明旧 v0.3.0 在当时的 `debian13-1c2g` schema 4、200 Mbps 基线上完成 190 Mbit/s 的短时挂载、ACTIVE、watchdog、stop 和根 `fq` 恢复。smoke 期间 `overlimits=0` 且无测量负载，因此只证明旧版生命周期和恢复，不证明整形暴露或性能收益。
- 三组材料至少涉及 2026-08-10 的 1C1G 旧目标和 2026-08-16 的 1C2G 旧目标；文件内记录的目标地址也不等于用户本轮指定的当前目标。不能跨主机、profile、版本、时间和测试方法拼接成当前 VMISS Basic 的候选速率证据。

### 未完成门禁

- 当前目标仍缺少 rc.14 固定 Release、schema 4 `VERIFIED`、实际 `debian13-1c1g` 或 `debian13-1c2g` profile、200 Mbps 端口、单一根 `fq`、managed-state SHA-256 和 v0.4.0 执行器哈希的现场只读确认。
- 当前目标仍未完成 v0.4.0 的 preflight、10 秒 smoke 和恢复复核；旧 v0.3.0 smoke 不继承为 rc.14/v0.4.0 通过。
- 当前目标仍未形成 schema 3、5 样本的 HTB200 reference，也没有有效的测量、HTB 暴露和资源三类 gate；因此 180/190/195 candidate sweep、候选冻结、A/B/A、反向窗口、真实代理链路复验和永久整形均未获相邻阶段证据授权。

### 延期事项变化

- 无新增延期事项。网络安全专项、全面生产加固、复杂测试工程和 CI 依赖维护的既有状态不变。

### 当前成熟度判断

旧证据已完成真实性与适用性分层，但当前 VMISS Basic 尚未进入 rc.14 HTB 速率发现的目标机 reference 阶段。下一安全检查点是先确认当前目标身份和 rc.14 只读基线；通过后才执行 v0.4.0 smoke，再以全新目录获取 HTB200 reference。项目仍处于验证和文档闭环阶段，不满足阶段切换条件。

## 本轮记录：2026-08-28（rc.14 GitHub Pre-release 发布）

### 已完成及证据

- 已从中断点继续 rc.14 发布任务，在独立分支完成 28 个候选文件的本地生成一致性、Bash 语法、控制器/事务/恢复 fixture、HTB fixture、manifest、staged whitespace 及新增敏感模式检查；Windows 本地的 root installer 门禁按预期报告 `installer check requires root`，没有冒充通过。
- 已通过 PR #9 合并到 `master`。CodeRabbit 首轮实质评审提出英文 README 输出契约不同步和 rollback 菜单槽位未锁定两项意见；两项均经源码复核后修复，唯一 inline thread 已回复并解决。修复后的 push/PR CI、合并后 `master` CI 和 tag CI 均通过，覆盖 Ubuntu root installer lifecycle 与固定 ShellCheck 0.11.0；后续 CodeRabbit 状态为 `Review rate limited`，未作为第二轮实质评审证据。
- 已创建 annotated tag `v0.1.0-rc.14`，tag object 为 `aedee73b7b4d2f87d4f810e61b97eec866aa14c6`，解引用目标为 PR 合并提交 `a0ce7c5bdbedd903ec2f027b7041939f2b6242d7`；reviewed head、合并提交与 tag 的 tree 一致。
- 已发布非 Draft 的 GitHub Pre-release，共 17 项资产。公开反向下载后，资产名称和 `uploaded` 状态为 17/17，GitHub API SHA-256 与下载字节为 17/17；重建 GitHub 扁平化的 HTB 逻辑目录后，`SHA256SUMS` 中 15 项运行资产全部通过。
- 公开 `install.sh` 与 `SHA256SUMS` 直连下载最终均为 HTTP 200；SHA-256 分别为 `1aef3822996421b05e5055d87289502c0ddb01149454aa3ba27a825d40ecf909` 和 `4449dc8fe73e23020c8b2d38066435d7c3429ad821f43beac9ac8b965f1241de`。发布页正文与仓库发布说明一致，验证临时目录已清理。

### 未完成门禁

- 本次发布证明源码、生成资产、fixture、PR/CI、tag、Release 元数据和公开资产字节完整性；不证明 rc.14 在目标 VPS 上的首次安装、rc.13→rc.14 迁移、同值/100→200/200→500/500→200 重配置、故障恢复、重启持久性或真实代理链路。
- TcpQuality、真实 HTB 窗口和性能改善仍未取得 rc.14 最终哈希绑定的目标环境证据；Pre-release 发布不得替代这些运行与业务层门禁。
- GitHub Actions 成功作业对 `actions/checkout@v4` 报告 Node.js 20 弃用告警，并说明当前由 runner 强制使用 Node.js 24。该告警未造成 rc.14 CI 失败，但 workflow 依赖升级尚未评估或实施。

### 延期事项变化

- 新增“CI 依赖维护”延期候选：后续独立核对 `actions/checkout` 当前受支持 major、迁移影响和供应链边界；本轮不为消除非阻断告警临时改变已经通过并发布的 workflow。
- 网络安全专项、全面生产加固和复杂测试工程的既有延期状态不变；无其他新增延期事项。

### 当前成熟度判断

rc.14 的本地、Linux CI、PR/评审、完整性链和公开 Pre-release 发布闭环已经完成；项目仍处于验证和文档闭环阶段。当前主要缺口是目标 VPS 生命周期、重配置/恢复、重启持久性和真实业务链路，不满足阶段切换条件。

## 本轮记录：2026-08-28（验证与文档闭环工作指南）

### 已完成及证据

- 已依据当前 `AGENTS.md`、本备忘、`docs/validation.md`、rc.14 发布说明和 GitHub Actions 工作流，把后续闭环拆分为范围冻结、本地确定性门禁、Linux root lifecycle、完整性与发布资产、目标 VPS 功能、业务链路、证据审查和文档同步八个阶段。
- 已明确区分四种完成声明：本地候选可审查、Pre-release 可发布、核心功能已在目标 VPS 验证、稳定版可发布；后一级不得由前一级证据替代。
- 已确认性能改善不是 rc.14 带宽重配置功能的当前声明，因此 TcpQuality、HTB 和全量性能矩阵不应自动成为本轮阻塞项；只有准备发布相应性能结论时才升级为门禁。
- 本轮仅形成后续工作指南并更新备忘，没有执行新的代码修改、VPS 操作、网络流量测试、发布或生产变更。

### 未完成门禁

- rc.14 仍需按现有候选重新闭合固定 ShellCheck 0.11.0、Linux root installer lifecycle、最终完整性链、文档证据状态和 diff 自检。
- Release 资产反向下载、rc.13→rc.14 迁移、同值/100→200/200→500/500→200 重配置、重启持久性和真实代理链路仍缺少 rc.14 最终哈希绑定的目标环境证据。
- 是否进入 Pre-release、目标 VPS 验证或稳定版门禁，应由用户先确定本轮目标声明和可用测试环境；本备忘不构成执行授权。

### 延期事项变化

- 无新增延期类别。既有网络安全专项、全面生产加固和复杂测试工程仍保持“延期候选，未授权”。

### 当前成熟度判断

项目仍处于验证和文档闭环阶段。当前最优先事项是先关闭 rc.14 的本地与 Linux root 发布门禁，再按用户批准的声明层级选择最小目标 VPS 矩阵；尚未达到阶段切换条件。

## 本轮记录：2026-08-28

### 已完成及证据

- 已将“验证和文档闭环”规定为当前项目阶段，并明确其目标、范围优先级、延期登记、每轮更新和阶段提醒规则。
- 已为备忘建立固定路径和效力边界，避免将延期候选误解为已批准实施项。
- 本轮开始前正在收口 `dvt reconfigure --port <MBPS>` 候选：生成一致性、Bash 语法、controller fixture、六份 profile static fixture 和 HTB fixture 已在本地主机通过；这些结果仍不等于目标 VPS 运行验证。

### 未完成门禁

- `0.1.0-rc.14` 的最终 ShellCheck 0.11.0、完整性链复核、文档证据状态和最终 diff 自检尚未在本轮阶段规则变更后全部重新收口。
- Linux root installer lifecycle、公开 Release 资产反向下载以及目标 VPS 的带宽重配置、恢复、重启持久性和真实代理链路仍未验证；当前未创建 tag、GitHub Release，也未执行 VPS 变更。

### 延期事项

| 类别 | 发现或建议 | 当前依据 | 延期理由 | 重新评估触发条件 | 状态 |
|---|---|---|---|---|---|
| 网络安全专项 | 对 installer、Release 供应链、受管状态与恢复证据开展独立威胁建模和专项审计 | 当前项目已有固定摘要、文件所有权和事务恢复控制，但尚无独立安全专项结论 | 不直接阻断当前 rc.14 验证与文档闭环，展开后会改变工作重心 | 当前发布验证闭合，或发现可复现的供应链/权限/恢复安全缺陷 | 延期候选，未授权 |
| 全面生产加固 | 评估 SSH、主机防火墙、入侵防护、面板暴露面、备份与救援通道等生产基线 | 这些控制依赖实际服务商、网络拓扑、面板和运维边界，不属于现有调优 profile 的已批准管理面 | 需要独立威胁边界和目标环境授权，不能由调优项目顺带接管 | 用户决定进入生产加固阶段并提供目标边界与授权 | 延期候选，未授权 |
| 复杂测试工程 | 评估跨 Linux 环境的 root lifecycle 自动化、进程中断/掉电故障注入和真实 VPS 编排框架 | 当前已有静态与 fixture 门禁，但最终仍依赖 Linux root、目标 VPS 和重启后的分层证据 | 新建测试基础设施超出当前最小闭环；本阶段先完成已有门禁和人工目标机矩阵 | 现有验证矩阵基本闭合，且重复人工验证成本或遗漏风险成为主要瓶颈 | 延期候选，未授权 |
| CI 依赖维护 | 评估并升级 `actions/checkout@v4` 到当前受支持 major | rc.14 的 `master` 与 tag CI 成功，但 GitHub runner 报告 Node.js 20 弃用并临时强制使用 Node.js 24 | 不阻断当前候选，版本选择和迁移影响需依据届时官方 Action 文档独立核对 | GitHub 不再兼容当前版本、告警升级为失败，或进入下一次 CI 维护窗口 | 延期候选，未授权 |

### 当前成熟度判断

项目仍处于验证和文档闭环阶段。rc.14 候选仍有明确的本地最终门禁和目标环境证据缺口，尚未达到应切换到下一阶段的条件。本轮无其他新增延期事项。
