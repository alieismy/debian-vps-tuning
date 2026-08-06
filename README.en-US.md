

# Debian VPS Tuning

A conservative host network tuning script for Debian 12/13 small cloud VPS. The project primarily targets natively systemd-deployed **3X-UI, Xray-core, VLESS + REALITY + TCP** scenarios; the current target machine acceptance baseline includes 3X-UI v3.4.2 and Xray-core v26.6.27, but this is not a compatibility guarantee for other versions. The script also provides limited read-only recognition for S-UI, sing-box, and standalone Xray services.

The script uses BBR + fq, controlled TCP buffering, standard queue parameters, emergency swap, and journald space limits, aiming to form a host configuration that is preflight-checkable, verifiable, idempotent/repeatable, and rollable back. It does not configure proxy services, routing, or firewalls, nor does it promise to increase throughput or reduce latency across all routes, virtualization platforms, and loads.

> **System Selection Summary (as of 2026-08-04):** Newly created 1C1G, 1C2G, and 2C2G VPS instances are recommended to use Debian 13 minimal by default. Debian 13 is the current stable release; Debian 12 has transitioned to LTS and is better suited for retaining existing stable nodes or meeting explicit compatibility constraints. The OS version alone does not guarantee BBR availability, higher performance, or lower idle memory usage; virtualization type, running kernel, and target machine resources must still be verified.

> Current release candidate: `v0.1.0-rc.11`. The following online commands are pinned to this specific RC release and its checksum assets, and will not follow branches or `latest`; do not execute these online commands before the release is published and public assets have been re-downloaded and verified. The official `v0.1.0` still requires completion of [Target VPS Runtime Acceptance](docs/validation.md); do not treat the release candidate as having completed full-platform, full-bandwidth, or performance acceptance.

## Online Installation and Verification

The following commands assume you have entered the VPS root shell (prompt usually `#`, `id -u` should output `0`). The script modifies host-level network, systemd, journald, and swap configurations; before first execution, ensure the provider console or rescue mode is accessible, and save necessary baseline information.

### 1. Online Installation

After the rc.11 Release is published and passes public asset verification, it is recommended to execute its pinned main entry point. It will automatically detect Debian 12/13, amd64, CPU, and memory tiers, and will default to running a read-only `preflight` first; `apply` will only be executed if preflight passes and `y` is explicitly entered again:

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

The safe guide will:

1. Display the detected system, CPU, memory, and tier;
2. Select provider port bandwidth; press Enter directly to use 200 Mbps;
3. Display the actual invoked script, source, and SHA-256;
4. Execute read-only `preflight` first;
5. Ask again after `preflight` passes; `apply` is only executed if `y` is explicitly entered.

After successful application, reboot as prompted:

```bash
reboot
```

### 2. Online Verification After Reboot

Execute after re-logging into the VPS. `verify` is read-only validation and will not apply again, nor does it require re-entering the port bandwidth already saved in the state:

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

`verify_after_reboot_exit=0` indicates verification passed. Save the full output; do not only extract the last line.

### 3. Strict Online Verification After 3X-UI Installation

The recommended order is to complete tuning and reboot verification first, then install 3X-UI. After installing and starting 3X-UI, execute:

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

Strict verification requires `x-ui.service` to be active, and checks that the systemd configuration, 3X-UI main process, and direct Xray child process NOFILE soft/hard limits are all not less than 65536. Reboot once more after installing 3X-UI, and repeat this strict verification command to prove that boot startup and new process inheritance are still correct.

### 4. Execute Read-Only Upgrade Check from Early rc Versions

VPS instances already managed by rc.9 or rc.10 can download the rc.11 main entry and execute `update`. It will read the resource tier and port bandwidth from the state, verify the current profile, target `SHA256SUMS`, and target main entry script, sequentially execute the current version `verify` and the target version's read-only `update-preflight`, and finally output the fixed URL, SHA-256, and migration order required for the maintenance window. `update` does not perform rollback, purge, apply, or reboot, nor will it replace old Release assets already published.

The main entry, `SHA256SUMS`, and profile are treated as an indivisible Release package. **Assets from different versions must not be placed in the same directory.** For example, do not place rc.11 `SHA256SUMS` and profile next to the rc.10 main entry; otherwise, the main entry will refuse to execute per integrity protection rules and will not automatically fall back to online download. The following online commands and subsequent rollback examples all use independent `mktemp -d` directories to avoid version collisions.

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

Specify the target version using `update --target v0.1.0-rc.11`. Auto-discovery does not cross `major.minor` release lines: when on an rc, you can select a higher rc on the same line or the stable release; when on a stable release, prereleases are automatically excluded. Cross-line upgrades must be explicitly specified with `--target`, and downgrades and duplicate upgrades are still rejected. Explicitly specifying a prerelease represents the user's active choice of that target and is not affected by the stable channel auto-exclusion rule.

`update` is only an upgrade compatibility check and plan generator; it will not rewrite old scripts on disk, system tuning configurations, or 3X-UI. A passed check does not mean the upgrade is complete; during the maintenance window, manually execute rollback/purge, reboot, target preflight/apply, reboot again, and verify according to the output and this README. If GitHub API queries fail or are subject to anonymous rate limits, using a reviewed `--target` can skip auto-discovery, but target Release assets will still be verified.

### 5. Online Execution Notes

- Only supports vendor minimal Debian 12/13, `x86_64/amd64`, and the four CPU/memory resource tiers listed in the README; other combinations will be rejected;
- Port bandwidth should be the provider's plan limit, not the link speed shown by the virtual NIC; default is 200 Mbps, allows 100–1000 Mbps;
- Online entry is pinned to `v0.1.0-rc.11` and will not fall back to `master`, `main`, `latest`, HTTP, or third-party mirrors;
- The above commands verify the fixed SHA-256 of the rc.11 main entry asset before execution; the main entry subsequently downloads the fixed Release's `SHA256SUMS` and matching profile, and verifies again;
- Main entry, `SHA256SUMS`, and profile must come from the same Release; use different temporary directories for different versions, do not mix rc.10 and rc.11 assets in `/root` or the same working directory;
- Tags should not be moved or same-named assets replaced after publication; release a new version when defects are found;
- `update` is a read-only upgrade check and will not automatically migrate configurations; after a passed check, you must still choose another maintenance window to complete manual rollback/apply and two reboots;
- The script does not configure or allow UFW ports; do not treat UFW status prompts as the firewall being configured; ensure the SSH management port will not be locked out first;
- `apply` writes system configurations and may create `/swapfile-proxy`; production VPS should backup first, confirm console/rescue access, and execute during a maintenance window;
- `verify` passing proves that the current configuration and checked services comply with the script contract, not that line throughput, latency, packet loss, or VLESS + REALITY + TCP business performance will definitely improve;
- `verify` and `preflight` will reject duplicate sysctl definitions outside this project, even if the values written by external files are the same as this project; do not run the built-in BBR or network optimization menus of 3X-UI/X-UI again, to avoid recreating `99-bbr-x-ui.conf`;
- `rollback` reverts tuning configurations managed by this project and should be tested during a maintenance window; normal rollback defaults to keeping the swap created by the script;
- Do not use `curl ... | bash` or `bash <(curl ...)` without reading the script and release notes.

## Real Environment Validation Baseline

As of 2026-08-04, the project has obtained the following target machine evidence for sanitized configuration categories. The numbers in the table represent validation records, not the number of VPS instances; the same configuration category may be repeatedly validated on the same asset at different times. To reduce asset association risks, public documents do not record providers, regions, IPs, domains, hostnames, panel ports, subscription addresses, accounts, credentials, certificate identifiers, or report IDs that can be reverse-searched.

| Record | OS & Kernel Series | VPS Config | Storage/Network | Covered Paths | Evidence Boundary |
|---|---|---|---|---|---|
| C1 | Debian 13; Linux 6.12 series | 1 vCPU / ~1 GiB; `debian13-1c1g` | ext4; plan limit 1000 Mbps | Fixed rc.9 asset verification, safe boot, `preflight`, `apply`, immediate/post-reboot `verify`, strict verification after 3X-UI installation; BBR, fq, swap, and NOFILE persist after reboot | Only proves the main path for corresponding rc.9 artifacts and this configuration category, not inherited as rc.10/rc.11 conclusion |
| C2 | Debian 12; Linux 6.1 series | 1 vCPU / ~1 GiB; `debian12-1c1g` | XFS; plan limit 200 Mbps | Completed rc.10 candidate `apply` after exiting rc.8, normal/strict `verify` and repeated `apply` after reboot; repeated execution did not overwrite configuration | Does not replace final Release asset verification, does not prove proxy throughput or line quality |
| C3 | Debian 12; Linux 6.1 series | 1 vCPU / ~2 GiB; `debian12-1c2g` | XFS; plan limit 200 Mbps | Completed rc.10 candidate `apply` after exiting rc.8, normal/strict `verify` and repeated `apply` after reboot; 3X-UI main process and direct Xray child process NOFILE is 65536/65536 | Does not cover 2C2G, 512 MiB, other filesystems, or final Release assets |
| C4 | Debian 13; Linux 6.12 series | 1 vCPU / ~1 GiB; `debian13-1c1g` | ext4; plan limit 1000 Mbps | Completed rc.9→rc.10 candidate migration using isolated directory, strict `verify` and repeated `apply` after reboot | This is a migration record, configuration category may overlap with C1; does not represent an additional independent VPS |

The above records are bound to the specific script hashes at the time of testing. If the script content or SHA-256 changes before or after release, evidence must be re-established according to the [Validation Matrix](docs/validation.md); passing conclusions cannot be inherited solely based on version names or identical configuration values. Target VPS lifecycle validation for the final rc.11 hash is still pending.

### 1C2G / 200 Mbps Performance Observation Case

The same Debian 12, 1C2G configuration category previously ran TcpQuality under the old v6 configuration and the rc.10 configuration respectively. The public README only retains aggregated results and does not publish report URLs, report IDs, exact test times, providers, and regions that have asset associations; original reports are saved by maintainers in private evidence sets.

All three reports show `bbr`, `fq`, TCP send `4K/64K/16M`, TCP receive `4K/128K/16M`. Quantifiable summary follows; each cell lists "zero anomalies / 1–20% / >20%", normal backhaul categorized by packet loss, large-packet backhaul categorized by retransmission, 93 determination items per category:

| Sanitized Sample | IPv4 Backhaul | IPv4 Large-Packet Backhaul | IPv6 Backhaul |
|---|---:|---:|---:|
| v6 Baseline Sample | 93 / 0 / 0 | 91 / 0 / 2 | 69 / 24 / 0 |
| rc.10 Sample A | 92 / 1 / 0 | 84 / 7 / 2 | 67 / 23 / 3 |
| rc.10 Sample B | 93 / 0 / 0 | 92 / 0 / 1 | 79 / 14 / 0 |

In the two time-period samples of the same rc.10 configuration, the zero-retransmission nodes for IPv4 large packets changed from 84 to 92, and zero-packet-loss nodes for IPv6 changed from 67 to 79; intra-group fluctuations are already greater than or close to the inter-group difference between v6 and rc.10 Sample A. Therefore, these three observations cannot prove that the kernel parameters of v6 or rc.10 are faster, nor can concentrated anomalies in individual regions or ISPs be uniquely attributed to a specific route. Test periods, ISP links, speedtest nodes, shared host load, and tool versions remain candidate explanations.

Furthermore, v6 has only one sample and rc.10 only two, which is still insufficient to estimate a stable distribution; TcpQuality uses random built-in packet lengths when `-s` is not specified, and the default `-c` sends only 30 packets per node; TcpQuality directly tests the VPS network stack, without passing through 3X-UI, VLESS, REALITY, or client links. Existing evidence is primarily remote images, lacking machine-readable raw tables sufficient for public recalculation.

Therefore, the project will not roll back rc.10 based on these single reports, modify the 17 managed sysctls of rc.11, or add aggressive parameters. Performance acceptance must fix the TcpQuality commit, script SHA-256, node files, and `-c/-s/-p` parameters, cover low load, daytime, and evening peaks with repeated sampling, compare median, P95, and anomaly node reproduction rates; simultaneously cover actual VLESS + REALITY + TCP concurrency of 1, 3, 5, 10. Full pending test items see [Validation Matrix](docs/validation.md).

## Local Usage and Command Line Mode

`debian-vps-tuning.sh` is the main entry point. It automatically reads the Debian major version, amd64 architecture, available logical CPUs, and actual memory, selecting one from six OS/memory profiles; users do not need to manually determine 512M/1G/2G filenames. The main entry script does not contain another set of tuning logic, it only handles selection, SHA-256 verification, and invocation.

Run from the complete project directory:

```bash
bash ./debian-vps-tuning.sh
```

Use command line mode directly:

```bash
bash ./debian-vps-tuning.sh preflight --port 200
bash ./debian-vps-tuning.sh apply --port 200
bash ./debian-vps-tuning.sh verify
bash ./debian-vps-tuning.sh status
bash ./debian-vps-tuning.sh diagnose
# benchmark also requires BENCHMARK_HOST, see below
bash ./debian-vps-tuning.sh benchmark
bash ./debian-vps-tuning.sh update
bash ./debian-vps-tuning.sh update --target v0.1.0-rc.11
bash ./debian-vps-tuning.sh rollback
```

In automated environments without an interactive terminal, the action must be explicitly specified; it will not implicitly enter a menu or auto-apply. `recover` remains as an advanced command for rc.2 empty state, but does not appear in the normal menu.

This project does not recommend the following forms as entry points:

```text
curl ... | bash
bash <(curl ...)
```

The reason is that they directly execute the download stream under root privileges, lacking an independent "download complete → file verification → then execute" gate.

## Applicable Scenarios

- VPS vendor pre-installed Debian 12 or Debian 13 minimal systems;
- `x86_64/amd64`; supports four resource tiers: 1C512MB, 1C1GB, 1C2GB, and 2C2GB;
- Measured memory boundaries are 384–767 MiB, 768–1535 MiB, or 1536–3072 MiB;
- 10 GB, 15 GB, or larger SSDs, with sufficient remaining space;
- Normal default routes for IPv4 or IPv4 + IPv6 dual-stack;
- Provider port limit 100–1000 Mbps, designed by default at 200 Mbps;
- Small proxy servers primarily using TCP, with connection scales empirically tested on target machines; the project does not guarantee capacity based on "number of users";
- The kernel actually provides BBR and fq.

Main validation baselines:

| System | Kernel Baseline | Resource Scripts |
|---|---|---|
| Debian 12 (bookworm) | Linux 6.1 series | 1C512MB, 1C1GB, 1C2GB, 2C2GB |
| Debian 13 (trixie) | Linux 6.12 series | 1C512MB, 1C1GB, 1C2GB, 2C2GB |

These are known validation baselines, not patch level whitelists. The script strictly checks the Debian major version and amd64 architecture, but after kernel minor version changes, it still relies on actual BBR/fq capabilities.

## Debian 12/13 Selection

The following conclusions are bounded by 2026-08-04. Debian officially currently defines Debian 13 as stable, with the latest point release at 13.6; Debian 12 is oldstable, with regular Release/Security/Backports support ended, LTS until 2028-06-30. Debian 13's regular support is until 2028-08-09, LTS until 2030-06-30. See [Debian Releases](https://www.debian.org/releases/) and [Bookworm transition to LTS announcement](https://www.debian.org/News/2026/20260712).

Therefore, newly created 1C1G, 1C2G, and 2C2G VPS instances are recommended to use Debian 13 minimal by default; Debian 12 continues to be used for existing stable nodes, confirmed defects in provider Debian 13 images, or third-party software with explicit Debian 12 compatibility constraints. Do not perform in-place major version upgrades on a single production node solely to pursue unproven performance improvements.

| Dimension | Debian 12 | Debian 13 | Project Judgment |
|---|---|---|---|
| Release Status | oldstable, in LTS | Current stable | New deployments prioritize Debian 13 |
| Support Period | LTS until 2028-06-30; some packages may not be covered by LTS | Regular support until 2028-08-09, LTS until 2030-06-30 | Long-term public nodes prioritize longer regular support windows |
| Typical Kernel Series | Linux 6.1 LTS | Linux 6.12 LTS | 13 has newer kernels and virtualization drivers, but does not guarantee higher throughput |
| User-space Baseline | systemd 252, OpenSSH 9.2, OpenSSL 3.0, glibc 2.36 | systemd 257, OpenSSH 10.0, OpenSSL 3.5, glibc 2.41 | More favorable for new software compatibility; old scripts and closed-source agents require verification |
| Migration Risk | Existing deployments are mature, fewer changes | In-place upgrades require checking NIC names, SSH, `/tmp`, and sysctl load behavior | Critical nodes prioritize new Debian 13 parallel migration |

Main advantages of Debian 13:

- Current stable, with longer regular security maintenance and LTS lifecycle;
- Linux 6.12 LTS, systemd 257, OpenSSH 10.0p1, and OpenSSL 3.5 provide newer kernels, virtualization, and system components;
- Debian officially provides cloud images such as GenericCloud, NoCloud, and OpenStack;
- 3X-UI official installation script selects APT and Debian systemd units by distro ID `debian`, no Debian 12-only version checks found;
- Xray-core official Linux builds use `CGO_ENABLED=0`, typically not dependent on Debian 12/13 specific glibc ABIs.

Main limitations and migration risks of Debian 13:

- Debian 13 does not guarantee lower memory usage than Debian 12, nor does it guarantee automatic improvements in Xray throughput, latency, or concurrency;
- `/tmp` defaults to on-demand allocated tmpfs, max up to 50% of memory; 1C1G nodes should limit large temporary files and logs;
- `systemd-sysctl` no longer reads `/etc/sysctl.conf`, local configurations should be placed in `/etc/sysctl.d/*.conf`; this project uses this standard path, but old tuning scripts may be incompatible;
- During in-place upgrade from Debian 12 to 13, predictable NIC names may change on some systems, network, firewall, or qdisc configurations with hardcoded interface names must be checked in advance;
- Major version changes in OpenSSH, OpenSSL, Python, and systemd may affect old keys, automation scripts, or provider closed-source agents;
- Provider providing "Debian 13" images does not mean the running kernel is definitely 6.12, nor does it prove cloud-init, IPv6, and network templates have passed verification.

Related changes see [Debian 13 Release Announcement](https://www.debian.org/News/2025/20250809) and [Debian 13 Release Notes: Known Issues](https://www.debian.org/releases/stable/release-notes/issues.en.html).

### Selection by VPS Resource Tier

| VPS Config | Recommended OS | Applicable Judgment | Main Constraints |
|---|---|---|---|
| 1C1G | Debian 13 minimal | Default choice for new nodes; no desktop, few necessary services | 1 GiB is the recommended memory for Debian 13 non-desktop installation, does not mean 3X-UI/Xray still has fixed headroom; should monitor RSS, FD, CPU steal, softirq, logs, and `/tmp` |
| 1C2G | Debian 13 | More balanced among the three tiers, better memory headroom for updates and temp tasks than 1C1G | Single core may still become a bottleneck for encryption, soft interrupts, or high concurrency |
| 2C2G | Debian 13 | Better suited for multi-connection, multi-inbound, or higher CPU load | 2 vCPUs do not guarantee doubled throughput, nor can RPS/RFS/XPS or IRQ affinity be enabled solely based on CPU count |

The minimum memory specified by Debian 13 official for non-desktop amd64 installation is 512 MB, recommended is 1 GB; actual server requirements depend on running services, cannot derive "idle fixed ~100 MB" or proxy capacity from this. See [Debian 13 amd64 Installation Requirements](https://www.debian.org/releases/trixie/amd64/ch03s04.en.html).

### Virtualization Type is Closer to Kernel Reality Than Distro Name

Full VMs like KVM, VMware, Hyper-V typically run their own Debian kernel for the guest OS; LXC, Incus, and some OpenVZ-like system containers share the host kernel. Even if `/etc/os-release` inside the container shows Debian 13, it cannot prove the kernel is 6.12, BBR is loadable, or qdisc/sysctl has full privileges. Before selecting a profile, at least check:

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

The six scripts separately verify OS, CPU, memory, running kernel capabilities, and qdisc topology, avoiding directly copying Debian 12 environmental assumptions to Debian 13. OS selection cannot replace target machine `preflight`.

## Script Selection

| File | OS | CPU Range | Memory Tier | Swap Default/Max |
|---|---|---:|---:|---:|
| `debian12-1c512m-vps-tuning.sh` | Debian 12 | 1 vCPU | 384–767 MiB | 1024/2048 MiB |
| `debian12-1c1g-vps-tuning.sh` | Debian 12 | 1 vCPU | 768–1535 MiB | 1024/2048 MiB |
| `debian12-1c2g-vps-tuning.sh` | Debian 12 | 1–2 vCPU | 1536–3072 MiB | 1024/4096 MiB |
| `debian13-1c512m-vps-tuning.sh` | Debian 13 | 1 vCPU | 384–767 MiB | 1024/2048 MiB |
| `debian13-1c1g-vps-tuning.sh` | Debian 13 | 1 vCPU | 768–1535 MiB | 1024/2048 MiB |
| `debian13-1c2g-vps-tuning.sh` | Debian 13 | 1–2 vCPU | 1536–3072 MiB | 1024/4096 MiB |

`1c2g` in filenames and state IDs is a compatibility name; the same 2G profile carries both 1C2GB and 2C2GB resource tiers, no duplicate 2C2G files are created, existing `debian12-1c2g`/`debian13-1c2g` states do not need migration. The six resource scripts still perform their own system, architecture, CPU, and memory verification; main entry selection cannot bypass underlying preflight. 2C512MB, 2C1GB, above 3 vCPUs, and out-of-bound memory will be explicitly rejected.

Scripts use 200 Mbps as the default port limit, but also allow explicit setting of 100–1000 Mbps. This should be the VPS plan or provider-given limit, do not treat the link speed shown by the virtual NIC as the plan limit.

## What the Script Will Modify

- `/etc/sysctl.d/90-proxy-vps.conf`;
- `/etc/systemd/journald.conf.d/90-proxy-vps.conf`;
- `/usr/local/sbin/proxy-vps-fq`;
- `/etc/systemd/system/proxy-vps-fq.service`;
- `/etc/systemd/system/x-ui.service.d/90-proxy-vps.conf`, preset `LimitNOFILE=65536`;
- `/var/lib/proxy-vps-tuning/state.json` and original qdisc state;
- Creates fixed path `/swapfile-proxy` on demand when no active swap exists on the system;
- Adds one line to `/etc/fstab` only for the swap actually created by the script.

Main sysctls include:

- `net.core.default_qdisc=fq`;
- `net.ipv4.tcp_congestion_control=bbr`;
- TCP socket buffer limits calculated by bandwidth and target RTT;
- `somaxconn`, `tcp_max_syn_backlog`, and `netdev_max_backlog`;
- TCP Fast Open kernel switch, MTU probing, and keepalive;
- `vm.swappiness=20`.

Full boundaries see [Design Scope](docs/design-scope.md).

### TCP Fast Open and Xray Boundaries

`net.ipv4.tcp_fastopen=3` only enables the basic client/server capabilities of Linux. Linux kernel documentation explicitly distinguishes between global bitmaps and individual listener `TCP_FASTOPEN` socket options; Xray also controls inbound or outbound sockets via `streamSettings.sockopt.tcpFastOpen`. Therefore, when the following command has no output, it can only indicate that the Xray configuration generated by 3X-UI does not have an explicit `tcpFastOpen` field, **it cannot prove TFO is enabled, nor can it prove TFO is disabled**:

```bash
jq '.. | objects | select(has("tcpFastOpen")) | .tcpFastOpen' \
  /usr/local/x-ui/bin/config.json
```

Current `verify` and `diagnose` will read-only report whether this field is explicitly present, but will not modify proxy configurations. Do not directly edit `/usr/local/x-ui/bin/config.json`: it is a 3X-UI generated file and may be overwritten when the panel rebuilds configuration. Only configure via the panel when the current 3X-UI version explicitly provides corresponding inbound/outbound sockopt or advanced configuration entry, and client compatibility testing is completed; re-check generated JSON and actual connections after configuration. TFO mainly affects the handshake phase, cannot replace BBR, fq, or line quality, and does not guarantee benefits across all intermediate devices.

Similarly, the host's `tcp_keepalive_time/intvl/probes` only affect sockets that have enabled `SO_KEEPALIVE` and are not overwritten by the application. Xray official documentation states: inbound Keep-Alive is disabled by default, enabled only when `tcpKeepAliveIdle` or `tcpKeepAliveInterval` is configured; outbound has its own defaults. Therefore, host sysctls cannot alone prove that Xray connections are adopting these keepalive values. See [Linux IP sysctl](https://docs.kernel.org/networking/ip-sysctl.html) and [Xray Sockopt](https://xtls.github.io/en/config/transports/sockopt.html).

## What the Script Will Not Modify

- Does not install, upgrade, or downgrade 3X-UI, S-UI, sing-box, Xray;
- Does not read or modify 3X-UI databases, Xray JSON, UUIDs, REALITY private keys, certificate private keys, or panel credentials;
- Does not add, delete, or reorder UFW rules;
- Does not open SSH, panel, subscription, or proxy ports;
- Does not restart `x-ui.service`, `xray.service`, `s-ui.service`, or `sing-box.service`; if x-ui is already running during apply, normal verification will prompt to restart the service or host before strict verification;
- Does not configure RPS/RFS/XPS, IRQ affinity, CPU affinity, or `GOMAXPROCS`;
- Does not modify DNS, routing, policy routing, MTU, or IPv6 enable/disable policies;
- Does not enable IP forwarding, NAT, or TProxy;
- Does not modify `ip_local_port_range`, `tcp_mem`, `fs.file-max`, or conntrack limits;
- Does not take over the packet processing relationship between Docker and UFW.

## VPS Initialization

The following commands assume you have entered the root shell (prompt usually `#`, `id -u` outputs `0`), so examples do not use `sudo`. Vendor minimal images usually allow direct root login and may not have `sudo` installed.

It is recommended to update the system and check the upgrade plan first:

```bash
apt update
apt -s full-upgrade
apt full-upgrade -y
```

Install basic tools and script dependencies:

```bash
apt install -y \
  curl wget ca-certificates gnupg lsb-release unzip \
  vim nano htop ufw jq \
  iproute2 procps kmod util-linux
```

If you need to clean up automatically installed and no longer needed packages, simulate and check the list first:

```bash
apt-get -s autoremove --purge
```

Execute after confirming it's correct:

```bash
apt autoremove --purge -y
```

After updating the kernel, reboot before running the tuning script:

```bash
reboot
```

## UFW Notes

Before enabling UFW on a remote VPS, you must first allow the real SSH port. For example, if SSH uses 22/TCP:

```bash
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed
ufw allow 22/tcp comment 'SSH management'
ufw enable
ufw status numbered
```

If SSH is not 22, replace with the real port. Dual-stack VPS should ensure `IPV6=yes` in `/etc/default/ufw`.

VLESS + REALITY inbound should only open the TCP ports actually used. Panel ports are best restricted to trusted management IPs or accessed via SSH local forwarding. The tuning script only reads UFW status and listening ports, it will not modify rules for you.

## Download and Verification

When downloading complete assets from GitHub Release, check all files:

```bash
sha256sum -c SHA256SUMS
```

When downloading only the main entry script and `SHA256SUMS`, check the corresponding entry:

```bash
grep -F '  debian-vps-tuning.sh' SHA256SUMS | sha256sum -c -
less ./debian-vps-tuning.sh
chmod +x ./debian-vps-tuning.sh
```

This is a root-level system script, skipping checks and directly using `curl | bash` is not recommended. The main entry script will subsequently perform an SHA-256 verification on the actual resource script invoked.

## Usage

Prioritize using the main entry script. The following independent script methods are reserved for offline, audit, and fault recovery scenarios, using Debian 13, 1C1G, 200 Mbps as an example; users must replace with files matching their system, CPU, and memory.

### 1. Read-Only Preflight

```bash
env PORT_SPEED_MBPS=200 \
  bash ./debian13-1c1g-vps-tuning.sh preflight
```

`preflight` does not write configurations, load modules, create swap, or stop services. It will block on:

- Mismatched OS, architecture, CPU, or memory tier;
- Missing required commands;
- BBR/fq unavailable;
- No normal default route;
- Unclear ownership of management files with the same name;
- Duplicate keys in `/etc/sysctl.conf` or `/etc/sysctl.d`;
- qdisc topology too complex to reliably recover;
- Fixed swap path already occupied by other files;
- Insufficient disk space.

Automatic swap files are only enabled on `ext2`, `ext3`, `ext4`, and `xfs` root filesystems. Btrfs, ZFS, overlay, NFS, FUSE, and other unverified filesystems will warn and skip automatic swap creation, without affecting other network configurations from being applied.

### 2. Apply

```bash
env PORT_SPEED_MBPS=200 \
  bash ./debian13-1c1g-vps-tuning.sh apply
```

Reboot after successful application:

```bash
reboot
```

If tuning is done before 3X-UI installation, the script will first create an `x-ui.service` drop-in; at this time, `verify` will treat "proxy service not yet installed" as a normal pending state, not a warning. When 3X-UI is installed later, systemd will automatically read this configuration.

### 3. Verification After Reboot

```bash
bash ./debian13-1c1g-vps-tuning.sh verify
bash ./debian13-1c1g-vps-tuning.sh status
```

### 4. Verification After 3X-UI Installation

When strictly using 3X-UI v3.4.2, obtain the installation script or assets from the official `v3.4.2` tag/release, do not use installation entries pointing to `master` expecting a fixed version.

After installing and configuring 3X-UI:

```bash
env REQUIRE_PROXY_SERVICE=1 \
  PROXY_SERVICE_UNITS='x-ui.service' \
  bash ./debian13-1c1g-vps-tuning.sh verify
```

The script will check the systemd configuration values of `x-ui.service`, the main process, and `/proc/<PID>/limits` of its direct child processes. Strict verification requires configuration and runtime soft/hard limits to be no less than 65536.

### 5. Read-Only Diagnose

```bash
bash ./debian-vps-tuning.sh diagnose
```

`diagnose` defaults to 5-second before/after sampling, outputting TCP retransmission/timeout/listen overflow/TFO, per-CPU softnet, whole-machine CPU user/system/softirq/steal, interface rx/tx/drop/error increments, and recognizable ethtool error counts, and saving pre/post qdisc states, default routes, RPS/XPS/IRQ, and proxy main process/direct child process CPU time, RSS, thread count, and FD count. Process evidence does not output command line arguments. It does not generate performance traffic or modify the system; it is recommended to reproduce actual VLESS + REALITY + TCP load from the client within the sampling window:

```bash
env DIAG_INTERVAL_SECONDS=15 \
  bash ./debian-vps-tuning.sh diagnose
```

Default does not output connection peers and process details. If `ss -tinp` collection is truly needed, it should be sanitized before saving and sharing logs:

```bash
env DIAG_INCLUDE_SOCKET_DETAILS=1 \
  bash ./debian-vps-tuning.sh diagnose
```

### 6. Explicit iperf3 Benchmark

`benchmark` does not change system configurations, but actively generates high-bandwidth TCP traffic. It requires the user to prepare and authorize an iperf3 server themselves; the script will not install packages, open ports, or select public servers. Default sequentially executes upload and download: each direction first does a 3-second warmup excluded from statistics, then records a 10-second valid window; both directions output iperf3 JSON, TCP/softnet/CPU/interface increments, and pre/post qdisc statistics. Run metadata includes UTC time, run ID, script version and SHA-256, profile, boot ID, management status, network parameters, congestion control, default qdisc, and iperf3 version:

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

`BENCHMARK_IP_FAMILY=4` or `6` is used to fix the address family, `auto` continues system resolution and connection selection; when comparing IPv4/IPv6, they must be executed separately and default routes saved. `BENCHMARK_OMIT_SECONDS=0` can be used to deliberately observe short connection experiences including slow start, non-zero values are for steady-state throughput comparison, the two must not be mixed into the same sequence. This result only measures direct TCP from VPS to iperf3 server, without passing through VLESS + REALITY + TCP client links; do not directly judge proxy experience with single results from public test points. `BENCHMARK_PARALLEL` is limited to 1–4, baseline tests for 1C1G/1C2G should use 1 first. iperf3 parameter semantics see [ESnet Official Documentation](https://software.es.net/iperf/invoking.html).

## 100–1000 Mbps

100 Mbps:

```bash
env PORT_SPEED_MBPS=100 \
  bash ./debian12-1c1g-vps-tuning.sh apply
```

200 Mbps:

```bash
env PORT_SPEED_MBPS=200 \
  bash ./debian12-1c2g-vps-tuning.sh apply
```

1000 Mbps:

```bash
env PORT_SPEED_MBPS=1000 \
  bash ./debian13-1c2g-vps-tuning.sh apply
```

Any integer within 100–1000 can be used, 500 Mbps is also provided in the main menu. rc.11 maintains rc.10 network parameters: default target RTT is 200 ms, using 1×, 1.25×, 1.5×BDP targets by resource tier, then rounding up to 16/32/64 MiB, constrained by 16/32/64 MiB limits of 512M/1G/2G profiles:

| Resource Tier | BDP Coeff | 100 Mbps | 200 Mbps | 500 Mbps | 1000 Mbps |
|---|---:|---:|---:|---:|---:|
| 512M | 1× | 16 MiB | 16 MiB | 16 MiB | 16 MiB (truncation warning) |
| 1G | 1.25× | 16 MiB | 16 MiB | 16 MiB | 32 MiB |
| 2G | 1.5× | 16 MiB | 16 MiB | 32 MiB | 64 MiB |

All resource tiers for the main 200 Mbps are 16 MiB. 512M tier prioritizes limiting memory pressure; 1G/2G tiers progressively increase high BDP headroom, only the 512M/1000 Mbps/200 ms combination triggers a resource truncation warning. The limits here are the maximum socket buffers allowed by auto-tuning, not indicating every connection will immediately fill up. Linux TCP receive buffering still grows automatically by connection demand via auto-tuning; explicit application `setsockopt(SO_RCVBUF)` may change this behavior. Resource truncation is for memory protection, does not mean bandwidth input is invalid. Without continuous monitoring and high BDP evidence, manually specifying `BUF_MAX` is not recommended.

## Parameters

| Variable | Default | Range/Description |
|---|---:|---|
| `PORT_SPEED_MBPS` | `200` | `100–1000` |
| `BUFFER_TARGET_RTT_MS` | `200` | `20–500` |
| `BUF_MAX` | `auto` | 512M/1G/2G profile limits are 16/32/64 MiB respectively |
| `ENABLE_SWAP` | `1` | `0` or `1` |
| `SWAP_MB` | `1024` | 512M/1G scripts max 2048, 2G script max 4096 |
| `PURGE_CREATED_SWAP` | `0` | Whether to clean up script-created swap during rollback |
| `PROXY_SERVICE_UNITS` | Auto-detect | Space-separated systemd services |
| `REQUIRE_PROXY_SERVICE` | `0` | Verification fails if target proxy service is missing when `1` |
| `DIAG_INTERVAL_SECONDS` | `5` | `1–60`, diagnose increment window |
| `DIAG_INCLUDE_SOCKET_DETAILS` | `0` | Outputs `ss -tinp` which may contain peer addresses when `1` |
| `BENCHMARK_HOST` | None | Required for benchmark, user-authorized iperf3 server |
| `BENCHMARK_PORT` | `5201` | `1–65535` |
| `BENCHMARK_SECONDS` | `10` | `5–120`, per direction |
| `BENCHMARK_OMIT_SECONDS` | `3` | `0–10`, warmup time per direction, not included in iperf3 statistics |
| `BENCHMARK_PARALLEL` | `1` | `1–4` |
| `BENCHMARK_IP_FAMILY` | `auto` | `auto`, `4`, or `6` |
| `BENCHMARK_DIRECTION` | `both` | `upload`, `download`, or `both` |
| `BENCHMARK_RUN_ID` | Auto-generated | Optional 1–96 character run label; letters, numbers, dots, underscores, colons, and hyphens only |
| `UPDATE_TAG` | Auto-discover | Target Release for `update`; equivalent CLI argument is `--target` |

Custom swap file paths are not supported; the script may only create `/swapfile-proxy`.

## State and Idempotent Execution

State is saved in a root-only JSON:

```text
/var/lib/proxy-vps-tuning/state.json
```

When repeatedly executing `apply` with the same script version and parameters, the script first verifies the current configuration; if verification passes, it does not rewrite. When repeatedly executing `apply` via the main entry script without providing `--port` or `PORT_SPEED_MBPS`, it reuses the port bandwidth already installed in the state; explicit parameters still take precedence. If the state version differs from the current script, uses a different resource script, or changes bandwidth/buffer parameters, `apply` will require rollback first, avoiding misreporting "old configuration still verifiable" as "new version already installed".

State updates are first written to a temporary file in the same directory by `jq`, then the command exit code, non-empty, single JSON object, and complete schema are checked; only after all pass is `state.json` atomically replaced. Empty files, blank files, multiple JSON documents, or update failures must not overwrite the previous valid state.

### Upgrading from rc.10 to rc.11

rc.11 does not change the 17 sysctls, qdisc, swap, journald, NOFILE, or state schema of rc.10; the main changes are enhanced read-only `diagnose` and user-authorized `benchmark`. Since the script versions and SHA-256 of the six profiles have changed, existing rc.10 states still cannot directly repeat `apply` via rc.11. First execute `update --target v0.1.0-rc.11` with the rc.11 main entry for read-only check; after passing, use the fixed and verified rc.10 Release in a maintenance window to execute `verify`, `PURGE_CREATED_SWAP=1 rollback`, and reboot, then use rc.11 in an independent directory to execute `preflight`, `apply`, reboot, and strict `verify`. rc.10 and rc.11 main entries, manifests, and profiles must not be placed in the same directory.

If only the new diagnose or benchmark is needed, and migrating management state to rc.11 is not required, the installed rc.10 can continue to manage the configuration lifecycle, and the rc.11 profile can be placed in an independent temporary directory to execute read-only `diagnose` or explicitly authorized `benchmark`; do not use rc.11 `apply` to overwrite rc.10 state.

### Upgrading from rc.8/rc.9 or old v5/v6 to rc.10

No output from `tcpFastOpen` query is not itself a failure requiring upgrade: rc.10 only adds detection and explanation, still will not modify 3X-UI/Xray configurations for users. The main configuration change for upgrading to rc.10 is using 1×/1.25×/1.5×BDP tiers by 512M/1G/2G; 200 Mbps remains 16 MiB, 1G/2G at 1000 Mbps are 32/64 MiB respectively.

For hosts already managed by rc.8 or rc.9 with a valid `/var/lib/proxy-vps-tuning/state.json`, first use the `update --target v0.1.0-rc.10` from the preceding rc.10 main entry for read-only compatibility check and save the output URL, SHA-256, profile, and port bandwidth. After passing, choose another maintenance window. Taking rc.9 as an example, re-download and verify the rc.9 main entry in an independent temporary directory, then complete verify/rollback/purge with the rc.9 fixed Release profile:

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

After re-logging, use another independent temporary directory to re-download and verify the rc.10 main entry, execute `preflight --port <port bandwidth from original state>`; after confirming it passes, execute `apply --port <same bandwidth>`, reboot, and `verify`. Strict verification should also be executed if 3X-UI is installed. `PURGE_CREATED_SWAP=1` will only attempt to delete `/swapfile-proxy` confirmed created by this project in the state; if `swapoff` fails, the script preserves swap, fstab line, and state, forced deletion should not occur. If using external swap, rollback will not take over or delete it. Any step failure should stop and preserve the current state, do not skip reboot or directly execute subsequent apply.

Old v5/v6 do not have the same state/ownership contract as rc.8+, rc.10 will not guess their original sysctl, qdisc, or swap ownership. First backup `sysctl`, `tc -j qdisc show`, systemd units, swap, and old scripts, exit old configuration and reboot according to the corresponding old script's cleanup process; after confirming old sysctl/service files are no longer effective, run rc.10 `preflight`. If sysctl conflicts occur, they must first be merged or removed according to real file ownership, do not use rc.10 `rollback` to impersonate old script uninstallers.

### rc.2 Empty State Recovery

Early rc.2 left an empty `state.json` when initial JSON construction failed, but qdisc snapshots still exist. `recover` only handles this known "pre-first system write" legacy scenario and requires explicit confirmation:

```bash
env ALLOW_EMPTY_STATE_RECOVERY=1 \
  bash ./debian12-1c1g-vps-tuning.sh recover
```

This operation will only quarantine the state directory if all the following conditions are met: `state.json` is an empty JSON stream, no project management files exist, no `/swapfile-proxy` or corresponding fstab line exists, fq helper is not running, and the current qdisc is semantically consistent with the saved snapshot. The original state directory will be renamed to preserve evidence and will not be deleted. `recover` must not be used for general JSON corruption, valid states, or scenarios that cannot be proven to have occurred before the first system write.

## Rollback

Default rolls back system configurations but preserves the emergency swap created by the script:

```bash
bash ./debian13-1c1g-vps-tuning.sh rollback
```

If memory is confirmed sufficient and you wish to simultaneously delete the swap created by the script:

```bash
env PURGE_CREATED_SWAP=1 \
  bash ./debian13-1c1g-vps-tuning.sh rollback
```

If normal rollback preserved swap, the state must first be cleaned up with the explicit purge above before re-applying. The script will not delete swap, fstab entries, or ownership state when `swapoff` fails.

## qdisc Boundaries

The script supports normal root `fq`, `fq_codel`, standard `pfifo_fast` with default parameters, `noqueue`, and normal cloud NICs with root `mq` and leaves as `fq`/`fq_codel`. Complex HTB, TBF, CAKE, custom `pfifo_fast`, or other hierarchies will be blocked during preflight. This avoids breaking existing multi-queue or traffic shaping structures with simple `tc qdisc replace ... root fq`.

Existing root `fq` and existing `fq` leaves under `mq` will not be repeatedly replaced, nor will their custom parameters be reset to default fq during rollback. The script only switches `fq_codel` root/leaves or standard root `pfifo_fast` confirmed to support recovery to fq, and restores according to pre-saved semantics during rollback.

The display format of `tc` and command input format are not completely identical, e.g., status output may show `limit 10240p`, recovery command still uses `limit 10240`. The script saves values via `tc -j` and rebuilds according to command input syntax; when comparing `target`, `interval`, and `ce_threshold`, it only tolerates ±1 microsecond quantization differences caused by kernel/tool echo, other supported parameters still require consistency.

Rollback re-reads the actual state after executing qdisc recovery commands; state and snapshot deletion are only allowed if the recovery result is semantically consistent with the original snapshot. `handle 0:` in the original snapshot means unspecified, allowing the kernel to automatically assign runtime handles for classless qdiscs; explicit non-zero handles will attempt recovery and strictly compare. If post-verification fails, the state is preserved as `DEGRADED`, complete rollback must not be reported.

## Docker Boundaries

The first version primarily validates native systemd deployments. Docker may change UFW filtering paths via its own netfilter rules; using `network_mode: host` also exposes all listening ports inside containers. Docker scenarios require independent checks and are not part of this script's firewall promises.

## Validation and Known Limitations

- Local `bash -n`, ShellCheck, generation consistency, disabled key, and encoding checks do not equal successful target VPS runtime;
- BBR, fq, swap, reboot persistence, UFW, 3X-UI, and actual client connectivity must be validated on the VPS;
- Current pre-release scope only supports amd64;
- Policy routing, TProxy, gateways, Docker firewalls, and complex qdiscs are out of scope;
- Performance results are affected by CPU, virtualization overselling, lines, cross-border routing, clients, and encryption overhead.
- Performance acceptance should separately cover 1, 3, 5, 10 concurrency; the script will not automatically generate proxy traffic.
- 2C2G has been included in rc.11 resource contracts and local fixtures, real VPS lifecycle results are subject to [Validation Matrix](docs/validation.md).

See [Runtime Acceptance Instructions](docs/validation.md) for details.

## Security Issues

Public documents and Issues should only retain information directly related to reproduction and insufficient to locate specific assets, such as OS major version, kernel series, CPU/memory tier, filesystem type, sanitized plan bandwidth, and validation conclusions. The following must not be published:

- Providers, data centers, regions, order numbers, and instance IDs;
- Public/Private IPs, IPv6 prefixes, domains, hostnames, default gateways, and associable DNS records;
- Real combinations of SSH, panel, subscription, API, monitoring, and proxy ports;
- Usernames, passwords, UUIDs, subscription IDs, API Tokens, Cookies, SSH private keys, certificate private keys, REALITY private keys, and Short IDs;
- Unsanitized 3X-UI databases, Xray JSON, client links, QR codes, logs, and screenshots;
- Third-party report URLs/IDs like TcpQuality, exact test times, boot IDs, reverse-searchable run IDs, and authorized iperf3 server addresses.

`diagnose` may output interface addresses, routes, and interrupt information; `DIAG_INCLUDE_SOCKET_DETAILS=1` may also output connection peers. `benchmark` metadata contains boot ID, user-specified host, and run ID. Must sanitize item by item before sharing logs, cannot just replace public IPv4. Script SHA-256 and project download URLs of public Releases belong to supply chain verification information, should be retained, and do not belong to VPS privacy data.

Submit security issues according to [SECURITY.md](SECURITY.md), do not attach complete asset configurations in public Issues.

## License

[MIT License](LICENSE)
