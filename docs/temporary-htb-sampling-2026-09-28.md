# 低速 HTB 短窗口采样修正

日期：2026-09-28。状态：根因已用原始证据、iperf3 源码和隔离 Linux 对照核实；采集修正进入验证，目标机复验尚未执行。范围仅为未发布 `0.2.0-rc.1` 的独立 `htb-sweep`。

## 问题与证据

[首轮 VPS 记录](temporary-htb-acceptance-2026-09-28.md)中的 18 个正式样本全部触发 `RECEIVER_DIVERGENCE`，两个还触发窗口不一致。离线重放仍得到同一结果；全部 36 份 sender/receiver 指标与原始 JSON 字节、时长和速率算术一致。解析器没有把数据读错，历史无效样本不能重分类为有效。

iperf3 3.18 的 [`iperf_tcp_send`](https://github.com/esnet/iperf/blob/2a2984488d6de8f7a2d1f5938e03ca7be57e227c/src/iperf_tcp.c#L83)把 `Nwrite` 返回量累计为 `bytes_sent`；这是写入 socket 的数据量。客户端结束时停止 sender thread 并发送 `TEST_END`，服务端在该状态收集统计、关闭数据 socket，见[客户端源码](https://github.com/esnet/iperf/blob/2a2984488d6de8f7a2d1f5938e03ca7be57e227c/src/iperf_client_api.c#L745)和[服务端源码](https://github.com/esnet/iperf/blob/2a2984488d6de8f7a2d1f5938e03ca7be57e227c/src/iperf_server_api.c#L263)。因此短时间内的 sender bytes 不能直接等同于已经交付的数据，更不能把差值认作网络丢包。

固定 `335c53e` 的 [Linux 对照 CI](https://github.com/alieismy/debian-vps-tuning/actions/runs/36405504325)在两个专有 netns/veth 内使用 iperf3 3.18、BBR、2 Mbps HTB 和默认 5 Mbps application cap；所有数据流量留在 runner 内。改变一个因素得到以下单次观测（仅说明机制，不代表性能基准）：

| 对照 | sender Mbps | receiver Mbps | 最大 socket notsent bytes | 解释 |
|---|---:|---:|---:|---|
| 默认，5 秒 | 5.032 | 1.831 | 1605048 | 复现大量未发送积压 |
| 仅改为 16 KiB write | 4.849 | 1.954 | 1765448 | 小块本身不能消除持续过量入队 |
| 仅设 64 KiB socket buffer | 2.097 | 1.840 | 114392 | 积压减少，但会改变 TCP 窗口约束 |
| 仅延长到 30 秒 | 2.447 | 1.891 | 2421056 | 仍触发 20% 背离阈值 |
| 仅把 offered rate 改为 2.2 Mbps | 2.306 | 1.848 | 196984 | 减少积压，默认大块仍造成明显量化误差 |

这与 VPS 症状及源码机制一致，支持“持续按远高于当前整形速率的 cap 写入 socket，短窗口统计包含未交付积压”的成因。CI 没有重建公网路径的全部条件，不能由此解释历史的每一次重传、时长异常或 softnet 压力。

## 实施选择

正式 HTB 样本的 offered rate 改为 `min(rate-cap, current HTB rate × 1.10)`；write block 改为 `min(131072, current HTB Mbps × 6250)` bytes，即最多对应当前档位 50 ms 的数据。普通 `measure` 和 discovery 仍使用原发送目标及 128 KiB block。每个事件与样本记录实际 offered rate 和 block，计划公开采集政策。

最主要的反对理由是较小发送余量可能无法充分暴露整形，尤其用户 cap 接近上界或路径吞吐受限时。因此保留每样本正 HTB overlimits、sender/receiver 均至少达到 HTB rate 的 90%、20% receiver 背离、原窗口、资源和首尾 reference 门禁；不满足即保留无效，不增加重试或把阈值放宽。

不采用固定小 socket buffer，因为它可能在高 RTT 路径引入新的吞吐限制。不自动延长测试，因为时长本身不能保证解决问题，并会增加流量。上述选择不修改系统 sysctl、TCP buffer、HTB burst/cburst/quantum、恢复与预算政策。

预留仍按用户的完整 application cap 和原超时余量计算，成功仍按 sender bytes 结算。内部执行器独立拒绝 offered rate 超出 cap 或非法 block；新的参数不会绕过账本。

## 验证边界

调用路径回归在修正前观察到原固定 cap 参数而失败；修正后通过，并检查账本预留没有降低。原生回归将通过实际 `HTBMeasurementRun.take → runtime → iperf3` 在 1/2/4 Mbps 各采两次，核对原始参数、窗口、收发、负载、overlimits、结算和恢复；结果待对应修复 CI 记录。

目标复验继续使用原共享窗口，不扩容或重置。原始私有证据、失败记录与恢复 checkpoint 保留。采样有效性不等于发现 policer、性能提升或业务验收。
