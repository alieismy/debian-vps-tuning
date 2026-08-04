# Debian VPS Tuning

面向 Debian 12/13 小型云 VPS 的保守型主机网络调优脚本。项目以原生 systemd 部署的 **3X-UI、Xray-core、VLESS + REALITY + TCP** 为主要场景；当前目标机验收基线包含 3X-UI v3.4.2 和 Xray-core v26.6.27，但这不是对其他版本的兼容性保证。脚本同时对 S-UI、sing-box 和独立 Xray 服务提供有限的只读识别。

脚本使用 BBR + fq、受控 TCP 缓冲、常规队列参数、应急 swap 和 journald 空间限制，目标是形成可预检、可验证、可重复执行、可回滚的主机配置。它不配置代理业务、路由或防火墙，也不承诺在所有线路、虚拟化平台和负载下提高吞吐或降低延迟。

> **系统选型摘要（截至 2026-08-04）：** 新建的 1C1G、1C2G 和 2C2G VPS 默认推荐 Debian 13 minimal。Debian 13 是当前 stable；Debian 12 已转入 LTS，更适合保留既有稳定节点或满足明确的兼容约束。操作系统版本不能单独证明 BBR 可用、性能更高或空载内存更低，仍须检查虚拟化类型、运行内核和目标机资源。

> 当前预发行候选版本：`v0.1.0-rc.11`。下面的联网命令固定到该候选 Release 及其校验和资产，不跟随分支或 `latest`；Release 发布并完成公开资产重下载校验前，不应执行这些联网命令。正式 `v0.1.0` 仍需完成 [目标 VPS 运行验收](docs/validation.md)，不要把候选版本视为全平台、全带宽或性能验收已经完成。

## 联网安装与验证

以下命令均假定已经进入 VPS 的 root shell，提示符通常为 `#`，`id -u` 应输出 `0`。脚本会修改主机级网络、systemd、journald 和 swap 配置；首次执行前应确认服务商控制台或救援模式可用，并保存必要的基线信息。

### 1. 联网安装

rc.11 Release 发布并通过公开资产复核后，推荐执行其固定总控入口。它会自动识别 Debian 12/13、amd64、CPU 和内存档位，默认先执行只读 `preflight`，只有预检通过且再次明确输入 `y` 才执行 `apply`：

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
    https://github.com/alieismy/debian-vps-tuning/releases/download/v0.1.0-rc.11/debian-vps-tuning.sh

  printf '%s  %s\n' \
    '24b1b9a15ad0c50834ef450f98a6a2d25b95bd93d89d22c00422f77e38b4ad96' \
    "$dvt_tmp/debian-vps-tuning.sh" | sha256sum -c -

  bash "$dvt_tmp/debian-vps-tuning.sh"
)
```

安全引导将：

1. 显示检测到的系统、CPU、内存和档位；
2. 选择服务商端口带宽，直接按 Enter 使用 200 Mbps；
3. 显示实际调用脚本、来源和 SHA-256；
4. 先执行只读 `preflight`；
5. `preflight` 通过后再次询问，只有明确输入 `y` 才执行 `apply`。

应用成功后按提示重启：

```bash
reboot
```

### 2. 重启后联网验证

重新登录 VPS 后执行。`verify` 是只读验证，不会再次 apply，也不需要重新输入已经保存在状态中的端口带宽：

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
    https://github.com/alieismy/debian-vps-tuning/releases/download/v0.1.0-rc.11/debian-vps-tuning.sh

  printf '%s  %s\n' \
    '24b1b9a15ad0c50834ef450f98a6a2d25b95bd93d89d22c00422f77e38b4ad96' \
    "$dvt_tmp/debian-vps-tuning.sh" | sha256sum -c -

  bash "$dvt_tmp/debian-vps-tuning.sh" verify
)

printf 'verify_after_reboot_exit=%s\n' "$?"
```

`verify_after_reboot_exit=0` 才表示验证通过。保存完整输出；不要只截取最后一行。

### 3. 安装 3X-UI 后严格联网验证

推荐顺序是先完成调优和重启验证，再安装 3X-UI。安装并启动 3X-UI 后执行：

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
    https://github.com/alieismy/debian-vps-tuning/releases/download/v0.1.0-rc.11/debian-vps-tuning.sh

  printf '%s  %s\n' \
    '24b1b9a15ad0c50834ef450f98a6a2d25b95bd93d89d22c00422f77e38b4ad96' \
    "$dvt_tmp/debian-vps-tuning.sh" | sha256sum -c -

  env \
    REQUIRE_PROXY_SERVICE=1 \
    PROXY_SERVICE_UNITS='x-ui.service' \
    bash "$dvt_tmp/debian-vps-tuning.sh" verify
)

printf 'strict_verify_after_3xui_exit=%s\n' "$?"
```

严格验证要求 `x-ui.service` 处于 active，并检查 systemd 配置、3X-UI 主进程和直接 Xray 子进程的 NOFILE soft/hard limit 均不低于 65536。安装 3X-UI 后再重启一次，并重复执行这条严格验证命令，才能证明开机启动和新进程继承仍然正确。

### 4. 从早期 rc 版本执行只读升级检查

已经由 rc.9 或 rc.10 管理的 VPS，可下载 rc.11 总控执行 `update`。它会读取状态中的资源档和端口带宽，校验当前 profile、目标 `SHA256SUMS` 和目标总控脚本，依次执行当前版本 `verify` 与目标版本的只读 `update-preflight`，最后输出维护窗口所需的固定 URL、SHA-256 和迁移顺序。`update` 不执行 rollback、purge、apply 或 reboot，也不会替换已经发布的旧 Release 资产。

总控、`SHA256SUMS` 和 profile 被视为一个不可拆分的 Release 包。**不同版本的资产不得放在同一目录。**例如，rc.10 总控旁边不能放 rc.11 的 `SHA256SUMS` 和 profile；否则总控会按完整性保护规则拒绝执行，也不会自动回退联网下载。下面的联网命令以及后续 rollback 示例都使用独立 `mktemp -d` 目录，避免版本碰撞。

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
    https://github.com/alieismy/debian-vps-tuning/releases/download/v0.1.0-rc.11/debian-vps-tuning.sh

  printf '%s  %s\n' \
    '24b1b9a15ad0c50834ef450f98a6a2d25b95bd93d89d22c00422f77e38b4ad96' \
    "$dvt_tmp/debian-vps-tuning.sh" | sha256sum -c -

  bash "$dvt_tmp/debian-vps-tuning.sh" update
)
```

指定目标版本可使用 `update --target v0.1.0-rc.11`。自动发现不跨 `major.minor` 发布线：当前是 rc 时可选择同线更高 rc 或稳定版；当前是稳定版时自动排除 prerelease。跨线升级必须用 `--target` 明确指定，仍会拒绝降级和重复升级。显式指定 prerelease 代表用户主动选择该目标，不受稳定通道自动排除规则影响。

`update` 只是升级兼容性检查和计划生成器，不会改写磁盘上的旧脚本、系统调优配置或 3X-UI。检查通过不代表升级已经完成；应在维护窗口按输出和本 README 的顺序人工执行 rollback/purge、重启、目标 preflight/apply、再次重启和 verify。GitHub API 查询失败或受匿名速率限制时，使用审阅过的 `--target` 可跳过自动发现，但仍会校验目标 Release 资产。

### 5. 联网执行注意事项

- 只支持厂商最小化 Debian 12/13、`x86_64/amd64` 和 README 列出的四个 CPU/内存资源档；其他组合会拒绝执行；
- 端口带宽填写服务商套餐上限，不要填写虚拟网卡显示的链路速率；默认 200 Mbps，允许 100–1000 Mbps；
- 联网入口固定到 `v0.1.0-rc.11`，不会回退到 `master`、`main`、`latest`、HTTP 或第三方镜像；
- 上述命令在执行总控脚本前核对 rc.11 总控资产的固定 SHA-256；总控随后下载固定 Release 的 `SHA256SUMS` 和匹配 profile，并再次校验；
- 总控、`SHA256SUMS` 和 profile 必须来自同一 Release；不同版本使用不同的临时目录，不要把 rc.10 与 rc.11 资产混放在 `/root` 或同一工作目录；
- 发布后不应移动 tag 或替换同名资产，发现缺陷时应发布新版本；
- `update` 是只读升级检查，不会自动迁移配置；检查通过后仍必须另选维护窗口完成人工 rollback/apply 和两次重启；
- 脚本不配置或放行 UFW 端口，不要把 UFW 状态提示当成防火墙已配置；先确保 SSH 管理端口不会被锁死；
- `apply` 会写入系统配置并可能创建 `/swapfile-proxy`；生产 VPS 应先备份、确认控制台/救援入口，并在维护窗口执行；
- `verify` 通过证明当前配置和受检查服务符合脚本契约，不证明线路吞吐、延迟、丢包或 VLESS + REALITY + TCP 业务性能一定改善；
- `verify` 和 `preflight` 会拒绝本项目之外的重复 sysctl 定义，即使外部文件写入的值与本项目相同；不要再运行 3X-UI/X-UI 内置的 BBR 或网络优化菜单，以免重新创建 `99-bbr-x-ui.conf`；
- `rollback` 会撤销本项目管理的调优配置，应在维护窗口测试；普通 rollback 默认保留脚本创建的 swap；
- 不要在未阅读脚本和发布说明时使用 `curl ... | bash` 或 `bash <(curl ...)`。

## 真实环境验证基线

截至 2026-08-04，项目已取得以下脱敏配置类别的目标机证据。表中编号表示验证记录，不表示 VPS 数量；同一配置类别可能在同一资产的不同时期重复验证。为降低资产关联风险，公开文档不记录服务商、区域、IP、域名、主机名、面板端口、订阅地址、账号、凭据、证书标识或可反查报告 ID。

| 记录 | 操作系统与内核系列 | VPS 配置 | 存储/网络 | 已覆盖路径 | 证据边界 |
|---|---|---|---|---|---|
| C1 | Debian 13；Linux 6.12 系列 | 1 vCPU / 约 1 GiB；`debian13-1c1g` | ext4；套餐上限 1000 Mbps | 固定 rc.9 资产校验、安全引导、`preflight`、`apply`、立即/重启后 `verify`、安装 3X-UI 后严格验证；BBR、fq、swap 和 NOFILE 重启后保持 | 只证明对应 rc.9 产物和该配置类别的主路径，不继承为 rc.10/rc.11 结论 |
| C2 | Debian 12；Linux 6.1 系列 | 1 vCPU / 约 1 GiB；`debian12-1c1g` | XFS；套餐上限 200 Mbps | 退出 rc.8 后完成 rc.10 候选 `apply`、重启后普通/严格 `verify` 和重复 `apply`；重复执行未重写配置 | 不替代最终 Release 资产复核，不证明代理吞吐或线路质量 |
| C3 | Debian 12；Linux 6.1 系列 | 1 vCPU / 约 2 GiB；`debian12-1c2g` | XFS；套餐上限 200 Mbps | 退出 rc.8 后完成 rc.10 候选 `apply`、重启后普通/严格 `verify` 和重复 `apply`；3X-UI 主进程及 Xray 直接子进程 NOFILE 为 65536/65536 | 不覆盖 2C2G、512 MiB、其他文件系统或最终 Release 资产 |
| C4 | Debian 13；Linux 6.12 系列 | 1 vCPU / 约 1 GiB；`debian13-1c1g` | ext4；套餐上限 1000 Mbps | 使用隔离目录完成 rc.9→rc.10 候选迁移、重启后严格 `verify` 和重复 `apply` | 这是迁移记录，配置类别可能与 C1 重合；不代表新增一台独立 VPS |

上述记录绑定测试时的具体脚本哈希。发布前后只要脚本内容或 SHA-256 改变，就必须按 [验证矩阵](docs/validation.md) 重新建立证据，不能仅凭版本名称或配置值相同继承通过结论。rc.11 最终哈希的目标 VPS 生命周期验证仍待完成。

### 1C2G / 200 Mbps 性能观察案例

同一 Debian 12、1C2G 配置类别曾分别在旧 v6 配置和 rc.10 配置下运行 TcpQuality。公开 README 只保留聚合结果，不公开具有资产关联性的报告 URL、报告 ID、精确测试时间、服务商和区域；原始报告由维护者在私有证据集中保存。

三次报告都显示 `bbr`、`fq`、TCP 发送 `4K/64K/16M`、TCP 接收 `4K/128K/16M`。可量化摘要如下；每格依次为“零异常 / 1–20% / >20%”，普通回程按丢包分档，大包回程按重传分档，每类共 93 个判定项：

| 脱敏样本 | IPv4 回程 | IPv4 大包回程 | IPv6 回程 |
|---|---:|---:|---:|
| v6 基线样本 | 93 / 0 / 0 | 91 / 0 / 2 | 69 / 24 / 0 |
| rc.10 样本 A | 92 / 1 / 0 | 84 / 7 / 2 | 67 / 23 / 3 |
| rc.10 样本 B | 93 / 0 / 0 | 92 / 0 / 1 | 79 / 14 / 0 |

同一 rc.10 配置的两个时段样本中，IPv4 大包零重传节点从 84 变为 92，IPv6 零丢包节点从 67 变为 79；组内波动已大于或接近 v6 与 rc.10 样本 A 的组间差异。因此，这三次观测不能证明 v6 或 rc.10 的内核参数更快，也不能把个别区域或运营商的集中异常唯一归因于某条路由。测试时段、运营商链路、测速节点、共享宿主机负载和工具版本都仍是候选解释。

此外，v6 只有一次样本，rc.10 也只有两次样本，仍不足以估计稳定分布；TcpQuality 未指定 `-s` 时随机使用内置包长，默认 `-c` 每节点只发送 30 个包；TcpQuality 直接测试 VPS 网络栈，不经过 3X-UI、VLESS、REALITY 或客户端链路。现有证据以远程图片为主，没有足以公开复算的机器可读原始表格。

因此，项目不会根据这些单次报告回退 rc.10、修改 rc.11 的 17 个受管 sysctl 或增加激进参数。性能验收必须固定 TcpQuality commit、脚本 SHA-256、节点文件和 `-c/-s/-p` 参数，覆盖低负载、白天和晚高峰并重复采样，比较中位数、P95 和异常节点复现率；同时覆盖实际 VLESS + REALITY + TCP 的 1、3、5、10 并发。完整待测项见 [验证矩阵](docs/validation.md)。

## 本地使用与命令行模式

`debian-vps-tuning.sh` 是总控入口。它自动读取 Debian 主版本、amd64 架构、可用逻辑 CPU 数和实际内存，在六份操作系统/内存 profile 中选择一份；用户不需要手工判断 512M/1G/2G 文件名。总控脚本不包含另一套调优逻辑，只负责选择、SHA-256 校验和调用。

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
bash ./debian-vps-tuning.sh update --target v0.1.0-rc.11
bash ./debian-vps-tuning.sh rollback
```

在没有交互终端的自动化环境中必须明确指定 action；不会隐式进入菜单或自动 apply。`recover` 仍作为 rc.2 空状态的高级命令保留，但不出现在普通菜单中。

本项目不把下面的形式作为推荐入口：

```text
curl ... | bash
bash <(curl ...)
```

原因是它们在 root 权限下直接执行下载流，不具备独立的“下载完成 → 文件校验 → 再执行”门禁。

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

这些是已知验证基线，不是 patch level 白名单。脚本严格检查 Debian 主版本和 amd64 架构，但内核小版本变化后仍以实际 BBR/fq 能力为准。

## Debian 12/13 选型

以下结论以 2026-08-04 为时间边界。Debian 官方当前将 Debian 13 定义为 stable，最新点版本为 13.6；Debian 12 为 oldstable，常规 Release/Security/Backports 支持已经结束，LTS 持续到 2028-06-30。Debian 13 的常规支持到 2028-08-09、LTS 到 2030-06-30。参见 [Debian Releases](https://www.debian.org/releases/) 和 [Bookworm 转入 LTS 公告](https://www.debian.org/News/2026/20260712)。

因此，新建的 1C1G、1C2G 和 2C2G VPS 默认推荐 Debian 13 minimal；Debian 12 继续用于已有稳定节点、服务商 Debian 13 镜像存在已确认缺陷、或第三方软件具有明确的 Debian 12 兼容约束。不要仅为追求未经证明的性能提升对唯一生产节点执行原地大版本升级。

| 维度 | Debian 12 | Debian 13 | 项目判断 |
|---|---|---|---|
| 发布状态 | oldstable，处于 LTS | 当前 stable | 新部署优先 Debian 13 |
| 支持期限 | LTS 至 2028-06-30；少数包可能不在 LTS 覆盖范围 | 常规支持至 2028-08-09，LTS 至 2030-06-30 | 公网长期节点优先更长的常规支持窗口 |
| 典型内核系列 | Linux 6.1 LTS | Linux 6.12 LTS | 13 有更新的内核和虚拟化驱动，但不保证吞吐更高 |
| 用户态基线 | systemd 252、OpenSSH 9.2、OpenSSL 3.0、glibc 2.36 | systemd 257、OpenSSH 10.0、OpenSSL 3.5、glibc 2.41 | 新软件兼容性更有利；旧脚本和闭源 agent 需验证 |
| 迁移风险 | 现有部署成熟，变更较少 | 原地升级需检查网卡名、SSH、`/tmp` 和 sysctl 加载行为 | 关键节点优先新建 Debian 13 并行迁移 |

Debian 13 的主要优点：

- 当前 stable，常规安全维护和 LTS 生命周期更长；
- Linux 6.12 LTS、systemd 257、OpenSSH 10.0p1 和 OpenSSL 3.5 提供更新的内核、虚拟化和系统组件；
- Debian 官方提供 GenericCloud、NoCloud 和 OpenStack 等云镜像；
- 3X-UI 官方安装脚本按发行版 ID `debian` 选择 APT 和 Debian systemd unit，没有发现 Debian 12-only 的版本判断；
- Xray-core 官方 Linux 构建使用 `CGO_ENABLED=0`，通常不依赖 Debian 12/13 的特定 glibc ABI。

Debian 13 的主要限制和迁移风险：

- Debian 13 不保证比 Debian 12 占用更少内存，也不保证 Xray 吞吐、延迟或并发能力自动提高；
- `/tmp` 默认使用按需分配的 tmpfs，最大值可达到内存的 50%；1C1G 节点应限制大型临时文件和日志；
- `systemd-sysctl` 不再读取 `/etc/sysctl.conf`，本地配置应放入 `/etc/sysctl.d/*.conf`；本项目使用该规范路径，但旧调优脚本可能不兼容；
- Debian 12 原地升级到 13 时，部分系统的可预测网卡名可能改变，硬编码接口名的网络、防火墙或 qdisc 配置必须提前检查；
- OpenSSH、OpenSSL、Python 和 systemd 的大版本变化可能影响旧密钥、自动化脚本或服务商闭源 agent；
- 服务商提供“Debian 13”镜像不等于运行内核一定为 6.12，也不证明 cloud-init、IPv6 和网络模板已经通过验证。

相关变化见 [Debian 13 发布公告](https://www.debian.org/News/2025/20250809) 和 [Debian 13 Release Notes：已知问题](https://www.debian.org/releases/stable/release-notes/issues.en.html)。

### 按 VPS 资源档选择

| VPS 配置 | 推荐系统 | 适用判断 | 主要约束 |
|---|---|---|---|
| 1C1G | Debian 13 minimal | 新建节点的默认选择；无桌面、少量必要服务 | 1 GiB 是 Debian 13 无桌面安装的推荐内存，不代表 3X-UI/Xray 仍有固定余量；应监控 RSS、FD、CPU steal、softirq、日志和 `/tmp` |
| 1C2G | Debian 13 | 三档中较均衡，更新和临时任务的内存余量优于 1C1G | 单核仍可能成为加密、软中断或高并发瓶颈 |
| 2C2G | Debian 13 | 更适合多连接、多入站或较高 CPU 负载 | 2 vCPU 不保证吞吐翻倍，也不能仅凭 CPU 数启用 RPS/RFS/XPS 或 IRQ affinity |

Debian 13 官方对无桌面 amd64 安装给出的最低内存为 512 MB、推荐内存为 1 GB；服务器实际需求取决于运行服务，不能据此推导“空载固定约 100 MB”或代理容量。参见 [Debian 13 amd64 安装要求](https://www.debian.org/releases/trixie/amd64/ch03s04.en.html)。

### 虚拟化类型比发行版名称更接近内核事实

KVM、VMware、Hyper-V 等完整虚拟机通常运行来宾系统自己的 Debian 内核；LXC、Incus 和部分 OpenVZ 类系统容器共享宿主机内核。容器内的 `/etc/os-release` 即使显示 Debian 13，也不能证明内核为 6.12、BBR 可加载或 qdisc/sysctl 具有完整权限。选择 profile 前至少检查：

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

六份脚本分别校验操作系统、CPU、内存、运行内核能力和 qdisc 拓扑，避免把 Debian 12 的环境假设直接复制到 Debian 13。操作系统选择不能替代目标机 `preflight`。

## 脚本选择

| 文件 | 操作系统 | CPU 范围 | 内存档位 | swap 默认值/上限 |
|---|---|---:|---:|---:|
| `debian12-1c512m-vps-tuning.sh` | Debian 12 | 1 vCPU | 384–767 MiB | 1024/2048 MiB |
| `debian12-1c1g-vps-tuning.sh` | Debian 12 | 1 vCPU | 768–1535 MiB | 1024/2048 MiB |
| `debian12-1c2g-vps-tuning.sh` | Debian 12 | 1–2 vCPU | 1536–3072 MiB | 1024/4096 MiB |
| `debian13-1c512m-vps-tuning.sh` | Debian 13 | 1 vCPU | 384–767 MiB | 1024/2048 MiB |
| `debian13-1c1g-vps-tuning.sh` | Debian 13 | 1 vCPU | 768–1535 MiB | 1024/2048 MiB |
| `debian13-1c2g-vps-tuning.sh` | Debian 13 | 1–2 vCPU | 1536–3072 MiB | 1024/4096 MiB |

文件名和状态 ID 中的 `1c2g` 是兼容名称；同一 2G profile 同时承载 1C2GB 和 2C2GB 两个资源档，不建立重复的 2C2G 文件，已有 `debian12-1c2g`/`debian13-1c2g` 状态无需迁移。六份资源脚本仍执行自己的系统、架构、CPU 和内存校验；总控选择不能绕过底层预检。2C512MB、2C1GB、3 vCPU 以上和边界外内存会明确拒绝。

脚本以 200 Mbps 为默认端口上限，也允许明确设置 100–1000 Mbps。这里应填写 VPS 套餐或服务商给出的上限，不要把虚拟网卡显示的链路速率当成套餐限速。

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

`net.ipv4.tcp_fastopen=3` 只启用 Linux 的客户端/服务端基础能力。Linux 内核文档明确区分全局位图与单个 listener 的 `TCP_FASTOPEN` socket option；Xray 也通过 `streamSettings.sockopt.tcpFastOpen` 控制入站或出站 socket。因而下面的命令没有输出时，只能说明 3X-UI 生成的 Xray 配置中没有显式 `tcpFastOpen` 字段，**不能据此证明 TFO 已启用，也不能证明 TFO 已禁用**：

```bash
jq '.. | objects | select(has("tcpFastOpen")) | .tcpFastOpen' \
  /usr/local/x-ui/bin/config.json
```

当前 `verify` 和 `diagnose` 会只读报告该字段是否显式存在，但不会修改代理配置。不要直接编辑 `/usr/local/x-ui/bin/config.json`：它是 3X-UI 生成文件，面板重建配置时可能覆盖。只有在当前 3X-UI 版本明确提供对应的入站/出站 sockopt 或高级配置入口、并完成客户端兼容性测试后，才通过面板配置；配置后重新检查生成 JSON 和实际连接。TFO 主要影响握手阶段，不能替代 BBR、fq 或线路质量，也不保证跨所有中间设备都获益。

同理，主机的 `tcp_keepalive_time/intvl/probes` 只影响已经启用 `SO_KEEPALIVE` 且没有被应用覆盖的 socket。Xray 官方文档说明：入站 Keep-Alive 默认关闭，配置 `tcpKeepAliveIdle` 或 `tcpKeepAliveInterval` 才启用；出站还有自己的默认值。因此，主机 sysctl 不能单独证明 Xray 连接正在采用这些 keepalive 值。参见 [Linux IP sysctl](https://docs.kernel.org/networking/ip-sysctl.html) 和 [Xray Sockopt](https://xtls.github.io/en/config/transports/sockopt.html)。

## 脚本不会修改什么

- 不安装、升级或降级 3X-UI、S-UI、sing-box、Xray；
- 不读取或修改 3X-UI 数据库、Xray JSON、UUID、REALITY 私钥、证书私钥或面板凭据；
- 不增加、删除或重排 UFW 规则；
- 不开放 SSH、面板、订阅或代理端口；
- 不重启 `x-ui.service`、`xray.service`、`s-ui.service` 或 `sing-box.service`；若 apply 时 x-ui 已在运行，普通验证会提示重启服务或主机后再做严格验证；
- 不配置 RPS/RFS/XPS、IRQ affinity、CPU affinity 或 `GOMAXPROCS`；
- 不修改 DNS、路由、策略路由、MTU、IPv6 启停策略；
- 不开启 IP forwarding、NAT 或 TProxy；
- 不修改 `ip_local_port_range`、`tcp_mem`、`fs.file-max` 或 conntrack 上限；
- 不接管 Docker 与 UFW 的数据包处理关系。

## VPS 初始化

以下命令均假定已经进入 root shell（提示符通常为 `#`，`id -u` 输出 `0`），因此示例不使用 `sudo`。厂商最小化镜像通常可以直接以 root 登录，也可能没有安装 `sudo`。

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

如需清理自动安装且不再需要的软件包，先模拟并检查列表：

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

这是 root 级系统脚本，不建议跳过检查直接使用 `curl | bash`。总控脚本随后还会对实际调用的资源脚本执行一次 SHA-256 校验。

## 使用方法

优先使用总控脚本。以下独立脚本方法保留给离线、审计和故障恢复场景，以 Debian 13、1C1G、200 Mbps 为例；使用者必须替换为与系统、CPU 和内存匹配的文件。

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
- `/etc/sysctl.conf` 或 `/etc/sysctl.d` 存在重复键；
- qdisc 拓扑复杂到无法可靠恢复；
- 固定 swap 路径已被其他文件占用；
- 磁盘空间不足。

自动 swap 文件只在 `ext2`、`ext3`、`ext4` 和 `xfs` 根文件系统上启用。Btrfs、ZFS、overlay、NFS、FUSE 以及未验证的其他文件系统会给出警告并跳过自动创建 swap，不影响其他网络配置继续应用。

### 2. 应用

```bash
env PORT_SPEED_MBPS=200 \
  bash ./debian13-1c1g-vps-tuning.sh apply
```

应用成功后重启：

```bash
reboot
```

如果调优先于 3X-UI 安装，脚本会先创建 `x-ui.service` drop-in；此时 `verify` 将“尚未安装代理服务”作为正常待安装状态，不记为警告。以后安装 3X-UI 时 systemd 会自动读取该配置。

### 3. 重启后验证

```bash
bash ./debian13-1c1g-vps-tuning.sh verify
bash ./debian13-1c1g-vps-tuning.sh status
```

### 4. 安装 3X-UI 后验证

固定使用 3X-UI v3.4.2 时，应从官方 `v3.4.2` tag/release 获取安装脚本或资产，不要使用指向 `master` 的安装入口来期待固定版本。

安装并配置 3X-UI 后：

```bash
env REQUIRE_PROXY_SERVICE=1 \
  PROXY_SERVICE_UNITS='x-ui.service' \
  bash ./debian13-1c1g-vps-tuning.sh verify
```

脚本会检查 `x-ui.service` 的 systemd 配置值、主进程及其直接子进程的 `/proc/<PID>/limits`。严格验证要求配置和运行时的 soft/hard limit 均不低于 65536。

### 5. 只读诊断

```bash
bash ./debian-vps-tuning.sh diagnose
```

`diagnose` 默认做 5 秒前后采样，输出 TCP 重传/超时/监听溢出/TFO、每 CPU softnet、整机 CPU user/system/softirq/steal、接口收发/丢包/错误和可识别 ethtool 错误计数的增量，并保存 qdisc 前后状态、默认路由、RPS/XPS/IRQ 以及代理主进程/直接子进程的 CPU time、RSS、线程数和 FD 数。进程证据不输出命令行参数。它不发起性能流量，也不修改系统；建议在采样窗口内由客户端复现实际 VLESS + REALITY + TCP 负载：

```bash
env DIAG_INTERVAL_SECONDS=15 \
  bash ./debian-vps-tuning.sh diagnose
```

默认不输出连接对端和进程详情。如确需采集 `ss -tinp`，应在保存和共享日志前脱敏：

```bash
env DIAG_INCLUDE_SOCKET_DETAILS=1 \
  bash ./debian-vps-tuning.sh diagnose
```

### 6. 显式 iperf3 benchmark

`benchmark` 不改变系统配置，但会主动产生高带宽 TCP 流量。它要求用户自行准备并授权使用 iperf3 服务端，脚本不会安装软件包、开启端口或选择公共服务器。默认顺序执行上传和下载：每个方向先做 3 秒预热并从统计中排除，再记录 10 秒有效窗口；两个方向分别输出 iperf3 JSON、TCP/softnet/CPU/接口增量及 qdisc 前后统计。运行元数据包含 UTC 时间、run ID、脚本版本与 SHA-256、profile、boot ID、管理状态、网络参数、拥塞控制、默认 qdisc 和 iperf3 版本：

```bash
env BENCHMARK_HOST='iperf.example.com' \
  BENCHMARK_PORT=5201 \
  BENCHMARK_SECONDS=10 \
  BENCHMARK_OMIT_SECONDS=3 \
  BENCHMARK_PARALLEL=1 \
  BENCHMARK_IP_FAMILY=4 \
  BENCHMARK_DIRECTION=both \
  BENCHMARK_RUN_ID='case-1c1g-ipv4-a1' \
  bash ./debian-vps-tuning.sh benchmark
```

`BENCHMARK_IP_FAMILY=4` 或 `6` 用于固定地址族，`auto` 继续由系统解析和连接选择；比较 IPv4/IPv6 时必须分别执行并保存默认路由。`BENCHMARK_OMIT_SECONDS=0` 可用于刻意观察包含 slow start 的短连接体验，非零值用于稳态吞吐比较，二者不得混为同一序列。该结果只测量 VPS 到 iperf3 服务端的直连 TCP，不经过 VLESS + REALITY + TCP 客户端链路；不能拿公共测试点的单次结果直接判断代理体验。`BENCHMARK_PARALLEL` 限制为 1–4，1C1G/1C2G 的基线测试先用 1。iperf3 参数语义见 [ESnet 官方文档](https://software.es.net/iperf/invoking.html)。

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

100–1000 内的任意整数都可以使用，500 Mbps 也在总控菜单中提供。rc.11 保持 rc.10 的网络参数：默认目标 RTT 为 200 ms，按资源档分别采用 1×、1.25×、1.5×BDP 目标，再向上选择 16/32/64 MiB，并受 512M/1G/2G profile 的 16/32/64 MiB 上限约束：

| 资源档 | BDP 系数 | 100 Mbps | 200 Mbps | 500 Mbps | 1000 Mbps |
|---|---:|---:|---:|---:|---:|
| 512M | 1× | 16 MiB | 16 MiB | 16 MiB | 16 MiB（截断警告） |
| 1G | 1.25× | 16 MiB | 16 MiB | 16 MiB | 32 MiB |
| 2G | 1.5× | 16 MiB | 16 MiB | 32 MiB | 64 MiB |

主力 200 Mbps 的所有资源档均为 16 MiB。512M 档优先限制内存压力；1G/2G 档逐级增加高 BDP 余量，只有 512M/1000 Mbps/200 ms 组合触发资源截断警告。这里的上限是自动调优允许的最大 socket 缓冲，不表示每条连接会立即占满。Linux TCP 接收缓冲仍由自动调优按连接需求增长；应用显式 `setsockopt(SO_RCVBUF)` 时可能改变该行为。资源截断是内存保护，不代表带宽输入无效。没有持续监控和高 BDP 证据时，不建议手工指定 `BUF_MAX`。

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
| `BENCHMARK_RUN_ID` | 自动生成 | 可选的 1–96 字符运行标签；仅限字母、数字、点、下划线、冒号和连字符 |
| `UPDATE_TAG` | 自动发现 | `update` 的目标 Release；等价命令行参数为 `--target` |

不支持自定义 swap 文件路径；脚本只可能创建 `/swapfile-proxy`。

## 状态与重复执行

状态保存在 root-only JSON 中：

```text
/var/lib/proxy-vps-tuning/state.json
```

同一脚本版本、同一参数下重复执行 `apply` 时，脚本先验证当前配置；验证通过后不重复写入。通过总控脚本重复执行 `apply` 且未提供 `--port` 或 `PORT_SPEED_MBPS` 时，会复用状态中已安装的端口带宽；显式参数仍优先。状态版本与当前脚本不同、使用不同资源脚本或改变带宽/缓冲参数时，`apply` 会要求先回滚，避免把“旧配置仍可验证”误报为“新版本已经安装”。

状态更新先由 `jq` 写入同目录临时文件，随后检查命令退出码、非空、仅含一个 JSON 对象及完整 schema，全部通过后才原子替换 `state.json`。空文件、空白文件、多个 JSON 文档或更新失败均不得覆盖上一个有效状态。

### 从 rc.10 升级到 rc.11

rc.11 不改变 rc.10 的 17 个 sysctl、qdisc、swap、journald、NOFILE 或状态 schema；主要变化是增强只读 `diagnose` 和用户授权的 `benchmark`。由于六份 profile 的脚本版本和 SHA-256 已改变，已有 rc.10 状态仍不得直接由 rc.11 重复 `apply`。先用 rc.11 总控执行 `update --target v0.1.0-rc.11` 做只读检查；通过后在维护窗口使用固定且已校验的 rc.10 Release 执行 `verify`、`PURGE_CREATED_SWAP=1 rollback` 和重启，再使用独立目录中的 rc.11 执行 `preflight`、`apply`、重启和严格 `verify`。rc.10 与 rc.11 的总控、清单和 profile 不得放在同一目录。

只需要使用新增诊断或 benchmark、且不需要把管理状态迁移到 rc.11 时，可以继续由已安装的 rc.10 负责配置生命周期，并把 rc.11 profile 放在独立临时目录执行只读 `diagnose` 或显式授权的 `benchmark`；不得用 rc.11 `apply` 覆盖 rc.10 状态。

### 从 rc.8/rc.9 或旧 v5/v6 升级到 rc.10

`tcpFastOpen` 查询无输出本身不是必须升级的故障：rc.10 只增加检测与说明，仍不会替用户修改 3X-UI/Xray 配置。升级 rc.10 的主要配置变化是按 512M/1G/2G 使用 1×/1.25×/1.5×BDP 档位；200 Mbps 仍为 16 MiB，1000 Mbps 的 1G/2G 分别为 32/64 MiB。

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

重新登录后，使用另一个独立临时目录重新下载并校验 rc.10 总控，执行 `preflight --port <原状态中的端口带宽>`；确认通过后再执行 `apply --port <相同带宽>`、重启并 `verify`。安装了 3X-UI 时还应执行前文严格验证。`PURGE_CREATED_SWAP=1` 只会尝试删除状态确认由本项目创建的 `/swapfile-proxy`；如果 `swapoff` 失败，脚本保留 swap、fstab 行和状态，不应强制删除。若使用的是外部 swap，rollback 不会接管或删除它。任何一步失败都应停止并保留当前状态，不能跳过重启或直接执行后续 apply。

旧 v5/v6 没有 rc.8+ 的同一状态/所有权契约，rc.10 不会猜测其原始 sysctl、qdisc 或 swap 归属。应先保存 `sysctl`、`tc -j qdisc show`、systemd unit、swap 和旧脚本备份，按对应旧脚本的清理流程退出旧配置并重启；确认旧 sysctl/service 文件不再生效后，再运行 rc.10 `preflight`。出现 sysctl 冲突时必须先按真实文件归属合并或移除，不能用 rc.10 `rollback` 冒充旧脚本卸载器。

### rc.2 空状态恢复

早期 rc.2 曾在初始 JSON 构造失败时留下空 `state.json`，但 qdisc 快照仍然存在。`recover` 只处理这一已知的“首次系统写入前”遗留场景，并要求显式确认：

```bash
env ALLOW_EMPTY_STATE_RECOVERY=1 \
  bash ./debian12-1c1g-vps-tuning.sh recover
```

该操作只有在以下条件全部成立时才会隔离状态目录：`state.json` 是空 JSON 流、没有项目管理文件、没有 `/swapfile-proxy` 或对应 fstab 行、fq helper 未运行，并且当前 qdisc 与保存快照语义一致。原状态目录会改名保留证据，不会被删除。一般 JSON 损坏、有效状态或无法证明发生在首次系统写入前的场景不得使用 `recover`。

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

如果普通回滚保留了 swap，重新应用前必须先用上面的显式 purge 完成状态清理。`swapoff` 失败时脚本不会删除 swap、fstab 项或所有权状态。

## qdisc 边界

脚本支持普通根 `fq`、`fq_codel`、默认参数的常规 `pfifo_fast`、`noqueue`，以及根 `mq` 且叶子为 `fq`/`fq_codel` 的常规云网卡。复杂的 HTB、TBF、CAKE、自定义 `pfifo_fast` 或其他层次会在预检阶段阻断。这样可以避免用简单的 `tc qdisc replace ... root fq` 破坏现有多队列或流量整形结构。

已有根 `fq` 和 `mq` 下已有的 `fq` 叶子不会被重复替换，回滚时也不会用默认 fq 重置其自定义参数。脚本只把确认支持恢复的 `fq_codel` 根/叶子或常规根 `pfifo_fast` 切换为 fq，并在回滚时按预先保存的语义恢复。

`tc` 的显示格式与命令输入格式并不完全相同，例如状态输出可显示 `limit 10240p`，恢复命令仍使用 `limit 10240`。脚本按 `tc -j` 保存数值并按命令输入语法重建；比较 `target`、`interval` 和 `ce_threshold` 时只容忍内核/工具回显产生的 ±1 微秒量化差异，其他受支持参数仍要求一致。

rollback 在执行 qdisc 恢复命令后会重新读取实际状态；只有恢复结果与原始快照语义一致，才允许删除状态和快照。原快照中的 `handle 0:` 表示未指定，允许内核为 classless qdisc 自动分配运行时 handle；显式非零 handle 则会尝试恢复并严格比较。后置验证失败时状态保留为 `DEGRADED`，不得报告完整回滚。

## Docker 边界

首个版本主要验证原生 systemd 部署。Docker 可能通过自己的 netfilter 规则改变 UFW 的过滤路径；使用 `network_mode: host` 还会暴露容器内所有监听端口。Docker 场景需要独立检查，不属于本脚本的防火墙承诺。

## 验证与已知限制

- 本地 `bash -n`、ShellCheck、生成一致性、禁用键和编码检查不等于目标 VPS 运行成功；
- BBR、fq、swap、重启持久性、UFW、3X-UI 和实际客户端连通性必须在 VPS 上验证；
- 当前预发布范围只支持 amd64；
- 策略路由、TProxy、网关、Docker 防火墙和复杂 qdisc 不在范围内；
- 性能结果受 CPU、虚拟化超售、线路、跨境路由、客户端和加密开销影响。
- 性能验收应分别覆盖 1、3、5、10 并发；脚本不会自动生成代理流量。
- 2C2G 已纳入 rc.11 资源契约和本地 fixture，真实 VPS 生命周期结果以 [验证矩阵](docs/validation.md) 为准。

详见 [运行验收说明](docs/validation.md)。

## 安全问题

公开文档和 Issue 只应保留与复现直接相关、且不足以定位具体资产的信息，例如操作系统主版本、内核系列、CPU/内存档位、文件系统类型、脱敏后的套餐带宽和验证结论。下列内容不得公开：

- 服务商、机房、区域、订单号和实例 ID；
- 公网/私网 IP、IPv6 前缀、域名、主机名、默认网关和可关联的 DNS 记录；
- SSH、面板、订阅、API、监控和代理端口的真实组合；
- 用户名、密码、UUID、订阅 ID、API Token、Cookie、SSH 私钥、证书私钥、REALITY 私钥和 Short ID；
- 未脱敏的 3X-UI 数据库、Xray JSON、客户端链接、二维码、日志和截图；
- TcpQuality 等第三方报告 URL/ID、精确测试时间、boot ID、可反查 run ID 和授权 iperf3 服务端地址。

`diagnose` 可能输出接口地址、路由和中断信息；`DIAG_INCLUDE_SOCKET_DETAILS=1` 还可能输出连接对端。`benchmark` 元数据包含 boot ID、用户指定 host 和 run ID。共享日志前必须逐项脱敏，不能只替换公网 IPv4。公开 Release 的脚本 SHA-256 和项目下载 URL属于供应链校验信息，应保留，不属于 VPS 隐私数据。

发现安全问题时按 [SECURITY.md](SECURITY.md) 提交，不要在公开 Issue 中附带完整资产配置。

## 许可证

[MIT License](LICENSE)
