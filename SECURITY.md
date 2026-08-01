# Security Policy

## Supported versions

在首个正式版本发布前，仅最新的 `v0.1.0-rc.*` 预发布版本接受安全修复。正式发布后，支持范围将在此更新。

## Reporting a vulnerability

请优先使用 GitHub 仓库的 **Security → Report a vulnerability** 私密报告入口。不要先创建公开 Issue。

报告建议包含：

- 受影响的脚本名和版本；
- Debian 主版本、内核版本和 amd64 架构信息；
- 可复现步骤、实际退出码和脱敏日志；
- 是否涉及文件删除、状态所有权、qdisc、swap、sysctl 或 systemd；
- 预期行为与实际行为。

不得提交：

- SSH 私钥或密码；
- 面板用户名、密码或 API Token；
- VLESS UUID；
- REALITY privateKey；
- TLS/ACME 私钥；
- 未脱敏的 3X-UI 数据库或 Xray 完整配置。

## Operational safety

这些脚本以 root 权限运行。请从 GitHub Release 下载、核对 `SHA256SUMS`、阅读脚本并先执行 `preflight`。不要把未知 fork 或未经核验的网络内容直接通过 `curl | bash` 交给 root shell。
