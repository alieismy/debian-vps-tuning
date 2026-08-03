# 设计范围

## 目标

为 Debian 12/13 amd64 小型 VPS 提供性能优先、稳定性受约束且可验证、可回滚的主机网络配置。资源范围严格限定为 1C512MB、1C1GB、1C2GB 和 2C2GB。主要验收负载是原生 systemd 部署的 3X-UI v3.4.2、Xray-core v26.6.27、VLESS + REALITY + TCP，默认 200 Mbps、目标 RTT 200 ms、通常 3–5 人且最多 10 人并发。

## 信任边界

脚本信任：

- root 所有且权限受控的项目状态目录；
- `/etc/os-release`、`/proc`、`sysctl`、`ip`、`tc`、systemd 和内核返回的本机状态；
- 用户明确传入且通过白名单和范围校验的环境变量。

脚本不信任：

- 同名但没有管理标记、状态记录和匹配哈希的文件；
- 自定义 swap 路径；
- 复杂或不可重建的 qdisc；
- 其他调优脚本写入的 sysctl；
- 代理面板数据库、生成的 JSON 和用户凭据。

## 配置归属

唯一命名空间为 `proxy-vps`。状态文件是脚本所有权、资源档位、原始 qdisc、swap 和 managed file 哈希的唯一事实来源。状态文件使用 JSON，不通过 `source` 或 `eval` 解释。

## 总控入口与分发边界

`debian-vps-tuning.sh` 是选择器和调用器，不是另一份调优实现。它只允许 Debian 12/13、amd64 下的四个资源档：1C + 384–767 MiB、1C + 768–1535 MiB、1C + 1536–3072 MiB、2C + 1536–3072 MiB。底层共有六个操作系统/内存 profile；1C2GB 和 2C2GB 共用兼容 ID `debian12-1c2g`/`debian13-1c2g`，不建立重复实现或迁移已有状态。2C512MB、2C1GB、3 vCPU 以上及边界外内存拒绝执行。存在可解析状态时，检测档位必须与 `.profile.id` 一致，否则阻断。

总控入口支持交互安全引导和显式 action。带宽只为 `guided`、`preflight`、`apply` 选择，默认 200 Mbps，范围是 100–1000 的任意整数；`apply` 的选择优先级是 `--port`、`PORT_SPEED_MBPS`、已安装状态值、交互选择/默认值，因而无显式值的重复 `apply` 复用已安装带宽；`verify`、`status`、`diagnose`、`rollback` 不通过 `--port` 重写现有状态。安全引导先运行 preflight，只有交互终端再次明确确认才调用 apply。`diagnose` 只读取本机状态，不生成流量。普通菜单不提供 rc.2 专用 `recover`。

本地模式要求总控脚本、目标 profile 和 `SHA256SUMS` 位于同一目录，并在调用前核对唯一清单条目。远程模式只允许 HTTPS，从总控脚本内固定的 GitHub Release tag 下载 `SHA256SUMS` 和目标 profile；HTTP 错误、重定向协议降级、超时、空文件、重复清单条目或哈希不匹配均阻断。下载失败不得回退到可变分支、latest、第三方镜像或另一个 profile。

总控脚本不写 sysctl、systemd、qdisc、swap、journald 或状态文件，不捕获后伪造底层成功，不改变底层退出码。SHA-256 证明下载内容与同一发布清单一致，不单独证明发布者身份；Release tag、资产不可变性和发布来源仍属于用户信任边界。

## CPU 调优边界

CPU 数只参与资源档位选择和底层预检，不改变 BBR、fq、TCP 缓冲、backlog、swap 或 journald 参数。首发版本不配置 RPS/RFS/XPS、IRQ affinity、CPU affinity、busy polling 或 `GOMAXPROCS`；这些行为依赖虚拟网卡队列、软中断分布和实测瓶颈，不由 2 vCPU 这一条件单独触发。

## 资源参数边界

自动 socket 上限先按端口带宽和目标 RTT 的 BDP 选择 16/32/64 MiB，再限制为 512M/1G/2G profile 的 16/32/64 MiB 上限。显式 `BUF_MAX` 不得越过对应 profile 上限；自动值因 512M 内存预算被截断时必须给出覆盖 RTT 警告。

journald 的 `SystemMaxUse`/`RuntimeMaxUse`/`SystemKeepFree` 分别为：512M 档 `64M/16M/256M`，1G 档 `128M/32M/512M`，2G 档 `128M/64M/1G`。swap 默认均为 1 GiB；512M/1G 上限 2 GiB，2G 上限 4 GiB；创建后必须分别保留至少 256/512/1024 MiB 可用磁盘。所有档位保持 `vm.swappiness=20`。

## 事务状态

正常路径：

```text
UNMANAGED → PREPARED → APPLYING → APPLIED → VERIFIED
```

`PREPARED` 只表示原始状态已提交；在首个系统写入前必须进入 `APPLYING`。失败路径保留 `DEGRADED` 状态。回滚失败时不得删除诊断状态或所有权证据；只有项目文件不存在、swap 未被脚本接管、qdisc 与快照语义一致且原始 sysctl 已恢复时，才能把残留事务判定为已经恢复并清理状态。普通回滚保留脚本创建的 swap；显式 purge 才能在 `swapoff` 成功后删除。

状态持久化不依赖 `set -e` 或 jq 1.6 对空输入的退出码。每次创建或转换先写同目录临时文件；只有生产命令成功、文件非空、输入恰好为一个 JSON 对象且完整 schema 校验通过，才以原子 rename 替换目标。`state_set_phase`、managed file 哈希和 swap 所有权不得自行实现另一套写入路径。

早期 rc.2 空状态不包含原始 sysctl，因此不能按普通 rollback 推断或重建。显式 `recover` 只允许在用户确认该状态产生于首次系统写入前，且项目文件、脚本 swap、fstab、fq helper 均不存在、当前 qdisc 与快照一致时，将整个状态目录改名隔离；不自动删除证据，也不处理一般损坏状态。

## qdisc 边界

只支持：

- 根 `fq`；
- 根 `fq_codel`；
- 仅含默认参数且没有附加层次的常规根 `pfifo_fast`；
- 根 `noqueue`，只警告；
- 根 `mq` 且叶子为 `fq`/`fq_codel`。

其他拓扑在第一次系统写入前阻断。IPv4 和 IPv6 默认路由网卡分别发现并去重；策略路由表不属于该发现范围。

已有根 `fq` 和 `mq` 下已有 `fq` 叶子视为不需要修改，应用和回滚均保留其现有参数。只有已保存完整可恢复参数的 `fq_codel` 根/叶子或常规根 `pfifo_fast` 会被切换并在回滚时重建。HTB、TBF、CAKE、自定义 `pfifo_fast` 或其他未知层次继续阻断。

qdisc 状态以 `tc -j` 数值为准，但恢复命令按 `tc` 输入语法生成：`limit` 使用纯数据包数量，`memory_limit` 使用原始字节数，不复用文本显示后缀。语义比较忽略运行时 `refcnt` 和 JSON 字段顺序；`target`、`interval`、`ce_threshold` 仅允许 ±1 微秒量化差异。原快照 `handle 0:` 代表未指定，允许内核为受支持的 classless qdisc 自动分配 handle；显式非零 handle、kind、parent、root 及其他 options 仍严格比较。rollback 恢复命令完成后必须再次读取并比较实际 qdisc，只有通过后置验证才允许删除状态和快照。

## swap 文件系统边界

自动 swap 文件只允许在 `ext2`、`ext3`、`ext4` 和 `xfs` 根文件系统上创建。Btrfs、ZFS、overlay、NFS、FUSE 以及未验证类型会跳过自动创建，不影响 sysctl、qdisc 和 journald 的应用。XFS 仍需由目标 VPS 验证 `fallocate → swapon` 路径；失败时脚本使用 `dd` 重试并纳入事务回滚。

## 3X-UI 边界

脚本预先托管 `/etc/systemd/system/x-ui.service.d/90-proxy-vps.conf`，设置 `LimitNOFILE=65536`，因此先调优、后安装 3X-UI 是正常路径。未安装时 verify 报告待安装但不警告；安装后严格验证 systemd 配置、主进程和直接子进程的运行时限制。脚本不主动重启代理服务；若 apply 时 `x-ui.service` 已在运行，非严格验证只警告旧运行时限制，用户重启服务或主机后再执行严格验证。脚本不安装、升级 3X-UI，也不读取数据库、凭据、REALITY 密钥或 Xray JSON。

## 防火墙边界

UFW 只读。脚本不推断 SSH、面板、订阅和 VLESS 入站端口，也不启用 forwarding、NAT 或 TProxy。
