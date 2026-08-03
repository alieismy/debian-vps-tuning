# Changelog

本项目采用 [Semantic Versioning](https://semver.org/)。

## [0.1.0-rc.9] - Unreleased

### Added

- 新增 `debian-vps-tuning.sh` 总控入口，自动识别 Debian 12/13、amd64 和 1C512MB、1C1GB、1C2GB、2C2GB 四个资源档；
- 新增交互安全引导，带宽默认 200 Mbps，支持 100–1000 Mbps；先执行 preflight，确认后才 apply；
- 新增显式 `guided/preflight/apply/verify/status/diagnose/rollback/recover` 调用模式；`diagnose` 只读采集网络与 softnet 状态；
- 新增本地及固定 GitHub Release 资源解析、严格 HTTPS 下载和目标 profile SHA-256 校验；
- 新增 Debian 12/13 的 512 MiB profile、控制器映射、资源缓冲上限、常规 `pfifo_fast`、NOFILE 待安装状态、清单、失败下载和退出码透传测试；
- 预置受状态哈希保护且可回滚的 `x-ui.service` drop-in，设置 `LimitNOFILE=65536`。

### Changed

- 六份资源脚本内部版本同步为 `0.1.0-rc.9`；状态 schema 保持 3；
- 两个兼容名称为 `1c2g` 的 2G 档位正式支持 1–2 vCPU；总控和底层 profile 均校验 CPU/RAM 组合，不新增重复 2C2G 脚本；
- socket 上限按 512M/1G/2G 资源分别限制为 16/32/64 MiB；journald 和磁盘保留量按资源档收敛，swap 默认仍为 1 GiB；
- 2C2G 沿用 2G 网络、swap 和 journald 参数，不启用 RPS/RFS/XPS、IRQ affinity 或 CPU affinity；
- README 将总控入口作为普通用户首选，独立 profile 作为离线、审计和恢复入口；
- Release 必须上传总控脚本、六份 profile 和 `SHA256SUMS`，控制器不回退到 `master`、`main`、`latest`、HTTP 或第三方源。

### Validation

- `bash -n`、四资源档控制器/底层 fixture、六份模板生成一致性及状态/qdisc 故障注入测试已通过；
- ShellCheck v0.11.0 已覆盖总控脚本、六份 profile 和测试脚本；
- 固定 rc.9 Release 远程下载仍需在 Release assets 发布后验证；目标 VPS 的控制器生命周期测试仍待执行。

## [0.1.0-rc.8] - 2026-08-02

### Fixed

- rollback 在 `tc` 恢复命令成功后强制重新读取 qdisc 并与原始快照做语义比较；不一致时记录 `DEGRADED`、保留 `state.json` 和 `qdisc-original.json`，不再删除证据后报告成功；
- 原快照的 `handle 0:` 按 tc 的 unspecified 语义处理，允许受支持的 classless qdisc 使用内核自动分配 handle；原快照显式保存非零 handle 时，恢复命令会携带该 handle 并继续严格比较；
- 保留 `target`、`interval` 和 `ce_threshold` 的 ±1 微秒量化容差，kind、parent、root、显式 handle 和其他 options 仍严格比较。

### Validation

- 增加 `handle 0:` 与自动 handle 等价、显式 handle 不得漂移及显式 handle 恢复命令测试；
- 增加 qdisc 恢复命令成功但后置比较失败的故障注入，确认 rollback 返回失败、保留状态并记录 `ROLLBACK_PENDING → DEGRADED`；
- Debian 12 1C2G、200 Mbps 目标机使用与发布件哈希一致的 rc.7 完成 preflight、apply、立即/重启后 verify、重复 apply、严格 3X-UI verify、rollback、回滚后重启、重新 apply 和最终重启后严格 verify；外部 `/swapfile-3xui` 和 3X-UI/Xray 保持正常；
- 该目标机显示恢复命令后的自动 handle 为 `8001:`，时间字段回显相差 1 微秒，重启后回到原始 `0:` 和精确时间值，由此触发 rc.8 后置验证和 handle 语义整改；
- rc.8 已完成本地静态和失败注入验证，仍需在目标机复测主动 rollback 后置验证。

## [0.1.0-rc.7] - 2026-08-02

### Fixed

- `verify` 对 sysctl 值先折叠首尾空白及连续空格/制表符，再比较字段内容，修复 `tcp_rmem`、`tcp_wmem` 数值一致却因内核对齐格式不同而误报；
- 原始 sysctl 的回滚完成判断使用同一归一化规则，避免已恢复的多值参数仅因显示空白不同而被误判；
- NOFILE 审计显式以制表符传递 soft/hard 两列，不再受脚本全局 `IFS` 排除空格的影响；同时按 `/proc/<PID>/limits` 的固定字段读取值；
- README 的 VPS 命令示例统一按 root shell 编写，不再包含 `sudo`。

### Validation

- 增加 sysctl 多空格/制表符等价和数值变化不等价测试；
- 增加与目标机 `/proc/<PID>/limits` 输出一致的 NOFILE soft/hard 分列测试；
- Debian 12 1C1G、1000 Mbps 目标机已完成 rc.6 `recover` 和 `preflight`；rc.6 `apply` 写入后仅因 sysctl 空白格式误报而触发自动回滚，回滚成功并清理管理状态；
- rc.7 的 apply、verify、重启后 verify 和重复 apply 仍待目标机执行。

## [0.1.0-rc.6] - 2026-08-02

### Fixed

- 修复 Debian 12 自带 jq 1.6 对空输入可能仍返回成功，导致空 `state.json` 绕过 `jq -e` 校验的问题；状态校验现在先检查非空，再用 slurp 强制输入恰好包含一个完整对象；
- 移除流式 `jq | atomic writer` 状态接口；所有状态创建和更新改为“同目录临时文件 → 检查 jq 退出码 → 非空/单对象/schema 校验 → 原子替换”，上游失败不再提交目标文件；
- `state_set_phase`、`refresh_managed_files` 和 swap 所有权更新统一使用同一提交路径，任何失败都保留上一个有效状态；
- 为已确认发生在首次系统写入前的 rc.2 空状态增加显式 `recover`，仅在管理文件、swap 和 qdisc 安全门全部通过时隔离证据目录；
- apply/rollback 的关键步骤不再依赖 `set -e` 在函数或 OR-list 中的隐式行为，改为显式检查并传播失败。
- 区分独立 `preflight` 与 `apply` 内部预检：前者遇到既有状态给出操作提示，后者仍允许相同参数的 `VERIFIED` 状态进入幂等验证路径。

### Validation

- 增加空文件、空白文件、`null`、缺字段对象、多个 JSON 文档和有效状态的校验矩阵；
- 增加无效临时 JSON 不得改变既有目标状态、jq 转换失败不得覆盖状态的失败注入测试；
- 增加 rc.2 空状态受控隔离测试；
- 目标 Debian 12 1C1G、1000 Mbps VPS 已确认 `state.json` 为空、qdisc 快照完整且当前 qdisc 与快照一致；随后 rc.6 `recover` 成功，`preflight` 通过，`apply` 因 sysctl 空白格式误报而自动回滚成功。

## [0.1.0-rc.5] - 2026-08-02

### Fixed

- `fq_codel` 回滚不再把 `tc` 输出中的数据包后缀 `p` 拼入 `limit` 输入，也不再给字节数追加 `b`，修复 `limit 10240p` 导致的恢复命令失败；
- qdisc 语义比较对 `target`、`interval` 和 `ce_threshold` 允许 ±1 微秒回显量化差异，避免把 5000/100000 与 4999/99999 误判为配置漂移；
- qdisc 快照缺失、哈希不匹配、语义不一致或恢复命令失败时，输出具体接口、期望值、实际值或失败命令；
- `preflight` 检测到 `DEGRADED` 等未完成事务时不再误报通过，并对已安装、保留 swap 和异常状态分别给出下一步；
- README 说明 Debian 最小化镜像没有 `sudo` 时，root 用户应直接执行命令。

### Validation

- 增加 `fq_codel` 参数恢复命令回归测试，确保命令使用 `limit 10240` 和原始字节数；
- 增加 qdisc 时间字段 ±1 微秒等价及非时间参数差异测试；
- Debian 12 1C1G、1000 Mbps 目标机已确认 rc.4 回滚失败时当前 qdisc 为 `fq_codel limit 10240p`；rc.5 rollback/apply/重启验证仍待执行。

## [0.1.0-rc.4] - 2026-08-01

### Fixed

- 状态机增加 `APPLYING` 阶段，区分“只建立快照”和“已经开始系统写入”；
- `PREPARED`、`ROLLBACK_PENDING` 或 `DEGRADED` 状态在项目文件、原始 qdisc 和原始 sysctl 均已恢复时，可安全清理残留事务状态；
- qdisc 回滚增加忽略 `refcnt` 和 JSON 字段顺序的语义比较，当前状态已等于快照时不再执行无意义的 replace；
- 参数冲突错误同时输出保存值和当前值；回滚对 service、qdisc、文件、daemon-reload、sysctl 和 swap 分步骤报告失败原因。

### Validation

- 增加 qdisc 语义等价与参数差异回归测试；
- 增加 `APPLYING` 必须先于首个系统写入的不变式检查；
- Debian 12 1C1G、1000 Mbps 目标机确认 rc.3 状态冲突和无诊断回滚失败，rc.4 恢复和 apply 仍待执行。

## [0.1.0-rc.3] - 2026-08-01

### Fixed

- 状态 JSON 构造器不再使用 jq 保留字 `label` 作为变量名，修复 `apply` 在状态初始化阶段退出码 3 的问题；
- 原子 JSON 写入失败时清理临时文件；
- 状态尚未提交前发生错误时，自动清理本次进程创建的 qdisc 快照和空状态目录，不再误报为无法回滚的已安装事务。

### Validation

- 静态测试实际提取并编译四份脚本内的状态 JSON jq 过滤器；
- 增加 jq 保留字和未提交状态清理的不变式检查；
- Debian 12 1C1G、1000 Mbps、XFS 目标机已完成 `preflight`，修复后的 `apply`/重启/回滚仍待重新执行。

## [0.1.0-rc.2] - 2026-08-01

### Fixed

- 已有根 `fq` 或 `mq` 下已有 `fq` 叶子不再被重复替换，回滚也不再重置其自定义 fq 参数；
- `verify` 在没有项目状态时返回明确、可操作的错误信息；
- swap 预检增加根文件系统白名单：允许 ext2/ext3/ext4/XFS，已知不适用或未知文件系统安全跳过自动创建。

### Validation

- 静态测试增加 qdisc 不变式、XFS swap 白名单和未安装 `verify` 提示检查；
- 补齐 T1–T6 目标机、M0–M11 生命周期和 Q1–Q5 qdisc 回归矩阵；真实 VPS 结果仍待执行和回填。

## [0.1.0-rc.1] - 2026-08-01

### Added

- Debian 12/13、1C1G/1C2G 四种独立调优脚本；
- 200 Mbps 默认配置和 100–1000 Mbps 参数范围；
- BBR + fq 能力检测、TCP 缓冲、队列和 keepalive 配置；
- `preflight`、`apply`、`verify`、`status`、`rollback` 接口；
- root-only JSON 状态、管理文件哈希和进程锁；
- 常规根 qdisc 与 `mq` 叶子处理；
- 固定路径、受限大小和事务式创建的应急 swap；
- journald 空间限制；
- 以 `x-ui.service` 为主的 3X-UI/Xray 进程和 NOFILE 审计；
- 静态验证脚本、GitHub Actions、验证文档和安全报告说明。

### Known limitations

- 这是预发布版本；目标 VPS 运行矩阵尚待完成；
- 只支持 Debian 12/13 amd64；
- 不支持复杂 qdisc、策略路由、TProxy、网关或 Docker 防火墙治理。
