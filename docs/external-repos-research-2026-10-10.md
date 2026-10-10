# 四个外部 VPS 调优仓库研究与吸收评估

日期：2026-10-10（Asia/Singapore）

状态：研究证据包与决策输入；未批准实现。只读检查固定提交的源码、文档、Issue 和 fork；没有运行第三方脚本或测试，没有连接 VPS，也没有产生公网测速流量。

研究模式：`rd-research` 技术与开源研究。前序研究为 [2026-09-10 三项目研究](external-network-tuning-research-2026-09-10.md)（其中 vps-netpilot 固定在 `705a307`）、[tcpfit v0.5.8 研究](tcpfit-v0.5.8-research-2026-09-11.md)、[2026-09-28 可行性评估](tcpfit-policer-refactor-feasibility-2026-09-28.md)和 [tcpfit v0.5.9 研究](tcpfit-v0.5.9-research-2026-10-05.md)。本报告只记录增量证据和当前判断，不重复前序结论。

## 1. 结论

**结论：当前运行实现不需要修改，没有可以直接移植的代码。置信度高。** 四个仓库中，只有 tcpfit 生态（上游 Issue、未合并分支和两个有实质改动的 fork）提供了新的设计输入。vps-netpilot 的新提交与本项目已有控制同向。CG-spring 的两个仓库是纯文档指南，按一手资料核对存在多处可证伪的错误，没有可吸收内容。

| 编号 | 内容 | 性质 | 置信度 |
|---|---|---|---|
| B1 | 由客户端主动接入、测量 VPS 到用户下载方向的业务路径测量，来源是 fork `tcpfit-x` | 为既有“业务收益验证”条件分支补充设计输入，不新增延期项 | 设计可行性：中；收益：未知 |
| C1 | conntrack 压力只读诊断信号 | 新增低优先级条件候选 | 中 |
| N1 | 高速率多流聚合对照 | 既有候选，新增一份用户现场报告作为佐证 | 中 |

其余各项均为已覆盖、不适用或拒绝，见第 3–5 节。

最强反对意见：tcpfit-x 的“优化线路调优”测量 VPS 到家宽客户端的下载方向。这正是用户真实的业务方向：Windows 11 客户端经 VPS 上网。本项目目前只测 VPS 到公共或自有数据中心端点的出向路径，不吸收就意味着业务路径一直没有证据。

回应：这个方向是对的，但目前不应启动实现，理由有三：

1. 该 fork 自己的验证记录写明，没有执行家宽接入与实际测速全流程。
2. 它没有流量预算，试调不设轮数和总时长上限，也不检查内存；接入脚本经第三方镜像下载，没有摘要校验；控制通道是明文 HTTP。
3. 用户已说明业务当前没有丢包或卡顿，既有条件分支的触发条件（出现可复现的业务症状）没有满足。

因此只把它的接入与采样设计登记为 B1 的输入。如果用户决定在没有症状时也建立业务路径基线，B1 是首选起点。

## 2. 研究问题、基线与方法

研究问题：

1. 四个仓库当前实际提供什么能力？相对前序研究有哪些新变化？
2. 每项能力在本项目当前实现中是否已经覆盖、是否适用、能否带来新增价值？
3. 哪些内容只能作为条件候选？进入实施需要什么证据？

| 对象 | 固定证据（2026-10-10 读取） | 许可证 | 能证明的范围 |
|---|---|---|---|
| `Kylin010/tcpfit` | `main` 与 `v0.5.9` 均为 `38fbf5a`，之后没有新提交；另有未合并分支 `claude/hello-00y04u`（`aac5300`，基于 v0.5.7）；Issue 与 PR 共 10 个；fork 92 个 | MIT | 源码与 Issue 原文。Issue 中的数字是用户报告 |
| `P0me1oo/tcpfit-x`（tcpfit 的 fork） | `main` 为 `259cab6`（自称 v0.22.2，2026-09-16），领先上游 18 个提交、落后 2 个 | MIT | README、源码和维护者自述的验证记录。未运行其测试 |
| `Sung-Kim0430/tcpfit`（tcpfit 的 fork） | 领先上游 1 个提交 `3ec690a`（自称 v0.5.10，2026-10-04） | MIT（继承上游） | 提交说明与改动范围 |
| `sanmussh/vps-netpilot` | `main` 为 `7b7bea9`（2026-09-26）。相对前序研究的 `705a307`，只改了 `tcp.sh`（`+77/−35`） | MIT | 源码 |
| `CG-spring/vps-network-tuning` | `master` 为 `a2b990f`；只有中英文 README 和 3 行 LICENSE | LICENSE 只有标题和年份，没有授权条款；GitHub 识别为 NOASSERTION | 文档声明 |
| `CG-spring/vps-optimization-guide` | `master` 为 `6e1eda7`；只有中英文 README 和 1 行 LICENSE | 同上 | 文档声明 |
| 本项目 | HEAD `68dbb0a`。运行代码相对 `1c5e922` 没有变化：`git diff` 中的非文档改动只有 `.claude/settings.json` 和 LICENSE 署名 | MIT | 当前源码对照 |

方法：

- 把各仓库克隆到会话临时目录，不进入本仓库；用 `git diff` 取得增量。
- 读取 tcpfit 的全部 Issue 和评论。
- fork 只比较 92 个中最近推送的 12 个。其中 2 个有实质领先提交，其余领先 0 个提交。
- 影响判断的外部事实用一手来源核对：Linux 内核源码与文档、systemd 源码与 NEWS、Debian 13 发布说明与 Debian 包内容、procps-ng 源码。
- 检索关键词用英文，例如 `tcpfit Kylin010 TCP tuning policer knee VPS`、`tcp_max_tw_buckets "must not lower the limit artificially"`、`systemd 240 fs.nr_open fs.file-max bumped`。

证据边界：

- NodeSeek 上关于 tcpfit 的帖子（包括一位用户补充的 9 台机器数据）用 WebFetch 读取时返回 403。本轮只看到搜索摘要，不把它作为结论依据。
- 没有运行任何第三方脚本或测试。fork 自述的测试数字（例如 tcpfit-x 0.22.2 的“247 项、226 项通过”）是维护者声明。

## 3. tcpfit（重点）

### 3.1 上游、Issue 与未合并分支的新证据

| # | 证据 | 本项目对应实现 | 判断 |
|---|---|---|---|
| T1 | 上游在 v0.5.9 之后没有新提交，Release 仍为 v0.5.9 | — | 2026-10-05 的结论不变 |
| T2 | [Issue #10][I10]（2026-09-28，维护者未回复）：标称 2.5G 的主机，不限速时单流估算丢包 1.17%、8 流 0.37%。工具据此判定 “Policer present”，但在 6140–8231 Mbit 范围内没有找到拐点；各档 goodput 在 5336–7029 Mbps 之间非单调波动。用户想手动填写整形值 | 测量固定为单流。没有观察到上升时只报告 `NO_RISE_IN_TESTED_RANGE`，`policer_identified=false`，不给整形建议（[v0.5.9 研究 §3](tcpfit-v0.5.9-research-2026-10-05.md#3-变化与本项目逐项对照)第 3、4 行） | **为 N1 提供现场佐证。** 单流丢包高、多流丢包低时，单流结论不能定位聚合限速器。“不限速时有丢包就说明有限速器”的推断，在这一例中没有得到扫描结果支持。这是用户报告，未复现 |
| T3 | [Issue #8][I8]：希望支持 `tcp_fastopen=1027`，即包含 0x400 位 | 本项目设为 3，[操作指南](usage.md#tcp-fast-open-与-xray-的边界)区分全局位图与 listener 选项 | 不采纳。按[内核文档][K2]，0x400 让所有 listener 不经 `TCP_FASTOPEN` 选项就支持 TFO，会改变主机上所有服务的行为；Xray 可以按 socket 自行开启 |
| T4 | [Issue #7][I7]（v0.5.7 已修复）：开机持久化脚本在单队列网卡上误走 mq 分支，导致每次开机整形静默丢失；交互路径本身正确 | 七组平台生命周期都包含两次真实重启，并比对 17 项 sysctl 和 qdisc（[平台支持](platform-support.md)） | 已覆盖。“开机路径与交互路径分叉”这类问题，在本项目已有运行证据约束 |
| T5 | [Issue #4][I4]（v0.5.7 已修复）：中国大陆主机到 18 个公共节点都超过 100 ms，导致选点失败；修复方式是放宽距离限制 | 自动选点按有限 RTT 排序，并在预算内做协议尝试（[自动测量](automatic-measurement.md)） | 已覆盖，与 2026-09-28 评估中对“近处”的定义一致 |
| T6 | 未合并提交 [`5bbc0b8`][B1c] 改了三处：内核没有 sch_fq 时，probe 不再提示“检查对端是否可达”，而是说明这是本机限制；probe 降级为不带 pacing 的测量，sweep 仍然硬失败；没有 `ethtool` 时从 sysfs 读取驱动名。v0.5.9 的 `main` 仍保持旧行为（[`tcpfit.sh` L2570–L2573、L2609][T5]） | 内核没有 sch_fq 时，preflight 以 `EXIT_UNSUPPORTED` 报告本机原因（[V3][V3]）；测量入口只接受可以完整恢复的单根 fq；`ethtool` 只用于可选计数 | 已覆盖。“扫描必须有 pacing，不降级”与本项目一致 |
| T7 | 未合并提交 [`aac5300`][B2c]：CI 检查 `bash -n`、shellcheck 和 SHA256SUMS 是否同步 | 已有 `shell-static-checks` CI 和摘要清单校验 | 已覆盖 |

### 3.2 fork `tcpfit-x`：优化线路调优

**它做什么**（README 与源码事实）：

- 调优端是 VPS。测速端是家宽 Linux、OpenWrt 或 Windows 主机，主动连接 VPS（[X1][X1]）。
- iperf3 始终由家宽一侧以 `-R` 运行，由服务器发送数据（[X3][X3]）。
- 先在客户端采集 TCP 握手时延，用它推导 BDP。随后从 1.5×BDP 开始，以单流测速试调收发缓冲区，最高到 2.5×BDP。
- 最终在估算重传比中位数不超过 1% 的候选中，选择接收速度中位数最高的一项；没有合格候选时默认选择“0：不修改”（[X3][X3]）。

**可以借鉴、只作为 B1 设计输入的部分：**

- **测量方向。** 服务器发送、客户端接收，与代理业务的下载方向一致。
- **接入模型。** 客户端只做出站连接，家宽不需要公网 IP 或端口映射。Windows 端使用系统自带的 PowerShell 5.1/7 和 iperf3.exe，不修改 Windows 网络参数（[X1][X1]）。
- **会话控制。**
  - 一次性 32 字符 token，默认 600 秒有效；配对后即撤销，并绑定来源 IP。
  - 临时 iperf3 端口只放行已配对的来源。
  - 心跳超时 45 秒后清理；清理失败时保留恢复记录，不报告成功（[X2][X2]）。
- **RTT 采样。** 每组取 5 个 TCP 握手样本求均值，再取各组中位数，不依赖 ICMP（[X3][X3]、[X5][X5]）。

**不能采用的部分：**

- **没有流量预算。** README 和 `tcpfit-return.py` 都没有流量上限。试调“不设轮数、连续无收益次数或总时长限制”（[X3][X3] 第 7 条）。按用户的 200 Mbps 计算，一次 10 秒满速单流约 250 MB（算术估计）；默认每个候选测 2 次，而候选轮数没有上限。这与本项目逐次预留的流量账本冲突。
- **不检查内存。** README 写明，优化线路试调不检查可用内存、系统预留或缓冲区增量预算（[X4][X4]）。这与本项目的资源档封顶冲突。
- **供应链与传输。**
  - 客户端脚本按 GitHub tag 下载，默认经第三方镜像 `github.chenc.dev`，下载后直接执行。
  - Windows 端以 `-ExecutionPolicy Bypass` 运行，没有摘要校验。
  - 配对、控制和结果回报都走明文 HTTP，token 写在命令行里（[X2][X2]、[X5][X5]）。
  - 服务端监听 `0.0.0.0` 或 `::`（[X6][X6]）。
- **判据。** 每个候选只测 2 次、每次 10 秒，再按中位数挑最快的一项，候选之间的差异可能落在噪声内。本项目的[候选可信度研究](two-host-measurement-acceptance-2026-09-30.md#候选可信度的离线评估)已经说明这类低样本比较的局限。原本存在整形时，它还会自动把提高后的整形值持久化。
- **验证缺口。** 其 TESTING.md 的各版本记录都写着“未执行实际线路测速”或“未执行家宽接入与实际测速全流程”（[X7][X7]）。
- **业务代表性**（推断）。iperf3 明文 TCP 跑在 12224 端口，而 VLESS + REALITY 业务跑在 443，两者可能被路径上的设备区别对待。直连 iperf3 结果不能替代业务验收，见既有[重传归因矩阵](external-network-tuning-research-2026-09-10.md#重传归因矩阵)。

**交叉印证：** tcpfit-x 独立发现，新内核 fq 的 `bands`、`priomap`、`weights` 需要完整保存，而且 iproute2 6.15 解析 `weights` 时会多推进一个参数。本项目的 HTB 事务已经按同样的方式处理这两点（[V7][V7]）。

### 3.3 fork `Sung-Kim0430/tcpfit`：RTT 输入

[`3ec690a`][F2] 在向导中增加 RTT 一问。可选项包括：按地区预设（50/150/180/250 ms）、手填、回车使用默认 150 ms，或者自动 ping 三家国内运营商的单播 DNS 并取最差值。提交说明称，旧版自动 ping anycast DNS 时，香港机器测得 2 ms，而真实值超过 140 ms。这是 fork 作者的声明。

本项目使用显式的 `BUFFER_TARGET_RTT_MS`，范围 20–500，默认 200，没有自动探测（[操作指南](usage.md#参数)），因此不受 anycast 误测影响。按用户的 200 Mbps 计算，BDP 为 25,000 字节/ms × RTT。512M、1G、2G 三档的系数分别为 1、1.25、1.5，结果超过 16 MiB 时对应的 RTT 分别为 671、537、447 ms。所以 RTT 在 20–447 ms 之间时，三档结果都是 16 MiB，改用地区预设不会改变用户主机的配置。**无需修改。**

### 3.4 tcpfit 价值点现状总账

| 类别 | 内容 | 当前状态与依据 |
|---|---|---|
| 已吸收 | 公共端点自动选点、分阶段出向测量、可恢复的临时 HTB 扫描 | `0.2.0-rc.1` 实现（[发布说明](releases/v0.2.0-rc.1.md)） |
| 已吸收 | 先把 mq `0:` 根句柄规范化，再寻址叶子 | rc.18（[v0.5.8 研究补充](tcpfit-v0.5.8-research-2026-09-11.md#2026-09-14-补充更正mq-0-句柄寻址)） |
| 同向且更严格 | receiver goodput、重传/GiB、不可判定终态、逐次流量预留 | [实测校准说明](measured-calibration.md)、[v0.5.9 研究](tcpfit-v0.5.9-research-2026-10-05.md) |
| 条件候选 | N1（多流对照）、N2（networkd 事件后 fq 是否保持）、U1（PPP）、U2（持久 HTB 约束）、B1（业务路径测量） | 未启动；进入条件见 [v0.5.9 研究 §4](tcpfit-v0.5.9-research-2026-10-05.md#4-候选的进入条件与最小验证)和本报告第 6 节 |
| 拒绝 | 32 项 sysctl；initcwnd 持久化；自动持久整形；从可变 `main` 安装与默认遥测；`fleet.py`；把重传估算比当作 policer 定论；tcpfit-x 的闭环缓冲试调 | 维持前序研究和本报告的结论 |

## 4. vps-netpilot 增量（[`705a307` → `7b7bea9`][P1]）

**变化：**

1. 删除“内核 ≥ 6.12 即为 BBRv3”的推断，改为说明 BBR 实现由系统内核提供。前序研究对这一推断的批评，已不适用于当前 `main`。
2. 新增 `ensure_bbr_fq`（[P2][P2]）。流程是：加载模块；以 `tcp_available_congestion_control` 为准判断是否支持 BBR；写入 `/etc/sysctl.d/10-bbr.conf`；执行 `sysctl --system` 后核对两项。菜单状态分为“已激活”“部分启用”“未开启”三种。
3. 新增调优前置门禁（[P3][P3]）：BBR + FQ 没有生效时，不执行通用或中转调优。BBR 两项从 `99-network-performance.conf` 中移出，只保留在 `10-bbr.conf`。

**对照本项目：**

- preflight 检查 BBR 与 sch_fq 是否可用。
- verify 比对 17 项运行值，并核对每个默认路由接口实际的根 qdisc（[V9][V9]）。`net.core.default_qdisc` 只作用于新建的 qdisc，所以只看它是不够的；本项目的检查更强。
- **已覆盖。**

**新发现的问题（推断，置信度中高）：** 在安装了 `linux-sysctl-defaults` 的 Debian 13 上，这个提交会让 BBR + FQ 门禁失败。依据如下：

- 按 [Debian 13 发布说明][D1] §5.1.15，`linux-sysctl-defaults` 是 systemd 的推荐依赖，默认会安装，并提供 `/usr/lib/sysctl.d/50-default.conf`。该文件（源码包 linux-base 4.12.1）第 48 行为 `-net.core.default_qdisc = fq_codel`（[D2][D2]）。
- systemd-sysctl（[S4][S4]）和 procps-ng 4.0.4 的 `sysctl --system`（[D3][D3]）都会跨目录按文件名排序，排在后面的文件覆盖前面的设置。
- `10-bbr.conf` 排在 `50-default.conf` 之前，所以最终 `default_qdisc` 是 `fq_codel`，`ensure_bbr_fq` 返回 2，菜单选项 3 和 4 拒绝执行。旧版本的选项 3 和 4 把这两项也写进了 `99-…`，因此不会被覆盖；单独的选项 2 在旧版本中同样只写 `10-bbr.conf`。
- 本轮没有在 Debian 13 实机验证。不安装推荐包的镜像不受影响。

本项目使用 `/etc/sysctl.d/90-proxy-vps.conf`（[V8][V8]），排在 `50-default.conf` 之后；Debian 13 平台生命周期在两次重启后比对 17 项 sysctl，结果通过。无需修改。

**共存：** 如果用户先后运行 NetPilot 和本项目，本项目的 preflight 与 verify 会把 `/etc/sysctl.d` 中重复定义的受管键判为冲突，并拒绝继续（[V1][V1]、[V2][V2]）。已覆盖。

**维持前序拒绝的内容：**

- 从可变的 `main` 自更新，没有摘要校验（[P4][P4]）；
- 回退只恢复四个值；
- UDP、conntrack、RPS、MSS 等参数超出本项目范围。

## 5. CG-spring 的两个文档仓库

**性质：**

- 两个仓库都只有 README，没有脚本。`vps-network-tuning` 的一键命令指向不存在的 `main/install-bbr.sh`，在 `main` 和 `master` 分支下都返回 404（[G1][G1] L104）。
- 账户创建于 2026-03-31，有 164 个公开仓库；README 末尾的资源区链接到 VPS 推荐和 Clash 订阅站点。
- 以上是可核对的事实；“这是以导流为主的内容仓库”是推断。

**经一手资料核对的错误**（只列影响判断的项）：

| 主张（位置） | 核对结果 | 来源 |
|---|---|---|
| `net.ipv4.tcp_bbr_budget`、`tcp_bbr_cwnd_gain`、`tcp_bbr_probe_rtt_cap` 等 BBR 参数（[G2][G2] “BBR Fine-Tuning”；中文 README L176–L179） | 主线 `tcp_bbr.c` 没有 sysctl，也没有 `module_param`，增益是编译期常量，例如 `bbr_cwnd_gain = BBR_UNIT * 2`。写入这些键后，`sysctl -p` 会对不存在的键报错 | [K1][K1] |
| `vm.nr_hugepages = 128`，并标注为“禁用透明大页”（[G2][G2] L128–L129） | 该项设置的是持久大页池，不是透明大页（THP）。池中页面不能挪作他用，也不能换出。按常见的 2 MiB 大页计为 256 MiB，在 512M 档主机上占去一半内存 | [K3][K3] L89–L91 |
| `tcp_max_tw_buckets = 5000`，并称其为 DDoS 防护（[G1][G1] L424；[G2][G2] L95） | 内核文档明确说明：该限制只用于防范简单 DoS，不得人为调低 | [K2][K2] |
| `fs.file-max = 65535`、`fs.nr_open = 65535`（[G2][G2] L116–L117） | systemd 从 v240 起在开机时把这两项调到最大；Debian 打包规则（salsa `debian/master`）没有关闭这个默认开启的构建选项，所以写入 65535 实际是下调。RLIMIT_NOFILE 的硬限制大于 `nr_open` 时，内核返回 EPERM。65535 低于本项目为 x-ui 设置的 `LimitNOFILE=65536`（[V5][V5]），也低于 systemd 默认的硬限制 524288。服务启动层面的实际后果没有做运行验证 | [S1][S1]、[S2][S2]、[S3][S3]、[K4][K4] |
| 写入 `/etc/sysctl.conf` 后执行 `sysctl -p`（两个仓库） | Debian 13 的 systemd-sysctl 不再读取 `/etc/sysctl.conf`，重启后设置失效；`sysctl -p` 只在当次生效 | [D1][D1] §5.1.15 |
| 在 Debian 上用 `.rpm` 加 `alien` 安装 BBR Plus；“Debian 10/11 升级内核”一节使用 elrepo 和 `yum`（[G1][G1] L177–L256） | 引用的 Release 资产返回 404；elrepo 和 yum 是 RHEL 系工具 | 本轮 HTTP 检查 |
| 把 9929 线路标识为 `172.16.x.x`、10099 标识为 `100.64.x.x`（[G1][G1] L479–L480） | 前者属于 RFC 1918 私有地址，后者属于 RFC 6598 共享地址空间，都不能用来标识运营商线路 | RFC 1918、RFC 6598 |

**结论：没有可吸收的内容。**

- 两份指南提出“路由差时，TCP 调优的改善有限”，这与本项目“不修改路由”的边界一致（[操作指南](usage.md#脚本不会修改什么)），不需要新增文档。
- 排查路径问题需要哪些证据，既有[重传归因矩阵](external-network-tuning-research-2026-09-10.md#重传归因矩阵)已经列出。
- conntrack 话题转为 C1：只做只读诊断，不调整上限。

## 6. 候选与进入条件

### B1：业务路径测量（补充既有业务收益验证分支）

- **价值。** 本项目现有的测量只覆盖 VPS 到数据中心端点的出向路径，而用户的业务方向是 VPS 到家宽客户端的下载。由客户端主动接入，可以在家宽不开放入站端口的前提下，取得这一方向的吞吐、重传和握手 RTT。
- **进入条件。** 沿用[既有条件分支](two-host-measurement-acceptance-2026-09-30.md#条件分支与剩余工作)：出现可复现的业务症状；或者用户明确决定，即使没有症状也要建立业务路径基线。
- **必须保留的约束：**
  - 逐次预留的流量账本和总量上限。用户此前给出的 10 GB 测试上限，口径尚待确认。
  - 使用固定版本资产并校验摘要；不经第三方镜像，不用 `ExecutionPolicy Bypass` 执行未校验的脚本。
  - 控制通道需要认证，暴露面最小：端口只对已配对来源开放、有时限，清理结果可以核验。
  - 只测量，不自动试调，也不持久化任何配置。
  - 结果标注为“iperf3 路径证据”，不等于 VLESS + REALITY 业务验收。
- **最小验证。** 先在本地隔离环境中验证接入、计量和清理。真实家宽测试需要单独授权预算，并且只测一个固定方向、一个固定时段。
- **当前决定。** 2026-10-10 用户决定暂不建立业务路径基线，B1 保持条件状态，见[项目备忘](project-memo.md#本轮记录2026-10-10四个外部调优仓库研究)。

### C1：conntrack 压力只读信号

- **现状。** `diagnose` 采集 softnet、TCP 计数、CPU、链路和 qdisc 计数，不包括 conntrack（[V6][V6]）。本项目不修改 conntrack 上限（[操作指南](usage.md#脚本不会修改什么)）。
- **价值：**
  - UFW 启用后，内核会加载 nf_conntrack。默认上限等于哈希桶数，按内存 ÷ 16384 计算，下限 1024、上限 262144（[K5][K5]）。
  - 表满时，内核按速率限制打印 `nf_conntrack: table full, dropping packet`，并在 `/proc/net/stat/nf_conntrack` 中累计 `drop`、`early_drop` 和 `insert_failed`（[K6][K6]）。
  - 三个外部仓库都把调高上限当作代理优化手段，但调高之前应先有证据证明表确实满了。
- **进入条件（满足任一项）：**
  - 用户报告新连接失败或间歇断连；
  - 多用户代理进入目标范围；
  - vps-hardening 的 UFW 方案落地后，需要联合诊断。
- **约束：**
  - 只读；
  - 模块未加载时报告“未启用”，不能报告为 0；
  - 只输出计数和比例，不输出含对端地址的连接条目。
- **最小验证。** 用合成 `/proc` fixture 覆盖三种情况：模块未加载、正常、`drop` 增量。

### N1：补充现场证据

把 T2 补入 N1 的进入条件：如果真实报告中出现“单流丢包高、多流丢包低”，应按 N1 处理，不能解读为存在 policer。其他条件和约束不变，见 [v0.5.9 研究 §4](tcpfit-v0.5.9-research-2026-10-05.md#n1高速率多流聚合对照)。

## 7. 重新评估条件与剩余缺口

出现以下任一情况时，应重新判断：

- tcpfit 上游合并 `claude/hello-00y04u`，或者发布涉及 fq/mq 恢复、预算上界、证据完整性的新版本；
- tcpfit-x 公布真实家宽路径的测试结果，或者补上流量预算和资产校验；
- 用户报告业务症状，或者决定建立业务路径基线（B1）；
- 出现连接失败类症状（C1）。

未验证的内容：

- tcpfit Issue 中的现场数字；
- tcpfit-x 与 Sung-Kim0430 fork 自述的测试和实测结果；
- NetPilot 在 Debian 13 上门禁失败（目前是基于源码和包内容的推断）；
- `fs.nr_open = 65535` 对 systemd 服务启动的实际后果；
- NodeSeek 帖子的内容（读取返回 403）。

fork 只检查了 92 个中最近推送的 12 个。本轮证据最高到源码实现、一手文档和包内容层级。

## 8. 已检查来源

外部源码链接固定到对应提交。内核与 systemd 的源码和文档读取的是 2026-10-10 的主线版本。

[I4]: https://github.com/Kylin010/tcpfit/issues/4
[I7]: https://github.com/Kylin010/tcpfit/issues/7
[I8]: https://github.com/Kylin010/tcpfit/issues/8
[I10]: https://github.com/Kylin010/tcpfit/issues/10
[T5]: https://github.com/Kylin010/tcpfit/blob/38fbf5af30daf87735f2ffbc5e0905033ee2b86e/tcpfit.sh#L2570-L2609
[B1c]: https://github.com/Kylin010/tcpfit/commit/5bbc0b87df1db217901255bb59dec2addcbd3d98
[B2c]: https://github.com/Kylin010/tcpfit/commit/aac53005c8e8786851ab3e39ca4367091cc48c66
[X1]: https://github.com/P0me1oo/tcpfit-x/blob/259cab6dde12eaf846c27ded3e4fadcbbdc7b680/README.md#L150-L172
[X2]: https://github.com/P0me1oo/tcpfit-x/blob/259cab6dde12eaf846c27ded3e4fadcbbdc7b680/README.md#L207-L217
[X3]: https://github.com/P0me1oo/tcpfit-x/blob/259cab6dde12eaf846c27ded3e4fadcbbdc7b680/README.md#L221-L236
[X4]: https://github.com/P0me1oo/tcpfit-x/blob/259cab6dde12eaf846c27ded3e4fadcbbdc7b680/README.md#L262
[X5]: https://github.com/P0me1oo/tcpfit-x/blob/259cab6dde12eaf846c27ded3e4fadcbbdc7b680/tcpfit-client.ps1#L204-L284
[X6]: https://github.com/P0me1oo/tcpfit-x/blob/259cab6dde12eaf846c27ded3e4fadcbbdc7b680/tcpfit-return.py#L78-L84
[X7]: https://github.com/P0me1oo/tcpfit-x/blob/259cab6dde12eaf846c27ded3e4fadcbbdc7b680/TESTING.md#L3-L12
[F2]: https://github.com/Sung-Kim0430/tcpfit/commit/3ec690a9146a44c1827611b5014d9d350023d680
[P1]: https://github.com/sanmussh/vps-netpilot/compare/705a307684b7b0cb57747bf2e5abb4ed6ada6cdd...7b7bea91768d0a8f65d28f8e0b1b66865a9f91cf
[P2]: https://github.com/sanmussh/vps-netpilot/blob/7b7bea91768d0a8f65d28f8e0b1b66865a9f91cf/tcp.sh#L146-L172
[P3]: https://github.com/sanmussh/vps-netpilot/blob/7b7bea91768d0a8f65d28f8e0b1b66865a9f91cf/tcp.sh#L270-L301
[P4]: https://github.com/sanmussh/vps-netpilot/blob/7b7bea91768d0a8f65d28f8e0b1b66865a9f91cf/tcp.sh#L35-L69
[G1]: https://github.com/CG-spring/vps-network-tuning/blob/a2b990f439a4f0652264a63d53179d1d338a2198/README.md
[G2]: https://github.com/CG-spring/vps-optimization-guide/blob/6e1eda779f292a1c223819e88208be9e67fd34b2/README_EN.md
[K1]: https://github.com/torvalds/linux/blob/master/net/ipv4/tcp_bbr.c
[K2]: https://docs.kernel.org/networking/ip-sysctl.html
[K3]: https://github.com/torvalds/linux/blob/master/Documentation/admin-guide/mm/hugetlbpage.rst
[K4]: https://github.com/torvalds/linux/blob/master/kernel/sys.c
[K5]: https://docs.kernel.org/networking/nf_conntrack-sysctl.html
[K6]: https://github.com/torvalds/linux/blob/master/net/netfilter/nf_conntrack_standalone.c
[S1]: https://github.com/systemd/systemd/blob/main/NEWS
[S2]: https://github.com/systemd/systemd/blob/main/src/core/main.c
[S3]: https://github.com/systemd/systemd/blob/main/meson_options.txt
[S4]: https://github.com/systemd/systemd/blob/main/man/standard-conf.xml
[D1]: https://www.debian.org/releases/trixie/release-notes/issues.en.html
[D2]: https://sources.debian.org/src/linux-base/4.12.1/sysctl.d/50-default.conf/#L48
[D3]: https://gitlab.com/procps-ng/procps/-/blob/v4.0.4/src/sysctl.c#L801-L873
[V1]: https://github.com/alieismy/vps-tuning/blob/68dbb0a69b0277861b1cf51f932c1c5403cb5945/tools/profile-template.sh.in#L509-L554
[V2]: https://github.com/alieismy/vps-tuning/blob/68dbb0a69b0277861b1cf51f932c1c5403cb5945/tools/profile-template.sh.in#L1607-L1612
[V3]: https://github.com/alieismy/vps-tuning/blob/68dbb0a69b0277861b1cf51f932c1c5403cb5945/tools/profile-template.sh.in#L634-L635
[V5]: https://github.com/alieismy/vps-tuning/blob/68dbb0a69b0277861b1cf51f932c1c5403cb5945/tools/profile-template.sh.in#L83
[V6]: https://github.com/alieismy/vps-tuning/blob/68dbb0a69b0277861b1cf51f932c1c5403cb5945/tools/profile-template.sh.in#L2766-L2790
[V7]: https://github.com/alieismy/vps-tuning/blob/68dbb0a69b0277861b1cf51f932c1c5403cb5945/dvt_htb_transaction.py#L126-L187
[V8]: https://github.com/alieismy/vps-tuning/blob/68dbb0a69b0277861b1cf51f932c1c5403cb5945/tools/profile-template.sh.in#L75
[V9]: https://github.com/alieismy/vps-tuning/blob/68dbb0a69b0277861b1cf51f932c1c5403cb5945/tools/profile-template.sh.in#L1544-L1569

- tcpfit 生态：Issue [#4][I4]、[#7][I7]、[#8][I8]、[#10][I10]；上游源码 [T5][T5]；未合并提交 [`5bbc0b8`][B1c]、[`aac5300`][B2c]；fork 锚点 X1–X7 与 [`3ec690a`][F2]。另读取文件的 SHA-256：tcpfit-x `tcpfit-return.py` 为 `82900f0a3ff41453045a114c1321e9946fa9105f5dd106b60b0bdbeaf22ecf22`，`tcpfit-client.ps1` 为 `411a121f061fec8e014145a19e904b15e2756cc26d732968705898dc854c23e7`。
- vps-netpilot：[增量对比][P1]，锚点 P2–P4；`tcp.sh` 的 SHA-256 为 `fcaa31eb5eb760984716a156c453353e62aad9e3d92ede5116181da1ccc84d5f`。
- CG-spring：[G1][G1]、[G2][G2]。
- 一手技术资料：
  - [`tcp_bbr.c`][K1]：无 `module_param`，增益为常量；
  - [ip-sysctl][K2]：`tcp_max_tw_buckets` 与 `tcp_fastopen` 0x400；
  - [hugetlbpage.rst][K3]；
  - [`kernel/sys.c`][K4] 中的 `do_prlimit`；
  - [nf_conntrack sysctl 文档][K5]；
  - [`nf_conntrack_standalone.c`][K6] 中的统计列；
  - systemd [NEWS][S1] “CHANGES WITH 240”、[`main.c`][S2] 中的 `bump_file_max_and_nr_open`、[`meson_options.txt`][S3]、[`standard-conf.xml`][S4]；
  - [Debian 13 发布说明][D1]；
  - [linux-base 50-default.conf][D2]；
  - [procps-ng 4.0.4 `sysctl.c`][D3]。
- 本项目：锚点 V1–V3、V5–V9，固定到 `68dbb0a`。
