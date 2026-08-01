# 设计范围

## 目标

为 Debian 12/13 amd64 小型 VPS 提供保守、可验证、可回滚的主机网络配置。主要验收负载是原生 systemd 部署的 3X-UI v3.4.2、Xray-core v26.6.27、VLESS + REALITY + TCP，默认 200 Mbps、少于 10 名用户。

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
- 根 `noqueue`，只警告；
- 根 `mq` 且叶子为 `fq`/`fq_codel`。

其他拓扑在第一次系统写入前阻断。IPv4 和 IPv6 默认路由网卡分别发现并去重；策略路由表不属于该发现范围。

已有根 `fq` 和 `mq` 下已有 `fq` 叶子视为不需要修改，应用和回滚均保留其现有参数。只有已保存完整可恢复参数的 `fq_codel` 根或叶子会被切换并在回滚时重建。

qdisc 状态以 `tc -j` 数值为准，但恢复命令按 `tc` 输入语法生成：`limit` 使用纯数据包数量，`memory_limit` 使用原始字节数，不复用文本显示后缀。语义比较忽略运行时 `refcnt` 和 JSON 字段顺序；`target`、`interval`、`ce_threshold` 仅允许 ±1 微秒量化差异。原快照 `handle 0:` 代表未指定，允许内核为受支持的 classless qdisc 自动分配 handle；显式非零 handle、kind、parent、root 及其他 options 仍严格比较。rollback 恢复命令完成后必须再次读取并比较实际 qdisc，只有通过后置验证才允许删除状态和快照。

## swap 文件系统边界

自动 swap 文件只允许在 `ext2`、`ext3`、`ext4` 和 `xfs` 根文件系统上创建。Btrfs、ZFS、overlay、NFS、FUSE 以及未验证类型会跳过自动创建，不影响 sysctl、qdisc 和 journald 的应用。XFS 仍需由目标 VPS 验证 `fallocate → swapon` 路径；失败时脚本使用 `dd` 重试并纳入事务回滚。

## 3X-UI 边界

脚本只识别 `x-ui.service`、主进程、子进程和运行时 NOFILE。它不安装、升级、停止或重启 3X-UI，也不读取数据库、凭据、REALITY 密钥或 Xray JSON。

## 防火墙边界

UFW 只读。脚本不推断 SSH、面板、订阅和 VLESS 入站端口，也不启用 forwarding、NAT 或 TProxy。
