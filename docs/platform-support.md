# 跨平台持久配置支持

日期：2026-09-29。适用：未发布 `0.2.0-rc.1` 候选；第三阶段已进入实现，真实平台生命周期结果以本页矩阵和[验证说明](validation.md)为准。旧 rc.19 的公开资产与支持范围不变。

## 平台与资源选择

候选纳入 Debian 12、Debian 13、Ubuntu 24.04 LTS，架构为 `x86_64` 与 `aarch64`。使用原生 systemd 的完整 Linux 主机；需要实际可用的 BBR、fq、sysctl 和可恢复 qdisc，系统名称不替代能力检查。其他 Ubuntu 版本、其他发行版和容器持久化未纳入。

- 原 Debian 四个 CPU/内存组合仍映射原六份 profile，ID、BDP 系数、内存上限、swap/journald 默认保持兼容；ARM64 上也按相同的资源组合选择。
- 其他 Debian 组合选择 `debian12-adaptive` 或 `debian13-adaptive`；Ubuntu 24.04 选择 `ubuntu2404-adaptive`。至少 1 个可用逻辑 CPU、384 MiB 可识别物理内存，不再按最大 CPU/RAM 档位拒绝。
- 已有 `.profile.id` 必须与选择结果一致。跨 OS、资源缩放导致的 profile 切换不自动覆盖旧状态；仍需按原恢复和迁移流程处理。
- 安装器只安装经过同一清单校验的资产。持久 `preflight/apply/verify/reconfigure/rollback` 复用既有事务、文件所有权、mq/fq 拓扑处理与恢复入口。

## 缓冲和带宽策略

受管 `--port` 接受 **1–10000 Mbps**，默认仍为 200 Mbps。此值是服务商套餐上限的配置输入，参与 BDP（带宽时延积）计算，不创建限速器，也不代表通过相应速率的性能验收。

自适应 profile 使用以下明确上限：

```text
socket_cap = min(256 MiB, max(16 MiB, physical_RAM / 32))
BDP_target = port_Mbps × 125 × target_RTT_ms
auto_buffer = min(socket_cap, 向上选择 16/32/64/128/256 MiB)
```

BDP 超过封顶时明确报告 `auto-clamped`；显式 `BUF_MAX` 超过资源上限则拒绝。socket 上限不是预分配内存，也不是所有连接的总内存保证；连接数与业务占用仍须观测。现有 profile 保留 1×/1.25×/1.5×BDP 的策略。全部计算使用字节，不新增 `tcp_mem`，不假定 ARM64 的内存页大小。

新增 profile 默认 `ENABLE_SWAP=0`，管理员仍可显式启用原有受管 swap 事务。journald 使用固定 128 MiB 持久/64 MiB 运行上限，不随物理内存无限放大。17 项受管 sysctl、BBR+fq 默认和非持久 HTB 边界保持。

schema 4 的 `profile` 增加 `os_id`/`os_version` 描述字段；Debian 保留 `debian_version`，Ubuntu 将其置为 `null`。旧 schema 4 读取契约不要求新增字段，不会把 Ubuntu 伪装成 Debian。现有迁移器仍只接受已定义的 rc.1–rc.19 Debian 来源，未为不存在的 Ubuntu 历史版本放宽来源检查。

## 验证矩阵

| 平台 | x86_64 | ARM64 |
|---|---|---|
| Debian 12 | 待执行原生 VM 生命周期 | 待执行原生 VM 生命周期 |
| Debian 13 | 待执行原生 VM 生命周期 | 待执行原生 VM 生命周期 |
| Ubuntu 24.04 LTS | 待执行原生 VM 生命周期 | 待执行原生 VM 生命周期 |

`tests/platform-vm.py` 使用固定官方镜像摘要、一次性 SSH 凭据、严格主机密钥校验和独立 QEMU 客体；生命周期覆盖校验安装、重复安装、preflight、apply、同值幂等、1→10000→1 Mbps 重配置、真实客体重启、verify、rollback 及再次重启。比较 17 项 sysctl、qdisc 参数、受管文件和状态，保存镜像/架构/内存/页大小/boot ID 及运行输出。客体内不执行公网 iperf3，不接触用户 VPS。

控制器与资源策略另有原有档位、扩展组合、极端输入、缓冲封顶及显式超限的离线回归。它们不能替代上表的原生生命周期，更不能证明 3X-UI/Xray 业务或吞吐改善。

## 与前两阶段的关系

自动 `measure` 仍不修改系统配置。临时 `htb-sweep` 仍只接受单根 fq；Ubuntu/ARM64 的持久 apply 支持不会扩大临时实验到 mq。候选区间必须满足原预算与有效性门禁；未出现可靠拐点并不阻止独立的平台功能验收。持久 HTB 仍是需临时实验与业务对照的独立策略，没有在本候选中启用。
