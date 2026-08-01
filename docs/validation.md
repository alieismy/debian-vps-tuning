# 验证说明

## 证据分层

验证结果必须分为：

1. 本地静态检查；
2. 同源模板与四个资源变体的一致性；
3. 目标 VPS 运行、重启和回滚；
4. 3X-UI/Xray 与客户端业务连接。

前三项不能相互替代。静态检查通过不证明 BBR、qdisc、swap、重启持久性或代理连接成功。

## 首发运行矩阵

| ID | 系统 | 资源 | 端口 | 内核基线 | 状态 |
|---|---|---|---:|---|---|
| T1 | Debian 12 | 1C1G | 200 Mbps | `6.1.0-51-cloud-amd64` | 待执行 |
| T2 | Debian 12 | 1C2G | 200 Mbps | `6.1.0-51-cloud-amd64` | 待执行 |
| T3 | Debian 13 | 1C1G | 200 Mbps | `6.12.100+deb13-cloud-amd64` | 待执行 |
| T4 | Debian 13 | 1C2G | 200 Mbps | `6.12.100+deb13-cloud-amd64` | 待执行 |
| T5 | 任一匹配配置 | 1C1G | 100 Mbps | 对应系统内核 | 待执行 |
| T6 | 任一匹配配置 | 1C1G/2G | 1000 Mbps | 对应系统内核 | 待执行 |

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

## 失败路径

至少覆盖：已有 swap、同名非项目 swap 文件、磁盘不足、sysctl 冲突、同名非项目 unit、`mq`、`noqueue`、复杂 qdisc、双栈不同默认网卡、未安装 3X-UI、停止的 `x-ui.service`、缺失的 Xray 子进程、应用中断和 `swapoff` 失败。
