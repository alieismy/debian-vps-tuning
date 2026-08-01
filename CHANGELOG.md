# Changelog

本项目采用 [Semantic Versioning](https://semver.org/)。

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
