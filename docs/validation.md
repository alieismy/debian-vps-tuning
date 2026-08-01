# 验证说明

## 证据分层

验证结果必须分为：

1. 本地静态检查；
2. 同源模板与四个资源变体的一致性；
3. 目标 VPS 运行、重启和回滚；
4. 3X-UI/Xray 与客户端业务连接。

前三项不能相互替代。静态检查通过不证明 BBR、qdisc、swap、重启持久性或代理连接成功。

## 首发目标机矩阵

下表是必须取得证据的目标矩阵，不是已经完成的测试结果。没有真实 VPS 回填证据前，不得把状态改为“通过”。

| ID | 系统 | 资源 | XFS SSD | 端口 | 内核基线 | 定位 | 状态 |
|---|---|---|---:|---:|---|---|---|
| T1 | Debian 12 | 1C1G | 10 GB | 200 Mbps | `6.1.0-51-cloud-amd64` | 主力/首要门槛 | 待执行 |
| T2 | Debian 12 | 1C2G | 15 GB | 200 Mbps | `6.1.0-51-cloud-amd64` | 主力/首要门槛 | rc.7 部分通过；rc.8 rollback 待复测 |
| T3 | Debian 13 | 1C1G | 以实机为准 | 200 Mbps | `6.12.100+deb13-cloud-amd64` | 系统兼容 | 待执行 |
| T4 | Debian 13 | 1C2G | 以实机为准 | 200 Mbps | `6.12.100+deb13-cloud-amd64` | 系统兼容 | 待执行 |
| T5 | 与脚本匹配的 Debian 版本 | 1C1G | 10 GB | 100 Mbps | 以实机为准 | 低带宽边界 | 待执行 |
| T6 | 与脚本匹配的 Debian 版本 | 1C1G | 50 GB | 1000 Mbps | 以实机为准 | 高带宽边界 | 待执行 |

T1、T2 必须通过才能发布首个稳定版；T3、T4 是 Debian 13 稳定版门槛；T5、T6 用于确认 100–1000 Mbps 输入边界，不能用 200 Mbps 的结果代替。

## 每台目标机的生命周期矩阵

每一行都要分别在 T1–T6 回填“通过/失败/不适用”、执行时间、脚本 SHA-256 和脱敏证据路径。任一失败都应保留退出码和错误输出。

| 阶段 | 操作 | 关键判据 | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---|---|---|---|---|---|---|---|
| M0 | 基线采集 | OS、内核、内存、XFS、磁盘、双栈、qdisc、swap 可追溯 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M1 | 未安装状态执行 `verify` | 退出码 5；提示先运行 `preflight`/`apply`；无系统写入 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M2 | `preflight` | 退出码 0；识别 XFS；无系统写入 | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M3 | `apply` | 退出码 0；状态为 `VERIFIED`；swap/qdisc 行为符合预期 | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M4 | 立即 `verify` | 退出码 0；sysctl、qdisc、journald、swap 一致 | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M5 | 重启后 `verify` | 退出码 0；BBR、fq、sysctl、swap 持久 | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M6 | 重复 `apply` | 退出码 0；报告无需重复写入；无重复 fstab/unit | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M7 | 3X-UI/Xray 验证 | `REQUIRE_PROXY_SERVICE=1 verify` 通过；服务未被脚本重启 | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M8 | VLESS + REALITY + TCP | IPv4/IPv6 按实际能力建立连接；连续传输无异常 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |
| M9 | 普通 `rollback` | 系统配置恢复；脚本创建的 swap 默认保留；状态可追溯 | 待执行 | rc.7 实际恢复通过；rc.8 后置验证待复测 | 待执行 | 待执行 | 待执行 | 待执行 |
| M10 | 回滚后重启 | `status` 行为正确；无残留 unit/sysctl/journald 配置 | 待执行 | rc.7 通过 | 待执行 | 待执行 | 待执行 | 待执行 |
| M11 | 显式 purge | `swapoff` 成功才删除 swap/fstab 行；失败时保留证据 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 | 待执行 |

状态初始化还必须覆盖 jq 构造器失败路径：状态 JSON 未成功提交时，不得创建 sysctl、journald、helper 或 unit；脚本应删除本次进程创建的 qdisc 快照、JSON 临时文件和空状态目录，并明确报告“未写入系统配置”。

状态兼容性测试必须使用 Debian 12 的 jq 1.6 语义，至少覆盖：0 字节、仅空白、`null`、缺字段对象、多个连续 JSON 对象、jq 编译失败、jq 转换失败和有效单对象。任何无效输入都不得覆盖既有状态。不能只用 jq 1.7/1.8 的 `-e` 空输入退出码证明兼容。

rc.2 空状态的 `recover` 必须拒绝一般损坏 JSON、有效状态、仍存在项目文件、脚本 swap/fstab 行、活动 fq helper 或 qdisc 不一致；成功时只能把状态目录改名隔离，不能删除证据。

已有任何管理状态时，`preflight` 不得输出可直接应用的“通过”：`VERIFIED`/`APPLIED` 应引导执行 `verify` 或先回滚，`SWAP_RETAINED` 应引导显式 purge，其他事务状态应要求先完成 `rollback`。

独立 `preflight` 的状态阻断不得破坏重复 `apply`：相同参数且状态为 `VERIFIED` 时，`apply` 必须进入验证后无写入返回；参数不同或事务状态不允许时才阻断。

sysctl 校验应比较归一化后的字段值：内核通过 `sysctl -n` 返回的连续空格或制表符只用于显示对齐，不构成配置差异；字段数量或任一字段数值变化仍必须失败。NOFILE 审计必须把 `/proc/<PID>/limits` 的 soft/hard 两列分别输出，不能受脚本全局 `IFS` 影响。

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

## 已取得的目标机证据

2026-08-02，Debian 12 1C1G、1000 Mbps 目标机使用 rc.6 完成受控空状态恢复，随后 `preflight` 通过。`apply` 已写入并切换到 fq，但 `verify` 把 `tcp_rmem`/`tcp_wmem` 的制表符对齐误判为值不一致，因此事务按设计自动回滚；日志确认“回滚完成，管理状态已清理”。这证明 recover 和该次失败回滚路径通过，不代表 M3 apply 通过，也不代表 rc.7 已在目标机通过。

2026-08-02，Debian 12 1C2G、200 Mbps、已有外部 `/swapfile-3xui` 的目标机使用 SHA-256 `8c241f3a5c58ab34c5d7286621ab52e2552dd17cdeaa4aa1c46137c17d53d7e4` 的 rc.7 完成干净迁移、preflight、apply、立即/重启后 verify、重复 apply、严格 3X-UI verify、rollback、回滚后重启、重新 apply 和最终重启后严格 verify。rollback 立即恢复为功能参数一致的 `fq_codel`，内核自动分配 `handle 8001:`，时间字段回显比快照少 1 微秒；重启后恢复为原始 `handle 0:`、`target 4999`、`interval 99999`。外部 swap 始终保留，x-ui/Xray 始终活动。该证据证明 rc.7 实际生命周期成功，同时暴露其恢复命令后缺少删除状态前语义复核；rc.8 已修复但尚未取得目标机运行证据。

qdisc 快照往返测试必须区分显示单位和命令输入：不得把文本输出的 `p` 后缀拼入 `limit`；`memory_limit` 使用 `tc -j` 返回的原始字节整数。`target`、`interval` 和 `ce_threshold` 可容忍 ±1 微秒回显量化差异。快照 `handle 0:` 与内核自动分配的 classless qdisc handle 视为等价；显式非零 handle、kind、parent、root 及其他 options 仍严格比较。恢复命令成功后还必须执行后置语义比较；不一致时保留状态和快照并进入 `DEGRADED`。

## 每台 VPS 的验收顺序

```text
基线采集
→ preflight
→ apply
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
systemctl show x-ui.service -p LoadState -p ActiveState -p MainPID -p LimitNOFILE
ufw status verbose
```

不要上传密码、UUID、REALITY 私钥、API Token、TLS 私钥或未脱敏配置。

## 通过条件

- 所有命令退出码符合文档；
- `apply` 后关键验证全部通过；
- 重启后 BBR、fq、sysctl 和 swap 状态保持；
- 重复 `apply` 不产生重复 fstab 行或漂移文件；
- UFW 规则和代理配置不被修改；
- `x-ui.service` 不被调优脚本重启；
- VLESS + REALITY + TCP 可以实际建立连接；
- 回滚只删除本项目管理的文件；
- 回滚失败时状态和证据保留；
- 普通回滚保留 swap，显式 purge 只在 `swapoff` 成功后删除。
- 原本已经是 `fq` 的根或 `mq` 叶子在 apply/rollback 后保持原有参数；
- XFS 根文件系统允许创建 swap，已知不适用或未知文件系统只警告并跳过。

## 失败路径

至少覆盖：已有 swap、同名非项目 swap 文件、XFS、已知不适用和未知根文件系统、磁盘不足、sysctl 冲突、同名非项目 unit、带自定义参数的根 `fq`、`mq` 下混合 `fq`/`fq_codel` 叶子、qdisc 快照仅 `refcnt` 不同、qdisc 时间回显相差 1 微秒、`fq_codel limit` 文本输出带 `p`、`noqueue`、复杂 qdisc、双栈不同默认网卡、未安装项目状态时执行 `verify`、已有 `DEGRADED` 状态时执行 `preflight`、0 字节/空白/多文档状态、状态 JSON 构造器编译失败、状态转换失败、rc.2 空状态 recover、状态提交前应用中断、`DEGRADED` 无活动配置恢复、未安装 3X-UI、停止的 `x-ui.service`、缺失的 Xray 子进程、应用中断和 `swapoff` 失败。
