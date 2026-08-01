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
UNMANAGED → PREPARED → APPLIED → VERIFIED
```

失败路径保留 `DEGRADED` 状态。回滚失败时不得删除诊断状态或所有权证据。普通回滚保留脚本创建的 swap；显式 purge 才能在 `swapoff` 成功后删除。

## qdisc 边界

只支持：

- 根 `fq`；
- 根 `fq_codel`；
- 根 `noqueue`，只警告；
- 根 `mq` 且叶子为 `fq`/`fq_codel`。

其他拓扑在第一次系统写入前阻断。IPv4 和 IPv6 默认路由网卡分别发现并去重；策略路由表不属于该发现范围。

## 3X-UI 边界

脚本只识别 `x-ui.service`、主进程、子进程和运行时 NOFILE。它不安装、升级、停止或重启 3X-UI，也不读取数据库、凭据、REALITY 密钥或 Xray JSON。

## 防火墙边界

UFW 只读。脚本不推断 SSH、面板、订阅和 VLESS 入站端口，也不启用 forwarding、NAT 或 TProxy。
