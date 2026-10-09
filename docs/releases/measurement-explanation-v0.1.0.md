# 离线测量解释工具 0.1.0 发布说明

发行类型：独立源码 **Pre-release**，2026-09-30 发布，不设为 Latest。工具 tag 为 `measurement-explanation-v0.1.0`，源码固定于 `1c5e922c2fce916d5217bf6c238d6cd50a8c51b0`。它不替代主程序 `v0.2.0-rc.1`，不是 VPS 升级包。

## 下载与使用

[GitHub Release](https://github.com/alieismy/debian-vps-tuning/releases/tag/measurement-explanation-v0.1.0) 提供三个资产：

- [完整源码 ZIP](https://github.com/alieismy/debian-vps-tuning/releases/download/measurement-explanation-v0.1.0/dvt-measurement-explanation-0.1.0-source.zip)
- [中文使用说明](https://github.com/alieismy/debian-vps-tuning/releases/download/measurement-explanation-v0.1.0/RELEASE-NOTES.zh-CN.md)，包含校验、Windows/Linux 解包与运行命令
- [SHA256SUMS](https://github.com/alieismy/debian-vps-tuning/releases/download/measurement-explanation-v0.1.0/SHA256SUMS)

保留完整解包目录，使用 Python 3 运行 `tools/explain_measurement.py --input-dir <已完成报告目录>`；追加 `--json` 可输出派生 JSON。无需 pip、Git、root、SSH 凭据或在 VPS 上执行安装器。源码包保留 MIT 许可证。

源码 ZIP 为 1494689 bytes、115 个文件，其 SHA-256 为：

```text
f242180f1abb9502de3745186a2328b979918225f6ff45a3e9e524b209eb46c8
```

## 功能与证据

工具核验原报告后解释绝对重传、字节暴露量、原阈值所需整数次数和候选限制，保留原分类。缺失字段和高档汇总不足时明确表示不可评估，不生成限速决定；接口与数学定义由[工具契约](../measurement-explanation.md)维护。

固定源码的[默认分支 CI](https://github.com/alieismy/debian-vps-tuning/actions/runs/36694985355)与 [tag CI](https://github.com/alieismy/debian-vps-tuning/actions/runs/36696765305)通过：105 项 Python 无跳过及既有完整 Linux 门禁。Windows/Python 3.13.12 解包目录通过 16 项工具测试、生成检查和四轮真实归档回读；三个公开下载资产逐字节匹配批准制品。分层验证记录见[验证说明](../validation.md#测量证据解释工具2026-09-30独立-pre-release)。

完整源码快照内保留主程序和历史文档，各自状态以对应记录为准。此次发布没有修改主程序安装资产；实际 Release 列表经主程序版本选择函数核验，仍选择 `v0.2.0-rc.1`，独立工具 tag 被跳过。运行代码及已发布制品保持不可变。

合成场景验证契约，有限公网归档验证可读取性与解释一致性；它们不证明统计准确率、可靠 policer 识别、业务收益或两台旧部署迁移完成。Linux ZIP 及 macOS 未新增专项验收，不扩大平台声明。
