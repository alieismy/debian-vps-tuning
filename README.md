# Debian VPS Tuning

Debian VPS Tuning 用于配置 Debian 12/13 小型云 VPS 的主机网络。主要验证场景是在原生 systemd 环境中运行 3X-UI、Xray-core 和 VLESS + REALITY + TCP。当前目标机基线为 3X-UI v3.4.2 和 Xray-core v26.6.27；其他版本需单独验证。脚本还可只读识别 S-UI、sing-box 和独立 Xray 服务。

脚本管理 BBR + fq、TCP 缓冲上限、常规队列参数、应急 swap 和 journald 空间上限，并提供 `preflight`、`apply`、`verify` 和 `rollback` 生命周期。它不配置代理业务、路由或防火墙。吞吐、延迟和丢包还取决于线路、虚拟化平台及实际负载，不能由这些主机参数单独保证。

> 系统选择（信息日期：2026-08-04）：新建的 1C1G、1C2G 和 2C2G VPS 默认使用 Debian 13 minimal。Debian 13 是当前 stable；Debian 12 已转入 LTS，适用于保留既有稳定节点或满足明确兼容约束的场景。系统版本不能单独证明 BBR 可用、性能更高或空载内存更低，仍需检查虚拟化类型、运行内核和目标机资源。

> 当前预发行候选版本为 `v0.1.0-rc.12`。以下联网命令固定到该候选 Release 及其校验和资产，不跟随分支或 `latest`。只有在 Release 发布且公开资产通过重下载校验后，这些命令才可使用。正式 `v0.1.0` 仍以 [目标 VPS 运行验收](docs/validation.md) 为发布条件；候选版本不代表已完成全平台、全带宽或性能验收。

## 联网安装与验证

以下命令要求在 VPS 的 root shell 中执行；提示符通常为 `#`，`id -u` 应输出 `0`。脚本会修改主机级网络、systemd、journald 和 swap 配置。首次执行前，确认服务商控制台或救援模式可用，并保存系统与网络基线。

### 1. 联网安装

rc.12 Release 发布并通过公开资产复核后，使用以下固定总控入口。总控自动识别 Debian 12/13、amd64、CPU 和内存档位，先执行只读 `preflight`；预检通过后，只有明确输入 `y` 才执行 `apply`：

```bash
(
  set -e

  dvt_tmp="$(mktemp -d)"
  trap 'rm -rf -- "$dvt_tmp"' EXIT

  curl --fail --show-error --silent --location \
    --proto '=https' \
    --proto-redir '=https' \
    --connect-timeout 15 \
    --max-time 120 \
    -o "$dvt_tmp/debian-vps-tuning.sh" \
    https://github.com/alieismy/debian-vps-tuning/releases/download/v0.1.0-rc.12/debian-vps-tuning.sh

  printf '%s  %s\n' \
    '1f72c8ce8c727577086b133e39cf6410899b0d6589278fdce145f42dcaf0322a' \
    "$dvt_tmp/debian-vps-tuning.sh" | sha256sum -c -

  bash "$dvt_tmp/debian-vps-tuning.sh"
)
```

总控入口依次执行：

1. 显示检测到的系统、CPU、内存和档位；
2. 选择服务商端口带宽；直接按 Enter 使用 200 Mbps；
3. 显示实际调用脚本、来源和 SHA-256；
4. 先执行只读 `preflight`；
5. `preflight` 通过后再次询问，只有明确输入 `y` 才执行 `apply`。

应用成功后按提示重启：

```bash
reboot
```

### 2. 重启后联网验证

重启并重新登录 VPS 后执行。`verify` 只读检查当前状态，不会再次运行 `apply`，也不要求重新输入状态中已保存的端口带宽：

```bash
(
  set -e

  dvt_tmp="$(mktemp -d)"
  trap 'rm -rf -- "$dvt_tmp"' EXIT

  curl --fail --show-error --silent --location \
    --proto '=https' \
    --proto-redir '=https' \
    --connect-timeout 15 \
    --max-time 120 \
    -o "$dvt_tmp/debian-vps-tuning.sh" \
    https://github.com/alieismy/debian-vps-tuning/releases/download/v0.1.0-rc.12/debian-vps-tuning.sh

  printf '%s  %s\n' \
    '1f72c8ce8c727577086b133e39cf6410899b0d6589278fdce145f42dcaf0322a' \
    "$dvt_tmp/debian-vps-tuning.sh" | sha256sum -c -

  bash "$dvt_tmp/debian-vps-tuning.sh" verify
)

printf 'verify_after_reboot_exit=%s\n' "$?"
```

只有 `verify_after_reboot_exit=0` 表示验证通过。应保存完整输出，不能只保留最后一行。

### 3. 安装 3X-UI 后严格联网验证

先完成调优和重启验证，再安装 3X-UI。安装并启动 3X-UI 后执行：

```bash
(
  set -e

  dvt_tmp="$(mktemp -d)"
  trap 'rm -rf -- "$dvt_tmp"' EXIT

  curl --fail --show-error --silent --location \
    --proto '=https' \
    --proto-redir '=https' \
    --connect-timeout 15 \
    --max-time 120 \
    -o "$dvt_tmp/debian-vps-tuning.sh" \
    https://github.com/alieismy/debian-vps-tuning/releases/download/v0.1.0-rc.12/debian-vps-tuning.sh

  printf '%s  %s\n' \
    '1f72c8ce8c727577086b133e39cf6410899b0d6589278fdce145f42dcaf0322a' \
    "$dvt_tmp/debian-vps-tuning.sh" | sha256sum -c -

  env \
    REQUIRE_PROXY_SERVICE=1 \
    PROXY_SERVICE_UNITS='x-ui.service' \
    bash "$dvt_tmp/debian-vps-tuning.sh" verify
)

printf 'strict_verify_after_3xui_exit=%s\n' "$?"
```

严格验证要求 `x-ui.service` 处于 `active`，并确认 systemd 配置、3X-UI 主进程及其直接 Xray 子进程的 NOFILE soft/hard limit 均不低于 65536。安装 3X-UI 后再次重启并重复严格验证，用于检查开机启动和新进程的限制继承。

### 4. 从早期 rc 版本执行只读升级检查

由 rc.9、rc.10 或 rc.11 管理的 VPS，可下载 rc.12 总控并执行 `update`。该操作读取状态中的资源档和端口带宽，校验当前 profile、目标 `SHA256SUMS` 和目标总控脚本，然后依次运行当前版本的 `verify` 与目标版本的只读 `update-preflight`。输出包括维护窗口所需的固定 URL、SHA-256 和迁移顺序。`update` 不执行 `rollback`、purge、`apply` 或重启，也不替换已发布的旧 Release 资产。

总控、`SHA256SUMS` 和 profile 构成一个不可拆分的 Release 包。不同版本的资产不得放在同一目录。例如，rc.11 总控不能与 rc.12 的 `SHA256SUMS` 和 profile 混放；总控检测到版本不一致时会拒绝执行，且不会自动改用联网下载。以下联网命令和后续回滚示例均使用独立的 `mktemp -d` 目录。

```bash
(
  set -e

  dvt_tmp="$(mktemp -d)"
  trap 'rm -rf -- "$dvt_tmp"' EXIT

  curl --fail --show-error --silent --location \
    --proto '=https' \
    --proto-redir '=https' \
    --connect-timeout 15 \
    --max-time 120 \
    -o "$dvt_tmp/debian-vps-tuning.sh" \
    https://github.com/alieismy/debian-vps-tuning/releases/download/v0.1.0-rc.12/debian-vps-tuning.sh

  printf '%s  %s\n' \
    '1f72c8ce8c727577086b133e39cf6410899b0d6589278fdce145f42dcaf0322a' \
    "$dvt_tmp/debian-vps-tuning.sh" | sha256sum -c -

  bash "$dvt_tmp/debian-vps-tuning.sh" update
)
```

使用 `update --target v0.1.0-rc.12` 可指定目标版本。自动发现不跨 `major.minor` 发布线：当前版本为 rc 时，可选择同线更高 rc 或稳定版；当前版本为稳定版时，自动排除 prerelease。跨线升级必须通过 `--target` 指定目标，且仍会拒绝降级和重复升级。显式指定 prerelease 视为主动选择，不受稳定通道的自动排除规则限制。

`update` 只检查升级兼容性并生成操作计划，不改写磁盘上的旧脚本、系统配置或 3X-UI。检查通过不表示升级完成。维护窗口内仍需按输出和本文顺序执行 rollback/purge、重启、目标版本的 `preflight`/`apply`、再次重启及 `verify`。GitHub API 查询失败或触发匿名速率限制时，可用已审阅的 `--target` 跳过自动发现；目标 Release 资产仍会接受校验。

### 5. 联网执行注意事项

- 仅支持厂商最小化 Debian 12/13、`x86_64/amd64` 和本文列出的四个 CPU/内存资源档；其他组合会被拒绝；
- 端口带宽填写服务商套餐上限，不要填写虚拟网卡显示的链路速率；默认 200 Mbps，允许 100–1000 Mbps；
- 联网入口固定到 `v0.1.0-rc.12`，不会回退到 `master`、`main`、`latest`、HTTP 或第三方镜像；
- 上述命令在执行总控前核对 rc.12 总控资产的固定 SHA-256；总控随后下载固定 Release 的 `SHA256SUMS` 和对应 profile，并再次校验；
- 总控、`SHA256SUMS` 和 profile 必须来自同一 Release；不同版本使用不同的临时目录，不要把 rc.11 与 rc.12 资产混放在 `/root` 或同一工作目录；
- 发布后不应移动 tag 或替换同名资产，发现缺陷时应发布新版本；
- `update` 是只读升级检查，不自动迁移配置；检查通过后仍需在维护窗口人工完成 rollback/apply 和两次重启；
- 脚本不配置或放行 UFW 端口，不要把 UFW 状态提示当成防火墙已配置；先确保 SSH 管理端口不会被锁死；
- `apply` 会写入系统配置并可能创建 `/swapfile-proxy`；生产 VPS 应先备份、确认控制台/救援入口，并在维护窗口执行；
- `verify` 通过仅证明当前配置和受检服务符合脚本契约，不证明线路吞吐、延迟、丢包或 VLESS + REALITY + TCP 业务性能得到改善；
- `preflight` 对 `/etc/sysctl.conf` 中唯一且值严格为 `fq`/`bbr` 的厂商基线给出只读迁移计划；`apply` 会先完整备份原文件，再把对应配置归属迁移到项目管理文件。其他重复 sysctl 定义仍会被 `preflight` 和 `verify` 拒绝；不要再运行 3X-UI/X-UI 内置的 BBR 或网络优化菜单，以免重新创建 `99-bbr-x-ui.conf`；
- `rollback` 会撤销本项目管理的调优配置，应在维护窗口测试；普通 rollback 默认保留脚本创建的 swap；
- 不要在未阅读脚本和发布说明时使用 `curl ... | bash` 或 `bash <(curl ...)`。

## 真实环境验证基线

截至 2026-08-07，项目已取得下列脱敏目标机证据。表中编号代表验证记录，不代表 VPS 数量；同一资产在不同时期的同类配置可以形成多条记录。公开文档不记录服务商、区域、IP、域名、主机名、面板端口、订阅地址、账号、凭据、证书标识或可反查报告 ID。

| 记录 | 操作系统与内核系列 | VPS 配置 | 存储/网络 | 已覆盖路径 | 证据边界 |
|---|---|---|---|---|---|
| C1 | Debian 13；Linux 6.12 系列 | 1 vCPU / 约 1 GiB；`debian13-1c1g` | ext4；套餐上限 1000 Mbps | 固定 rc.9 资产校验、安全引导、`preflight`、`apply`、立即/重启后 `verify`、安装 3X-UI 后严格验证；BBR、fq、swap 和 NOFILE 重启后保持 | 只证明对应 rc.9 产物和该配置类别的主路径，不继承为后续 rc 结论 |
| C2 | Debian 12；Linux 6.1 系列 | 1 vCPU / 约 1 GiB；`debian12-1c1g` | XFS；套餐上限 200 Mbps | 退出 rc.8 后完成 rc.10 候选 `apply`、重启后普通/严格 `verify` 和重复 `apply`；重复执行未重写配置 | 不替代最终 Release 资产复核，不证明代理吞吐或线路质量 |
| C3 | Debian 12；Linux 6.1 系列 | 1 vCPU / 约 2 GiB；`debian12-1c2g` | XFS；套餐上限 200 Mbps | 退出 rc.8 后完成 rc.10 候选 `apply`、重启后普通/严格 `verify` 和重复 `apply`；3X-UI 主进程及 Xray 直接子进程 NOFILE 为 65536/65536 | 不覆盖 2C2G、512 MiB、其他文件系统或最终 Release 资产 |
| C4 | Debian 13；Linux 6.12 系列 | 1 vCPU / 约 1 GiB；`debian13-1c1g` | ext4；套餐上限 1000 Mbps | 使用隔离目录完成 rc.9→rc.10 候选迁移、重启后严格 `verify` 和重复 `apply` | 这是迁移记录，配置类别可能与 C1 重合；不代表新增一台独立 VPS |
| C5 | Debian 13；Linux 6.12 系列 | 1 vCPU / 约 1 GiB；`debian13-1c1g` | ext4；套餐上限 200 Mbps | 固定 rc.11 候选完成 `preflight`、`apply`、立即/重启后 `verify`、幂等门禁，以及固定 commit/rootfs 的三轮 S1 与三轮 S2 TcpQuality 采集 | 原始证据私有保存；只证明 rc.11 生命周期和两时段线路观察，不证明 rc.12 最终哈希或调优导致性能改善 |
| C6 | Debian 13；Linux 6.12 系列 | 1 vCPU / 967 MiB；`debian13-1c1g` | 10 GB / ext4；套餐上限 100 Mbps | rc.12 本地候选完成校验和复核、错误参数退出、显式 swap purge、100 Mbps `preflight`/`apply`、重启后 `verify` 和重复 `apply`；BBR、fq、1024 MiB swap 持久，缺失的 `/etc/sysctl.conf` 未被创建 | 暴露并修正了改参提示和缺失文件元数据；原运行绑定修正前 profile 哈希，最终候选仍须重跑哈希绑定门禁；未安装 3X-UI，不覆盖严格代理验证或性能收益 |

每条记录均绑定测试时的脚本哈希。脚本内容或 SHA-256 改变后，必须按 [验证矩阵](docs/validation.md) 重新取证；版本名称或配置值相同不足以继承原结论。rc.12 最终哈希尚未完成目标 VPS 生命周期、严格代理验证、持久化 benchmark 和独立 TcpQuality 工具验证。

### 1C2G / 200 Mbps 性能观察案例

同一 Debian 12、1C2G 配置类别曾在旧 v6 配置和 rc.10 配置下分别运行 TcpQuality。本文只保留聚合结果；报告 URL、报告 ID、精确测试时间、服务商和区域不公开。原始报告保存在维护者的私有证据集中。

三次报告均显示 `bbr`、`fq`、TCP 发送缓冲 `4K/64K/16M` 和接收缓冲 `4K/128K/16M`。下表每格依次为“零异常 / 1–20% / >20%”：普通回程按丢包率分档，大包回程按重传率分档，每类包含 93 个判定项。

| 脱敏样本 | IPv4 回程 | IPv4 大包回程 | IPv6 回程 |
|---|---:|---:|---:|
| v6 基线样本 | 93 / 0 / 0 | 91 / 0 / 2 | 69 / 24 / 0 |
| rc.10 样本 A | 92 / 1 / 0 | 84 / 7 / 2 | 67 / 23 / 3 |
| rc.10 样本 B | 93 / 0 / 0 | 92 / 0 / 1 | 79 / 14 / 0 |

同一 rc.10 配置的两个时段样本中，IPv4 大包零重传节点由 84 变为 92，IPv6 零丢包节点由 67 变为 79。组内波动已经大于或接近 v6 与 rc.10 样本 A 的组间差异。这三次观测不能证明 v6 或 rc.10 的内核参数更快，也不能将个别区域或运营商的集中异常唯一归因于某条路由。测试时段、运营商链路、测速节点、共享宿主机负载和工具版本均可能影响结果。

样本量同样不足：v6 只有一次，rc.10 只有两次，无法估计稳定分布。TcpQuality 未指定 `-s` 时随机使用内置包长，默认 `-c` 每个节点只发送 30 个包。该工具直接测试 VPS 网络栈，不经过 3X-UI、VLESS、REALITY 或客户端链路。现有证据以远程图片为主，缺少可供公开复算的机器可读原始表格。

这些报告不足以支持回退 rc.10、修改 rc.11/rc.12 的 17 个受管 sysctl，或增加激进参数。性能验收必须固定 TcpQuality commit、脚本 SHA-256、节点文件和 `-c/-s/-p` 参数，在低负载、白天和晚高峰重复采样，并比较中位数、P95 与异常节点复现率。实际 VLESS + REALITY + TCP 链路还需覆盖 1、3、5、10 并发。完整待测项见 [验证矩阵](docs/validation.md)。

## 本地使用与命令行模式

`debian-vps-tuning.sh` 是总控入口。它读取 Debian 主版本、amd64 架构、可用逻辑 CPU 数和实际内存，从六份系统/内存 profile 中选择匹配项。总控不包含独立的调优逻辑，只负责选择、SHA-256 校验和调用 profile。

从完整项目目录运行：

```bash
bash ./debian-vps-tuning.sh
```

直接使用命令行模式：

```bash
bash ./debian-vps-tuning.sh preflight --port 200
bash ./debian-vps-tuning.sh apply --port 200
bash ./debian-vps-tuning.sh verify
bash ./debian-vps-tuning.sh status
bash ./debian-vps-tuning.sh diagnose
# benchmark 还需要 BENCHMARK_HOST，见下文
bash ./debian-vps-tuning.sh benchmark
bash ./debian-vps-tuning.sh update
bash ./debian-vps-tuning.sh update --target v0.1.0-rc.12
bash ./debian-vps-tuning.sh rollback
```

在没有交互终端的自动化环境中，必须明确指定 action；总控不会进入菜单或自动执行 `apply`。`recover` 仅用于处理 rc.2 空状态，不出现在普通菜单中。

不要使用以下入口：

```text
curl ... | bash
bash <(curl ...)
```

这两种形式会在 root 权限下直接执行下载内容，绕过“完整下载、文件校验、执行”三个独立步骤。

## 适用场景

- VPS 厂商预装的 Debian 12 或 Debian 13 最小化系统；
- `x86_64/amd64`；支持 1C512MB、1C1GB、1C2GB 和 2C2GB 四个资源档；
- 实测内存边界为 384–767 MiB、768–1535 MiB 或 1536–3072 MiB；
- 10 GB、15 GB 或更大 SSD，且有足够剩余空间；
- IPv4 或 IPv4 + IPv6 双栈的常规默认路由；
- 服务商端口上限 100–1000 Mbps，默认按 200 Mbps 设计；
- 以 TCP 为主、连接规模经过目标机实测的小型代理服务器；项目不按“用户数”承诺容量；
- 内核实际提供 BBR 和 fq。

主要验证基线：

| 系统 | 内核基线 | 资源脚本 |
|---|---|---|
| Debian 12 (bookworm) | Linux 6.1 系列 | 1C512MB、1C1GB、1C2GB、2C2GB |
| Debian 13 (trixie) | Linux 6.12 系列 | 1C512MB、1C1GB、1C2GB、2C2GB |

这些版本是已知验证基线，不是内核补丁版本白名单。脚本严格检查 Debian 主版本和 amd64 架构；内核小版本变化后，仍以目标机实际提供的 BBR/fq 能力为准。

## Debian 12/13 选型

以下信息核对至 2026-08-04。Debian 13 是当前 stable，最新点版本为 13.6；Debian 12 是 oldstable，常规 Release、Security 和 Backports 支持已经结束，LTS 持续到 2028-06-30。Debian 13 的常规支持截至 2028-08-09，LTS 截至 2030-06-30。参见 [Debian Releases](https://www.debian.org/releases/) 和 [Bookworm 转入 LTS 公告](https://www.debian.org/News/2026/20260712)。

新建的 1C1G、1C2G 和 2C2G VPS 默认使用 Debian 13 minimal。Debian 12 适用于已有稳定节点、服务商 Debian 13 镜像存在已确认缺陷，或第三方软件明确要求 Debian 12 的情况。不得仅为未经证实的性能收益，对唯一生产节点执行原地大版本升级。

| 维度 | Debian 12 | Debian 13 | 项目判断 |
|---|---|---|---|
| 发布状态 | oldstable，处于 LTS | 当前 stable | 新部署优先 Debian 13 |
| 支持期限 | LTS 至 2028-06-30；少数包可能不在 LTS 覆盖范围 | 常规支持至 2028-08-09，LTS 至 2030-06-30 | 公网长期节点优先更长的常规支持窗口 |
| 典型内核系列 | Linux 6.1 LTS | Linux 6.12 LTS | 13 有更新的内核和虚拟化驱动，但不保证吞吐更高 |
| 用户态基线 | systemd 252、OpenSSH 9.2、OpenSSL 3.0、glibc 2.36 | systemd 257、OpenSSH 10.0、OpenSSL 3.5、glibc 2.41 | 新软件兼容性更有利；旧脚本和闭源 agent 需验证 |
| 迁移风险 | 现有部署成熟，变更较少 | 原地升级需检查网卡名、SSH、`/tmp` 和 sysctl 加载行为 | 关键节点优先新建 Debian 13 并行迁移 |

Debian 13 的适用理由：

- 当前为 stable，常规安全维护和 LTS 生命周期更长；
- Linux 6.12 LTS、systemd 257、OpenSSH 10.0p1 和 OpenSSL 3.5 提供更新的内核、虚拟化和系统组件；
- Debian 官方提供 GenericCloud、NoCloud 和 OpenStack 等云镜像；
- 3X-UI 官方安装脚本按发行版 ID `debian` 选择 APT 和 Debian systemd unit，没有发现 Debian 12-only 的版本判断；
- Xray-core 官方 Linux 构建使用 `CGO_ENABLED=0`，通常不依赖 Debian 12/13 的特定 glibc ABI。

Debian 13 的限制与迁移风险：

- Debian 13 不保证比 Debian 12 占用更少内存，也不保证自动提高 Xray 的吞吐、延迟或并发能力；
- `/tmp` 默认使用按需分配的 tmpfs，最大值可达到内存的 50%；1C1G 节点应限制大型临时文件和日志；
- `systemd-sysctl` 不再读取 `/etc/sysctl.conf`，本地配置应放入 `/etc/sysctl.d/*.conf`；本项目使用该规范路径，但旧调优脚本可能不兼容；
- Debian 12 原地升级到 13 时，部分系统的可预测网卡名可能改变，硬编码接口名的网络、防火墙或 qdisc 配置必须提前检查；
- OpenSSH、OpenSSL、Python 和 systemd 的大版本变化可能影响旧密钥、自动化脚本或服务商闭源 agent；
- 服务商提供“Debian 13”镜像不等于运行内核一定为 6.12，也不证明 cloud-init、IPv6 和网络模板已经通过验证。

相关变化见 [Debian 13 发布公告](https://www.debian.org/News/2025/20250809) 和 [Debian 13 Release Notes：已知问题](https://www.debian.org/releases/stable/release-notes/issues.en.html)。

### 按 VPS 资源档选择

| VPS 配置 | 推荐系统 | 适用判断 | 主要约束 |
|---|---|---|---|
| 1C1G | Debian 13 minimal | 新建节点的默认选择；不安装桌面，仅保留必要服务 | 1 GiB 是 Debian 13 无桌面安装的推荐内存，不代表 3X-UI/Xray 具有固定余量；应监控 RSS、FD、CPU steal、softirq、日志和 `/tmp` |
| 1C2G | Debian 13 | 三档中较均衡，更新和临时任务的内存余量优于 1C1G | 单核仍可能成为加密、软中断或高并发瓶颈 |
| 2C2G | Debian 13 | 更适合多连接、多入站或较高 CPU 负载 | 2 vCPU 不保证吞吐翻倍，也不能仅凭 CPU 数启用 RPS/RFS/XPS 或 IRQ affinity |

Debian 13 官方给出的无桌面 amd64 安装最低内存为 512 MB，推荐内存为 1 GB。服务器实际需求取决于运行服务，不能据此推导“空载固定约 100 MB”或代理容量。参见 [Debian 13 amd64 安装要求](https://www.debian.org/releases/trixie/amd64/ch03s04.en.html)。

### 虚拟化类型比发行版名称更接近内核事实

KVM、VMware、Hyper-V 等完整虚拟机通常运行来宾系统自己的 Debian 内核；LXC、Incus 和部分 OpenVZ 类系统容器则共享宿主机内核。容器内的 `/etc/os-release` 即使显示 Debian 13，也不能证明运行内核为 6.12、BBR 可用，或 qdisc/sysctl 权限完整。选择 profile 前至少检查：

```bash
cat /etc/os-release
uname -r
systemd-detect-virt
systemd-detect-virt --container || true
sysctl -n net.ipv4.tcp_available_congestion_control
sysctl -n net.ipv4.tcp_congestion_control
sysctl -n net.core.default_qdisc
tc -s -d qdisc show
```

六份脚本分别校验操作系统、CPU、内存、运行内核能力和 qdisc 拓扑。系统选型不能替代目标机 `preflight`。

## 脚本选择

| 文件 | 操作系统 | CPU 范围 | 内存档位 | swap 默认值/上限 |
|---|---|---:|---:|---:|
| `debian12-1c512m-vps-tuning.sh` | Debian 12 | 1 vCPU | 384–767 MiB | 1024/2048 MiB |
| `debian12-1c1g-vps-tuning.sh` | Debian 12 | 1 vCPU | 768–1535 MiB | 1024/2048 MiB |
| `debian12-1c2g-vps-tuning.sh` | Debian 12 | 1–2 vCPU | 1536–3072 MiB | 1024/4096 MiB |
| `debian13-1c512m-vps-tuning.sh` | Debian 13 | 1 vCPU | 384–767 MiB | 1024/2048 MiB |
| `debian13-1c1g-vps-tuning.sh` | Debian 13 | 1 vCPU | 768–1535 MiB | 1024/2048 MiB |
| `debian13-1c2g-vps-tuning.sh` | Debian 13 | 1–2 vCPU | 1536–3072 MiB | 1024/4096 MiB |

文件名和状态 ID 中的 `1c2g` 是兼容名称。同一 2G profile 同时支持 1C2GB 和 2C2GB，不另建重复的 2C2G 文件；已有 `debian12-1c2g`/`debian13-1c2g` 状态无需迁移。各资源脚本仍独立校验系统、架构、CPU 和内存，总控选择不能绕过底层预检。2C512MB、2C1GB、3 vCPU 以上及边界外内存均会被拒绝。

默认端口上限为 200 Mbps，也可显式设置为 100–1000 Mbps。该值应填写 VPS 套餐或服务商规定的上限，不能使用虚拟网卡显示的链路速率。

## 脚本会修改什么

- `/etc/sysctl.d/90-proxy-vps.conf`；
- `/etc/systemd/journald.conf.d/90-proxy-vps.conf`；
- `/usr/local/sbin/proxy-vps-fq`；
- `/etc/systemd/system/proxy-vps-fq.service`；
- `/etc/systemd/system/x-ui.service.d/90-proxy-vps.conf`，预置 `LimitNOFILE=65536`；
- `/var/lib/proxy-vps-tuning/state.json` 和 qdisc 原始状态；
- 在系统没有活动 swap 时，按需创建固定路径 `/swapfile-proxy`；
- 仅为脚本实际创建的 swap 添加一行 `/etc/fstab`。

主要 sysctl 包括：

- `net.core.default_qdisc=fq`；
- `net.ipv4.tcp_congestion_control=bbr`；
- 按带宽和目标 RTT 计算的 TCP socket 缓冲上限；
- `somaxconn`、`tcp_max_syn_backlog` 和 `netdev_max_backlog`；
- TCP Fast Open 内核开关、MTU probing 和 keepalive；
- `vm.swappiness=20`。

完整边界见 [设计范围](docs/design-scope.md)。

### TCP Fast Open 与 Xray 的边界

`net.ipv4.tcp_fastopen=3` 只启用 Linux 客户端和服务端的基础能力。Linux 内核区分全局位图与单个 listener 的 `TCP_FASTOPEN` socket option；Xray 则通过 `streamSettings.sockopt.tcpFastOpen` 控制入站或出站 socket。以下命令没有输出，只表示 3X-UI 生成的 Xray 配置中未显式设置 `tcpFastOpen`，不能据此判断 TFO 的实际启用状态：

```bash
jq '.. | objects | select(has("tcpFastOpen")) | .tcpFastOpen' \
  /usr/local/x-ui/bin/config.json
```

`verify` 和 `diagnose` 只读报告该字段是否存在，不修改代理配置。`/usr/local/x-ui/bin/config.json` 由 3X-UI 生成，面板重建配置时可能覆盖，不能直接编辑。只有当前 3X-UI 版本提供对应的入站/出站 sockopt 或高级配置入口，并已完成客户端兼容性测试时，才可通过面板配置。配置后应复查生成的 JSON 和实际连接。TFO 主要影响握手阶段，不能替代 BBR、fq 或线路质量，也不保证适用于所有中间设备。

主机的 `tcp_keepalive_time/intvl/probes` 只影响已经启用 `SO_KEEPALIVE`、且未被应用覆盖的 socket。Xray 入站 Keep-Alive 默认关闭，设置 `tcpKeepAliveIdle` 或 `tcpKeepAliveInterval` 后才启用；出站使用自身的默认值。主机 sysctl 不能单独证明 Xray 连接采用了这些 keepalive 参数。参见 [Linux IP sysctl](https://docs.kernel.org/networking/ip-sysctl.html) 和 [Xray Sockopt](https://xtls.github.io/en/config/transports/sockopt.html)。

## 脚本不会修改什么

- 不安装、升级或降级 3X-UI、S-UI、sing-box、Xray；
- 不读取或修改 3X-UI 数据库、Xray JSON、UUID、REALITY 私钥、证书私钥或面板凭据；
- 不增加、删除或重排 UFW 规则；
- 不开放 SSH、面板、订阅或代理端口；
- 不重启 `x-ui.service`、`xray.service`、`s-ui.service` 或 `sing-box.service`；若执行 `apply` 时 x-ui 已在运行，普通验证会要求重启服务或主机后再做严格验证；
- 不配置 RPS/RFS/XPS、IRQ affinity、CPU affinity 或 `GOMAXPROCS`；
- 不修改 DNS、路由、策略路由、MTU、IPv6 启停策略；
- 不开启 IP forwarding、NAT 或 TProxy；
- 不修改 `ip_local_port_range`、`tcp_mem`、`fs.file-max` 或 conntrack 上限；
- 不接管 Docker 与 UFW 的数据包处理关系。

## VPS 初始化

以下命令要求已经进入 root shell（提示符通常为 `#`，`id -u` 输出 `0`），因此不使用 `sudo`。厂商最小化镜像通常允许直接以 root 登录，也可能未安装 `sudo`。

建议先更新系统并查看升级计划：

```bash
apt update
apt -s full-upgrade
apt full-upgrade -y
```

安装基础工具和脚本依赖：

```bash
apt install -y \
  curl wget ca-certificates gnupg lsb-release unzip \
  vim nano htop ufw jq \
  iproute2 procps kmod util-linux
```

清理自动安装且不再需要的软件包前，先模拟并检查列表：

```bash
apt-get -s autoremove --purge
```

确认无误后再执行：

```bash
apt autoremove --purge -y
```

更新内核后应重启，再运行调优脚本：

```bash
reboot
```

## UFW 注意事项

在远程 VPS 上启用 UFW 前，必须先放行真实 SSH 端口。例如 SSH 使用 22/TCP：

```bash
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed
ufw allow 22/tcp comment 'SSH management'
ufw enable
ufw status numbered
```

如果 SSH 不是 22，请替换为真实端口。双栈 VPS 应确认 `/etc/default/ufw` 中为 `IPV6=yes`。

VLESS + REALITY 入站只开放实际使用的 TCP 端口。面板端口最好限制到可信管理 IP，或通过 SSH 本地转发访问。调优脚本只读取 UFW 状态和监听端口，不会替你修改规则。

## 下载与校验

从 GitHub Release 下载完整资产时，检查全部文件：

```bash
sha256sum -c SHA256SUMS
```

只下载总控脚本和 `SHA256SUMS` 时，检查对应条目：

```bash
grep -F '  debian-vps-tuning.sh' SHA256SUMS | sha256sum -c -
less ./debian-vps-tuning.sh
chmod +x ./debian-vps-tuning.sh
```

这是 root 级系统脚本。不得跳过校验并直接使用 `curl | bash`。总控随后还会校验实际调用资源脚本的 SHA-256。

## 使用方法

一般场景使用总控脚本。以下独立脚本方法用于离线操作、审计和故障恢复，示例环境为 Debian 13、1C1G、200 Mbps。执行时必须替换为与目标系统、CPU 和内存匹配的文件。

### 1. 只读预检

```bash
env PORT_SPEED_MBPS=200 \
  bash ./debian13-1c1g-vps-tuning.sh preflight
```

`preflight` 不写配置、不加载模块、不创建 swap、不停止服务。遇到以下情况会阻断：

- 操作系统、架构、CPU 或内存档位不匹配；
- 缺少必要命令；
- BBR/fq 不可用；
- 没有常规默认路由；
- 同名管理文件的所有权不明；
- `/etc/sysctl.conf` 或 `/etc/sysctl.d` 存在不能安全迁移的重复键；仅 `/etc/sysctl.conf` 中唯一且值严格为 `net.core.default_qdisc=fq` 或 `net.ipv4.tcp_congestion_control=bbr` 的厂商基线可进入只读迁移计划；
- qdisc 拓扑复杂到无法可靠恢复；
- 固定 swap 路径已被其他文件占用；
- 磁盘空间不足。

自动 swap 文件仅支持 `ext2`、`ext3`、`ext4` 和 `xfs` 根文件系统。Btrfs、ZFS、overlay、NFS、FUSE 及其他未验证文件系统会触发警告并跳过 swap 创建；其他网络配置仍可继续应用。

### 2. 应用

```bash
env PORT_SPEED_MBPS=200 \
  bash ./debian13-1c1g-vps-tuning.sh apply
```

如果预检结果为 `PASS_WITH_PROVIDER_SYSCTL_TRANSFER`，`apply` 会在建立事务状态后备份 `/etc/sysctl.conf`，仅注释预检确认的相同值 `fq`/`bbr` 定义，再写入项目管理文件。备份保存在 root-only 状态目录中并纳入 `verify` 与 `rollback`；迁移失败会触发自动回滚。

应用成功后重启：

```bash
reboot
```

如果在安装 3X-UI 前应用调优，脚本会预先创建 `x-ui.service` drop-in。此时 `verify` 将“尚未安装代理服务”视为正常状态，不产生警告。以后安装 3X-UI 时，systemd 会读取该配置。

### 3. 重启后验证

```bash
bash ./debian13-1c1g-vps-tuning.sh verify
bash ./debian13-1c1g-vps-tuning.sh status
```

### 4. 安装 3X-UI 后验证

固定使用 3X-UI v3.4.2 时，应从官方 `v3.4.2` tag/release 获取安装脚本或资产。指向 `master` 的安装入口不能保证得到固定版本。

安装并配置 3X-UI 后：

```bash
env REQUIRE_PROXY_SERVICE=1 \
  PROXY_SERVICE_UNITS='x-ui.service' \
  bash ./debian13-1c1g-vps-tuning.sh verify
```

脚本检查 `x-ui.service` 的 systemd 配置值，以及主进程和直接子进程的 `/proc/<PID>/limits`。严格验证要求配置值与运行时 soft/hard limit 均不低于 65536。

### 5. 只读诊断

```bash
bash ./debian-vps-tuning.sh diagnose
```

`diagnose` 默认采集间隔为 5 秒。它输出 TCP 重传、超时、监听溢出和 TFO 增量；每 CPU softnet 增量；整机 CPU user/system/softirq/steal；接口收发、丢包、错误及可识别的 ethtool 错误计数。输出还包含采样前后的 qdisc 状态、默认路由、RPS/XPS/IRQ，以及代理主进程和直接子进程的 CPU time、RSS、线程数与 FD 数。进程证据不包含命令行参数。

该操作不产生性能测试流量，也不修改系统。需要观察实际负载时，应在采样窗口内从客户端复现 VLESS + REALITY + TCP 业务：

```bash
env DIAG_INTERVAL_SECONDS=15 \
  bash ./debian-vps-tuning.sh diagnose
```

默认不输出连接对端和进程详情。确需采集 `ss -tinp` 时，保存或共享日志前必须脱敏：

```bash
env DIAG_INCLUDE_SOCKET_DETAILS=1 \
  bash ./debian-vps-tuning.sh diagnose
```

### 6. 显式 iperf3 benchmark

`benchmark` 不修改系统配置，但会产生高带宽 TCP 流量。运行前必须准备并获准使用 iperf3 服务端；脚本不安装软件包、不开放端口，也不选择公共服务器。

默认测试依次执行上传和下载。每个方向先预热 3 秒，该阶段不计入统计，再记录 10 秒有效窗口。设置 `BENCHMARK_OUTPUT_DIR` 后，脚本分别保存两个方向的原始 iperf3 JSON、结构化摘要、TCP/softnet/CPU/接口增量和 qdisc 前后统计，并生成运行元数据、总结果及核心证据 `SHA256SUMS`。证据目录必须是尚不存在的绝对路径；脚本以 `0700` 权限创建，并拒绝覆盖已有目录：

```bash
env BENCHMARK_HOST='iperf.example.com' \
  BENCHMARK_PORT=5201 \
  BENCHMARK_SECONDS=10 \
  BENCHMARK_OMIT_SECONDS=3 \
  BENCHMARK_PARALLEL=1 \
  BENCHMARK_IP_FAMILY=4 \
  BENCHMARK_DIRECTION=both \
  BENCHMARK_RATE_CAP_MBPS=200 \
  BENCHMARK_RUN_ID='case-1c1g-ipv4-a1' \
  BENCHMARK_OUTPUT_DIR='/root/dvt-benchmark-case-1c1g-ipv4-a1' \
  bash ./debian-vps-tuning.sh benchmark
```

`upload.summary.json` 和 `download.summary.json` 中，`sender.retransmits` 是对应方向的 iperf3 sender 统计，`host.tcp_delta` 是测试窗口内的整机全局计数，`qdisc_delta` 是本地 qdisc 统计。三者不可互换：背景连接会计入整机统计，本地 qdisc drop 也不等于远端路径丢包。

开始产生测试流量前，脚本会按 `带宽上限 × (有效时间 + omit) × 方向数` 计算 iperf payload 估算上界。`BENCHMARK_RATE_CAP_MBPS` 显式值优先；未提供时只接受合法管理状态中的 `network.port_speed_mbps`，否则明确报告无法量化，不使用 profile 默认值猜测。估算及其 `explicit`/`managed-state` 来源写入 `benchmark-meta.json`。该值不含 TCP/IP 和链路层开销，不等同于服务商最终计费流量，也不保证实际吞吐达到该上限。

`sender.retransmits_per_gib` 按 iperf3 sender bytes 归一化。存在 `mq` 叶子时，`qdisc_active_totals` 汇总叶 qdisc；否则汇总根 qdisc，来源记录在 `qdisc_coverage.aggregation_source`。根与叶的统计不相加，以免重复计算同一流量。这些指标只适合比较服务端、方向、时段和参数一致的重复测试，不能单独用于性能排名。

创建持久化目录后，脚本先写入 `INCOMPLETE`。上传/下载摘要、核心证据清单、`benchmark-result.json` 和 `COMPLETED` 全部提交成功后，才删除该标记。`SHA256SUMS` 覆盖原始测试数据、计数器、元数据和分方向摘要；为避免循环依赖，不覆盖 `benchmark-result.json`、`COMPLETED` 和 `INCOMPLETE`。`benchmark-result.json` 保存核心清单哈希，`COMPLETED` 绑定核心清单与最终结果哈希。

判定一组持久化证据有效，必须同时满足以下条件：

1. 命令退出码为 0；
2. 结果状态为 `PASS`；
3. 存在 `COMPLETED`；
4. 不存在 `INCOMPLETE`；
5. 两条哈希链均可重新计算并匹配。

`BENCHMARK_IP_FAMILY=4` 或 `6` 用于固定地址族；`auto` 由系统解析和连接过程选择。比较 IPv4 与 IPv6 时，应分别运行并保存各自的默认路由。`BENCHMARK_OMIT_SECONDS=0` 用于观察包含 slow start 的短连接；非零值用于比较稳态吞吐，两类结果不能混入同一序列。

该测试只测量 VPS 与 iperf3 服务端之间的直连 TCP，不经过 VLESS + REALITY + TCP 客户端链路。公共测试点的单次结果不能直接代表代理体验。`BENCHMARK_PARALLEL` 范围为 1–4；1C1G 和 1C2G 基线应先使用 1。iperf3 参数语义见 [ESnet 官方文档](https://software.es.net/iperf/invoking.html)。

### 7. 固定 TcpQuality 证据采集

`tcpquality-evidence.sh` 独立于系统调优生命周期，不自动下载“最新”脚本或 rootfs，也不执行 `apply`。运行前必须按已审阅流程准备固定 commit 目录，其中至少包含三个脚本、rootfs、`PINNED-METADATA.txt`，以及覆盖这些文件的 `SHA256SUMS`。

rc.12 只接受已审计 commit `5d1f85a6b8916b73ec0389dbc9b4ed4aa27dae01`、三个固定脚本哈希和 rootfs 哈希。在该 commit 中，`-s 0` 明确定义为标准无负载 TCP SYN，不表示随机包长；`-c` 的范围为 1–600，`-p` 的范围为 1–31。证据目录必须尚不存在：

```bash
env \
  TCPQUALITY_PIN_DIR='/root/tcpquality-pinned-5d1f85a6b8916b73ec0389dbc9b4ed4aa27dae01' \
  TCPQUALITY_EVIDENCE_DIR='/root/rc12-evidence/tcpquality-s2' \
  TCPQUALITY_COMMIT='5d1f85a6b8916b73ec0389dbc9b4ed4aa27dae01' \
  TCPQUALITY_ROOTFS_SHA256='db92956873d674e65a573721ec6a3db4995f7cf648f61954380e0bfa53ce71a1' \
  TCPQUALITY_RUNS=3 \
  TCPQUALITY_DELAY_SECONDS=60 \
  TCPQUALITY_COUNT=30 \
  TCPQUALITY_PACKET_SIZE=0 \
  TCPQUALITY_PARALLEL=16 \
  bash ./tcpquality-evidence.sh
```

每轮测试保存原始日志和唯一 CSV，并在测试前后分别采集 `all`/`tos` 节点表。节点响应通过固定 12 列 TSV 结构校验后才原子写入。`node-inventory.tsv` 记录各快照哈希；`node-drift.tsv` 区分逻辑节点增删、同一逻辑节点的 IP 变化，以及完整快照是否一致。`summary.txt` 记录实际节点 URL。

固定 commit、脚本和 rootfs 只能固定本地执行资产；远端节点、测速端点、运营商路径和测试时段仍是动态实验输入。最终 `SHA256SUMS` 覆盖 summary、文本、TSV、CSV 和日志，但不覆盖终态标记。`COMPLETED` 绑定清单哈希，`INCOMPLETE` 与 `COMPLETED` 不得同时存在。任何关键采集或校验失败都会终止后续轮次并保留失败现场。

节点变化不会自动使整组测试失效，但比较时必须剔除或单独标注不一致节点。包装脚本不调用主机包管理器或系统配置命令；固定上游的 `--all` 仍会访问节点、报告和测速端点，并产生显著的主动网络流量。

### 8. HTB 候选速率发现与 A/B/A

`experiments/htb-aggregate/rate-sweep-plan.sh`、`rate-sweep-run.sh` 和 `rate-sweep-analyze.sh` 把候选发现分成只读计划、显式流量/临时 qdisc 执行和只读分析三层。当前边界只接受 rc.12 schema 4、`VERIFIED`、200 Mbps 的 Debian 13 1C1G/1C2G 基线；只测上传，因为本地 egress HTB 不能用于归因下载方向的远端 sender 重传。默认计划在首尾重复根 `fq` 基线，并以正序/反序轮次重复 150/170/180/190/195 Mbit/s 候选；每阶段至少冷却 300 秒。

分析使用 iperf3 精确 sender bytes 归一化的 `retransmits_per_gib` 和 receiver goodput，不假设固定 MSS、不推算 packet loss percentage、不使用固定全局重传阈值。runner 还按秒保存只含 TCP_INFO 白名单 token、不含 endpoint/PID/进程名的 `socket-metrics.txt`，用于辅助检查 RTT、cwnd、重排、重传和收发缓冲受限；它可能混入同机背景 TCP，不能替代流级指标。输出只能是人工复核 shortlist；扫描完成、shortlist 非空和 HTB `overlimits` 都不授权持久化。完整命令、流量预算、停止条件和恢复边界见 [HTB 候选聚合速率发现 SOP](docs/experiments/htb-candidate-rate-sweep.md)。

候选经人工复核后，`experiments/htb-aggregate/experiment-plan.sh` 才用于生成机器可读的正式 A/B/A 计划；它本身不检查或修改目标机，也不自动执行流量。默认计划为首个窗口 `A1 → B1 → A2` 和另一个可比窗口中的反向顺序 `B2 → A3 → B3`，stage 之间至少冷却 300 秒：

```bash
bash ./experiments/htb-aggregate/experiment-plan.sh \
  --candidate-rate 190 \
  --repeat-cycles 2 \
  --cooldown-seconds 300 \
  --control-rate none >./experiment-plan-190.json
```

较低速率控制必须等候选结果分析关闭后另建窗口，例如 `--control-rate 180` 会附加独立的 `A-control-before → C1 → A-control-after`，不会自动执行或授权 180 Mbit/s。候选扫描不能替代该 A/B/A 和反序复验。

现行执行器 v0.3.0 只接受 rc.12 schema 4、`VERIFIED`、200 Mbps 的 `debian13-1c1g` 或 `debian13-1c2g` 基线，并把实际 profile 与受管 state 哈希绑定到活动状态。1C2G 新实验须使用独立的 [VMISS 1C2G / 200 Mbps HTB A/B/A SOP](docs/experiments/vmiss-1c2g-200mbps-htb-aba.md)。原 [VMISS Basic HTB A/B/A 实验 SOP](docs/experiments/vmiss-basic-200mbps-htb-aba.md) 保留为 1C1G/v0.2.1 历史运行证据，不得混用工具哈希或实验目录。

## 100–1000 Mbps

100 Mbps：

```bash
env PORT_SPEED_MBPS=100 \
  bash ./debian12-1c1g-vps-tuning.sh apply
```

200 Mbps：

```bash
env PORT_SPEED_MBPS=200 \
  bash ./debian12-1c2g-vps-tuning.sh apply
```

1000 Mbps：

```bash
env PORT_SPEED_MBPS=1000 \
  bash ./debian13-1c2g-vps-tuning.sh apply
```

可使用 100–1000 范围内的任意整数；总控菜单也提供 500 Mbps。rc.12 沿用 rc.11/rc.10 的网络参数：默认目标 RTT 为 200 ms；512M、1G 和 2G 资源档分别采用 1×、1.25× 和 1.5× BDP，再向上选择 16/32/64 MiB，并受各 profile 的 16/32/64 MiB 上限约束：

| 资源档 | BDP 系数 | 100 Mbps | 200 Mbps | 500 Mbps | 1000 Mbps |
|---|---:|---:|---:|---:|---:|
| 512M | 1× | 16 MiB | 16 MiB | 16 MiB | 16 MiB（截断警告） |
| 1G | 1.25× | 16 MiB | 16 MiB | 16 MiB | 32 MiB |
| 2G | 1.5× | 16 MiB | 16 MiB | 32 MiB | 64 MiB |

在 200 Mbps 下，所有资源档的上限均为 16 MiB。512M 档优先限制内存压力；1G 和 2G 档逐级增加高 BDP 余量。只有 512M、1000 Mbps、200 ms 的组合会触发资源截断警告。

表中数值是自动调优允许的最大 socket 缓冲，不表示每条连接会立即占满。Linux TCP 接收缓冲仍按连接需求自动增长；应用显式调用 `setsockopt(SO_RCVBUF)` 时可能改变该行为。资源截断用于限制内存风险，不表示带宽参数无效。没有持续监控和高 BDP 证据时，不应手工设置 `BUF_MAX`。

## 参数

| 变量 | 默认值 | 范围/说明 |
|---|---:|---|
| `PORT_SPEED_MBPS` | `200` | `100–1000` |
| `BUFFER_TARGET_RTT_MS` | `200` | `20–500` |
| `BUF_MAX` | `auto` | 512M/1G/2G profile 上限分别为 16/32/64 MiB |
| `ENABLE_SWAP` | `1` | `0` 或 `1` |
| `SWAP_MB` | `1024` | 512M/1G 脚本最高 2048，2G 脚本最高 4096 |
| `PURGE_CREATED_SWAP` | `0` | 回滚时是否清理脚本创建的 swap |
| `PROXY_SERVICE_UNITS` | 自动识别 | 空格分隔的 systemd service |
| `REQUIRE_PROXY_SERVICE` | `0` | 为 `1` 时没有目标代理服务即验证失败 |
| `DIAG_INTERVAL_SECONDS` | `5` | `1–60`，diagnose 增量窗口 |
| `DIAG_INCLUDE_SOCKET_DETAILS` | `0` | `1` 时输出可能包含对端地址的 `ss -tinp` |
| `BENCHMARK_HOST` | 无 | benchmark 必填，用户授权的 iperf3 服务端 |
| `BENCHMARK_PORT` | `5201` | `1–65535` |
| `BENCHMARK_SECONDS` | `10` | `5–120`，每个方向 |
| `BENCHMARK_OMIT_SECONDS` | `3` | `0–10`，每个方向的预热时间，不计入 iperf3 统计 |
| `BENCHMARK_PARALLEL` | `1` | `1–4` |
| `BENCHMARK_IP_FAMILY` | `auto` | `auto`、`4` 或 `6` |
| `BENCHMARK_DIRECTION` | `both` | `upload`、`download` 或 `both` |
| `BENCHMARK_RATE_CAP_MBPS` | 合法管理状态的端口带宽，否则不可估算 | 可选 `1–100000`；只用于测试流量预算，不改变 iperf3 或系统配置 |
| `BENCHMARK_RUN_ID` | 自动生成 | 可选的 1–96 字符运行标签；仅限字母、数字、点、下划线、冒号和连字符 |
| `BENCHMARK_OUTPUT_DIR` | 临时目录 | 可选的持久化证据目录；必须是父目录已存在、目标尚不存在的绝对路径 |
| `UPDATE_TAG` | 自动发现 | `update` 的目标 Release；等价命令行参数为 `--target` |

不支持自定义 swap 文件路径；脚本只可能创建 `/swapfile-proxy`。

## 状态与重复执行

状态保存在 root-only JSON 中：

```text
/var/lib/proxy-vps-tuning/state.json
```

同一脚本版本和参数下重复执行 `apply` 时，脚本先验证当前配置；验证通过后不再写入。通过总控重复执行 `apply`，且未提供 `--port` 或 `PORT_SPEED_MBPS` 时，脚本复用状态中已安装的端口带宽；显式参数优先。若状态版本与当前脚本不同、资源脚本不同，或带宽/缓冲参数已改变，`apply` 会要求先回滚，防止将“旧配置仍可验证”误判为“新版本已经安装”。

状态更新先由 `jq` 写入同目录临时文件。只有命令退出码、非空检查、单一 JSON 对象和完整结构校验全部通过后，才原子替换 `state.json`。空文件、空白文件、多个 JSON 文档或更新失败均不能覆盖上一个有效状态。

### 从 rc.11 升级到 rc.12

rc.12 不改变 rc.11 的 17 个 sysctl、qdisc、自动缓冲矩阵、swap、journald 或 NOFILE。状态 schema 升级为 4，用于记录厂商 `/etc/sysctl.conf` 的原始哈希、备份、迁移后哈希和恢复状态；只有只读 `update-preflight` 可以读取合法的 schema 3 状态。rc.12 不得直接对已有 rc.11 状态执行 `apply`。新增测量能力包括结构化 benchmark 证据和独立 TcpQuality 证据工具。

迁移管理状态时，先用 rc.12 总控执行 `update --target v0.1.0-rc.12` 做只读检查。检查通过后，在维护窗口使用固定且已校验的 rc.11 Release 依次执行 `verify`、`PURGE_CREATED_SWAP=1 rollback` 和重启；随后从独立目录运行 rc.12 的 `preflight`、`apply`、重启及严格 `verify`。

如果只需要新增测量能力，可继续由 rc.11 管理配置生命周期，并从独立目录执行 rc.12 的只读 `diagnose`、显式授权的 `benchmark` 或 `tcpquality-evidence.sh`。不得用 rc.12 的 `apply` 改写 rc.11 状态。

### 从 rc.10 升级到 rc.11

rc.11 不改变 rc.10 的 17 个 sysctl、qdisc、swap、journald、NOFILE 或状态结构；主要新增内容是只读 `diagnose` 和用户授权的 `benchmark`。由于六份 profile 的脚本版本和 SHA-256 已改变，rc.11 不得直接对已有 rc.10 状态重复执行 `apply`。

先用 rc.11 总控执行 `update --target v0.1.0-rc.11` 做只读检查。检查通过后，在维护窗口使用固定且已校验的 rc.10 Release 依次执行 `verify`、`PURGE_CREATED_SWAP=1 rollback` 和重启；随后从独立目录运行 rc.11 的 `preflight`、`apply`、重启及严格 `verify`。rc.10 与 rc.11 的总控、清单和 profile 不得放在同一目录。

如果只需要新增诊断或 benchmark，而不迁移管理状态，可继续由已安装的 rc.10 管理配置生命周期，并从独立临时目录运行 rc.11 profile 的只读 `diagnose` 或显式授权的 `benchmark`。不得用 rc.11 的 `apply` 覆盖 rc.10 状态。

### 从 rc.8/rc.9 或旧 v5/v6 升级到 rc.10

`tcpFastOpen` 查询无输出不是必须升级的故障。rc.10 只增加检测和说明，不修改 3X-UI/Xray 配置。其主要配置变化是按 512M、1G 和 2G 使用 1×、1.25× 和 1.5× BDP 档位；200 Mbps 仍为 16 MiB，1000 Mbps 下的 1G 和 2G 分别为 32 MiB 和 64 MiB。

对已经由 rc.8 或 rc.9 管理、且 `/var/lib/proxy-vps-tuning/state.json` 有效的主机，先使用前文 rc.10 总控的 `update --target v0.1.0-rc.10` 做只读兼容性检查并保存它输出的 URL、SHA-256、profile 和端口带宽。检查通过后，另选维护窗口。以 rc.9 为例，应在独立临时目录重新下载并校验 rc.9 总控，再由 rc.9 固定 Release profile 完成 verify/rollback/purge：

```bash
(
  set -e

  dvt_rc9_tmp="$(mktemp -d)"
  trap 'rm -rf -- "$dvt_rc9_tmp"' EXIT

  curl --fail --show-error --silent --location \
    --proto '=https' \
    --proto-redir '=https' \
    --connect-timeout 15 \
    --max-time 120 \
    -o "$dvt_rc9_tmp/debian-vps-tuning.sh" \
    https://github.com/alieismy/debian-vps-tuning/releases/download/v0.1.0-rc.9/debian-vps-tuning.sh

  printf '%s  %s\n' \
    '09cbb77591760fa1789729c31f64e03b29f145f50c8c419bca6057b23f492979' \
    "$dvt_rc9_tmp/debian-vps-tuning.sh" | sha256sum -c -

  bash "$dvt_rc9_tmp/debian-vps-tuning.sh" verify

  env PURGE_CREATED_SWAP=1 \
    bash "$dvt_rc9_tmp/debian-vps-tuning.sh" rollback
)

printf 'rc9_rollback_exit=%s\n' "$?"

reboot
```

重新登录后，在另一个独立临时目录中下载并校验 rc.10 总控，执行 `preflight --port <原状态中的端口带宽>`。预检通过后，再执行 `apply --port <相同带宽>`、重启和 `verify`。已安装 3X-UI 时，还应执行前文的严格验证。

`PURGE_CREATED_SWAP=1` 只尝试删除状态确认由本项目创建的 `/swapfile-proxy`。如果 `swapoff` 失败，脚本会保留 swap、fstab 行和状态，不能强制删除。外部 swap 不归 rollback 管理，也不会被删除。任何步骤失败后都应停止并保留当前状态；不得跳过重启或直接执行后续 `apply`。

旧 v5/v6 不具备 rc.8+ 的状态与所有权契约，rc.10 无法判断原 sysctl、qdisc 或 swap 的归属。迁移前应保存 `sysctl`、`tc -j qdisc show`、systemd unit、swap 和旧脚本备份，按对应旧脚本的清理流程退出旧配置并重启。确认旧 sysctl/service 文件不再生效后，才能运行 rc.10 `preflight`。出现 sysctl 冲突时，必须按实际文件归属合并或移除；rc.10 的 `rollback` 不能作为旧脚本的卸载器。

### rc.2 空状态恢复

早期 rc.2 曾在初始 JSON 构造失败时留下空 `state.json`，但 qdisc 快照仍然存在。`recover` 只处理这一已知的“首次系统写入前”遗留场景，并要求显式确认：

```bash
env ALLOW_EMPTY_STATE_RECOVERY=1 \
  bash ./debian12-1c1g-vps-tuning.sh recover
```

只有满足以下全部条件时，`recover` 才会隔离状态目录：`state.json` 是空 JSON 流；不存在项目管理文件；不存在 `/swapfile-proxy` 或对应 fstab 行；fq helper 未运行；当前 qdisc 与保存快照的语义一致。原状态目录会改名保留，不会删除。一般 JSON 损坏、有效状态，或无法证明问题发生在首次系统写入前的情况，不得使用 `recover`。

## 回滚

默认回滚系统配置，但保留脚本创建的应急 swap：

```bash
bash ./debian13-1c1g-vps-tuning.sh rollback
```

如果确认内存充足，并希望同时删除脚本创建的 swap：

```bash
env PURGE_CREATED_SWAP=1 \
  bash ./debian13-1c1g-vps-tuning.sh rollback
```

如果普通回滚保留了 swap，重新应用前必须先显式 purge，完成状态清理。`swapoff` 失败时，脚本不会删除 swap、fstab 项或所有权状态。

参数输入错误时先根据退出结果判断是否发生写入。已有 `VERIFIED` 状态且新旧参数不同时，`apply` 在事务写入前以退出码 4 拒绝，本次调用无需 rollback；按已安装参数重试或直接执行 `verify` 即可。只有确需把已安装参数改为新值时，才使用 `PURGE_CREATED_SWAP=1` 执行 rollback，重启后按新参数重新执行 `preflight` 和 `apply`。不要先执行普通 rollback；普通 rollback 默认保留脚本 swap，并留下 `SWAP_RETAINED` 状态。

如果 `apply` 曾迁移 `/etc/sysctl.conf` 中的厂商 `fq`/`bbr` 基线，`rollback` 会在删除项目 sysctl 文件前恢复完整原文件，并显式恢复安装前记录的运行时 sysctl 值。恢复前必须同时验证原始备份和当前迁移后文件的 SHA-256；如果当前文件已被管理员或其他程序修改，脚本拒绝覆盖，将状态保留为 `DEGRADED`。

## qdisc 边界

脚本支持以下 qdisc 拓扑：普通根 `fq`、`fq_codel`、默认参数的常规 `pfifo_fast`、`noqueue`，以及根为 `mq`、叶为 `fq`/`fq_codel` 的常规云网卡。HTB、TBF、CAKE、自定义 `pfifo_fast` 或其他复杂层次会在预检阶段阻断，防止 `tc qdisc replace ... root fq` 破坏既有多队列或流量整形结构。

已有根 `fq` 和 `mq` 下已有的 `fq` 叶子不会被重复替换；回滚也不会以默认 fq 重置其自定义参数。脚本只将能够可靠恢复的 `fq_codel` 根/叶或常规根 `pfifo_fast` 切换为 fq，并在回滚时按预先保存的语义恢复。

`tc` 的显示格式与命令输入格式并不完全相同。例如，状态可显示 `limit 10240p`，恢复命令仍使用 `limit 10240`。脚本通过 `tc -j` 保存数值，并按命令输入语法重建。比较 `target`、`interval` 和 `ce_threshold` 时，只容忍内核或工具回显造成的 ±1 微秒量化差异；其他受支持参数必须一致。

执行 qdisc 恢复命令后，rollback 会重新读取实际状态。只有恢复结果与原始快照语义一致，才删除状态和快照。原快照中的 `handle 0:` 表示未指定，允许内核为 classless qdisc 自动分配运行时 handle；显式非零 handle 会尝试恢复并严格比较。后置验证失败时，状态保留为 `DEGRADED`，回滚不得报告成功。

## Docker 边界

当前版本主要验证原生 systemd 部署。Docker 可能通过自身的 netfilter 规则改变 UFW 过滤路径；使用 `network_mode: host` 还会暴露容器内的全部监听端口。Docker 场景必须单独检查，不属于本脚本的防火墙范围。

## 验证与已知限制

- 本地 `bash -n`、ShellCheck、生成一致性、禁用键和编码检查不能替代目标 VPS 运行验证。
- BBR、fq、swap、重启持久性、UFW、3X-UI 和实际客户端连通性必须在 VPS 上验证。
- 当前预发布版本仅支持 amd64。
- 策略路由、TProxy、网关、Docker 防火墙和复杂 qdisc 不在支持范围内。
- 性能结果受 CPU、虚拟化超售、线路、跨境路由、客户端和加密开销影响。
- 性能验收应分别覆盖 1、3、5、10 并发；脚本不自动生成代理流量。
- 2C2G 已纳入 rc.12 资源契约和本地 fixture；真实 VPS 生命周期结果以 [验证矩阵](docs/validation.md) 为准。

详见 [运行验收说明](docs/validation.md)。

## 安全问题

公开文档和 Issue 只能保留复现所需、且不足以定位具体资产的信息，例如操作系统主版本、内核系列、CPU/内存档位、文件系统类型、脱敏后的套餐带宽和验证结论。下列内容不得公开：

- 服务商、机房、区域、订单号和实例 ID；
- 公网/私网 IP、IPv6 前缀、域名、主机名、默认网关和可关联的 DNS 记录；
- SSH、面板、订阅、API、监控和代理端口的真实组合；
- 用户名、密码、UUID、订阅 ID、API Token、Cookie、SSH 私钥、证书私钥、REALITY 私钥和 Short ID；
- 未脱敏的 3X-UI 数据库、Xray JSON、客户端链接、二维码、日志和截图；
- TcpQuality 等第三方报告 URL/ID、精确测试时间、boot ID、可反查 run ID 和授权 iperf3 服务端地址。

`diagnose` 可能输出接口地址、路由和中断信息；`DIAG_INCLUDE_SOCKET_DETAILS=1` 还可能输出连接对端。`benchmark` 元数据包含 boot ID、用户指定的 host 和 run ID；TcpQuality 节点表及 CSV 也可能包含时间和第三方节点地址。共享日志前必须逐项脱敏，不能只替换公网 IPv4。公开 Release 的脚本 SHA-256 和项目下载 URL 用于供应链校验，应予保留，不属于 VPS 隐私数据。

发现安全问题时按 [SECURITY.md](SECURITY.md) 提交，不要在公开 Issue 中附带完整资产配置。

## 许可证

[MIT License](LICENSE)
