# Debian VPS Tuning

面向 Debian 12/13 小型云 VPS 的保守型主机网络调优脚本。项目以原生 systemd 部署的 **3X-UI v3.4.2、Xray-core v26.6.27、VLESS + REALITY + TCP** 为主要验收场景，同时保留对 S-UI、sing-box 和独立 Xray 服务的只读识别能力。

脚本使用 BBR + fq、受控 TCP 缓冲、常规队列参数、应急 swap 和 journald 空间限制，目标是形成可预检、可验证、可重复执行、可回滚的配置。它不承诺在所有线路上提高吞吐或降低延迟。

> 当前公开版本：[`v0.1.0-rc.9`](https://github.com/alieismy/debian-vps-tuning/releases/tag/v0.1.0-rc.9)，标记为 Pre-release。正式 `v0.1.0` 仍需完成 [目标 VPS 运行验收](docs/validation.md)，不要把候选版本视为全平台、全带宽或性能验收已经完成。

## 联网安装与验证

以下命令均假定已经进入 VPS 的 root shell，提示符通常为 `#`，`id -u` 应输出 `0`。脚本会修改主机级网络、systemd、journald 和 swap 配置；首次执行前应确认服务商控制台或救援模式可用，并保存必要的基线信息。

### 1. 联网安装

推荐先执行 rc.9 固定 Release 的总控入口。它会自动识别 Debian 12/13、amd64、CPU 和内存档位，默认先执行只读 `preflight`，只有预检通过且再次明确输入 `y` 才执行 `apply`：

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
    https://github.com/alieismy/debian-vps-tuning/releases/download/v0.1.0-rc.9/debian-vps-tuning.sh

  printf '%s  %s\n' \
    '09cbb77591760fa1789729c31f64e03b29f145f50c8c419bca6057b23f492979' \
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
    https://github.com/alieismy/debian-vps-tuning/releases/download/v0.1.0-rc.9/debian-vps-tuning.sh

  printf '%s  %s\n' \
    '09cbb77591760fa1789729c31f64e03b29f145f50c8c419bca6057b23f492979' \
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
    https://github.com/alieismy/debian-vps-tuning/releases/download/v0.1.0-rc.9/debian-vps-tuning.sh

  printf '%s  %s\n' \
    '09cbb77591760fa1789729c31f64e03b29f145f50c8c419bca6057b23f492979' \
    "$dvt_tmp/debian-vps-tuning.sh" | sha256sum -c -

  env \
    REQUIRE_PROXY_SERVICE=1 \
    PROXY_SERVICE_UNITS='x-ui.service' \
    bash "$dvt_tmp/debian-vps-tuning.sh" verify
)

printf 'strict_verify_after_3xui_exit=%s\n' "$?"
```

严格验证要求 `x-ui.service` 处于 active，并检查 systemd 配置、3X-UI 主进程和直接 Xray 子进程的 NOFILE soft/hard limit 均不低于 65536。安装 3X-UI 后再重启一次，并重复执行这条严格验证命令，才能证明开机启动和新进程继承仍然正确。

### 4. 联网执行注意事项

- 只支持厂商最小化 Debian 12/13、`x86_64/amd64` 和 README 列出的四个 CPU/内存资源档；其他组合会拒绝执行；
- 端口带宽填写服务商套餐上限，不要填写虚拟网卡显示的链路速率；默认 200 Mbps，允许 100–1000 Mbps；
- 联网入口固定到 `v0.1.0-rc.9`，不会回退到 `master`、`main`、`latest`、HTTP 或第三方镜像；
- 上述命令在执行总控脚本前核对 rc.9 总控资产的固定 SHA-256；总控随后下载固定 Release 的 `SHA256SUMS` 和匹配 profile，并再次校验；
- rc.9 Release 当前未启用 GitHub Release immutability；发布后不应移动 tag 或替换同名资产，发现缺陷时应发布新版本；
- 脚本不配置或放行 UFW 端口，不要把 UFW 状态提示当成防火墙已配置；先确保 SSH 管理端口不会被锁死；
- `apply` 会写入系统配置并可能创建 `/swapfile-proxy`；生产 VPS 应先备份、确认控制台/救援入口，并在维护窗口执行；
- `verify` 通过证明当前配置和受检查服务符合脚本契约，不证明线路吞吐、延迟、丢包或 VLESS + REALITY + TCP 业务性能一定改善；
- `rollback` 会撤销本项目管理的调优配置，应在维护窗口测试；普通 rollback 默认保留脚本创建的 swap；
- 不要在未阅读脚本和发布说明时使用 `curl ... | bash` 或 `bash <(curl ...)`。

## rc.9 真实环境验证状态

2026-08-03 已取得一台真实 VPS 的主路径证据：

| 项目 | 实测值 |
|---|---|
| 操作系统 | Debian GNU/Linux 13 (trixie) |
| 内核 | `6.12.100+deb13-amd64` |
| CPU / 内存 | 1 vCPU / 929 MiB，识别为 1C1GB |
| 根文件系统 | ext4 |
| 服务商端口上限 | 1000 Mbps |
| profile | `debian13-1c1g` |
| 总控/profile 版本 | `0.1.0-rc.9` |
| profile SHA-256 | `9fd70c593b83d41337c6dfcada737855ce583e8bc3451ee8bb5952db850c81c6` |
| 代理平台 | 3X-UI，systemd unit 为 `x-ui.service` |

已通过：

- 固定 rc.9 Release 总控、清单和 profile 的联网下载及 SHA-256 校验；
- 交互安全引导、1000 Mbps 选择、`preflight`、首次 `apply` 和立即验证，均为退出码 0、警告 0；
- 安装 3X-UI 前重启，联网 `verify` 退出码 0、警告 0；
- 重启后 `proxy-vps-fq.service` 为 loaded/active/enabled，BBR、默认 fq、`eth0` 实际根 fq 和 `/swapfile-proxy` 均保持；
- 安装 3X-UI 后严格验证，以及再次重启后的严格验证，均为退出码 0、警告 0；
- 重启后 `x-ui.service` 主进程和直接 Xray 子进程的 NOFILE soft/hard limit 均为 65536/65536。

该结果只证明 **Debian 13、1C1G、1000 Mbps、ext4、3X-UI** 这一组合的上述主路径。尚未在这台机器上完成无显式端口参数的重复 `apply`、rollback/purge、VLESS + REALITY + TCP 客户端连通性和 1/3/5/10 并发性能测试，也不能替代 Debian 12、512 MiB、2G、2C2G 或其他带宽组合的目标机证据。完整状态见 [验证矩阵](docs/validation.md)。

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
- 少于 10 名用户、以 TCP 为主的小型代理服务器；
- 内核实际提供 BBR 和 fq。

主要验证基线：

| 系统 | 内核基线 | 资源脚本 |
|---|---|---|
| Debian 12 (bookworm) | `6.1.0-51-cloud-amd64` / `6.1.177-1` | 1C512MB、1C1GB、1C2GB、2C2GB |
| Debian 13 (trixie) | `6.12.100+deb13-cloud-amd64` / `6.12.100-1` | 1C512MB、1C1GB、1C2GB、2C2GB |

这些是已知验证基线，不是 patch level 白名单。脚本严格检查 Debian 主版本和 amd64 架构，但内核小版本变化后仍以实际 BBR/fq 能力为准。

## 为什么同时支持 Debian 12 和 Debian 13

Debian 12 适合已经部署、依赖既定兼容性或希望维持现有环境的 VPS。Debian 13 适合已经验证代理软件兼容性的新部署，并提供更新的系统组件和 6.12 系列内核。项目不宣称 Debian 12 天然比 Debian 13 更快或更安全，也不建议仅为了网络调优跨大版本升级。

六份脚本分开校验操作系统、CPU 和内存档位，避免把 Debian 12 的内核假设直接复制到 Debian 13。选择系统时应优先考虑 VPS 厂商镜像质量、应用兼容性、现有备份和个人运维能力。

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

自动 swap 文件只在 `ext2`、`ext3`、`ext4` 和 `xfs` 根文件系统上启用。你的 XFS SSD 属于允许范围。Btrfs、ZFS、overlay、NFS、FUSE 以及未验证的其他文件系统会给出警告并跳过自动创建 swap，不影响其他网络配置继续应用。

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

`diagnose` 只采集系统、路由、网卡队列、qdisc 统计、socket 汇总和 softnet 采样，不发起性能流量，也不修改系统。输出可用于定位丢包、CPU softnet 压力或队列异常，但不能代替真实客户端测试。

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

100–1000 内的任意整数都可以使用，500 Mbps 也在总控菜单中提供。默认目标 RTT 为 200 ms。自动缓冲先按 BDP 选择 16/32/64 MiB，再受内存档上限约束：512 MiB 档最多 16 MiB、1 GiB 档最多 32 MiB、2 GiB 档最多 64 MiB。512 MiB 高 BDP 场景被限制时会明确警告覆盖 RTT 不足；这是内存保护，不代表输入无效。没有持续监控和高 BDP 证据时，不建议手工指定 `BUF_MAX`。

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

不支持自定义 swap 文件路径；脚本只可能创建 `/swapfile-proxy`。

## 状态与重复执行

状态保存在 root-only JSON 中：

```text
/var/lib/proxy-vps-tuning/state.json
```

同一参数下重复执行 `apply` 时，脚本先验证当前配置；验证通过后不重复写入。通过总控脚本重复执行 `apply` 且未提供 `--port` 或 `PORT_SPEED_MBPS` 时，会复用状态中已安装的端口带宽；显式参数仍优先。使用不同资源脚本或改变带宽/缓冲参数前，应先回滚现有配置。

状态更新先由 `jq` 写入同目录临时文件，随后检查命令退出码、非空、仅含一个 JSON 对象及完整 schema，全部通过后才原子替换 `state.json`。空文件、空白文件、多个 JSON 文档或更新失败均不得覆盖上一个有效状态。

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
- 2C2G 已纳入 rc.9 资源契约和本地 fixture，真实 VPS 生命周期结果以 [验证矩阵](docs/validation.md) 为准。

详见 [运行验收说明](docs/validation.md)。

## 安全问题

不要在公开 Issue 中提交密码、UUID、REALITY 私钥、SSH 私钥、API Token、证书私钥或未脱敏的完整代理配置。参见 [SECURITY.md](SECURITY.md)。

## 许可证

[MIT License](LICENSE)
