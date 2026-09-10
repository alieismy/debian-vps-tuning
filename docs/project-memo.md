# 项目阶段备忘

文档性质：资料性状态与延期事项记录
当前阶段：rc.17 HTB/FQ 证据完整性 PR/CI 验证（候选实现已提交；tag、Release 与目标机验证未授权）
更新日期：2026-09-10（Asia/Singapore）

本文件是 `AGENTS.md` 指定的唯一项目阶段备忘入口，用于记录每轮对话工作的闭环状态，以及当前阶段不主动展开的后续候选事项。它不构成需求批准、生产变更授权、发布授权或下一阶段启动决定；控制规则以 [项目级 AGENTS.md](../AGENTS.md) 为准，具体验证事实以 [验证矩阵](validation.md) 和对应发布说明为准。

## 本轮记录：2026-09-10（rc.17 候选提交、PR 与 Linux CI）

### 已完成及证据

- 用户明确授权提交当前 rc.17 候选、创建并推送 `codex/rc17-htb-evidence` 分支、创建 PR、等待并修复本次改动引入的 CI 问题，并要求 CI 全部通过后停止，不创建 tag 或 Release。实施提交为 `b16a96845595d9dd881215cf85e63815f654d817`，提交主题 `fix(htb): preserve root and leaf qdisc evidence`；提交后工作树干净，`git diff HEAD^ --check` 通过。
- 分支已推送到 `origin/codex/rc17-htb-evidence`，GitHub PR 为 `#16`（`https://github.com/alieismy/debian-vps-tuning/pull/16`），base 为 `master`，head 精确绑定上述提交。PR 描述记录了原缺陷、schema 3 root/leaf 证据、脱敏 socket 指标、默认参数不变和未包含目标 VPS/发布操作的边界。
- 同一提交的 push 工作流 `34453343912` 和 PR 工作流 `34453404532` 均为 `success`。PR `validate` job `102794092373` 完成 checkout、生成 profile 与 shell 结构、Linux root verified installer lifecycle 和固定 ShellCheck 0.11.0；没有需要修复的本次引入失败。唯一 annotation 是 `actions/checkout@v4` 的 Node.js 20 弃用提示，GitHub runner 强制使用 Node.js 24，job 仍成功；该提示不属于 HTB 实现缺陷。

### 未完成门禁

- 本记录作为 docs-only 状态提交推送后，PR head 必须重新通过同一 GitHub Actions 门禁，才能在最终回复中称为当前 head CI 全部通过。该提交不修改 profile、installer、HTB 工具或候选摘要。
- 合并 PR、创建 `v0.1.0-rc.17` tag、Pre-release、上传及公开反向校验仍未授权；目标 VPS、iperf3、HTB A/B/A 和真实代理业务也未授权、未执行。

### 延期事项变化

- 无新增调优或实现延期事项。`actions/checkout@v4` Node.js 20 annotation 仅登记为上游 action 维护提示；当前 workflow 成功，不在本轮扩展为 CI 依赖升级。

### 当前成熟度判断

rc.17 实现提交已达到 `IMPLEMENTATION_COMMIT_AND_INITIAL_PR_CI_PASS`。在资料性状态提交的最终 head CI 通过后，本轮授权范围即闭合并停在开放 PR，不自动合并或发布；性能改善和生产采用仍没有目标 VPS 证据。

## 本轮记录：2026-09-10（rc.17 实现后的下一步门禁建议）

### 已完成及证据

- 基于 rc.17 已达到 `LOCAL_IMPLEMENTATION_AND_FIXTURE_COMPLETE`，确认下一条最短路径是先完成候选交付门禁：提交本地实现、推送独立分支、创建 PR、等待 Linux root 与固定 ShellCheck CI，并在修复所有本次引入的失败后再准备 `v0.1.0-rc.17` Pre-release。CI 和公开资产反向校验通过前，不把本地工作树候选部署到目标 VPS。
- 用户本轮只询问“下一步需要我怎么做”，尚未授权 commit、push、PR、tag、Release、目标 VPS 连接或主动流量测试；本轮没有执行这些动作，也没有修改实现、摘要或默认网络参数。

### 未完成门禁

- 第一门禁等待用户明确授权候选交付闭环，包括 commit、push、PR/CI、tag、Pre-release 和公开资产反向校验。若只授权 PR/CI，不自动创建 tag 或 Release。
- 第二门禁是在 rc.17 发布并通过公开资产复核后，由用户准备或指定独立测试 VPS、自有或获授权的固定 iperf3 endpoint、允许的地址族和总流量预算；随后才生成 reference-screen 计划。candidate sweep、A/B/A、反向窗口和真实 VLESS + REALITY + TCP 仍分别受证据及授权约束。

### 延期事项变化

- 无新增延期事项。既有永久 HTB、默认参数修改、tcpfit 参数包和 burst/cburst 独立比较继续保持原有边界。

### 当前成熟度判断

当前状态仍为 `LOCAL_IMPLEMENTATION_AND_FIXTURE_COMPLETE_AWAITING_DELIVERY_AUTHORIZATION`。用户现阶段无需在 VPS 上手工执行命令；只需决定是否授权 rc.17 候选的 Git/GitHub 交付闭环。目标机整形实验应在该闭环通过后单独开始，避免把未经过 Linux root CI 和公开摘要复核的工作树字节带入性能结论。

## 本轮记录：2026-09-10（rc.17 HTB/FQ 证据完整性实现候选）

### 已完成及证据

- 用户已授权进入实现阶段。本轮在本地工作树形成未发布的 `v0.1.0-rc.17` 候选，修复 `qdisc_counter_snapshot` 对 HTB 子 qdisc `parent MAJOR:MINOR` 的识别，同时保留 `mq` 的 `parent :N` 语义，并明确排除 `ingress`/`clsact`。HTB root 与 FQ leaf 现在分别写入 `qdisc_root_totals`、`qdisc_leaf_totals` 和 `qdisc_health`；root/leaf bytes 不相加，HTB root `overlimits` 只作为整形暴露证据。缺少与 HTB root 同接口的 FQ leaf 时摘要生成 fail closed。
- benchmark phase summary 升级到 schema 3；`rate-sweep-analyze.sh` 升级到 `0.4.0`，只接受完整的 schema 3 HTB→FQ upload 摘要。任一 root/leaf drop 或 requeue、旧 schema、缺失 qdisc 健康字段、无正 root `overlimits`、速率暴露不足、测量窗口无效、CPU/steal、softnet 或接口异常都会输出 `REVIEW_BLOCKED` 且 shortlist 为空。零本地 qdisc drop/requeue 只表示该采样窗口内未观察到本地两层队列异常，不解释下游或远端路径丢包。
- `rate-sweep-run.sh` 的脱敏 `ss -tin` 白名单新增 `pacing_rate`、`delivery_rate`、`minrtt`、`dsack_dups`、`rcv_ooopack`、`snd_wnd` 和 `rcv_wnd`。带空格的 rate 字段只接受数值加速率单位，继续丢弃 endpoint、端口、PID、进程名和 inode；字段缺失时保持缺失，不伪造零值。
- 新增或收紧的 fixture 覆盖：HTB root + `parent 1:10` FQ leaf、`parent ffff:fff1` ingress 不误归类、root drop 为零而 leaf drop/requeue 非零、root requeue 非零、root `overlimits > 0` 且 leaf 健康、HTB 缺叶 fail closed、既有 `mq parent :1/:2`、旧 schema 和 socket 脱敏。缺叶 fixture 的前后快照都保持相同键集合，确认失败来自拓扑门禁而不是计数器键漂移。
- 六份 profile 已从单一模板重新生成；controller、installer、预算、迁移、TcpQuality 和 HTB 实验绑定统一为未发布的 rc.17 候选。最终 `SHA256SUMS` SHA-256 为 `d44284ed010a5a9774fc104cea50a51bd209f8e0d1e57b9680cdf147e5bdc208`，`install.sh` SHA-256 为 `4fd4dde90df4524d657623c4e22e355ab9adac70a703cff61a68e41e09007cbc`。已发布 rc.16 文件和公开地址未被覆盖，README 仍把联网命令固定到不可变 rc.16。
- 最终本地验证均 exit 0：`bash -n` 覆盖本轮核心脚本和测试，`python tools/render_profiles.py --check`，`sha256sum -c SHA256SUMS`，`experiments/htb-aggregate/tests/static-check.sh`，`tests/static-check.sh` 和 `git diff --check`。主静态门禁末尾为 `static checks passed for 6 scripts`；其中 `mock tc failure` 和无效 eBPF 元数据是预期负向 fixture。没有连接或修改目标 VPS，没有运行公网测速、真实代理流量或第三方 root 脚本。

### 未完成门禁

- 当前 Windows/Git Bash 环境不能提供 Linux root lifecycle；`tests/installer-check.sh` 和 `tests/rc17-check.sh` 的 root 路径、固定 ShellCheck CI、GitHub PR/CI、tag、Pre-release、公开资产反向下载与摘要复核均未执行。用户本轮没有授权 commit、push、tag 或 Release，当前 rc.17 只能称为本地实现候选。
- 该实现修复的是 HTB 研究的证据完整性和 shortlist 门禁，不会直接降低用户 VPS 的重传。是否需要 aggregate shaping 仍须在单独授权后，以固定 endpoint、方向、地址族、并发、预算和时间窗执行 HTB200 reference、候选速率扫描、A/B/A、反向窗口和真实 VLESS + REALITY + TCP 复验；还须同时检查 RTT/min RTT、CPU/steal、softnet、接口与 root/leaf qdisc 计数。
- 默认 profile 继续使用 `BBR + fq`、17 项受管 sysctl、资源感知缓冲和非持久 HTB 实验边界。本轮没有采用 tcpfit 的完整 sysctl 参数包、固定 150 ms RTT、持久 systemd shaper、`fq maxrate` 二次逐流限速、`initcwnd/initrwnd`，也没有把当前 `burst=262144`/`cburst=32768` 改为 tcpfit 约 4 ms burst。

### 延期事项变化

- 新增 rc.17 发布门禁：只有用户另行授权后，才能进行提交、PR/CI、tag、Pre-release 和公开资产反向验证；在此之前不得把候选摘要或 installer 当作已发布入口。
- 新增目标 VPS 证据门禁：取得独立高额度测试机、固定 iperf3 endpoint 和量化流量预算后，先用 schema 3 验证真实 HTB root/FQ leaf 采集，再决定是否进入速率扫描和 A/B/A。burst/cburst 比较只能在速率候选稳定后作为单独变量，不能与 aggregate cap 同轮混杂。
- 无新增默认参数、永久 HTB、通用 UDP、CAKE、RPS/RFS、MSS Clamp 或第三方内核候选；既有延期状态保持。

### 当前成熟度判断

rc.17 达到 `LOCAL_IMPLEMENTATION_AND_FIXTURE_COMPLETE`：已从静态复现缺陷推进到本地实现、生成资产、摘要链和正负 fixture 闭环，能够避免 HTB root 零 drop 掩盖 FQ leaf 异常，并阻止旧或不完整证据进入 shortlist。它尚未达到 Linux root、公开发布、目标 VPS 或性能改善证据层级；因此只能支持“研究工具的证据可信度已提高”，不能支持“HTB 已降低用户 VPS 重传”或“应默认启用 HTB”。

## 本轮记录：2026-09-10（tcpfit 整形专项与重传因果再评估）

### 已完成及证据

- 在上一轮三个外部项目固定源码研究的基础上，针对用户报告的 VPS TCP 重传重新检查 tcpfit `v0.5.7`（commit `1163c20e88a4a7130ef7d885da8be3a163505003`）的整形路径、Linux FQ/HTB 一手语义、当前 rc.16 非持久 HTB 参数和重传证据链；详细主张、源码锚点与限制已补入 [外部网络调优研究证据包](external-network-tuning-research-2026-09-10.md) 的“整形专项再评估”章节。
- 确认 tcpfit 的 `HTB rate=ceil` 负责聚合出口上限，`fq maxrate` 只是单流上限；receiver goodput、sender retransmission/GiB 和重复 loss-spike 复测具有条件参考价值，但其固定 RTT、单一端点、流量估算和持久 unit 不能直接替换 rc.16 的资源/预算/所有权契约。
- 用当前 `tools/profile-template.sh.in:qdisc_counter_snapshot` 原样函数和 `qdisc htb 1: root` + `qdisc fq 10: parent 1:10` 合成输出复核：`parent 1:10` 被归入 `other`，不是 `leaf`。因此 HTB root drop 为零时，FQ 叶子 drop/requeue 可能未进入 `build_benchmark_phase_summary` 的主要汇总；这是高置信度的静态证据完整性缺口。现有 `tests/static-check.sh` 的 `mq` `parent :1/:2` fixture 未覆盖该拓扑。
- 本轮运行了现有本地 `bash tests/static-check.sh`，最终 exit 0；该结果只说明已有门禁未回归，不能抵消新增 HTB parent-handle fixture 缺口，也不构成 Linux root 或目标 VPS 性能证据。没有执行第三方 root 脚本、目标 VPS、公网 `iperf3` 或生产业务。

### 未完成门禁

- 用户报告的重传尚未绑定同一 endpoint、方向、地址族、负载窗口、sender bytes/retransmits、receiver goodput、RTT/pacing、CPU/steal、softnet、接口和 root/leaf qdisc 增量，因而不能确认根因是 provider aggregate policer、路径问题、虚拟化资源、队列溢出、端点或代理业务。
- 当前默认 profile 仍为 `BBR + fq`，没有 aggregate egress cap；tcpfit 的 HTB→FQ 只能作为条件候选。当前非持久 HTB 的 `burst=262144`/`cburst=32768` 与 tcpfit 约 4 ms burst 不同，但没有证据支持直接替换任何一组参数。
- HTB/FQ parent-handle 解析、root/leaf 全层 drop/requeue/backlog 汇总和 `pacing_rate`/`delivery_rate`/`minrtt` 等只读 socket 观测仍未实现；在此之前不应把现有 HTB 结果用于默认行为或永久整形决策。目标 VPS A/B/A、反向窗口、重启持久性和真实 VLESS + REALITY + TCP 业务仍未验证。

### 延期事项变化

- 新增一个有边界的证据链修复候选：在重新启用 HTB 性能研究前补齐 `parent MAJOR:MINOR` 叶子识别、HTB/FQ fixture 和全层 qdisc 汇总；它不等同于默认启用 HTB，也不改变 rc.16 已发布资产。
- 无新增默认参数或生产整形授权。tcpfit 的聚合 shaping、burst 比较和持久 opt-in 入口继续等待单独的需求、实现授权、固定 endpoint、预算和 A/B/A 证据；NetPilot/NetShape 的扩张 sysctl、CAKE、永久 HTB 等既有延期状态不变。

### 当前成熟度判断

rc.16 发布完整性和默认 profile 边界不变。当前结论从“没有已证明的 rc.16 功能缺陷”精炼为：没有已证明的**默认整形行为**缺陷，但发现了会影响 HTB 研究证据可信度的静态 parser 缺口；用户重传使缺少 aggregate shaping 成为中低置信度、高价值待验证假设。当前只达到固定源码、官方语义、本地源码和合成 fixture 层级，未达到目标 VPS 根因或性能改善层级。

## 本轮记录：2026-09-10（tcpfit、vps-netpilot、netshape-manager 外部研究）

### 已完成及证据

- 已按当前 GitHub `main`/tag 快照重新冻结并只读检查三个项目：`tcpfit` `v0.5.7`/commit `1163c20e88a4a7130ef7d885da8be3a163505003`，`vps-netpilot` `main`/commit `705a307684b7b0cb57747bf2e5abb4ed6ada6cdd`，`netshape-manager` `main`/commit `647b454b934349a179b1db289518eb9280adc839`；许可证均为 MIT。固定脚本摘要、源码锚点、功能和采用矩阵已写入 [外部网络调优研究证据包](external-network-tuning-research-2026-09-10.md)。
- 三个主脚本均通过只读 `bash -n`；NetShape `tests/self-test.sh` 和 `peertune/tests/self-test.sh` 全部通过。该证据只达到源码/合成 fixture 层级，未执行第三方 root 脚本、未连接目标 VPS、未运行公网 `iperf3` 或生产业务。
- 研究确认 tcpfit 的 receiver goodput、重传增量、重复 loss-spike、锁和异常回收具有条件参考价值；NetShape 的 HTB aggregate/fq 语义、qdisc drift/ownership 处理以及 peertune 的 `ss -tin` 分布观测可作为未来实验或只读诊断输入。当前 rc.16 已覆盖或以更强契约覆盖这些机制的核心边界。
- 研究确认 NetPilot 的可变 `main` 自更新、四项关键值回退、总内存 5% 缓冲、通用 UDP/conntrack、RPS/RFS、MSS Clamp、IPv4 优先和按内核版本推断 BBRv3 均不足以进入 rc.16；tcpfit/NetShape 的扩张 sysctl、`initcwnd/initrwnd`、CAKE、固定经验值和永久整形同样不进入默认 profile。

### 未完成门禁

- 本轮没有目标 VPS 的第三方运行、重启持久性、真实 VLESS + REALITY + TCP 业务、A/B/A 性能或 provider policer 因果证据；外部项目 README、维护者提交中的实时数字和合成测试不能提升这些证据层级。
- 当前 rc.16 的 17 项 sysctl、资源感知 BDP、根 `fq`、fail-closed 流量 ledger、非持久 HTB 和策略路由只读边界保持不变；本轮没有发现已被证明的默认整形行为缺陷，但默认 profile 没有 aggregate shaping，用户重传使该缺口成为高价值待验证假设。

### 延期事项变化

- 无新增延期事项。tcpfit/NetShape 的 goodput/聚合速率算法只在新实验需求、固定 endpoint、批准预算和 A/B/A 证据出现时重新评审；peertune 的多客户端 RTT/膨胀/抖动只在明确的多客户端诊断需求或可复现业务症状出现时重新评审。多跳 relay/landing、CAKE、永久 HTB、通用 UDP、RPS/RFS、MSS Clamp、`initcwnd/initrwnd` 和第三方内核继续保持既有延期或未授权状态。

### 当前成熟度判断

rc.16 发布完整性和阶段成熟度判断不变。本轮新增的是固定源码证据和采用分类，不构成参数、拓扑、默认 qdisc、发布资产或目标 VPS 运行状态变更；当前结论仍只达到仓库/公开发布完整性与外部源码研究层级，目标 VPS 真实性能和业务验收仍未验证。

## 本轮记录：2026-09-03（3X-UI v3.4.2 Stage 6A 安装前只读与供应链门禁）

### 已完成及证据

- 用户明确授权 Stage 6A：允许通过严格 SSH 对目标机重新执行系统健康、包管理、DVT 状态、受管文件、端口和防火墙只读检查，并固定核对 3X-UI v3.4.2 tag、commit、安装器和 amd64 Release 资产；同时明确禁止安装、修改防火墙、开放端口、reboot、创建代理入站和主动流量测试。执行始终使用独立确认的 ED25519 host key、`StrictHostKeyChecking=yes`、`HostKeyAlgorithms=ssh-ed25519`、`BatchMode=yes`、禁用密码/键盘交互认证、`IdentitiesOnly=yes` 和指定 agent identity；本轮没有把 host key 写入用户全局 `known_hosts`。
- 目标机最终精简复核共 18 项只读门禁全部通过：Debian 13、目标内核及 Stage 4/5 boot-ID 值摘要保持，systemd running、failed unit 0、SSH active、时间同步、无 reboot-required、`dpkg --audit` 为空且没有真实包管理进程；`dvt verify`/`status` 均 exit 0，state 摘要仍为 `77db50a4a26989133f7a58554d52c566d44724204698c9abb5c73366407ce8c9`，schema 4 `VERIFIED`、`debian13-1c2g`、500 Mbps、200 ms、33554432 字节保持。17 项 sysctl 文件值和运行值一致，`bbr + fq`、唯一根 `fq`、无 HTB、1024 MiB 项目 swap、fq service、默认 policy rules、provider source/backup 固定摘要和 DVT x-ui NOFILE drop-in 均未漂移。
- 3X-UI 在目标机上仍不存在：没有 `/usr/local/x-ui`、`/usr/bin/x-ui`、`/etc/x-ui`、systemd 主 unit、x-ui/Xray 进程或代理入站。当前监听集合仍只有 TCP 22/53/5355 和 UDP 53/5355，80/443 及 3X-UI 默认内部端口均空闲；UFW installed/inactive，`nft` 命令和服务未安装、guest 内没有 nft 对象。服务商侧防火墙无法由 guest 反向证明，继续保留为外部证据缺口。
- 固定上游证据为 3X-UI `v3.4.2` 非 Draft、非 Pre-release Release，发布时间 `2026-06-29T18:30:19Z`；lightweight tag 解析到 commit `f3a57d4c57fbcae94414138de42b7ef11dc513c8`，该 commit 的 GitHub verification 为 `verified=true, reason=valid`。固定 commit 的 `install.sh` 为 71736 字节，SHA-256 `bd1e19b674526c3e1fb7944500fef81e1e049e5c1db2ae7bbfa9a15b05667a1b`；`x-ui-linux-amd64.tar.gz` 为 83352799 字节，GitHub API digest 和本机实际下载摘要均为 `1086716ea4b09f87893da3d83d5957af28ab7094c3a3a374cb3b369f6c0009a6`。tag 本身不是 annotated/signed tag；本轮也没有取得 Release 二进制的维护者独立签名或可复现构建证明，因此该摘要门禁证明“将安装的字节等于本轮固定的 GitHub Release 字节”，不把它夸大为完整源码到二进制来源证明。
- 固定压缩包共 17 项、只有单一 `x-ui/` 顶层目录，未发现绝对路径、`..` 逃逸、重解析点或符号链接；压缩包中的 `x-ui.sh` 与固定 tag/commit 源码逐字节一致。关键内容摘要为：3X-UI 主程序 `03ee1876ad3fdea20edec890bd1169b7a35aaad23cfcc70eae839fcc59f58c25`、`x-ui.sh` `14b9ed4cd14aaf9bd54932249170c53ceac147940844e7929eb7b2b204568397`、Debian unit `dbd78334fc1931f4f8f8693050076193234685e7f2abf2ec91ea08c8c7a8343b`、Xray amd64 二进制 `8ef87ac07f95617e094b8e9302ea3e0c2d0edaa7045d57b455fdee28b3c9e41e`。固定源码内版本为 3X-UI 3.4.2，Release 声明捆绑 Xray 26.6.27；3X-UI Go build metadata 指向 Xray commit 前缀 `45cf2898ab12`，仍须在实际安装前用有界版本命令核对归档内二进制输出。
- 官方安装器即使传入固定 `v3.4.2`，仍会无条件从 `main/x-ui.sh` 下载管理脚本；当前 `main` 版本已与固定 tag 内容不同。安装器无 `sha256sum`/`sha512sum`、GPG 或 Cosign 校验原语；未传版本时还会查询 `releases/latest`。Debian 路径无条件执行 `apt-get update` 并安装 `cron curl tar tzdata socat ca-certificates openssl`；目标机仅缺 `cron`，当前模拟结果为 `0 upgraded, 18 newly installed, 0 to remove`，会连带 Exim、Perl 等与本次 SQLite、loopback 面板无关的包。APT 源递归解析后只有 `deb.debian.org` 且没有 insecure override；首次把 `mirror+file:` 当域名的结果是采集器假阴性。
- 官方安装器会把用户名、密码、panel port、WebBasePath、access URL 和 API Token 输出到 stdout，并写入 `/etc/x-ui/install-result.env`；这不满足本轮“秘密不得进入日志或对话”的约束。固定源码还确认：首次 `database.InitDB` 在空库中创建 bcrypt 化的默认 `admin/admin`；`x-ui setting` 的各单项更新失败可能只打印错误而总体仍返回成功；SQLite 初始化只 `MkdirAll(..., 0755)`，不显式把数据库改为 `0600`。因此下一阶段必须在服务第一次启动前以 `umask 077` 预建 root:root/0700 的 `/etc/x-ui`，立即覆盖默认凭据、panel port、WebBasePath 和 `listenIP=127.0.0.1`，把命令输出隔离后逐项回读比较，并确认 `/etc/x-ui/x-ui.db` 为 root:root/0600，不能只信 CLI exit 0。
- 固定源码确认 API Token 默认值为空，只有显式执行 `setting -getApiToken true` 才会创建并一次性打印明文，数据库只存 SHA-256。Stage 6B 不需要 API 自动化，推荐不调用该命令、不创建 API Token；后续若确需 API，再在独立授权阶段生成并一次性写入 root-only 凭据文件。Xray 运行配置由同目录临时文件原子替换并强制 `0600`；空业务配置下只含回环 API `127.0.0.1:62789` 和 metrics `127.0.0.1:11111`，面板启动时仍会启动 Xray，因此安装后须验证只存在这些内部监听且没有业务入站。
- 推荐 Stage 6B 不运行官方 `install.sh`，改用固定 Release 资产的等价手工安装：目标机从固定 URL 下载到 root-only staging，先核对字节数和 SHA-256，再复用归档内同 tag 的 `x-ui.sh` 和 `x-ui.service.debian`；不执行 APT update/install，从而同时消除 `latest`、`main`、无摘要下载和 18 个无关包。Debian unit 直接执行 `/usr/local/x-ui/x-ui`，无动态下载；与既有 `/etc/systemd/system/x-ui.service.d/90-proxy-vps.conf` 兼容，后者应使 x-ui 主进程和直接 Xray 子进程的 NOFILE soft/hard 均不低于 65536。
- Stage 6B 的秘密只在远端内存中生成，禁止 `set -x`，设置命令 stdout/stderr 进入 root-only 临时缓冲且不回传；用户名、密码、panel port 和 WebBasePath 只写 `/root/3x-ui-bootstrap.env`，root:root/0600，不写 access URL。3X-UI 可在数据库初始化时生成内部 panel GUID，但不得输出该值；本阶段不创建代理客户端 UUID、REALITY 密钥或客户端链接。普通证据只输出布尔门禁。服务启动后先用 `ss` 证明 panel 只绑定 `127.0.0.1`，再允许一次有界的本机回环 HTTP GET 作为 readiness；它不是公网或性能测试。用户应在自己的交互式 SSH 中读取 bootstrap 文件并存入密码管理器，不得把内容粘贴回 Codex。固定 CLI 只支持通过命令参数设置用户名和密码，因而在极短设置窗口内仍存在被同机 root 或可读 `/proc` 的本地观察者看到进程参数的剩余风险；Stage 6B 应先确认没有其他交互登录会话并立即执行、回读和清除 shell 变量，但不能把它描述为抵御已获得本机 root 权限的攻击者。
- 失败回滚仅允许删除 Stage 6B 新建对象：先 stop/disable `x-ui.service`，删除本阶段创建的主 unit、enable symlink、`/usr/local/x-ui`、`/usr/bin/x-ui`、`/etc/x-ui`、`/var/log/x-ui`、bootstrap 和 staging，再 `daemon-reload` 并运行普通 `dvt verify`。不得删除既有 x-ui drop-in、`/var/lib/proxy-vps-tuning`、`/swapfile-proxy`、项目 sysctl 或 `proxy-vps-fq.service`；若删除边界或回滚动作不能证明，停止并保留现场，不做宽泛清理。
- 两轮临时终态采集器出现的红项均已查明且未造成 VPS 写入：第一轮误用了不存在的 `state.env` 而非 `state.json`，对 boot-ID 文件直接哈希而不是对无换行值哈希，并使用了不适用的 swap 输出断言；第二轮把 `tcp_rmem`/`tcp_wmem` 的 tab 与空格差异误判为值漂移，且 PowerShell 传输尾部 CR 使诊断脚本在已输出结果后返回 2。改为真实 state 路径、权威 boot 摘要算法、`/proc/swaps`/`stat`、规范化向量空白并增加传输终止注释后，最终 18/18 只读门禁 exit 0；没有把采集器问题冒充主机故障。

### 未完成门禁

- Stage 6A 已完成并停在安装计划审阅。Stage 6B 尚未授权或执行；目标机没有下载或安装 3X-UI，没有创建数据库、bootstrap、API Token、代理入站或客户端材料，没有启动 x-ui/Xray、修改 UFW/服务商防火墙、开放端口、reboot 或运行主动公网流量。
- Stage 6B 若获授权，仍须紧邻写入重新检查严格 SSH、DVT 固定摘要、包管理、监听端口和安装目标均未漂移；完成固定资产安装、秘密内部回读、loopback 监听、systemd/进程/NOFILE、默认 Xray config、一次本机 readiness、严格 `REQUIRE_PROXY_SERVICE=1 PROXY_SERVICE_UNITS='x-ui.service' dvt verify`、`dvt status` 和 DVT 前后摘要不变性后立即停止。任何秘密回显、默认凭据残留、非 loopback panel、未知监听、版本/摘要不符或回滚不完整都必须 fail closed。
- 用户已确认的快照创建发生在 DVT Stage 2 之前；尚未确认是否另建 Stage 5 `VERIFIED` 终态快照。Stage 6B 前优先新增该快照；若服务商只允许一份，应由用户明确选择保留 pre-DVT 恢复点、替换为 Stage 5 恢复点，或接受只依赖受控文件级回滚的风险。
- 第二次 reboot、重启后严格 3X-UI/Xray 验证、VLESS + REALITY 配置、真实 1/3/5/10 并发 TCP 冒烟、业务期 `diagnose` 和真实性能对比仍未执行。Stage 4 的 `TCP22_CYCLE_OBSERVATION=NOT_OBSERVED` 继续保留；benchmark、probe、TcpQuality、HTB、故障注入、DVT rollback/purge 和快照恢复演练仍未授权。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。3X-UI 固定资产、凭据隔离、loopback 暴露面和安装失败回滚属于进入既定代理验收前的运行门禁，不把 3X-UI 安装器、API Token、面板安全或防火墙治理吸收到 rc.16 DVT 的产品管理面。

### 当前成熟度判断

目标机达到 `STAGE6A_SUPPLY_CHAIN_AND_READONLY_GATE_PASS_READY_FOR_STAGE6B_AUTHORIZATION`：固定 Release 资产、上游安装器风险、等价手工安装路径、秘密处理、监听顺序、systemd/DVT 兼容性、成功判据和有限回滚边界均已形成可执行计划，且目标机 Stage 5 终态无漂移。该状态只证明安装前就绪，不证明 3X-UI 已安装、面板已绑定 loopback、Xray/REALITY 已运行、第二次 reboot 或真实业务链路通过。

## 本轮记录：2026-09-03（确认 Stage 6 的 3X-UI 安装前门禁）

### 已完成及证据

- Stage 5 已以 `STAGE5_IDEMPOTENCY_PASS_READY_FOR_3XUI_AUTHORIZATION` 封口。用户本轮只询问下一步，不构成安装、服务启动、防火墙、reboot、代理入站或主动流量授权；本轮没有连接目标 VPS，也没有改变目标机状态。
- 依据当前仓库验收顺序，下一项运行门禁是安装并启动固定 3X-UI v3.4.2 后执行 `REQUIRE_PROXY_SERVICE=1 PROXY_SERVICE_UNITS='x-ui.service' dvt verify`；该严格验证只证明 `x-ui.service`、直接 Xray 子进程和 systemd/运行时 NOFILE 不低于 65536，不替代后续第二次 reboot、VLESS + REALITY + TCP 业务链路或性能验收。
- 本轮从官方 `MHSanaei/3x-ui` 重新核对 `v3.4.2` Release/tag：Release 为非 Draft、非 Pre-release，tag 解析到 commit `f3a57d4c57fbcae94414138de42b7ef11dc513c8`；tag 下 `install.sh` 的 SHA-256 为 `bd1e19b674526c3e1fb7944500fef81e1e049e5c1db2ae7bbfa9a15b05667a1b`，amd64 资产大小为 83352799 字节，GitHub API digest 为 `sha256:1086716ea4b09f87893da3d83d5957af28ab7094c3a3a374cb3b369f6c0009a6`。
- 上游安装器的当前固定源码审阅发现四项必须在写入前解决的操作风险：不传版本参数会查询 `releases/latest`；即使传入 `v3.4.2`，仍从 `main` 下载 `/usr/bin/x-ui` 管理脚本；下载 Release 压缩包后没有摘要校验；安装流程会向 stdout 输出用户名、密码、WebBasePath 和 API Token，并写入 root:root/0600 的 `/etc/x-ui/install-result.env`。此外，非交互且跳过 TLS 时明确选择不绑定 loopback；交互路径才可调用 `x-ui setting -listenIP "127.0.0.1"`，而安装器随后启用并启动 `x-ui.service`。
- 因此推荐把下一阶段拆为 Stage 6A/6B：Stage 6A 只读复核供应链、系统防漂移、端口/暴露面、凭据处理、systemd 和恢复路径，停在安装前；Stage 6B 再按审阅结论安装固定资产，默认使用 SQLite、面板仅监听 `127.0.0.1`、通过 SSH 本地转发访问、不启用 UFW、不创建 VLESS/REALITY 入站、不 reboot，并在不采集秘密的前提下执行严格运行态验证。进入 Stage 6B 前建议保留原始 pre-DVT 快照，并另建一份 Stage 5 终态快照；若服务商只允许单快照，应先决定保留哪个恢复点。

### 未完成门禁

- Stage 6A 尚未得到用户授权，也未执行。固定安装资产的安全落地方式、`main/x-ui.sh` 的消除或固定策略、解压前摘要门禁、面板 loopback 生效顺序、失败恢复和脱敏证据方案仍待 Stage 6A 形成最终安装计划；在此之前不执行 3X-UI 安装。
- Stage 6B 安装及安装后严格 `dvt verify`、第二次 reboot 与再次严格验证、真实 VLESS + REALITY + TCP 冒烟、业务期只读 `diagnose` 均未执行。Stage 4 的 `TCP22_CYCLE_OBSERVATION=NOT_OBSERVED` 限制继续保留；benchmark、probe、TcpQuality、HTB、故障注入、rollback、purge 和快照恢复演练仍未授权。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。上述 3X-UI 供应链、凭据和监听地址问题是进入既定代理验收前的运行门禁，不据此扩大 rc.16 的 DVT 功能范围，也不吸收 3X-UI 安装、防火墙或代理凭据管理职责。

### 当前成熟度判断

目标机仍为 `STAGE5_IDEMPOTENCY_PASS_READY_FOR_3XUI_AUTHORIZATION`。当前最小安全下一步是用户单独授权 Stage 6A 安装前只读审阅；本轮对上游源码的静态核对不能替代目标机安装、服务运行、第二次 reboot 或业务链路证据。

## 本轮记录：2026-09-03（新目标机 rc.16 重复 apply 幂等性验收）

### 已完成及证据

- 用户明确授权 Stage 5：在严格 SSH 和 apply 前防漂移通过后，只运行一次 `dvt apply --port 500`，核对预期 no-op 文本，证明 state、受管文件、provider 文件、swap inode、根 `fq` 和 service 前后不变，再运行 `dvt verify/status` 并完成最终自检；同时明确禁止 reboot、安装 3X-UI 和主动流量测试。执行始终使用任务专用单条 ED25519 host-key pin、`BatchMode=yes`、`IdentitiesOnly=yes`、禁用密码/键盘交互认证、root/TCP 22 和唯一匹配的 `vps_rsa` agent 身份，没有依赖或写入用户全局 `known_hosts`。
- 首个客户端只读 SSH 包装器把 `dvt --version` 误断言为单一版本号，在已经确认严格 SSH、root、目标内核、systemd running、failed units 0 和 SSH active 后 exit 1；实际接口为 `controller=0.1.0-rc.16 release=v0.1.0-rc.16`。统一真实接口并同时核对 boot ID 的“文件含换行”和“值不含换行”两种摘要后，确认不含换行的权威算法仍得到 Stage 4 固定摘要，启动时间仍为 Stage 4 的唯一实际 reboot；该包装器没有写远端证据或配置，也没有调用 `apply`。
- 第一次远端 apply 前审阅已依次通过 root、证据目录、目标内核/boot、systemd/SSH/时间同步、7 份 Stage 4 权威日志、state/qdisc/provider 摘要、schema/profile/network、5 个受管文件、17/17 安装资产、17 项 sysctl、BBR、默认路由和根 `fq`，随后仅因临时审阅器把 `ip rule` 的空白固定为空格、而 Debian 输出制表符，在三条 IPv4 默认规则的文本比较处停止。失败日志为 `stage5-pre-apply.failed.log`，SHA-256 `12c25e0c27df053290b5426aa44aa867d6f5b045dccda7fd63856442d2e1ba74`，其中没有 `APPLY_INVOKED=YES`。修正为逐行空白规范化、保留而不覆盖该失败证据后，完整 apply 前门禁通过 105 项 `PASS`、0 项 `FAIL`，权威日志 `stage5-pre-apply.log` 的 SHA-256 为 `97bfcae785cbe028a29b264ec1a38800ae7363760f2a871320c4fb2178606d0f`。
- apply 前分别运行的 `dvt verify` 和 `dvt status` 均 exit 0，日志 SHA-256 分别为 `8d6a3878ba902ce3315b5e143f03eef697f864d3eb9ca0efd88b7d01be1f6c4f` 和 `4f74fd10c7772feddb375a70aff8f706d91424e93ae4b9632b905db3d4bd7462`。随后固定的稳定快照覆盖 boot、内核、state 及 state 目录、5 个受管文件、provider source/backup、swap file/state/active record/fstab、默认出口根 qdisc、fq service 和 17 项文件/运行 sysctl，SHA-256 为 `ea3f4700aec4ed55088bbd3138d15fdb7d0553fd689d72ff29c3d1ecdf23a625`。
- 紧邻调用前再次核对上述权威日志和快照摘要、boot、state `VERIFIED`、500 Mbps/200 ms/33554432 字节、qdisc 原快照、provider 两份文件、state 目录、根 `fq`、swap device/inode、fq service、包管理进程和 DVT lock 后，受控包装器只调用一次 `dvt apply --port 500`。命令内部 preflight 和 `verify_settings` 均通过，exit 0，并精确输出“配置已存在且验证通过，无需重复写入。”；紧邻返回后的 boot、state、qdisc 原快照、provider 两份文件和 state 目录仍匹配。权威 apply 日志为 `stage5-repeat-apply.log`，SHA-256 `3882f0b7d4519e1a5c00e2daceac590deee93e2dbd8d7bb4e492f92f2f2d075c`，包含唯一一组调用、命令、exit 0 和 no-op 标记，且没有失败、未运行或歧义临时制品。
- apply 后分别运行的 `dvt verify` 和 `dvt status` 再次 exit 0；两份日志不仅摘要分别仍为 `8d6a3878ba902ce3315b5e143f03eef697f864d3eb9ca0efd88b7d01be1f6c4f` 和 `4f74fd10c7772feddb375a70aff8f706d91424e93ae4b9632b905db3d4bd7462`，还与 apply 前输出逐字节一致。post-apply 审阅完成 78 项 `PASS`、0 项 `FAIL`，日志 `stage5-post-apply.log` 的 SHA-256 为 `25b218386c62216c8dc6166f518a9a60f68cd708cc071e799285b9434ccca042`；post 稳定快照与 pre 快照逐字节相同，SHA-256 同为 `ea3f4700aec4ed55088bbd3138d15fdb7d0553fd689d72ff29c3d1ecdf23a625`，没有生成 snapshot diff。
- 最终独立自检完成 105 项 `PASS`、0 项 `FAIL`：state SHA-256 仍为 `77db50a4a26989133f7a58554d52c566d44724204698c9abb5c73366407ce8c9`，schema 4 `VERIFIED`、`debian13-1c2g`、500 Mbps、200 ms、33554432 字节、5 个受管文件、17 项文件/运行 sysctl、BBR、根 `fq`、provider `TRANSFERRED`、1024 MiB swap 的 device/inode/owner/mode/active/fstab、fq service enabled/active/exited 和 ExecMainStatus 0 全部通过。`stage5-final-self-audit.log` 的 SHA-256 为 `1d28cbe7184a5d0ba0fc75ee8039ba851e81bd97c9b2bf080a27f44eecd4d1cc`；新的严格 SSH 封口检查确认最终日志 root:root/0600、Stage 5 证据共 11 份、意外失败文件 0、隐藏临时文件 0、boot/state/system health 未变。全阶段未 reboot、未安装 3X-UI、未运行主动流量测试。

### 未完成门禁

- Stage 5 重复 apply 幂等门禁已完成。下一项既定生命周期门禁是另行授权安装并严格验证 3X-UI/Xray 运行态；在取得该授权前不安装面板或代理、不开放端口、不生成或使用真实客户端配置。其后仍需分别授权和执行第二次 reboot、真实 VLESS + REALITY + TCP 冒烟及业务期只读 diagnose，当前结果不证明代理进程的 NOFILE、生效配置、REALITY 链路或真实业务性能。
- Stage 4 的 `TCP22_CYCLE_OBSERVATION=NOT_OBSERVED` 限制继续保留；本轮按授权没有为补该观测再次 reboot。benchmark、probe、TcpQuality、HTB、故障注入、rollback、purge 和服务商快照恢复演练仍未授权且未执行。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。两次停止均来自本轮临时只读验收包装器对当前输出格式的过严断言，分别通过核对真实 `dvt --version` 接口和规范化 `ip rule` 空白修正；它们均发生在唯一 `apply` 之前，没有发现 rc.16 controller、profile、no-op 分支、managed state 或运行配置缺陷，不据此扩展通用框架。

### 当前成熟度判断

目标机达到 `STAGE5_IDEMPOTENCY_PASS_READY_FOR_3XUI_AUTHORIZATION`：固定 rc.16 在一次真实 reboot 后保持持久有效，并已证明相同 `--port 500` 输入下重复 `apply` 只验证现状、返回 0 且不改写稳定状态。该结论由严格 SSH、唯一调用日志、前后 `verify/status`、逐字节相同的稳定快照、独立自检和封口复核共同支撑；它不等于 3X-UI/Xray、第二次 reboot、真实 VLESS + REALITY + TCP、业务期 diagnose 或性能验收通过。

## 本轮记录：2026-09-03（确认 Stage 5 重复 apply 幂等性门禁）

### 已完成及证据

- 在 Stage 4 已完成一次真实 reboot、恢复后持久性审阅和最终自检的前提下，重新核对当前 rc.16 控制器：当已安装参数与本次输入一致且 state 为 `VERIFIED` 时，`apply` 会先执行 `verify_settings`，验证通过后输出“配置已存在且验证通过，无需重复写入。”并返回 0；因此下一项最短且有序的生命周期门禁是相同 `--port 500` 输入下的重复 `apply` 幂等性验收，而不是安装 3X-UI、再次 reboot 或运行流量测试。
- 用户本轮只询问“下一步需要我做什么”，不构成远端变更授权。本轮没有连接目标 VPS，没有执行 `dvt apply`、reboot、3X-UI/Xray 安装或主动流量测试，也没有改变任何目标机状态。

### 未完成门禁

- Stage 5 尚待用户明确授权。获授权后，应先完成严格 SSH、系统健康、包管理和摘要防漂移检查，记录 state、受管文件、provider 文件、swap、根 qdisc 和 service 的前置证据；只运行一次 `dvt apply --port 500`，核对预期 exit 0 和 no-op 文本，再证明 boot ID、state、文件摘要、swap device/inode、根 `fq` 与 service 状态未变化，并分别运行 `dvt verify` 和 `dvt status` 后停止。
- 严格 3X-UI/Xray 运行态验证、第二次 reboot、真实 VLESS + REALITY + TCP 冒烟、业务期只读 diagnose，以及另行授权和量化预算后的 benchmark/probe/TcpQuality/HTB 仍未执行。Stage 4 的 `TCP22_CYCLE_OBSERVATION=NOT_OBSERVED` 限制继续保留，不为补该观测单独增加 reboot。

### 延期事项变化

- 无新增项目功能或网络调优延期事项；本轮仅确认既定生命周期中的下一授权门禁，没有扩大范围。

### 当前成熟度判断

目标机状态仍为 `STAGE4_PERSISTENCE_REBOOT_PASS_READY_FOR_IDEMPOTENCY_AUTHORIZATION`，当前检查点为等待 Stage 5 明确授权。源码中的 `VERIFIED` no-op 分支只给出预期行为，不能替代目标 VPS 上对重复 `apply`、前后摘要不变性和后续 `verify/status` 的运行验收。

## 本轮记录：2026-09-03（新目标机 rc.16 单次持久性 reboot 与恢复验收）

### 已完成及证据

- 用户明确授权一次 DVT 持久性 reboot，要求在发出 reboot 前启动客户端 TCP/22 连续监测，并在恢复后核验 boot ID、严格 SSH、目标内核、`dvt verify/status`、schema 4 `VERIFIED`、17 项 sysctl、BBR、根 `fq`、项目 swap、fq service、受管文件和 provider 哈希；同时明确禁止重复 `apply`、安装 3X-UI 和主动流量测试。本轮始终使用任务专用 ED25519 host-key pin、`BatchMode=yes`、`IdentitiesOnly=yes`、root/TCP 22 和指定 identity，没有写入用户全局信任库。
- 紧邻实际 reboot 的最终防漂移检查完成 111 项 `PASS`、0 项 `FAIL`：Stage 3 权威日志、schema 4 state、9 个关键持久制品、17 项文件/运行 sysctl、`bbr + fq`、根 qdisc、1024 MiB 项目 swap、fq service、provider transfer、17/17 安装资产、`dvt verify/status` 和系统健康均未漂移；权威日志 `stage4-pre-reboot-armed.log` 的 SHA-256 为 `9bdfb8cad67df78963df8dc88f8ceed32cbd5b799e67cc2110a3794885212e27`。
- 首轮 TCP 监测实现每 500 ms 建立并立即关闭未认证的 TCP/22 连接。三个 dispatch 新 SSH 会话均在远端脚本启动前被丢弃；每次均以“无 dispatch 成功/失败/临时文件、boot hash 未变化、uptime 未归零、对应时间窗无 shutdown/reboot journal、systemd 无 reboot job”确认没有发生 reboot，因此没有把客户端 `exit 255` 误记为实际重启。目标 `sshd -T` 显示 `PerSourcePenalties` 包含 `noauth:1`、`min:15`；对应日志窗口出现 54 条 penalty 相关消息、46 条拒绝/丢弃消息，并明确记录 `penalty: connections without attempting authentication`，另有 124 次丢弃被日志限速汇总。该证据解释了未认证 TCP 探针与新 SSH dispatch 会话的冲突，但不把该时间窗内所有互联网扫描连接都归因于本机监测器。
- 在不改变实际 reboot 次数的前提下，改为先建立并校验一个严格、已认证且等待单次令牌的 SSH 会话，再启动新的 TCP/22 监测器；监测器达到连续 3 次 `UP` 后，只向既有会话发送一次令牌。远端 dispatch 门禁原子写入 `DISPATCH_GATE=PASS` 和 `REBOOT_REQUEST_PREPARED=YES`，日志 SHA-256 为 `d93e93b5c96174223444e4da7bcfae7b6757bfac9f8ef6faac3d69e6561d8f9d`，`systemctl reboot --no-block` 返回 0。只有这一请求实际进入 systemd 并形成 boot ID 变化，故目标机实际只重启一次。
- 最终客户端监测于 `2026-09-03T08:34:28Z` 在 reboot 前启动，`08:34:29Z` 达到 ready，并连续运行至 300 秒上限；恢复后的 boot 起始时间为 `08:34:53Z`，明确落在该监测窗口内，但 TCP connect 始终返回 `UP`，因此结果为 `ready=yes offline=no recovered=no`、exit 3，而不是预期的 `UP→DOWN→UP`。原始日志已以 root:root/0600 归档为 `stage4-tcp22-monitor.log`，SHA-256 为 `a46d89f6af41b8fa012b7719041efc656fcfc8830d4aacca631bb08dccc7e8fe`。该日志证明监测确实跨越实际 reboot，但不能证明端口下线窗口；不能排除服务商网络层仍完成 TCP 握手，也不能据此判断 guest sshd 在重启期间始终可用。
- 探针停止且 OpenSSH 来源惩罚窗口解除后，严格 SSH 重新认证成功。重启前 boot ID 的 SHA-256 为 `7300fbb9c034f6b475114331ee09c68c4a95f02a353b7b09c8f63622af705e52`，恢复后为 `b6421b00302173c81cdd49eee6db5a0b9ff7bec70318025b02a6a880d5112272`；仅记录摘要，不记录完整 boot ID。运行内核仍为目标 `6.12.107+deb13-amd64`，systemd running、failed unit 为 0、SSH active、时间同步、单 IPv4 默认路由和默认 policy rules 均正常。
- 独立 post-reboot 持久性审阅完成 157 项 `PASS`、0 项 `FAIL`，日志 SHA-256 为 `3affc7b675d69b56503ecb8aee382e4ab331dec3535f3b2e9c42475ea0391237`。分别执行并保存的 `dvt verify` 与 `dvt status` 均返回 0，日志 SHA-256 分别为 `27fe36cbabf164a03f93e33a8852e1beda0fc555463abc18ede5e3f0e7d3c78a` 和 `848d78074789c45f3abdd6cb7991f38fdcf9a3fecacfa50e51fce47726b5c982`；verify 为警告数 0，status 为 schema 4、`0.1.0-rc.16`、`VERIFIED`、`debian13-1c2g`、500 Mbps、200 ms、自动 `33554432` 字节，并报告 `bbr + fq`。
- 独立审阅逐项确认 17 个受管 sysctl 的文件值与运行值完全一致、BBR 可用且已启用、唯一 IPv4 默认出口实际根 qdisc 为 `fq`；`/swapfile-proxy` 为 root:root/0600、1024 MiB、device/inode 与 state 一致、已激活且 fstab 项目行精确一次；`proxy-vps-fq.service` enabled/active/exited、ExecMainStatus 0；journald 三项为 `128M/1G/64M` 且服务 active；x-ui 仍未安装而 NOFILE drop-in 保持 `65536`；无 iperf3、无 DVT 事务残留。state、qdisc 原快照、provider 原始备份、迁移后 `/etc/sysctl.conf` 及 5 个受管文件的固定摘要全部与 Stage 3 一致，17/17 安装资产校验通过。
- 最终自检再次完成 108 项 `PASS`、0 项 `FAIL`，日志 SHA-256 为 `d72a3a349fe8c7cd8fc5a241d5172a22d18989cbc83fe1bce7f2b68bd9d2525f`；其后新的严格 SSH 会话复核该日志、当前 boot hash、目标内核、state 摘要、systemd/SSH 和 failed units 均通过。3 个只用于 dispatch 的远端隐藏脚本在逐一核对固定摘要、owner/mode 和限定路径后删除，远端 Stage 4 隐藏临时文件计数为 0；没有再次 reboot、重复 `apply`、安装 3X-UI 或运行任何主动流量测试。

### 未完成门禁

- 客户端原始 TCP connect 监测没有观察到 `DOWN`，因此“TCP/22 `UP→DOWN→UP`”仍为 `NOT_OBSERVED`，不能写成通过。boot hash 变化、持久 dispatch 日志、目标内核和重启后运行态足以证明一次真实 reboot 以及 DVT 持久性，但不能替代该特定链路观测。不得只为补这一观测再次 reboot；若后续已授权阶段包含 reboot，应先建立已认证控制会话，或使用不会触发 `PerSourcePenalties` 的认证型 SSH 可用性监测，再独立保留 TCP 层结果。
- 重复 `dvt apply --port 500` 的幂等门禁尚未授权和执行。严格 3X-UI/Xray 验证、第二次 reboot、真实 VLESS + REALITY + TCP 冒烟和业务期 diagnose 仍未执行；当前 x-ui drop-in 只证明持久文件预置，不证明代理服务、Xray/REALITY 链路或业务性能。
- benchmark、probe、TcpQuality、HTB、故障注入、rollback 和 purge 继续未授权且未执行。服务商快照恢复能力仍停留在用户已创建并确认控制台可用的操作者证据层，本轮没有主动执行恢复演练。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。新增的是目标 OpenSSH 接受层与临时验收监测器之间的操作性证据：未认证高频 TCP/22 connect 会触发 `PerSourcePenalties` 并阻断同来源的新 SSH 控制会话。该问题不属于 rc.16 DVT 配置缺陷；其最小处置已在本轮验证为“先建立已认证控制会话，再启动监测”，不据此扩展新的仓库功能或安全专项。

### 当前成熟度判断

目标机的 DVT 持久性达到 `STAGE4_PERSISTENCE_REBOOT_PASS_READY_FOR_IDEMPOTENCY_AUTHORIZATION`：一次真实 reboot 后，严格 SSH、目标内核、schema 4 `VERIFIED`、17 项 sysctl、BBR、根 `fq`、项目 swap、fq service、受管文件、provider transfer 和发布资产均通过独立审阅及最终自检。该成熟度同时保留 `TCP22_CYCLE_OBSERVATION=NOT_OBSERVED` 限制；它不等于重复 apply、代理链路、第二次 reboot、真实业务或性能验收通过，下一步只能由用户另行授权幂等门禁。

## 本轮记录：2026-09-03（新目标机 rc.16 apply 与立即验收）

### 已完成及证据

- 用户明确授权重新执行 apply 前防漂移检查、运行一次 `dvt apply --port 500`，并完成立即 `verify`、`status`、managed state/文件/运行态审阅后停止；本阶段明确不 reboot、不安装 3X-UI、不运行主动流量测试。执行前再次确认 Windows OpenSSH alias 为 root/TCP 22、配置的 `vps_rsa` 与当前 agent 中身份唯一匹配，任务专用 `known_hosts` 只有固定 ED25519 记录；严格 host-key 校验的连接和 rc.16 版本检查通过。服务商快照继续以用户控制台确认作为操作者证据，目标机内部不能反向证明。
- 第一次防漂移采集器核对 Stage 2 权威日志摘要时，误把包装器返回的 `PASS_COUNT=55` 当作日志内文本；7 份 Stage 2 日志固定 SHA-256、系统健康和包管理门禁均已通过，但因过严格式断言以 exit 41 停止，未执行 apply，失败日志 SHA-256 为 `c31d9a19845cde970315ad8ad9b290d6edf4b0c985654080122bfd03cd648c06`。只读检查确认权威日志实际包含 55 条 `PASS:`、0 条 `FAIL:` 和 `OVERALL=PASS`，随后按真实格式修正断言。
- 第二次完整防漂移检查的 72 项系统断言和重跑的 `dvt preflight --port 500` 均已通过；preflight 仍为 `PASS_WITH_PROVIDER_SYSCTL_TRANSFER`、警告数 3，且 `/etc/sysctl.conf`、`/etc/fstab`、qdisc、`cubic + fq_codel`、无 swap/managed state 均确认零写入。PowerShell 在脚本 EOF 后追加只含 CR 的空行，远端 Bash 在全部通过标记之后返回 127；仍未执行 apply，失败日志 SHA-256 为 `5a585a1466fc3cacfafb3cdb09fbf0e08fbb3dfbd455f255cafd8f0ad324732b`。改用注释终止传输后第三次完整重跑通过，权威 pre-apply 日志 SHA-256 为 `d3011d4bc8af5cdd4452e95733e12d9f9f0d41ae55581827cbdfd3117b607f05`。
- 在紧邻 apply 的最小门禁继续确认 pre-apply 日志、`/etc/sysctl.conf` 固定原始摘要、未管理状态、rc.16 版本、systemd、failed units、真实包管理进程和四个锁均未漂移后，只执行一次 `dvt apply --port 500`。DVT 内部 preflight 再次通过，完整备份并事务化迁移厂商 sysctl 归属，写入受管配置，启用持久根 `fq` service，创建并激活 1024 MiB `/swapfile-proxy`，内建 verify 通过并提交 schema 4 `VERIFIED`；命令和外层包装均返回 0，apply 日志 SHA-256 为 `8693949bd02be957b00b1bd19dbe309a6f17e541e8cfaf2ad9e7d688b2e07ff7`。apply 前后 boot ID 一致，SSH 会话持续在线。
- apply 后使用新的严格 SSH 会话复核日志并分别运行 `dvt verify` 和 `dvt status`，两者均返回 0。立即 verify 确认自动选择 `debian13-1c2g`、固定 profile 摘要和警告数 0；因未安装代理服务，只报告 x-ui NOFILE drop-in 已预置，不把代理运行时写成通过。verify 日志 SHA-256 为 `c97a84e1f7ce8e655868b5fa007b8224c5427b46c0a9cea3c3657e9773b872ff`，status 为 `ee66a8e82dae20685fd11e8304b70440ced716660acb44ba11e5e282f5e3b66b`。
- 独立 post-apply 审阅完成 173 项 `PASS`、0 项 `FAIL`：state 为 schema 4、`0.1.0-rc.16`、`VERIFIED`、`debian13-1c2g`、500 Mbps、200 ms、自动 `BUF_MAX=33554432`；provider transfer 为 `TRANSFERRED`，原始 `/etc/sysctl.conf` 备份保持原摘要，迁移后源文件不再含活动定义；5 个受管文件的 owner/mode/marker/状态哈希全部匹配，17 个受管 sysctl 的文件值与运行值逐项一致；原 qdisc 快照为 `fq_codel`，当前唯一出口根 qdisc 为 `fq`；项目 swap 的路径、1024 MiB 文件大小、device/inode、活动状态和唯一 fstab 行一致；`proxy-vps-fq.service` enabled/active/exited，journald 三项有效配置和服务状态通过，x-ui 仍未安装。policy rules/default route、systemd、SSH、时间同步、UFW、dpkg 和包管理锁均正常，无 iperf3 进程。审阅日志 SHA-256 为 `cede4f6b134dd17e237cb0ef2f49cb4279f33e4474aabe272de0f6be10498d7a`。
- 关键终态摘要为：state `77db50a4a26989133f7a58554d52c566d44724204698c9abb5c73366407ce8c9`，qdisc 原快照 `33d926bdb2b9a27df37afeeb6106834e2a88b5ea752fac22b4198d727750bf4e`，provider 原始备份 `3f8a0bc244ff20b7ab4aa5900d736a7dba6b69f196d6125230bd7c34b7498ffd`，provider 迁移后文件 `7cf5fff5135b53f7eb84ff88d8d1b59d24540bed0e59b9b76ea740359adedfe6`，受管 sysctl `d0d2e7477f2f8c377857955f6d663310e44a78a9ebf080379d4527f826b6a9bb`。最终自检 42 项 `PASS`、0 项 `FAIL`，日志 SHA-256 为 `6f7b5e52231512153bb521c011a9d331c382686027b3b677c5c14739cc796601`；日志原子提交后严格重连和摘要复核通过，Stage 3 临时证据文件及 state 事务临时文件均为 0。

### 未完成门禁

- 本轮按授权停在立即审阅，不 reboot。尚未证明 17 项 sysctl、根 `fq`、活动项目 swap、journald、NOFILE drop-in、fq service 和 schema 4 state 在一次真实 reboot 后持续有效；下一次 reboot 必须在发出命令前先启动客户端 TCP/22 监测，以补齐此前未直接观察到的“在线→下线→上线”周期，再严格重连并运行 `dvt verify/status` 与文件哈希复核。
- 重启后通过以前，不执行重复 `apply` 幂等门禁。严格 3X-UI/Xray 验证、第二次 reboot、真实 VLESS + REALITY + TCP 冒烟和业务期 diagnose 仍未执行；当前 x-ui drop-in 仅是静态预置，不能证明代理服务存在、NOFILE 已作用到进程、Xray/REALITY 可用或业务性能改善。
- benchmark、probe、TcpQuality、HTB、故障注入、rollback 和 purge 继续未授权，也没有因 apply 成功而自动纳入默认路径。服务商快照恢复能力仍只达到“已创建且控制台可用”的操作者确认层，没有为了本轮成功主动执行恢复演练。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。两次 pre-apply 失败均来自本轮临时证据包装器，分别通过检查真实日志格式和修正 CRLF 传输闭合；失败证据完整保留，没有发现 rc.16 installer、controller、profile、事务迁移或立即 verify 缺陷，不据此扩展新的通用框架。

### 当前成熟度判断

目标机达到 `STAGE3_APPLIED_IMMEDIATE_VERIFY_PASS_PENDING_PERSISTENCE_REBOOT`：固定 rc.16 已在该 Debian 13 / 1C2G / 500 Mbps 目标机实际应用，立即 DVT 自验、独立运行态审阅、严格 SSH 连通和证据完整性均闭合。该结论仅证明本次启动周期内的配置与状态正确；下一安全检查点是用户单独授权一次 DVT 持久性 reboot，而不是自动安装代理、重复 apply 或运行性能流量。

## 本轮记录：2026-09-03（新目标机 rc.16 安装与 500 Mbps preflight）

### 已完成及证据

- 用户确认已在服务商控制台创建快照，并授权固定 rc.16 installer、未管理状态 `verify` 和 `preflight --port 500`，明确要求停在 preflight 审阅、不执行 `apply`。快照状态属于操作者确认，目标机自身无法反向证明；SSH identity 与任务专用 ED25519 host-key pin 在执行前再次匹配。
- 已现场反查 GitHub `v0.1.0-rc.16` Release：tag 精确、非 Draft、Pre-release，19/19 资产均为 `uploaded`，名称集合与当前清单一致，GitHub API 的 19 个 SHA-256 digest 全部匹配。目标机从固定 Release URL 下载的 `install.sh` 与 `SHA256SUMS` 分别通过外层固定摘要，清单为 17 项且包含预期总控与 `debian13-1c2g` profile；安装前系统、Stage 1B 哈希、包管理、路由、qdisc、swap 和未管理状态均未漂移。安装前日志 SHA-256 为 `3f32c276f61aa79a233b6b85931f2e243eef3e3ed65cfad6ef7585a379fb71ad`。
- `install.sh --no-launch` 实际返回 0 并完成版本化安装，下载并校验 17 项运行资产；外层证据包装因在当前 shell 的重定向块中使用 `exit` 而提前结束，只留下唯一 root-only 临时日志。只读确认 installer 完成、`dvt --version` 与 `current` 正确且 managed state 不存在后，未重复安装，直接把该唯一日志原子归档并完成遗漏的 postcheck。安装原始日志 SHA-256 为 `816de6ed179732975a711d4c9638210ae711c07183e35715dded16145c167ba2`，postcheck 为 `102e886640f055b04e86a1fad00fcb93db1dd343cf7a63ad0c065002f2a7d934`；17/17 资产、固定 manifest、root 所有权、非 group/world 可写权限、wrapper、symlink 和版本契约全部通过。
- 首次未管理 `dvt verify` 已实际返回预期 exit 5，选择固定 `debian13-1c2g-vps-tuning.sh` 并输出“当前主机尚未安装本项目配置”的预期语义；外层 state guard 写成无效复合 `[` 表达式，SSH stderr 出现语法错误，但 DVT 输出和内部断言已完成且没有系统写入。原日志 SHA-256 为 `d9e76714dff43480a727217b56aad16f62b33ce0d67ca7892e6d4ead9878a8c3`；改用显式文件/符号链接判断后完整重跑，再次精确返回 exit 5，权威日志 SHA-256 为 `f55e490c3907e8d8c7ff5261dcb59d0fe40c4661ddb3d09300985e632b38afef`。
- `dvt preflight --port 500` 返回 0，自动识别 Debian 13、1 vCPU、1973 MiB、`debian13-1c2g`，固定 profile SHA-256 与 Release 清单一致。preflight 输出 500 Mbps、目标 RTT 200 ms、理论 BDP 12500000 字节、3/2 BDP 目标 18750000 字节、自动 `BUF_MAX=33554432` 字节和约 536 ms 理论覆盖；ext4 允许创建 1024 MiB swap，磁盘余量超过 swap 加 1024 MiB 保留空间门禁，根 `fq_codel` 可安全切换为 `fq`。原始 preflight 日志 SHA-256 为 `767af1637ed19bf6fe65ee422e9158854e999e0fe4c317338f5136238e98e069`。
- preflight 结论为 `PASS_WITH_PROVIDER_SYSCTL_TRANSFER`、警告数 3：`/etc/sysctl.conf` 中分别且仅一次定义 `net.core.default_qdisc=fq` 和 `net.ipv4.tcp_congestion_control=bbr`，第三条警告说明未来 apply 的事务迁移。只读审阅确认该文件为 root:root/0644 普通文件、只有这两条活动配置、无其他活动行，`/etc/sysctl.d/99-sysctl.conf` 不存在，systemd-sysctl 当前有效配置也不包含这两项，因此运行态保持 `fq_codel + cubic` 是一致的。该情况严格符合 rc.16 仅允许迁移的厂商基线白名单；审阅日志 SHA-256 为 `a762ba96002489cbf992ea4cce1af9c6901e57710100a7843119d8e85c437e6f`。
- 第一次最终自检的 53 项中 52 项通过，唯一失败是检查过程把自己正在写的 `.stage2-final-self-audit.*` 临时文件计为残留；失败日志 SHA-256 为 `f141527dfb76080e6ba1955f9debc977d4f4baac57fa2f9bbf5df8688b006011`。改为创建新临时文件前计数并在原子提交后复核，完整重跑 55 项 `PASS`、0 项 `FAIL`，提交后临时文件为 0；权威最终自检日志 SHA-256 为 `c8839378da355454c7baeeded17822c32ce0a004f4f6fe391ab5c8dbfeae4c3a`。

### 未完成门禁

- 按授权已停在 preflight 审阅，未执行 `apply`。当前只有固定 rc.16 命令资产；不存在 `/var/lib/proxy-vps-tuning` managed state、项目 sysctl/journald/NOFILE/fq service 文件或 `/swapfile-proxy`，运行态仍为 `cubic + fq_codel`、无 swap，UFW inactive，systemd running、failed unit 为 0。
- 若后续授权 `dvt apply --port 500`，将先建立 schema 4 事务状态和 qdisc 快照，完整备份 `/etc/sysctl.conf` 并把其中两条厂商定义注释化，再写入 17 项受管 sysctl、journald 配置、x-ui NOFILE drop-in、fq helper/service，切换实际根 qdisc 为 `fq`，创建并持久化 1024 MiB 项目 swap，最后执行内建 verify 并提交 `VERIFIED`。任一步失败应由内建事务回滚；仍须在执行前复核 provider 文件哈希和系统状态没有漂移。
- apply 后的立即 `verify/status`、受管 state/文件哈希审阅、DVT 持久性 reboot、提前启动的 TCP/22 下线/上线观测、重启后 verify、重复 apply 幂等、严格 3X-UI/Xray、第二次 reboot、真实 VLESS + REALITY + TCP 冒烟和业务期 diagnose 均未执行。benchmark、probe、TcpQuality、HTB、故障注入、rollback 和 purge 继续未授权。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。三次失败均来自本轮临时证据包装器，已分别保留失败日志、查明原因并以改变后的判据重跑；未发现 rc.16 installer、controller 或 profile 缺陷，不据此扩大为新的通用测试框架。

### 当前成熟度判断

目标机已达到 `STAGE2_PREFLIGHT_REVIEWED_READY_FOR_APPLY_AUTHORIZATION`：公开资产、目标下载、版本化安装、未管理 exit 5、500 Mbps preflight 和 provider sysctl 迁移适用性均闭合；系统调优仍未应用。下一安全检查点是用户审阅上述明确变更后单独授权 `dvt apply --port 500`，不是自动继续。

## 本轮记录：2026-09-03（首次内核 reboot 与新内核恢复验证）

### 已完成及证据

- 已现场确认 SSH 配置引用的 `vps_rsa` 公钥 fingerprint 存在于当前 Windows OpenSSH agent，任务专用 `known_hosts` 中唯一匹配的 ED25519 host key 与控制台已确认值一致；后续连接持续使用 `StrictHostKeyChecking=yes`、`BatchMode=yes`、`IdentitiesOnly=yes` 和任务专用信任文件，没有写入用户全局 `known_hosts`。
- 首次预重启门禁把常驻的 `unattended-upgrade-shutdown --wait-for-signal` 关机协调器误判为包管理工作进程，按 fail-closed 以 exit 41 停止且没有 reboot。失败日志 SHA-256 为 `a52b83627c926a103466eb444bc1ce262a478115c6953828074589166f8e13dc`；只读诊断确认 `apt-daily`/`apt-daily-upgrade` inactive、无 APT/DPKG 锁后，修正为“排除空闲协调器，同时要求无真实更新进程和包管理锁”。完整重跑通过，日志 SHA-256 为 `8bc8607e61710f1e8ed13f216cdee32e879585a1da043a40b00930f6de0de865`。
- 第一次即时 reboot 门禁使用 `cmp` 比较普通 boot-ID 文件和 `/proc` 伪文件时产生假阴性，按设计再次停止且没有 reboot；失败日志 SHA-256 为 `40df0833bb8846c659026c6c3d6172eb30992340e244b91255c876751451f1c2`。分别读取两端内容后确认 boot ID 完全一致且旧内核仍在运行，随后改用内容比较；修正后的即时门禁通过，日志 SHA-256 为 `c1f29b2fec0bf223f3f5a06574bd758d1f4211d258319cfbdd11b3eb1682c7df`，再按用户授权发出一次 `systemctl reboot --no-block`。
- reboot 后严格 SSH 重新认证成功；boot ID 已变化，运行内核为 `6.12.107+deb13-amd64`，目标与旧回退 kernel/initrd 均保留。systemd 为 running、failed unit 为 0、SSH active、时间同步正常、`/run/reboot-required` 已清除，单 IPv4 默认路由和默认 IPv4/IPv6 policy rules 未漂移。
- post-reboot 继续确认原始 `cubic + fq_codel`、BBR 可用、出口唯一根 `fq_codel`、无 swap、UFW inactive、无真实包管理进程或锁、根分区可写、EFI 正常；Stage 0、Stage 1A 及四份 reboot 前证据的 SHA-256 全部通过。post-reboot 日志 SHA-256 为 `d1d5f00a2bc0f5e36d6adeb0295bbefe16866a03fa05547e795e235b4110e6be`，包含 38 项 `PASS`、0 项 `FAIL`；无遗留临时文件，`dpkg --audit` 为 0，`dvt` 命令和版本化安装目录仍不存在。

### 未完成门禁

- 客户端监测在 reboot 请求后才启动，开始监测时目标已恢复，因此 90 秒窗口内没有观察到 TCP/22 下线事件；boot ID 变化、目标内核和近期启动时长提供了更强的实际 reboot 证据，但本轮不把未观察到的“端口下线→上线”写成通过。无需仅为补这一观测重复内核 reboot；可在后续另行授权的 DVT 持久性 reboot 中提前启动监测并补齐。
- 本轮授权只覆盖第一次内核 reboot 及恢复验证。固定 rc.16 installer、未管理状态 `dvt verify` 的预期 exit 5、`dvt preflight --port 500`、preflight 审阅、`apply`、立即 verify/status、DVT 持久性 reboot、幂等 apply、严格 3X-UI/Xray、第二次 reboot、真实 VLESS + REALITY + TCP 冒烟和业务期 diagnose 均未执行。
- 进入 DVT 写入阶段前仍建议在服务商控制台创建快照，并须取得 installer/preflight 及后续 apply 的相邻阶段授权。benchmark、probe、TcpQuality、HTB、故障注入、rollback 和 purge 继续不在默认目标机门禁内。

### 延期事项变化

- 无新增项目功能或网络调优延期事项。仅保留一次客户端 TCP 下线观测缺口，计划在后续已授权 reboot 中补证；它不改变 rc.16 功能范围，也不削弱本轮 boot ID 与目标内核形成的实际 reboot 结论。

### 当前成熟度判断

目标机首次内核 reboot 与新内核恢复门禁达到 `PASS_WITH_CLIENT_TCP_CYCLE_OBSERVATION_LIMITATION`：实际 reboot、目标内核、SSH/网络/systemd/时间/包状态和原始基线均已闭合，两个采集器假阴性已保留而未冒充主机故障。rc.16 仍未安装，目标机生命周期和真实代理业务验证尚未开始。

## 本轮记录：2026-09-03（首次内核 reboot 授权后的本机认证暂停）

### 已完成及证据

- 用户确认目标为可随时重装的专用验收机、服务商控制台/救援入口已实际可用、当前维护窗口可重启，并明确授权第一次内核 reboot；服务商支持快照但尚未创建，用户在知情情况下仍授权本次 reboot。
- 执行紧邻重启的防漂移检查时，首次命令在本地 PowerShell 解析阶段因内嵌 Bash 引号冲突失败，没有发出远端命令。改用已验证的 stdin 脚本方式前，本地身份门禁发现 Windows `ssh-agent` 已停止，任务 `vps_rsa` 不再可见，因此按设计停止。
- 已仅在本机把 Manual 启动类型的 Windows `ssh-agent` 恢复为 Running，没有改变启动类型。恢复后 agent 只有既有的其他 RSA identity，目标 `vps_rsa` 仍未加载；未尝试用错误 identity 连接，也未执行远端证据写入或 reboot。

### 未完成门禁

- 用户须在自己的 PowerShell 中使用 Windows OpenSSH `ssh-add.exe` 重新加载 `vps_rsa`，并确认 `ssh-add -l` 出现目标 key。私钥口令不得进入对话。
- 原 reboot 授权、任务专用 ED25519 host-key pin 和远端 root 身份证据继续有效，但实际执行前仍须重新完成紧邻重启的只读防漂移检查。只有 target identity、当前 6.12.105、目标 6.12.107、systemd/更新进程和证据哈希全部正常，才保存预重启证据并 reboot。

### 延期事项变化

- 无新增延期事项；这是本机临时认证状态变化，不改变目标机计划或授权范围。

### 当前成熟度判断

目标机技术与人工 reboot 门禁已具备，但本机 `vps_rsa` 临时身份不可用，当前状态为 `REBOOT_AUTHORIZED_WAITING_FOR_LOCAL_IDENTITY`。VPS 未发生任何本轮变更。

## 本轮记录：2026-09-02（HTB 脚本修改必要性澄清）

### 已完成及证据

- 已基于上一轮全部 HTB 文档、当前 rc.16 实现和运行证据边界，确认当前批准范围内不需要修改项目脚本：现有实现仍应保持 200 Mbps、Debian 13 1C1G/1C2G、`eth0`、非持久 HTB、100–199 Mbit/s 候选和根 `fq` 恢复契约；190 Mbit/s 继续只是待验证候选，缺少的是 A/B/A、反向窗口和真实业务证据，而不是当前脚本功能缺陷。
- 已区分“无需修改”与“尚未授权扩展”：将 95%设为所有端口的默认值、支持 100/500/1000 Mbps、多端口动态候选、永久 HTB 或开机持久整形，均会改变当前产品范围和安全契约，届时需要先批准新阶段，再修改执行器、计划/runner/analyzer、包装层、fixture、文档和生成/发布资产。本轮没有修改这些文件。

### 未完成门禁

- 200 Mbps 的 HTB200 reference、180/190/195 candidate sweep、双顺序窗口和真实代理链路仍未闭合；在这些证据完成前，不能把“不需要修改脚本”误解为“190 已验证有效”或“应立即部署永久 HTB”。
- 500/1000 Mbps 及 100 Mbps 的多端口能力仍处于未启动、未授权状态；上一轮发现的 rc.13/rc.14 研究文档版本标记漂移，应在重新启用相关实验前修订，但不构成当前 rc.16 已发布脚本的缺陷。

### 延期事项变化

- 无新增延期事项；多端口临时 HTB 与永久整形继续保持上一轮登记的延期和未授权状态。

### 当前成熟度判断

当前最小正确决策是保持 rc.16 脚本不变，先补证据或由用户明确启动新的多端口/持久整形阶段；没有证据支持为了体现 95%经验而立即改动现有实现。

## 本轮记录：2026-09-02（HTB 文档全量评审与 95% 速率外推）

### 已完成及证据

- 已逐行复核 `docs/experiments` 中全部 4 份、合计 2202 行的 HTB Markdown：候选速率发现 SOP、1C1G 完整 campaign、1C2G A/B/A 协议和历史 1C1G A/B/A 材料；文件名匹配与正文 `HTB` 匹配集合一致，没有遗漏同目录中的 HTB 文档。
- 已对照当前 rc.16 的 HTB 执行器、rate-sweep plan/runner/analyzer、A/B/A plan 和 `dvt htb` 包装层，并联网复核当前 iproute2 HEAD `873daf67da6d330b2d5778a335463a03ff30c1f2` 的 HTB/fq/police/stab 手册、Linux HEAD `89a312991dc6e638a36adc43ccb91dbc25504c04` 的 `tcp_wmem` 文档、iperf3 HEAD `c9b74229d0d9bfec6d2307b66b43c29a7665ad0b` 的方向语义、RFC 4022/5681/8985 及 OpenWrt SQM 当前指南。论坛经验只作为假设线索，没有替代一手来源和仓库证据。
- 评审结论为：`HTB 190 Mbit/s + fq` 是 200 Mbps 档合理的首选实验候选，但不是已经证明有效的生产默认值。当前历史有效 B1 只证明约 3.389 GB 流量经过 190 Mbit/s 聚合整形、`overlimits=103044` 且本地 qdisc 无 drop/requeue/backlog；缺少完整 A2、归一化重传对比和反向窗口，不能证明 95% 降低重传。另一个根 `fq` 单流样本曾达到约 199.96 Mbps 且 sender retransmits 为 0，也反驳“所有 200 Mbps 标称端口都必须留 5%”的普遍化结论。
- 95% 的数学映射是 100→95、200→190、500→475、1000→950 Mbit/s，但当前实验契约只支持 Debian 13 1C1G/1C2G、`eth0`、200 Mbps；执行器只接受 100–200 Mbit/s，候选计划只接受 100–199 Mbit/s，rate-sweep、runner 和 analyzer 都硬校验 provider port 200。因此 95、475、950 均不是当前可执行、已测试或可发布的项目能力。
- 当前固定 `burst=262144`、`cburst=32768` 在 190/475/950 Mbit/s 下分别约代表 11.04/4.42/2.21 ms 和 1.38/0.55/0.28 ms 的数据量；直接只放大 rate 会改变突发抑制和计时语义。500/1000 Mbps 扩展必须重新评估 timer、burst/cburst、CPU/softnet、队列拓扑、流量预算、计费层开销和目标机 fixture，不能只改端口与候选数字。
- 对“优化后重传增加”的判断仍须使用同发送方向、同端点和地址族下的 sender retransmits/GiB、goodput、RTT、qdisc、CPU/steal、softnet 和接口增量。HTB 只约束 VPS egress；绝对重传数会随发送字节增加，`tcpRetransSegs` 也不是等价的丢包计数。当前文档对归一化、方向、A/B/A、反向窗口和非持久化边界总体正确。本轮未修改 HTB 文档、代码、生成资产、发布资产或任何 VPS，也未运行公网流量。

### 未完成门禁

- 用户的新观察尚未形成与当前 schema、工具哈希和窗口契约绑定的原始证据；无法确认重传增加来自服务商 policer/虚拟交换机、路径拥塞或乱序、端点漂移、CPU/steal/softnet、计费层开销，还是吞吐提升后绝对计数自然增加。
- 200 Mbps 的 HTB200 reference、180/190/195 candidate sweep、独立 `A1/B1/A2`、另窗 `B2/A3/B3` 和真实代理链路复验仍未闭合；190 Mbit/s 只能保留为候选。若实测拐点明显低于标称端口，最终 shaper 应围绕拐点选择最高通过速率，而不是继续使用标称值的固定 95%。
- 500/1000 Mbps 以及 100 Mbps 的多端口 HTB 实验能力尚无已批准需求、设计、实现、fixture、Linux root 或目标机证据。三份研究专用现行文档仍标注 rc.13/rc.14，而执行器已硬绑定 rc.16；若下一阶段获准执行实验，必须先同步版本契约并重新完成静态、root、目标机和预算门禁。

### 延期事项变化

- 新增具体延期候选“100/500/1000 Mbps 多端口临时 HTB 速率发现与 A/B/A 能力”，包括动态 provider port、候选比例/整数化、burst/cburst、预算、队列/路由和资源门禁；它属于既有聚合整形研究边界，未获下一阶段或实现授权。永久 HTB 仍保持既有延期状态。

### 当前成熟度判断

rc.16 发布闭环不变。本轮达到“全部 HTB 文档、当前实现和外部机制证据已复核；200 Mbps 的 190 Mbit/s 可作为有条件实验候选；95% 跨档默认化不通过”的评审层级。尚无证据支持修改现有 BDP/socket-buffer 公式、发布多端口 HTB 或建立生产持久整形。

## 本轮记录：2026-09-02（标称带宽 0.9 倍与 TCP 重传只读研究）

### 已完成及证据

- 已按配置与基础设施研究边界联网核对 Linux 6.12/当前内核 `tcp_wmem` 文档、RFC 5681/RFC 8985/RFC 4022、当前 iproute2 的 `fq`/HTB/CAKE/police 手册、iperf3 当前手册、VMISS 当前法律与 Fair Use 文本，以及独立的 Bufferbloat/SQM 调整建议；论坛引语仅作为问题线索，没有作为关键结论依据。
- 已区分三种不同语义：`PORT_SPEED_MBPS` 是套餐端口/BDP 与状态元数据输入，`tcp_wmem[2]` 是每连接自动发送缓冲上限，HTB/CAKE/iperf3 pacing 才是实际速率控制。降低前两者不会自动把出口限制到套餐的 90%，不能用 socket buffer 改参替代聚合整形。
- 按当前 `debian13-1c1g` 默认 200 ms、1.25 倍 BDP 和 16/32/64 MiB 离散档计算，100/200/500 Mbps 分别改为 90/180/450 Mbps 后仍全部选择 16 MiB；其中 90 Mbps 还低于当前 `PORT_SPEED_MBPS=100..1000` 输入契约。因此把 0.9 直接写进现有 BDP 公式，对用户列出的 1C1G 默认场景不产生预期的重传控制效果，却会混淆标称端口、预算和状态语义。
- 当前仓库证据中，一次根 `fq`、单流、10 秒、200 Mbps cap 的样本达到约 199.96 Mbps 且 sender retransmits 为 0，反驳“标称 200 Mbps 必然达不到”的普遍化结论；另一次 HTB190 B1 只证明整形生效和本地 qdisc 无丢包，因缺少完整 A2/同窗比较，仍不能证明 95% 或 90% 整形降低重传。
- 研究结论是：0.9 可以作为出现可复现满速重传拐点时的首个、可逆出口整形候选，但应作用于经受控端点、多时段、固定方向和地址族确认的稳定瓶颈/拐点，并与 95%/85% 或相邻速率进行独立 A/B/A；不得无条件成为所有 VPS 的 BDP、socket buffer 或永久 HTB 默认值。本轮未修改实现、生成资产、README、验证矩阵或发布资产。

### 未完成门禁

- 用户本轮描述的是昨晚观察和论坛引语，尚未提供相同端点、方向、地址族、时段、负载、sender bytes/retransmits、CPU/steal、softnet、接口和 qdisc 前后增量，因而不能确认主要机制是服务商 policer、共享上联、路径拥塞/乱序、CPU/虚拟化资源、远端节点还是测试方法。
- 未连接或修改任何 VPS，未执行 iperf3、TcpQuality、qdisc 切换、主动流量或生产变更；现有新目标机仍停在首次 reboot 的人工门禁前，本轮分析不构成 reboot、DVT apply 或测速授权。
- 若后续考虑持久出口整形，仍须先使用授权端点和硬流量预算完成同机、同路径、双顺序窗口及真实代理链路复验；需把标称端口、实测稳定容量和最终 shaper rate 作为不同字段/证据保存，并由用户另行批准实现与生产持久化。

### 延期事项变化

- 无新增延期事项。“基于实测容量的永久聚合整形”继续属于既有 L4/永久 HTB 研究边界；本轮没有把它升级为 rc.16 发布缺陷或默认配置变更。

### 当前成熟度判断

rc.16 仓库与公开发布完整性结论不变。本轮达到“机制与仓库语义已核对、0.9 默认化不获支持、可逆候选实验方向明确”的研究层级；尚无目标机因果证据支持修改 socket buffer 公式或发布永久 HTB。

## 本轮记录：2026-09-01（首次 SSH 与内核 reboot 前只读门禁）

### 已完成及证据

- SSH alias 现场解析为 root、TCP/22、独立 `vps_rsa`、`IdentitiesOnly yes`；私钥及公钥文件存在，Windows OpenSSH agent 已加载该 identity。网络侧真实 SSH 握手观察到的 ED25519 host-key fingerprint 与用户从控制台提供的 fingerprint 逐字一致，随后仅写入任务专用临时 `known_hosts`，未改用户全局信任库。
- 在 `StrictHostKeyChecking=yes`、固定 ED25519 host key、`BatchMode=yes` 下，密钥认证成功，远端 UID/用户确认为 0/root。首次连接及后续审计均只读，没有执行 remote file write、软件包操作、reboot、DVT、UFW、代理或主动流量。
- 目标正在运行 6.12.105；`linux-image-amd64` 和 `linux-image-6.12.107+deb13-amd64` 均为已安装状态，目标 kernel/initrd 资产为 root-owned、0644、可读。GRUB `GRUB_DEFAULT=0`，配置同时包含 6.12.107 与 6.12.105，目标 6.12.107 位于默认 Debian 入口，旧内核保留为控制台回退候选。
- 根与 `/boot` 位于同一 ext4 分区，EFI 为独立 vfat 且空间充足。根目录 `/vmlinuz`/`initrd.img` 链接不存在，但当前 GRUB 配置直接包含两个 `/boot` 内核版本，不构成该镜像的 reboot 阻断。
- systemd 为 running、failed unit 为 0、时间同步正常、APT/dpkg/hold 清洁；单 IPv4 默认路由、默认 policy rules、原始 `cubic + fq_codel`、无 swap、UFW inactive 均未漂移。Stage 0 与 Stage 1A 日志重新执行 SHA-256 校验均为 OK。
- 首轮 `findmnt` 多目标调用和 GRUB 正则截断是采集命令错误；已改用逐目标 `findmnt -T`、固定版本 presence 与 menuentry 检查闭合，未把采集器错误误报为 VPS 失败。

### 未完成门禁

- 技术 reboot readiness 已通过，但用户尚未明确确认服务商控制台/救援入口、快照、VPS 用途和维护窗口，也尚未授权实际 reboot。当前必须停在第一次 reboot 前。
- 获得授权后应先把预重启摘要保存到既有 root-only 证据目录，再执行一次 reboot；恢复后必须确认 boot ID 变化、运行内核为 6.12.107、SSH/默认路由/time sync/systemd/failed units/Stage 0 与 Stage 1A 哈希正常。若启动或网络异常，使用控制台选择仍保留的 6.12.105，不进入 DVT installer。

### 延期事项变化

- 无新增延期事项。SSH 连接方式和内核 reboot 不改变 rc.16 核心验收与研究通道边界。

### 当前成熟度判断

首次 SSH 信任、root 密钥认证和 reboot 前技术门禁已闭合；目标达到 `READY_FOR_REBOOT_PENDING_OPERATOR_GATES`。尚未取得新内核运行证据，也未进入 DVT installer、M1 或 preflight。

## 本轮记录：2026-09-01（SSH config VPS 别名指导）

### 已完成及证据

- 已核对用户截图：现有用户级 SSH config 仅定义 `github.com`，通过 `ssh.github.com:443`、用户 `git` 和一把 RSA identity 连接 GitHub；该 Host block 不会为 VPS 登录提供 root、实际 SSH 端口或独立目标别名。
- 已建议保留 GitHub block 不变，为目标 VPS 追加独立、非敏感别名，显式设置 HostName、User、Port、目标私钥 IdentityFile 与 `IdentitiesOnly yes`。本轮只提供配置指导，没有读取或修改用户 SSH config，也没有发起连接。

### 未完成门禁

- 尚待用户确认 VPS 实际授权的是现有 GitHub RSA 公钥还是独立 VPS 公钥；不得仅凭 agent 中存在 RSA key 假设其已写入目标 `authorized_keys`。仍须提供 VPS 别名和控制台核对的 ED25519 host-key fingerprint。

### 延期事项变化

- 无新增延期事项。

### 当前成熟度判断

SSH 客户端配置方式已明确，但目标别名、登录 identity 与服务器 host key 尚未闭合，仍不能安全发起首次连接。

## 本轮记录：2026-09-01（SSH agent 身份门禁复核）

### 已完成及证据

- 用户报告已向 ssh-agent 加载密钥并提供一条 SHA-256 fingerprint。本机现场复核确认 Windows `ssh-agent` 服务现为 Running，Codex 使用的 Windows OpenSSH `ssh-add` 可以访问该 agent。
- Codex 可见 agent 中唯一客户端密钥的 fingerprint 与用户本轮报告值不一致。该差异可能来自 Git Bash/SmartGit 与 Windows OpenSSH 的不同 agent、加载了另一把客户端密钥，或用户报告值实际为服务器 host-key fingerprint；在完成归类前没有尝试 SSH 连接，也没有删除或替换 agent 中现有密钥。

### 未完成门禁

- 用户须确认其报告 fingerprint 来自本机 `ssh-add -l` 还是 VPS 控制台的 `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`。若是客户端密钥，须使用 `C:\Windows\System32\OpenSSH\ssh-add.exe` 把目标私钥加载到 Codex 当前可见的 Windows agent，并确认列表出现对应 fingerprint。
- 仍缺少 SSH config alias 或等价的用户名/端口/本机私钥路径，以及由 VPS 控制台取得并独立核对的 ED25519 host-key fingerprint。上述信息闭合前不得探测端口、接受未知 host key 或发起登录。

### 延期事项变化

- 无新增延期事项；该差异是首次 SSH 信任建立的当前门禁，不改变目标机验收范围。

### 当前成熟度判断

Stage 1A 结论保持通过，但 SSH 接管尚未就绪。下一安全检查点是对齐客户端 agent key、服务器 host key 与 SSH alias 三个独立身份信息；不是尝试默认端口或绕过 host-key 检查。

## 本轮记录：2026-09-01（新目标机 Stage 1A 与 SSH 接管准备）

### 已完成及证据

- Stage 1A 证据显示 root UID 为 0；Debian 官方 trixie、updates、backports 和 security 索引刷新成功，`apt-get --simulate dist-upgrade` 为 0 upgraded/installed/removed/not-upgraded，apt hold 与 `dpkg --audit` 均无输出，failed systemd unit 仍为 0。
- `/run/reboot-required` 明确列出新的 Debian 13 内核包，而当前仍运行 6.12.105；这支持“软件包状态已无待升级，但必须先只读核对已安装内核与引导资产，再通过一次真实 reboot 建立升级后基线”，不能把 0 upgrades 误写为无需重启。
- UFW 已安装但 inactive；当前未启用或修改规则。Stage 1A 只更新 APT 索引并模拟升级，没有安装、删除或升级软件包，没有执行 reboot、DVT installer/apply、代理安装或主动流量。
- 用户询问由 Codex 直接通过密钥 SSH 连接并完成测试验证。当前 Windows 主机已确认 OpenSSH 9.5 客户端可用、用户 SSH config 存在；Windows OpenSSH agent 当前不可达。尚未读取或接收任何私钥、口令、SSH alias、端口或主机指纹，也尚未发起网络连接。

### 未完成门禁

- 首次连接前须由用户提供现有 SSH config alias，或仅提供登录用户名、真实 SSH 端口和本机私钥绝对路径；私钥内容与口令不得进入对话。带口令私钥应由用户在自己的终端预先加载到 ssh-agent。
- 必须通过服务商控制台取得 ED25519 SSH host-key fingerprint，并与网络侧 host key 交叉核对；不得用 `StrictHostKeyChecking=no` 或未经核对的 `accept-new` 绕过首次信任建立。
- 首次 SSH 只授权只读连接、身份/内核/引导/路由/恢复入口复核。真实 reboot、DVT apply、UFW、3X-UI、rollback、purge 和主动流量仍分别受控制台/快照、用途、维护窗口、业务和流量授权门禁约束。

### 延期事项变化

- 无新增延期事项。SSH 接管是目标机验收的执行方式变化，不扩大到全面生产加固或高流量研究。

### 当前成熟度判断

Stage 1A 为 `PASS`，目标机已达到升级后首次 reboot 前的只读核对条件。当前阻塞项是安全建立 SSH 主机信任和补齐人工恢复/授权信息；在此之前不能由 Codex 连接、重启或进入 DVT 写入阶段。

## 本轮记录：2026-09-01（新目标机 Stage 0 基线复核）

### 已完成及证据

- 已复核用户返回的 Stage 0 完整性摘要和日志 SHA-256。目标为 Debian 13.6、Linux 6.12.105、amd64、KVM、1 vCPU、1973 MiB RAM；根分区为约 20 GB ext4、约 18 GB 可用，符合 `debian13-1c2g` 资源档和默认 1024 MiB 项目 swap 的文件系统/空间前提。
- 目标当前为单 IPv4 默认路由，无全局 IPv6 或 IPv6 默认路由；IPv4/IPv6 policy rules 均为常规默认集合，没有自定义 rule、非 `main` 路由表或多默认路由证据。内核公布 `reno cubic bbr`，当前运行态为 `cubic`、默认及单一出口根 qdisc 为常规 `fq_codel`；该状态是可由 preflight 进一步审计的未调优基线，不是异常或已优化状态。
- 当前无活动 swap、无 fstab swap 行、failed systemd unit 为 0；profile 所需命令均存在。Stage 0 只创建了 root-only 证据目录和日志，没有执行 DVT installer、preflight、apply、sysctl/qdisc/swap 变更、代理安装、重启或主动流量。

### 未完成门禁

- 用户返回的摘录未包含 `id -u` 行，虽 root 提示符和 `/root` 证据写入强烈支持 root 身份，下一阶段仍应重新输出该值以闭合直接证据。
- 进入系统升级或 DVT 写入前，仍须由用户确认：未来生产机或可重装验收机、服务商控制台/救援入口、快照能力、真实 SSH 端口、500 Mbps 套餐口径、维护窗口及流量额度。当前技术基线可判为通过，但写入授权门禁尚未闭合。
- 下一相邻步骤仅为 Stage 1A：更新 APT 索引、检查 hold/dpkg 状态并模拟 `dist-upgrade`；必须先审阅其计划，不得在同一批命令中自动执行真实升级、autoremove 或 reboot。

### 延期事项变化

- 无新增延期事项。破坏性 rollback/purge、benchmark、probe、TcpQuality、HTB、性能 A/B/A、M17 虚假端口变更和 M18 故障注入仍不进入首次上线默认路径。

### 当前成熟度判断

该目标机已达到 rc.16 首次安装前的技术基线条件，Stage 0 结论为 `PASS_WITH_PENDING_OPERATOR_GATES`。当前还没有 installer、managed state、重启持久性、严格代理服务或真实业务证据；下一安全检查点是 APT 只读升级计划和人工恢复条件确认。

## 本轮记录：2026-09-01（新购 Debian 13 1C2G/500 Mbps 目标机验收规划）

### 已完成及证据

- 已基于当前 `master`、rc.16 固定 Release 契约、自动缓冲矩阵和逐机生命周期矩阵，形成新购 Debian 13、1 vCPU、2 GiB、500 Mbps 目标机的分阶段验收路线；当前资源应由总控识别为 `debian13-1c2g`，500 Mbps 自动 buffer 预期为 32 MiB。
- 该主机为全新安装且尚无项目 managed state，因此 rc.15→rc.16 的旧版 verify/rollback/purge、迁移 checkpoint 和两次迁移 reboot gate 不适用。适用主路径为只读基线、固定 Release 安装器、未安装状态 verify、preflight、apply、立即与重启后 verify、重复 apply、严格 3X-UI/Xray 验证、第二次重启、VLESS + REALITY + TCP 冒烟及业务期间 diagnose。
- 已将默认目标机验收、可重装测试机的破坏性 rollback/purge 扩展，以及需要授权 endpoint 和流量预算的 benchmark/probe/TcpQuality/HTB 研究通道分开；未把 M17 虚假端口变更或 M18 故障注入列为未来生产机的默认验收动作。

### 未完成门禁

- 本轮未连接或修改该 VPS，尚未取得 OS/内核、实际内存、磁盘与根文件系统、IPv4/IPv6、policy rules、默认路由、qdisc、swap、BBR/fq 能力、failed units 或 boot ID 的目标机只读证据；也未执行系统升级、安装器、preflight、apply、reboot、代理安装、业务连接或主动流量测试。
- 进入写入阶段前仍须确认服务商控制台或救援入口、快照能力、真实 SSH 端口、维护窗口、月流量额度，以及该机是未来生产机还是可随时重装的专用验收机。任一复杂 qdisc、自定义 policy rule、多默认路由、非 `main` table、外部 sysctl/swap 所有权冲突或空间不足都必须停在只读评审。
- 一台 1C2G/500 Mbps Debian 13 主机只能补充与其配置相符的 rc.16 目标机证据，不能替代 Debian 12、512 MiB、1 GiB、2C2G、XFS 或其他端口档位的 T1–T10 项目矩阵。

### 延期事项变化

- 无新增延期事项。benchmark、`dvt probe`、TcpQuality、HTB 和性能 A/B/A 继续只在有获授权 endpoint、预先批准的硬流量预算和明确性能主张时进入；全面生产加固仍是独立范围。

### 当前成熟度判断

rc.16 的仓库与公开发布完整性结论不变。新目标机使首次 Debian 13 1C2G/500 Mbps 运行验收具备环境条件，但当前仅完成操作规划，尚未达到任何目标机运行证据层级；下一安全检查点是 Stage 0 只读基线，而不是直接 apply、rollback 或公网测速。

## 本轮记录：2026-08-31（rc.16 实现、CI 与 Pre-release 闭环）

### 已完成及证据

- rc.16 已在不改变 17 项受管 sysctl、BBR + 根 `fq`、资源感知缓冲、流量预算和非持久 HTB 边界的前提下完成两项实现：benchmark 每个 iperf3 方向使用独立进程组、硬超时及 TERM→KILL 回收；`diagnose` 和 benchmark 增加 IPv4/IPv6 policy rule 与按需非 `main` 路由表只读证据。迁移器同时收紧为只接受 rc.1–rc.15→rc.16，不接受由更高版本降级。
- 本地最终门禁通过：六份 profile 与单一模板一致；23 份 Shell 的 `bash -n`；controller、完整静态和 HTB fixture；17/17 `SHA256SUMS`；worktree/staged whitespace；当前版本、固定 URL、旧当前引用和 `_TBD` 防回退扫描；新增内容的私钥、常见 token/key、本机绝对路径、UUID 和 IPv4 地址扫描均无命中。Windows 本地没有绕过 root-only fixture。
- PR [#14](https://github.com/alieismy/debian-vps-tuning/pull/14) 已合并，merge commit 为 `5fa68877961efb7f04cb036edda5fdc43fa4820d`。中间 CI 先后暴露 GNU `timeout --kill-after` 返回 `137` 的真实语义和 fixture 未使用变量的 ShellCheck `SC2034`；实现保留 `124/137` 边界并做最小 fixture 修复。最终 push Run [33388026734](https://github.com/alieismy/debian-vps-tuning/actions/runs/33388026734) 与 pull_request Run [33388030020](https://github.com/alieismy/debian-vps-tuning/actions/runs/33388030020) 均通过，覆盖生成/静态检查、Linux root installer 与 rc.16 预算/迁移/进程组 fixture、ShellCheck 0.11.0。
- CodeRabbit 仅声明审查到 `44927ecd686a062e2132471c25dad0c76c9e9ffb`，未覆盖最后一个仅替换未使用 loop counter 的提交；PR 没有 review、行内意见或 review thread。本轮如实保留该覆盖限制，没有将 pending 状态描述为批准或替代 CI/人工审计。
- annotated tag `v0.1.0-rc.16` 的 tag object 为 `4a29bbf65959eafc5b9fb132c18ac4bd215e9c74`，远端 peeled target 与 merge commit 均为 `5fa68877961efb7f04cb036edda5fdc43fa4820d`。已发布非 Draft 的 [GitHub Pre-release](https://github.com/alieismy/debian-vps-tuning/releases/tag/v0.1.0-rc.16)，19 个资产均为 `uploaded`。
- 公开匿名反向下载通过：`PUBLIC_REDOWNLOAD=PASS`、`API_DIGEST_MATCHES=19`、`MANIFEST_ENTRIES=17`、`RELEASE_ASSETS=19`；19 项下载字节逐项匹配 GitHub API SHA-256，重建 HTB 子目录后 17/17 manifest 资产全部通过。`SHA256SUMS` SHA-256 为 `e2766b5e5851ae7ef064f21c2fd630663a8f3bcbb737c830f1272826b0b27cb2`，`install.sh` 为 `83d4f739918309b7585c0a0b6be7ac09252512dd7516d0dc6044b058cd17a15d`，总控为 `9ba31b2c5caa8c11e8e99fb339d8e5a82752d0c998f6284c2eed4d22f5c6631c`；唯一临时目录已安全清理。

### 未完成门禁

- 本轮未连接或修改任何真实 VPS，未执行公网 iperf3、TcpQuality、HTB、rollback、reboot、apply 或生产变更。发布闭环不证明目标机真实 timeout/signal 行为、进程回收、复杂策略路由拓扑、迁移两次重启、控制台恢复、严格 3X-UI/Xray 验证、代理业务链路或性能改善。
- 自定义 policy rule 目前只触发只读证据和警告；rc.16 仍不支持以非 `main` table、fwmark、VRF、多 WAN 或多默认路由拓扑执行 apply。真实目标机使用前仍须按其拓扑独立评审。

### 延期事项变化

- 无新增延期事项。永久 HTB、通用 UDP、MTU、RPS/RFS、MSS Clamp、`initcwnd/initrwnd`、第三方内核、网络安全专项、全面生产加固和新的高流量性能 campaign 继续保持既有延期或未授权状态。
- 下一阶段须由用户另行决定；本轮不自动把项目切换到稳定版、目标 VPS 迁移验收或新的调优实现阶段，也不移动或修改已发布的 rc.16 tag 与 Release 资产。

### 当前成熟度判断

rc.16 的实现、生成资产、固定摘要、本地 fixture、Linux root CI、PR、annotated tag、Pre-release 和公开资产反向验证已经闭合，满足本阶段完成定义。该结论只达到仓库与公开发布完整性层级；目标 VPS 生命周期、重启持久性、真实业务链路和性能仍明确未验证。

## 本轮记录：2026-08-31（外部网络调优与 tcpfit 对比评审）

### 已完成及证据

- 已只读全量枚举外部 `VPS/脚本` 目录中的 38 份 Markdown 或 Shell 文件（20 份 Markdown、18 份 Shell）：27 份网络调优材料进入详细对照，3 份综合材料只抽取网络章节，8 份部署、安全、路由封锁、重装或滥用事件材料在检查实际内容后排除。两份 tcpfit README 字节完全相同，SHA-256 均为 `3B45C43E27A1ABC6C46DD8635073BC5ED5176D2447B749397F19C8EFB0116C8F`，未将其误计为两个独立实现。
- 已深读 tcpfit `0.5.6` 主脚本（SHA-256 `7B9C778A0431D06425B76705C2C398D9D40085F1754FBADA0CB3C01AE55CB0E5`）及配套文档。其 `flock` 串行化、固定版本自安装、receiver goodput、疑似 policer 重复采样、重传比例、`mq` 识别和测试中断清理具有工程价值；但实际管理 32 项 sysctl，默认 RTT 仍为固定 150 ms，流量预算只是提示，qdisc 快照与 rollback 不能完整恢复原参数和层级，`initcwnd/initrwnd 32` 会改写路由属性，自动 policer 归因也不能排除公共服务端、路径、CPU/steal、共享带宽和虚拟交换机噪声。因此不支持整体移植、永久 HTB 或扩张当前参数面。
- 已对照 NetShape `5.3.0`（SHA-256 `F5A295D0A1E7F642214DB1D729856A772B6BED4C72646FA7C39729FB0C33EAA5`）、NetPilot（SHA-256 `0A3BC8708372373D931949E3EA3D9F7D9EE4D71079315B01EC2E4BD2301C868F`）、v5/v6、`Bak` 历史脚本、PanStar、VMISS/Lightlayer、初始化/开荒材料和只读采集脚本。relay/landing 双腿 RTT 模型只对未来多跳拓扑有条件意义；NetPilot 的不完整备份/回退、按总内存百分比定缓冲、通用 UDP/RPS/RFS/MSS Clamp、可变 `main` 下载和仅凭内核版本判断 BBRv3，及历史参数包的固定大缓冲、超大 backlog、覆盖 `/etc/sysctl.conf`、固定 MTU 等做法均不适合当前项目。
- 当前项目已经覆盖或强于第三方材料中的 receiver goodput、重复采样与中位数、短窗口重传、`mq` 叶子计数、接口字节辅助指标、完整 qdisc JSON 与恢复后语义比较、资源感知 BDP 缓冲、受限实验性 HTB，以及 rc.15 原子流量 reservation/ledger 和未知流量保守结算。新增价值仅保留为两个条件候选：为 benchmark/iperf3 增加显式超时与子进程/进程组回收；在未来支持多默认路由、策略路由、VRF 或多 WAN 时补充 `ip -4/-6 rule show` 和非 main table 诊断。两者均不要求修改网络参数。
- 已对全部 18 份 Shell 文件执行只读 `bash -n`，18/18 退出码为 0；该证据只证明 Bash 语法可解析，不证明参数安全、回滚完整、目标 VPS 可运行或性能有效。已直接核对 Linux 6.12 `ip-sysctl.rst`、BBR 源码、iproute2 `tc-fq(8)`/`ip-route(8)` 和 Google BBRv3 `v3` 分支说明，确认 `tcp_adv_win_scale` 已废弃、`tcp_tw_reuse=1` 非保守默认、`fq maxrate` 是单流上限、`initcwnd/initrwnd` 是目的路由属性，以及主线内核版本号不能证明 BBRv3。

### 未完成门禁

- 本轮未执行任何第三方脚本，未连接或修改真实 VPS，未执行公网测速、iperf3、TcpQuality、HTB、apply、rollback 或 reboot；静态源码评审不能证明第三方工具或当前 rc.15 在目标 VPS 上的生命周期、重启持久性、严格代理链路或性能改善。
- 未形成目标机配对 A/B、固定端点多轮交替测试、业务症状或 qdisc backlog/drop 证据，因此不批准从第三方材料引入新 sysctl、固定 MTU、定制 fq 深度、`initcwnd/initrwnd`、永久 HTB、RPS/RFS、UDP 或 MSS Clamp。

### 延期事项变化

- 无新增延期事项。benchmark 子进程显式超时/回收仅在出现可复现挂起、孤儿进程或发布可靠性要求时重新纳入；策略路由诊断仅在项目明确支持多默认路由、策略路由、VRF 或多 WAN 时重新纳入；NetShape 双腿 RTT 模型仅在支持中转/落地多跳拓扑时重新评审。上述条件不构成当前阶段需求或实施授权。

### 当前成熟度判断

rc.15 的发布完整性和阶段成熟度判断不变。本轮评审支持继续保持现有 17 项受管 sysctl、资源感知 BDP 缓冲、根 `fq` 默认路线和 fail-closed 预算/恢复控制，不支持因外部脚本数量更多或宣传为“实测推导”而扩张参数面。目标 VPS 生命周期、重启、严格代理链路和真实业务性能仍未验证，本轮只读对比不提升这些证据层级。

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
