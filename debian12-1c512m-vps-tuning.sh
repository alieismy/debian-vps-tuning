#!/usr/bin/env bash
# Generated from tools/profile-template.sh.in. Do not edit generated profiles directly.
# Debian 12 / 1 vCPU / 512 MiB / 3X-UI-first conservative VPS tuning.

set -Eeuo pipefail
IFS=$'\n\t'
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH

SCRIPT_VERSION='0.1.0-rc.10'
STATE_SCHEMA_VERSION=3
NAMESPACE='proxy-vps'
MANAGED_MARKER='# Managed by debian-vps-tuning; namespace=proxy-vps'

TARGET_DEBIAN_VERSION='12'
TARGET_DEBIAN_CODENAME='bookworm'
PROFILE_ID='debian12-1c512m'
PROFILE_LABEL='Debian 12 / 1 vCPU / 512 MiB'
PROFILE_CPU_MIN=1
PROFILE_CPU_MAX=1
PROFILE_RAM_MIN_MIB=384
PROFILE_RAM_MAX_MIB=767
SWAP_MAX_MIB=2048
SWAP_CREATE_RESERVE_MIB=256
JOURNAL_SYSTEM_MAX_USE='64M'
JOURNAL_SYSTEM_KEEP_FREE='256M'
JOURNAL_RUNTIME_MAX_USE='16M'

DEFAULT_PORT_SPEED_MBPS=200
DEFAULT_BUFFER_TARGET_RTT_MS=200
BUFFER_TARGET_NUMERATOR=1
BUFFER_TARGET_DENOMINATOR=1
DEFAULT_SWAP_MB=1024
MIN_BUF_MAX=262144
MAX_BUF_MAX=16777216
SWAP_FILE='/swapfile-proxy'
FSTAB_FILE='/etc/fstab'

PORT_SPEED_MBPS_INPUT="${PORT_SPEED_MBPS:-}"
BUFFER_TARGET_RTT_MS_INPUT="${BUFFER_TARGET_RTT_MS:-}"
BUF_MAX_INPUT="${BUF_MAX:-auto}"
ENABLE_SWAP="${ENABLE_SWAP:-1}"
SWAP_MB_INPUT="${SWAP_MB:-$DEFAULT_SWAP_MB}"
PURGE_CREATED_SWAP="${PURGE_CREATED_SWAP:-0}"
ALLOW_EMPTY_STATE_RECOVERY="${ALLOW_EMPTY_STATE_RECOVERY:-0}"
PROXY_SERVICE_UNITS_INPUT="${PROXY_SERVICE_UNITS:-}"
REQUIRE_PROXY_SERVICE="${REQUIRE_PROXY_SERVICE:-0}"
DIAG_INTERVAL_SECONDS="${DIAG_INTERVAL_SECONDS:-5}"
DIAG_INCLUDE_SOCKET_DETAILS="${DIAG_INCLUDE_SOCKET_DETAILS:-0}"
UPDATE_PREFLIGHT="${UPDATE_PREFLIGHT:-0}"

PORT_SPEED_MBPS=''
BUFFER_TARGET_RTT_MS=''
BUF_MAX=''
BUF_MAX_MODE=''
BUFFER_BDP_BYTES=''
BUFFER_TARGET_BYTES=''
BUFFER_COVERAGE_MS=''
BUFFER_CLAMPED=0
ROOT_FS_TYPE=''
SWAP_CREATE_ALLOWED='1'
SWAP_SKIP_REASON=''
STATE_DIR_CREATED=0
QDISC_MATCH_REASON=''

SYSCTL_FILE="/etc/sysctl.d/90-${NAMESPACE}.conf"
SYSCTL_SCAN_ROOT='/etc'
JOURNAL_FILE="/etc/systemd/journald.conf.d/90-${NAMESPACE}.conf"
FQ_HELPER="/usr/local/sbin/${NAMESPACE}-fq"
FQ_SERVICE_NAME="${NAMESPACE}-fq.service"
FQ_SERVICE="/etc/systemd/system/${FQ_SERVICE_NAME}"
XUI_DROPIN_DIR='/etc/systemd/system/x-ui.service.d'
XUI_DROPIN="${XUI_DROPIN_DIR}/90-${NAMESPACE}.conf"
XUI_NOFILE_LIMIT=65536
STATE_DIR="/var/lib/${NAMESPACE}-tuning"
STATE_FILE="${STATE_DIR}/state.json"
QDISC_STATE_FILE="${STATE_DIR}/qdisc-original.json"
LOCK_FILE="/run/lock/${NAMESPACE}-tuning.lock"

EXIT_USAGE=2
EXIT_UNSUPPORTED=3
EXIT_CONFLICT=4
EXIT_VERIFY=5
EXIT_ROLLBACK=6
WARNINGS=0
APPLY_ACTIVE=0

PROFILE_SYSCTL_KEYS=(
  net.core.default_qdisc
  net.ipv4.tcp_congestion_control
  net.core.rmem_max
  net.core.wmem_max
  net.core.rmem_default
  net.core.wmem_default
  net.ipv4.tcp_rmem
  net.ipv4.tcp_wmem
  net.core.netdev_max_backlog
  net.core.somaxconn
  net.ipv4.tcp_max_syn_backlog
  net.ipv4.tcp_fastopen
  net.ipv4.tcp_mtu_probing
  net.ipv4.tcp_keepalive_time
  net.ipv4.tcp_keepalive_intvl
  net.ipv4.tcp_keepalive_probes
  vm.swappiness
)

DEFAULT_PROXY_SERVICE_UNITS=(
  x-ui.service
  xray.service
  s-ui.service
  sing-box.service
  3x-ui.service
  v2ray.service
  hysteria-server.service
  hysteria.service
  tuic-server.service
  tuic.service
  naive.service
)

info() { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; WARNINGS=$((WARNINGS + 1)); }
error() { printf '[x] %s\n' "$*" >&2; }
die() { local code="$1"; shift; error "$*"; exit "$code"; }

need_root() {
  [ "${EUID}" -eq 0 ] || die "$EXIT_UNSUPPORTED" '必须以 root 权限运行。'
}

acquire_lock() {
  mkdir -p "$(dirname "$LOCK_FILE")"
  exec 9>"$LOCK_FILE"
  flock -n 9 || die "$EXIT_CONFLICT" '另一个 proxy-vps-tuning 进程正在运行。'
}

is_bool() { [ "$1" = '0' ] || [ "$1" = '1' ]; }

validate_inputs() {
  BUFFER_CLAMPED=0
  PORT_SPEED_MBPS="${PORT_SPEED_MBPS_INPUT:-$DEFAULT_PORT_SPEED_MBPS}"
  BUFFER_TARGET_RTT_MS="${BUFFER_TARGET_RTT_MS_INPUT:-$DEFAULT_BUFFER_TARGET_RTT_MS}"

  [[ "$PORT_SPEED_MBPS" =~ ^[0-9]{3,4}$ ]] ||
    die "$EXIT_USAGE" 'PORT_SPEED_MBPS 必须是 100–1000 的整数。'
  PORT_SPEED_MBPS=$((10#$PORT_SPEED_MBPS))
  if [ "$PORT_SPEED_MBPS" -lt 100 ] || [ "$PORT_SPEED_MBPS" -gt 1000 ]; then
    die "$EXIT_USAGE" 'PORT_SPEED_MBPS 必须在 100–1000 之间。'
  fi

  [[ "$BUFFER_TARGET_RTT_MS" =~ ^[0-9]{2,3}$ ]] ||
    die "$EXIT_USAGE" 'BUFFER_TARGET_RTT_MS 必须是 20–500 的整数。'
  BUFFER_TARGET_RTT_MS=$((10#$BUFFER_TARGET_RTT_MS))
  if [ "$BUFFER_TARGET_RTT_MS" -lt 20 ] || [ "$BUFFER_TARGET_RTT_MS" -gt 500 ]; then
    die "$EXIT_USAGE" 'BUFFER_TARGET_RTT_MS 必须在 20–500 之间。'
  fi

  BUFFER_BDP_BYTES=$((PORT_SPEED_MBPS * 125 * BUFFER_TARGET_RTT_MS))
  BUFFER_TARGET_BYTES=$(((BUFFER_BDP_BYTES * BUFFER_TARGET_NUMERATOR + BUFFER_TARGET_DENOMINATOR - 1) / BUFFER_TARGET_DENOMINATOR))
  if [ "$BUF_MAX_INPUT" = 'auto' ]; then
    BUF_MAX_MODE='auto'
    if [ "$BUFFER_TARGET_BYTES" -le 16777216 ]; then
      BUF_MAX=16777216
    elif [ "$BUFFER_TARGET_BYTES" -le 33554432 ]; then
      BUF_MAX=33554432
    else
      BUF_MAX=67108864
    fi
    if [ "$BUF_MAX" -gt "$MAX_BUF_MAX" ]; then
      BUF_MAX="$MAX_BUF_MAX"
      BUF_MAX_MODE='auto-clamped'
      BUFFER_CLAMPED=1
    fi
  else
    [[ "$BUF_MAX_INPUT" =~ ^[0-9]{6,8}$ ]] ||
      die "$EXIT_USAGE" 'BUF_MAX 必须为 auto 或允许范围内的整数字节数。'
    BUF_MAX=$((10#$BUF_MAX_INPUT))
    BUF_MAX_MODE='explicit'
  fi
  if [ "$BUF_MAX" -lt "$MIN_BUF_MAX" ] || [ "$BUF_MAX" -gt "$MAX_BUF_MAX" ]; then
    die "$EXIT_USAGE" "BUF_MAX 必须在 ${MIN_BUF_MAX}–${MAX_BUF_MAX} 字节之间。"
  fi
  BUFFER_COVERAGE_MS=$((BUF_MAX * 8 / (PORT_SPEED_MBPS * 1000)))
  if [ "$BUFFER_CLAMPED" -eq 1 ]; then
    warn "按 ${PROFILE_LABEL} 的内存预算将自动 socket 上限限制为 $((MAX_BUF_MAX / 1048576)) MiB；约覆盖 ${BUFFER_COVERAGE_MS} ms，未达到 ${BUFFER_TARGET_NUMERATOR}/${BUFFER_TARGET_DENOMINATOR}×BDP 性能目标。"
  fi

  is_bool "$ENABLE_SWAP" || die "$EXIT_USAGE" 'ENABLE_SWAP 只能为 0 或 1。'
  is_bool "$PURGE_CREATED_SWAP" || die "$EXIT_USAGE" 'PURGE_CREATED_SWAP 只能为 0 或 1。'
  is_bool "$REQUIRE_PROXY_SERVICE" || die "$EXIT_USAGE" 'REQUIRE_PROXY_SERVICE 只能为 0 或 1。'
  is_bool "$UPDATE_PREFLIGHT" || die "$EXIT_USAGE" 'UPDATE_PREFLIGHT 只能为 0 或 1。'
  [[ "$SWAP_MB_INPUT" =~ ^[0-9]{3,4}$ ]] ||
    die "$EXIT_USAGE" "SWAP_MB 必须是 512–${SWAP_MAX_MIB} 的整数。"
  SWAP_MB=$((10#$SWAP_MB_INPUT))
  if [ "$SWAP_MB" -lt 512 ] || [ "$SWAP_MB" -gt "$SWAP_MAX_MIB" ]; then
    die "$EXIT_USAGE" "SWAP_MB 必须在 512–${SWAP_MAX_MIB} MiB 之间。"
  fi
}

missing_commands() {
  local cmd
  for cmd in awk grep sed sysctl ip tc ss modprobe modinfo systemctl swapon swapoff mkswap findmnt find flock sha256sum pgrep jq stat readlink install nproc; do
    command -v "$cmd" >/dev/null 2>&1 || printf '%s\n' "$cmd"
  done
}

ensure_required_tools() {
  local missing
  missing="$(missing_commands)"
  if [ -n "$missing" ]; then
    error '缺少必要命令：'
    printf '%s\n' "$missing" >&2
    error '请先执行：apt install -y iproute2 procps kmod util-linux jq'
    exit "$EXIT_UNSUPPORTED"
  fi
}

check_supported_os() {
  [ -r /etc/os-release ] || die "$EXIT_UNSUPPORTED" '/etc/os-release 不可读。'
  # shellcheck disable=SC1091
  . /etc/os-release
  if [ "${ID:-}" != 'debian' ] || [ "${VERSION_ID:-}" != "$TARGET_DEBIAN_VERSION" ]; then
    die "$EXIT_UNSUPPORTED" "本脚本仅支持 Debian ${TARGET_DEBIAN_VERSION} (${TARGET_DEBIAN_CODENAME})。"
  fi
  case "$(uname -m)" in
    x86_64 | amd64) ;;
    *) die "$EXIT_UNSUPPORTED" '首个公开版本仅支持 x86_64/amd64。' ;;
  esac

  local kernel
  kernel="$(uname -r)"
  case "$TARGET_DEBIAN_VERSION:$kernel" in
    12:6.1.*) ;;
    13:6.12.*) ;;
    *) warn "内核 ${kernel} 不属于当前验证基线；将继续按实际 BBR/fq 能力判断。" ;;
  esac
}

memory_mib() { awk '/^MemTotal:/ {print int($2 / 1024); exit}' /proc/meminfo; }

check_resource_profile() {
  local mem cpus
  cpus="$(nproc 2>/dev/null || true)"
  mem="$(memory_mib)"
  [[ "$cpus" =~ ^[1-9][0-9]*$ ]] || die "$EXIT_UNSUPPORTED" '无法读取可用逻辑 CPU 数。'
  [ -n "$mem" ] || die "$EXIT_UNSUPPORTED" '无法读取物理内存。'
  if [ "$cpus" -lt "$PROFILE_CPU_MIN" ] || [ "$cpus" -gt "$PROFILE_CPU_MAX" ]; then
    die "$EXIT_UNSUPPORTED" "检测到 ${cpus} vCPU，不符合 ${PROFILE_LABEL} 的 ${PROFILE_CPU_MIN}–${PROFILE_CPU_MAX} vCPU 范围。"
  fi
  if [ "$mem" -lt "$PROFILE_RAM_MIN_MIB" ] || [ "$mem" -gt "$PROFILE_RAM_MAX_MIB" ]; then
    die "$EXIT_UNSUPPORTED" "检测到 ${mem} MiB RAM，不符合 ${PROFILE_LABEL} 的 ${PROFILE_RAM_MIN_MIB}–${PROFILE_RAM_MAX_MIB} MiB 范围。"
  fi
}

state_exists() { [ -f "$STATE_FILE" ]; }

state_file_is_valid() {
  local result
  [ -f "$STATE_FILE" ] && [ ! -L "$STATE_FILE" ] || return 1
  [ "$(stat -c '%u' "$STATE_FILE" 2>/dev/null || true)" = '0' ] || return 1
  [ -s "$STATE_FILE" ] || return 1
  result="$(jq -c -e -s --argjson schema "$STATE_SCHEMA_VERSION" --arg profile "$PROFILE_ID" '
    length == 1 and
    (.[0] |
      type == "object" and
      .schema_version == $schema and
      .profile.id == $profile and
      (.state | type == "string") and
      (.network | type == "object") and
      (.original_sysctls | type == "object") and
      (.qdisc.file | type == "string") and
      (.qdisc.sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
      (.swap | type == "object") and
      (.managed_files | type == "array") and
      (.timestamps | type == "object"))
  ' "$STATE_FILE" 2>/dev/null)" || return 1
  [ "$result" = 'true' ]
}

validate_state_file() {
  state_exists || return 0
  state_file_is_valid || die "$EXIT_CONFLICT" "状态文件为空、损坏、包含多份 JSON 或 schema/profile 不匹配：${STATE_FILE}。不要继续 apply；只有确认它来自 rc.2 首次系统写入前的失败，才可使用 ALLOW_EMPTY_STATE_RECOVERY=1 执行 recover。"
}

state_get() { jq -er "$1" "$STATE_FILE"; }

atomic_json_commit() {
  local target="$1" tmp="$2"
  if [ ! -f "$tmp" ] || [ -L "$tmp" ] || [ ! -s "$tmp" ] ||
    ! jq -e -s 'length == 1 and (.[0] | type == "object")' "$tmp" >/dev/null ||
    ! chmod 0600 "$tmp" || ! chown root:root "$tmp" || ! mv -f -- "$tmp" "$target"; then
    rm -f -- "$tmp"
    return 1
  fi
}

state_set_phase() {
  local phase="$1" tmp
  tmp="$(mktemp "${STATE_FILE}.tmp.XXXXXX")" || return 1
  if ! jq --arg phase "$phase" --arg now "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    '.state=$phase | .timestamps.last_update=$now' "$STATE_FILE" >"$tmp" ||
    ! atomic_json_commit "$STATE_FILE" "$tmp"; then
    rm -f -- "$tmp"
    error "无法原子更新事务状态为 ${phase}；原状态文件保持不变。"
    return 1
  fi
  state_file_is_valid || { error "事务状态 ${phase} 写入后校验失败。"; return 1; }
}

state_managed_hash() {
  local path="$1"
  jq -er --arg path "$path" '.managed_files[] | select(.path == $path) | .sha256' "$STATE_FILE" 2>/dev/null || true
}

is_marker_managed_file() {
  local path="$1"
  [ -f "$path" ] && [ ! -L "$path" ] && [ "$(stat -c '%u' "$path")" = '0' ] && grep -Fq "$MANAGED_MARKER" "$path"
}

assert_owned_file() {
  local path="$1" expected actual phase=''
  is_marker_managed_file "$path" || die "$EXIT_CONFLICT" "拒绝操作非本项目文件：${path}"
  expected="$(state_managed_hash "$path")"
  if [ -z "$expected" ]; then
    phase="$(state_get '.state' 2>/dev/null || true)"
    case "$phase" in
      PREPARED | DEGRADED | ROLLBACK_PENDING) return 0 ;;
      *) die "$EXIT_CONFLICT" "状态中没有文件所有权记录：${path}" ;;
    esac
  fi
  actual="$(sha256sum "$path" | awk '{print $1}')"
  [ "$actual" = "$expected" ] || die "$EXIT_CONFLICT" "管理文件已被外部修改：${path}"
}

check_managed_paths() {
  local path
  if state_exists; then
    validate_state_file
    for path in "$SYSCTL_FILE" "$JOURNAL_FILE" "$FQ_HELPER" "$FQ_SERVICE" "$XUI_DROPIN"; do
      if [ -e "$path" ] || [ -L "$path" ]; then
        assert_owned_file "$path"
      fi
    done
  else
    if [ -e "$STATE_DIR" ] || [ -L "$STATE_DIR" ]; then
      die "$EXIT_CONFLICT" "状态目录存在但没有有效状态：${STATE_DIR}"
    fi
    for path in "$SYSCTL_FILE" "$JOURNAL_FILE" "$FQ_HELPER" "$FQ_SERVICE" "$XUI_DROPIN"; do
      if [ -e "$path" ] || [ -L "$path" ]; then
        die "$EXIT_CONFLICT" "目标路径已存在且不属于本项目：${path}"
      fi
    done
  fi
  if [ -e "$SWAP_FILE" ] && ! state_exists; then
    die "$EXIT_CONFLICT" "${SWAP_FILE} 已存在；脚本不会接管或覆盖。"
  fi
}

check_preflight_state() {
  state_exists || return 0
  local phase
  phase="$(state_get '.state')"
  if [ "$UPDATE_PREFLIGHT" = '1' ]; then
    case "$phase" in
      VERIFIED | APPLIED)
        info "检测到现有管理状态 ${phase}；进入只读 update-preflight，不执行任何系统写入。"
        return 0
        ;;
      *)
        die "$EXIT_CONFLICT" "update-preflight 只接受 VERIFIED/APPLIED；当前状态 ${phase} 必须先按现有版本处理。"
        ;;
    esac
  fi
  case "$phase" in
    VERIFIED | APPLIED)
      die "$EXIT_CONFLICT" "检测到现有管理状态 ${phase}；已安装配置请执行 verify，需要更改参数时请先 rollback。"
      ;;
    SWAP_RETAINED)
      die "$EXIT_CONFLICT" '检测到 SWAP_RETAINED；重新应用前请用 PURGE_CREATED_SWAP=1 执行 rollback。'
      ;;
    *)
      die "$EXIT_CONFLICT" "检测到未完成的事务状态 ${phase}；请先执行 rollback，不要直接 apply。"
      ;;
  esac
}

report_sysctl_conflicts() {
  local key file found=0 escaped canonical managed_canonical
  local -a files=()
  declare -A seen=()

  if [ "$#" -gt 0 ]; then
    files=("$@")
  else
    shopt -s nullglob
    files=("${SYSCTL_SCAN_ROOT}/sysctl.conf" "${SYSCTL_SCAN_ROOT}/sysctl.d/"*.conf)
    shopt -u nullglob
  fi

  managed_canonical="$(readlink -f "$SYSCTL_FILE" 2>/dev/null || printf '%s' "$SYSCTL_FILE")"
  for file in "${files[@]}"; do
    [ -f "$file" ] || continue
    canonical="$(readlink -f "$file" 2>/dev/null || printf '%s' "$file")"
    [ "$file" = "$SYSCTL_FILE" ] && continue
    [ "$canonical" = "$managed_canonical" ] && continue
    [ -z "${seen[$canonical]:-}" ] || continue
    seen["$canonical"]=1
    for key in "${PROFILE_SYSCTL_KEYS[@]}"; do
      escaped="${key//./\\.}"
      if grep -Eq "^[[:space:]]*${escaped}[[:space:]]*=" "$file"; then
        error "sysctl 冲突：${key} 已在 ${file} 中定义；即使值相同也属于重复配置归属。"
        found=1
      fi
    done
  done
  [ "$found" -eq 0 ]
}

scan_sysctl_conflicts() {
  if ! report_sysctl_conflicts "$@"; then
    die "$EXIT_CONFLICT" '请先人工合并或移除上述重复 sysctl 定义。'
  fi
}

default_route_ifaces() {
  {
    ip -o -4 route show default 2>/dev/null || true
    ip -o -6 route show default 2>/dev/null || true
  } | awk '{for(i=1;i<=NF;i++) if($i=="dev" && (i+1)<=NF) print $(i+1)}' | awk 'NF && !seen[$0]++'
}

kernel_feature_available() {
  local module="$1" config_key="$2"
  [ -d "/sys/module/${module}" ] || modinfo "$module" >/dev/null 2>&1 ||
    grep -Eq "^${config_key}=[ym]$" "/boot/config-$(uname -r)" 2>/dev/null
}

check_bbr_fq_capability() {
  local available current_qdisc
  available="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)"
  if [[ " $available " != *' bbr '* ]] && ! kernel_feature_available tcp_bbr CONFIG_TCP_CONG_BBR; then
    die "$EXIT_UNSUPPORTED" '当前内核没有暴露或提供 tcp_bbr。'
  fi
  current_qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || true)"
  if [ "$current_qdisc" != 'fq' ] && ! kernel_feature_available sch_fq CONFIG_NET_SCH_FQ; then
    die "$EXIT_UNSUPPORTED" '当前内核没有暴露或提供 sch_fq。'
  fi
}

qdisc_snapshot_for_iface() {
  local iface="$1"
  tc -j qdisc show dev "$iface" | jq --arg iface "$iface" '{interface:$iface,qdiscs:.}'
}

is_conventional_pfifo_fast_snapshot() {
  jq -e '
    (.qdiscs | length) == 1 and
    (.qdiscs[0].root == true) and
    (.qdiscs[0].kind == "pfifo_fast") and
    ((.qdiscs[0].options // {}) |
      ((keys - ["bands", "multiqueue", "priomap"]) | length) == 0 and
      ((.bands // 3) == 3) and
      ((.multiqueue // false) == false) and
      ((has("priomap") | not) or
       .priomap == [1,2,2,2,1,2,0,0,1,1,1,1,1,1,1,1]))
  ' <<<"$1" >/dev/null 2>&1
}

validate_qdisc_topology() {
  local iface snapshot root_kind unsupported leaf_count unknown_options
  mapfile -t IFACES < <(default_route_ifaces)
  [ "${#IFACES[@]}" -gt 0 ] || die "$EXIT_UNSUPPORTED" '没有发现常规 IPv4 或 IPv6 默认路由网卡。'

  for iface in "${IFACES[@]}"; do
    snapshot="$(qdisc_snapshot_for_iface "$iface")" || die "$EXIT_UNSUPPORTED" "无法读取 ${iface} 的 qdisc。"
    root_kind="$(jq -r '.qdiscs[] | select(.root == true) | .kind' <<<"$snapshot" | head -n1)"
    case "$root_kind" in
      fq) info "${iface}: 根 qdisc 已是 fq。" ;;
      fq_codel)
        unknown_options="$(jq -r '[.qdiscs[] | select(.root == true and .kind == "fq_codel") | .options // {} | keys[] | select(. != "limit" and . != "flows" and . != "quantum" and . != "target" and . != "interval" and . != "memory_limit" and . != "ecn" and . != "ce_threshold" and . != "drop_batch")] | unique | join(",")' <<<"$snapshot")"
        [ -z "$unknown_options" ] || die "$EXIT_UNSUPPORTED" "${iface}: fq_codel 含有无法可靠恢复的选项：${unknown_options}"
        info "${iface}: 支持从根 fq_codel 切换到 fq。"
        ;;
      pfifo_fast)
        is_conventional_pfifo_fast_snapshot "$snapshot" ||
          die "$EXIT_UNSUPPORTED" "${iface}: pfifo_fast 不是可无损恢复的常规默认拓扑。"
        info "${iface}: 支持从常规根 pfifo_fast 切换到 fq，并在 rollback 时恢复。"
        ;;
      noqueue) warn "${iface}: 根 qdisc 为 noqueue，将跳过即时替换。" ;;
      mq)
        leaf_count="$(jq '[.qdiscs[] | select(has("parent"))] | length' <<<"$snapshot")"
        [ "$leaf_count" -gt 0 ] || die "$EXIT_UNSUPPORTED" "${iface}: mq 没有可识别的叶子 qdisc。"
        unsupported="$(jq -r '.qdiscs[] | select(has("parent")) | select(.kind != "fq" and .kind != "fq_codel") | .kind' <<<"$snapshot" | sort -u)"
        [ -z "$unsupported" ] || die "$EXIT_UNSUPPORTED" "${iface}: mq 包含不支持的叶子 qdisc：${unsupported}"
        unknown_options="$(jq -r '[.qdiscs[] | select(has("parent") and .kind == "fq_codel") | .options // {} | keys[] | select(. != "limit" and . != "flows" and . != "quantum" and . != "target" and . != "interval" and . != "memory_limit" and . != "ecn" and . != "ce_threshold" and . != "drop_batch")] | unique | join(",")' <<<"$snapshot")"
        [ -z "$unknown_options" ] || die "$EXIT_UNSUPPORTED" "${iface}: mq 叶子含有无法可靠恢复的选项：${unknown_options}"
        info "${iface}: 将保留 mq 根，仅对叶子应用 fq。"
        ;;
      '') die "$EXIT_UNSUPPORTED" "${iface}: 无法识别根 qdisc。" ;;
      *) die "$EXIT_UNSUPPORTED" "${iface}: 不支持自动修改复杂根 qdisc ${root_kind}。" ;;
    esac
  done
}

check_swap_preconditions() {
  [ "$ENABLE_SWAP" = '1' ] || return 0
  if swapon --show=NAME --noheadings 2>/dev/null | grep -q '[^[:space:]]'; then
    info '系统已有活动 swap，不会创建新的 swap。'
    return 0
  fi

  ROOT_FS_TYPE="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"
  [ -n "$ROOT_FS_TYPE" ] || ROOT_FS_TYPE='unknown'
  case "$ROOT_FS_TYPE" in
    ext2 | ext3 | ext4 | xfs)
      info "根文件系统为 ${ROOT_FS_TYPE}，允许创建普通 swap 文件。"
      ;;
    btrfs | zfs | overlay | overlayfs | nfs | nfs4 | fuse | fuse.*)
      SWAP_CREATE_ALLOWED='0'
      SWAP_SKIP_REASON="根文件系统 ${ROOT_FS_TYPE} 需要专用或不适合通用 swap-file 流程"
      warn "${SWAP_SKIP_REASON}；将跳过自动创建 swap。"
      return 0
      ;;
    *)
      SWAP_CREATE_ALLOWED='0'
      SWAP_SKIP_REASON="根文件系统 ${ROOT_FS_TYPE} 未经本项目验证"
      warn "${SWAP_SKIP_REASON}；将跳过自动创建 swap。"
      return 0
      ;;
  esac

  [ ! -e "$SWAP_FILE" ] || state_exists || die "$EXIT_CONFLICT" "${SWAP_FILE} 已存在且所有权未知。"
  local available_kib required_kib
  available_kib="$(df -Pk / | awk 'NR==2 {print $4}')"
  required_kib=$(((SWAP_MB + SWAP_CREATE_RESERVE_MIB) * 1024))
  [ "$available_kib" -ge "$required_kib" ] ||
    die "$EXIT_UNSUPPORTED" "剩余空间不足以创建 ${SWAP_MB} MiB swap 并保留 ${SWAP_CREATE_RESERVE_MIB} MiB。"
}

show_environment() {
  local mem cpus
  cpus="$(nproc 2>/dev/null || printf '?')"
  mem="$(memory_mib)"
  info "脚本版本：${SCRIPT_VERSION}"
  info "配置档位：${PROFILE_ID} (${PROFILE_LABEL})"
  info "系统：${PRETTY_NAME:-unknown}"
  info "内核：$(uname -r)"
  info "CPU：${cpus} vCPU"
  info "内存：${mem} MiB"
  info "端口上限：${PORT_SPEED_MBPS} Mbps；目标 RTT：${BUFFER_TARGET_RTT_MS} ms"
  info "理论 BDP：${BUFFER_BDP_BYTES} 字节；${BUFFER_TARGET_NUMERATOR}/${BUFFER_TARGET_DENOMINATOR}×BDP 目标：${BUFFER_TARGET_BYTES} 字节"
  info "BUF_MAX：${BUF_MAX} 字节 (${BUF_MAX_MODE})"
  info "所选缓冲上限的理论线路覆盖：${BUFFER_COVERAGE_MS} ms"
  info "默认路由网卡：$(default_route_ifaces | paste -sd, -)"
  if command -v ufw >/dev/null 2>&1; then
    ufw status 2>/dev/null | sed 's/^/[ufw] /' || true
  else
    warn '未安装 ufw；调优脚本不会自动安装或配置防火墙。'
  fi
}

run_preflight() {
  local context="${1:-standalone}"
  ensure_required_tools
  check_supported_os
  validate_inputs
  check_resource_profile
  check_managed_paths
  [ "$context" = 'apply' ] || check_preflight_state
  scan_sysctl_conflicts
  check_bbr_fq_capability
  validate_qdisc_topology
  check_swap_preconditions
  show_environment
  info "预检通过；警告数：${WARNINGS}。"
}

write_qdisc_snapshot() {
  local snapshot_iface tmp
  tmp="$(mktemp)"
  if ! {
    for snapshot_iface in "${IFACES[@]}"; do
      qdisc_snapshot_for_iface "$snapshot_iface"
    done | jq -s . >"$tmp"
  } || [ ! -s "$tmp" ] ||
    ! jq -e 'type == "array" and length > 0 and all(.[];
      (.interface | type == "string") and (.interface | length > 0) and
      (.qdiscs | type == "array") and (.qdiscs | length > 0) and
      ([.qdiscs[] | select(.root == true)] | length == 1))' "$tmp" >/dev/null ||
    ! install -o root -g root -m 0600 "$tmp" "$QDISC_STATE_FILE"; then
    rm -f -- "$tmp"
    return 1
  fi
  rm -f -- "$tmp"
}

original_sysctls_json() {
  local key value
  for key in "${PROFILE_SYSCTL_KEYS[@]}"; do
    value="$(sysctl -n "$key" 2>/dev/null || true)"
    printf '%s\t%s\n' "$key" "$value"
  done | jq -Rn '[inputs | split("\t") | {(.[0]): .[1]}] | add'
}

write_initial_state() {
  local original qhash now tmp
  mkdir -- "$STATE_DIR" || return 1
  STATE_DIR_CREATED=1
  chmod 0700 "$STATE_DIR" || return 1
  write_qdisc_snapshot || return 1
  if ! original="$(original_sysctls_json)"; then
    error '无法采集原始 sysctl 状态。'
    return 1
  fi
  qhash="$(sha256sum "$QDISC_STATE_FILE" | awk '{print $1}')"
  now="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  tmp="$(mktemp "${STATE_FILE}.tmp.XXXXXX")" || return 1
  if ! jq -n \
    --argjson schema "$STATE_SCHEMA_VERSION" --arg version "$SCRIPT_VERSION" \
    --arg profile "$PROFILE_ID" --arg profile_label "$PROFILE_LABEL" \
    --arg debian "$TARGET_DEBIAN_VERSION" --arg arch "$(uname -m)" \
    --arg kernel "$(uname -r)" --argjson mem "$(memory_mib)" \
    --argjson port "$PORT_SPEED_MBPS" --argjson rtt "$BUFFER_TARGET_RTT_MS" \
    --argjson buf "$BUF_MAX" --arg mode "$BUF_MAX_MODE" \
    --argjson target_numerator "$BUFFER_TARGET_NUMERATOR" \
    --argjson target_denominator "$BUFFER_TARGET_DENOMINATOR" \
    --arg qfile "$QDISC_STATE_FILE" --arg qhash "$qhash" --arg now "$now" \
    --argjson original "$original" \
    '{schema_version:$schema,script_version:$version,state:"PREPARED",
      profile:{id:$profile,label:$profile_label,debian_version:$debian,architecture:$arch,kernel_release:$kernel,memory_mib:$mem},
       network:{port_speed_mbps:$port,target_rtt_ms:$rtt,buffer_target_numerator:$target_numerator,buffer_target_denominator:$target_denominator,buffer_max_bytes:$buf,buffer_mode:$mode},
      original_sysctls:$original,qdisc:{file:$qfile,sha256:$qhash},
      swap:{created_by_script:false,path:"/swapfile-proxy",size_mib:0,device:0,inode:0,active:false},
      managed_files:[],timestamps:{prepared:$now,last_update:$now}}' >"$tmp" ||
    ! atomic_json_commit "$STATE_FILE" "$tmp"; then
    rm -f -- "$tmp"
    error '无法创建有效的初始事务状态；未提交空状态文件。'
    return 1
  fi
  state_file_is_valid || { error '初始事务状态写入后校验失败。'; return 1; }
}

cleanup_uncommitted_state() {
  [ "$STATE_DIR_CREATED" -eq 1 ] || return 1
  [ ! -e "$STATE_FILE" ] && [ ! -L "$STATE_FILE" ] || return 1
  rm -f -- "$QDISC_STATE_FILE" "${STATE_FILE}.tmp."*
  rmdir -- "$STATE_DIR"
}

write_managed_file() {
  local path="$1" mode="$2" dir
  dir="$(dirname "$path")"
  mkdir -p "$dir" || return 1
  local tmp
  tmp="$(mktemp "${path}.tmp.XXXXXX")"
  if ! cat >"$tmp" || ! chmod "$mode" "$tmp" || ! chown root:root "$tmp" ||
    ! mv -f -- "$tmp" "$path"; then
    rm -f -- "$tmp"
    return 1
  fi
}

refresh_managed_files() {
  local path json='[]' hash tmp
  for path in "$SYSCTL_FILE" "$JOURNAL_FILE" "$FQ_HELPER" "$FQ_SERVICE" "$XUI_DROPIN"; do
    [ -f "$path" ] || continue
    hash="$(sha256sum "$path" | awk '{print $1}')"
    if ! json="$(jq -c --arg path "$path" --arg hash "$hash" '. + [{path:$path,sha256:$hash}]' <<<"$json")"; then
      error '无法构造 managed_files 状态。'
      return 1
    fi
  done
  tmp="$(mktemp "${STATE_FILE}.tmp.XXXXXX")" || return 1
  if ! jq --argjson files "$json" '.managed_files=$files' "$STATE_FILE" >"$tmp" ||
    ! atomic_json_commit "$STATE_FILE" "$tmp"; then
    rm -f -- "$tmp"
    error '无法原子更新 managed_files；原状态文件保持不变。'
    return 1
  fi
  state_file_is_valid || { error 'managed_files 更新后状态校验失败。'; return 1; }
}

write_sysctl_profile() {
  write_managed_file "$SYSCTL_FILE" 0644 <<EOF_SYSCTL || return 1
${MANAGED_MARKER}
# ${PROFILE_LABEL}; provider cap ${PORT_SPEED_MBPS} Mbps; target RTT ${BUFFER_TARGET_RTT_MS} ms.
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = ${BUF_MAX}
net.core.wmem_max = ${BUF_MAX}
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.ipv4.tcp_rmem = 4096 131072 ${BUF_MAX}
net.ipv4.tcp_wmem = 4096 65536 ${BUF_MAX}
net.core.netdev_max_backlog = 4096
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
vm.swappiness = 20
EOF_SYSCTL
}

write_journal_profile() {
  write_managed_file "$JOURNAL_FILE" 0644 <<EOF_JOURNAL || return 1
${MANAGED_MARKER}
[Journal]
SystemMaxUse=${JOURNAL_SYSTEM_MAX_USE}
SystemKeepFree=${JOURNAL_SYSTEM_KEEP_FREE}
RuntimeMaxUse=${JOURNAL_RUNTIME_MAX_USE}
EOF_JOURNAL
}

write_xui_dropin() {
  write_managed_file "$XUI_DROPIN" 0644 <<EOF_XUI || return 1
${MANAGED_MARKER}
[Service]
LimitNOFILE=${XUI_NOFILE_LIMIT}
EOF_XUI
}

write_fq_helper() {
  write_managed_file "$FQ_HELPER" 0755 <<'EOF_HELPER' || return 1
#!/usr/bin/env bash
# Managed by debian-vps-tuning; namespace=proxy-vps
set -Eeuo pipefail
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
ifaces="$({ ip -o -4 route show default 2>/dev/null || true; ip -o -6 route show default 2>/dev/null || true; } |
  awk '{for(i=1;i<=NF;i++) if($i=="dev" && (i+1)<=NF) print $(i+1)}' | awk 'NF && !seen[$0]++')"
[ -n "$ifaces" ] || exit 0
while IFS= read -r iface; do
  [ -n "$iface" ] || continue
  root_kind="$(tc -j qdisc show dev "$iface" | jq -r '.[] | select(.root == true) | .kind' | head -n1)"
  case "$root_kind" in
    fq) ;;
    noqueue) ;;
    mq)
      unsupported="$(tc -j qdisc show dev "$iface" | jq -r '.[] | select(has("parent")) | select(.kind != "fq" and .kind != "fq_codel") | .kind' | sort -u)"
      if [ -n "$unsupported" ]; then
        printf '[proxy-vps-fq] unsupported mq leaf qdisc on %s: %s\n' "$iface" "$unsupported" >&2
        exit 1
      fi
      tc -j qdisc show dev "$iface" | jq -r '.[] | select(has("parent") and .kind == "fq_codel") | .parent' |
        while IFS= read -r parent; do
          [ -n "$parent" ] && tc qdisc replace dev "$iface" parent "$parent" fq
        done
      ;;
    fq_codel | pfifo_fast) tc qdisc replace dev "$iface" root fq ;;
    *) printf '[proxy-vps-fq] unsupported qdisc on %s: %s\n' "$iface" "$root_kind" >&2; exit 1 ;;
  esac
done <<<"$ifaces"
EOF_HELPER
  refresh_managed_files || return 1

  write_managed_file "$FQ_SERVICE" 0644 <<EOF_SERVICE || return 1
${MANAGED_MARKER}
[Unit]
Description=Apply fq to conventional default-route interfaces
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${FQ_HELPER}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF_SERVICE
  refresh_managed_files || return 1
}

apply_kernel_settings() {
  modprobe tcp_bbr >/dev/null 2>&1 || true
  modprobe sch_fq >/dev/null 2>&1 || true
  if ! sysctl -p "$SYSCTL_FILE" >/dev/null; then
    error "无法应用 ${SYSCTL_FILE}。"
    return 1
  fi
  if ! systemctl daemon-reload; then
    error 'systemctl daemon-reload 失败。'
    return 1
  fi
  if ! systemctl enable --now "$FQ_SERVICE_NAME" >/dev/null; then
    error "无法启用或运行 ${FQ_SERVICE_NAME}。"
    return 1
  fi
  if ! systemctl try-restart systemd-journald.service >/dev/null 2>&1; then
    warn 'systemd-journald 未能立即重启；配置将在服务下次启动时生效。'
  fi
}

state_set_swap_created() {
  local device inode tmp
  device="$(stat -c '%d' "$SWAP_FILE")"
  inode="$(stat -c '%i' "$SWAP_FILE")"
  tmp="$(mktemp "${STATE_FILE}.tmp.XXXXXX")" || return 1
  if ! jq --argjson size "$SWAP_MB" --argjson device "$device" --argjson inode "$inode" \
    '.swap.created_by_script=true | .swap.size_mib=$size | .swap.device=$device | .swap.inode=$inode | .swap.active=true' "$STATE_FILE" >"$tmp" ||
    ! atomic_json_commit "$STATE_FILE" "$tmp"; then
    rm -f -- "$tmp"
    error '无法原子记录 swap 所有权；原状态文件保持不变。'
    return 1
  fi
  state_file_is_valid || { error 'swap 所有权更新后状态校验失败。'; return 1; }
}

ensure_fstab_swap_line() {
  local line="${SWAP_FILE} none swap sw 0 0"
  grep -Fqx "$line" /etc/fstab 2>/dev/null || printf '%s\n' "$line" >>/etc/fstab
  [ "$(grep -Fxc "$line" /etc/fstab)" -eq 1 ]
}

create_swap_if_needed() {
  [ "$ENABLE_SWAP" = '1' ] || return 0
  if [ "$SWAP_CREATE_ALLOWED" != '1' ]; then
    info "跳过自动创建 swap：${SWAP_SKIP_REASON:-根文件系统不在支持范围内}。"
    return 0
  fi
  if swapon --show=NAME --noheadings 2>/dev/null | grep -q '[^[:space:]]'; then return 0; fi
  [ ! -e "$SWAP_FILE" ] || die "$EXIT_CONFLICT" "${SWAP_FILE} 已存在，拒绝覆盖。"
  info "创建 ${SWAP_MB} MiB 应急 swap：${SWAP_FILE}"
  if command -v fallocate >/dev/null 2>&1 && fallocate -l "${SWAP_MB}M" "$SWAP_FILE"; then :; else
    rm -f -- "$SWAP_FILE"
    if ! dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$SWAP_MB" status=none conv=fsync; then
      rm -f -- "$SWAP_FILE"
      die 1 'swap 文件分配失败。'
    fi
  fi
  if ! chmod 0600 "$SWAP_FILE" || ! mkswap "$SWAP_FILE" >/dev/null; then
    rm -f -- "$SWAP_FILE"
    die 1 'swap 初始化失败。'
  fi
  if ! swapon "$SWAP_FILE"; then
    warn 'fallocate 创建的 swap 未被文件系统接受，将使用 dd 重试。'
    rm -f -- "$SWAP_FILE"
    if ! dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$SWAP_MB" status=none conv=fsync ||
      ! chmod 0600 "$SWAP_FILE" || ! mkswap "$SWAP_FILE" >/dev/null || ! swapon "$SWAP_FILE"; then
      swapoff "$SWAP_FILE" >/dev/null 2>&1 || true
      rm -f -- "$SWAP_FILE"
      die 1 '使用 dd 重试 swap 仍失败。'
    fi
  fi
  if ! state_set_swap_created; then
    swapoff "$SWAP_FILE" >/dev/null 2>&1 || true
    rm -f -- "$SWAP_FILE"
    die 1 '无法持久记录 swap 所有权，已撤销。'
  fi
  if ! ensure_fstab_swap_line; then
    swapoff "$SWAP_FILE" || true
    rm -f -- "$SWAP_FILE"
    die 1 '无法可靠写入 /etc/fstab，已撤销 swap。'
  fi
}

profile_service_units() {
  local unit
  if [ -n "$PROXY_SERVICE_UNITS_INPUT" ]; then
    IFS=' ' read -r -a units <<<"$PROXY_SERVICE_UNITS_INPUT"
    for unit in "${units[@]}"; do
      [[ "$unit" =~ ^[A-Za-z0-9_.@-]+\.service$ ]] || die "$EXIT_USAGE" "非法 systemd unit：${unit}"
      printf '%s\n' "$unit"
    done
  else
    printf '%s\n' "${DEFAULT_PROXY_SERVICE_UNITS[@]}"
  fi
}

read_nofile_limits() {
  local limits_file="$1"
  awk '$1 == "Max" && $2 == "open" && $3 == "files" {printf "%s\t%s\n", $4, $5; exit}' "$limits_file"
}

verify_runtime_nofile() {
  local unit="$1" process_label="$2" limits_file="$3" runtime_strict="$4" soft='' hard=''
  IFS=$'\t' read -r soft hard < <(read_nofile_limits "$limits_file")
  printf '[service] %s %s NOFILE soft=%s hard=%s\n' "$unit" "$process_label" "$soft" "$hard"
  if ! [[ "$soft" =~ ^[0-9]+$ ]] || [ "$soft" -lt "$XUI_NOFILE_LIMIT" ] ||
    ! [[ "$hard" =~ ^[0-9]+$ ]] || [ "$hard" -lt "$XUI_NOFILE_LIMIT" ]; then
    if [ "$unit" = 'x-ui.service' ] && [ "$runtime_strict" -eq 1 ]; then
      error "${unit} 的 ${process_label} 运行时 NOFILE soft/hard limit 未达到 ${XUI_NOFILE_LIMIT}。"
      return 1
    fi
    warn "${unit} 的 ${process_label} 运行时 NOFILE soft/hard limit 低于 ${XUI_NOFILE_LIMIT}；重启服务或主机后再验证。"
  fi
}

verify_proxy_services() {
  local unit loaded=0 active_count=0 active main_pid child strict=0 runtime_strict=0 failures=0 configured_soft configured_hard
  [ -z "$PROXY_SERVICE_UNITS_INPUT" ] || strict=1
  if [ "$strict" -eq 1 ] || [ "$REQUIRE_PROXY_SERVICE" = '1' ]; then runtime_strict=1; fi
  while IFS= read -r unit; do
    [ -n "$unit" ] || continue
    [ "$(systemctl show -p LoadState --value "$unit" 2>/dev/null || true)" = 'loaded' ] || continue
    loaded=$((loaded + 1))
    active="$(systemctl show -p ActiveState --value "$unit" 2>/dev/null || true)"
    main_pid="$(systemctl show -p MainPID --value "$unit" 2>/dev/null || true)"
    printf '[service] %s ActiveState=%s MainPID=%s\n' "$unit" "$active" "${main_pid:-0}"
    if [ "$unit" = 'x-ui.service' ]; then
      configured_soft="$(systemctl show -p LimitNOFILESoft --value "$unit" 2>/dev/null || true)"
      configured_hard="$(systemctl show -p LimitNOFILE --value "$unit" 2>/dev/null || true)"
      printf '[service] %s configured NOFILE soft=%s hard=%s\n' "$unit" "${configured_soft:-unknown}" "${configured_hard:-unknown}"
      if ! [[ "$configured_soft" =~ ^[0-9]+$ ]] || [ "$configured_soft" -lt "$XUI_NOFILE_LIMIT" ] ||
        ! [[ "$configured_hard" =~ ^[0-9]+$ ]] || [ "$configured_hard" -lt "$XUI_NOFILE_LIMIT" ]; then
        error "x-ui.service 的 systemd LimitNOFILE 未达到 ${XUI_NOFILE_LIMIT}。"
        failures=$((failures + 1))
      fi
    fi
    if [ "$active" != 'active' ]; then
      if [ "$strict" -eq 1 ]; then error "指定的服务未运行：${unit}"; failures=$((failures + 1)); else warn "检测到未运行的兼容服务：${unit}"; fi
      continue
    fi
    active_count=$((active_count + 1))
    if [[ "$main_pid" =~ ^[1-9][0-9]*$ ]] && [ -r "/proc/${main_pid}/limits" ]; then
      verify_runtime_nofile "$unit" MainPID "/proc/${main_pid}/limits" "$runtime_strict" || failures=$((failures + 1))
      while IFS= read -r child; do
        [ -r "/proc/${child}/limits" ] || continue
        verify_runtime_nofile "$unit" "child=${child}" "/proc/${child}/limits" "$runtime_strict" || failures=$((failures + 1))
      done < <(pgrep -P "$main_pid" 2>/dev/null || true)
    fi
  done < <(profile_service_units)
  if [ "$loaded" -eq 0 ]; then
    if [ "$REQUIRE_PROXY_SERVICE" = '1' ]; then error '没有发现要求的代理服务。'; return 1; fi
    info '尚未安装代理服务；x-ui.service 的 LimitNOFILE drop-in 已预置，安装 3X-UI 后请重新 verify。'
  fi
  if [ "$REQUIRE_PROXY_SERVICE" = '1' ] && [ "$active_count" -eq 0 ]; then error '没有发现活动的目标代理服务。'; failures=$((failures + 1)); fi
  [ "$failures" -eq 0 ]
}

normalize_sysctl_value() {
  awk '{$1=$1; print}' <<<"$1"
}

verify_current_qdiscs() {
  local iface root_kind bad failures=0
  while IFS= read -r iface; do
    [ -n "$iface" ] || continue
    root_kind="$(tc -j qdisc show dev "$iface" | jq -r '.[] | select(.root == true) | .kind' | head -n1)"
    case "$root_kind" in
      fq) ;;
      noqueue) warn "${iface}: noqueue，未执行即时 fq 替换。" ;;
      mq)
        bad="$(tc -j qdisc show dev "$iface" | jq -r '.[] | select(has("parent") and .kind != "fq") | .kind' | sort -u)"
        if [ -n "$bad" ]; then error "${iface}: mq 叶子不是 fq：${bad}"; failures=$((failures + 1)); fi
        ;;
      *) error "${iface}: 实际根 qdisc 不是 fq：${root_kind:-missing}"; failures=$((failures + 1)) ;;
    esac
  done < <(default_route_ifaces)
  [ "$failures" -eq 0 ]
}

verify_settings() {
  local failures=0 key expected actual qhash unit_path
  state_exists || { error '当前主机尚未安装本项目配置；请先执行 preflight，确认通过后再执行 apply。'; return 1; }
  validate_state_file || return 1
  [ "$(state_get '.state')" = 'APPLIED' ] || [ "$(state_get '.state')" = 'VERIFIED' ] || {
    error "当前状态不允许 verify：$(state_get '.state')"; return 1; }
  if ! report_sysctl_conflicts; then
    error '检测到本项目以外的重复 sysctl 配置归属；verify 拒绝通过。'
    failures=$((failures + 1))
  fi
  for key in "${PROFILE_SYSCTL_KEYS[@]}"; do
    expected="$(awk -F= -v k="$key" '{name=$1; gsub(/^[[:space:]]+|[[:space:]]+$/, "", name); if(name==k){v=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); print v; exit}}' "$SYSCTL_FILE")"
    actual="$(sysctl -n "$key" 2>/dev/null || true)"
    expected="$(normalize_sysctl_value "$expected")"
    actual="$(normalize_sysctl_value "$actual")"
    [ "$actual" = "$expected" ] || { error "${key}: expected '${expected}', got '${actual}'"; failures=$((failures + 1)); }
  done
  qhash="$(sha256sum "$QDISC_STATE_FILE" | awk '{print $1}')"
  [ "$qhash" = "$(state_get '.qdisc.sha256')" ] || { error 'qdisc 原始状态文件哈希不匹配。'; failures=$((failures + 1)); }
  for key in "$SYSCTL_FILE" "$JOURNAL_FILE" "$FQ_HELPER" "$FQ_SERVICE" "$XUI_DROPIN"; do assert_owned_file "$key"; done
  unit_path="$(systemctl show -p FragmentPath --value "$FQ_SERVICE_NAME" 2>/dev/null || true)"
  [ "$(readlink -f "$unit_path" 2>/dev/null || true)" = "$(readlink -f "$FQ_SERVICE")" ] || {
    error 'fq helper 的 systemd FragmentPath 不匹配。'; failures=$((failures + 1)); }
  verify_current_qdiscs || failures=$((failures + 1))
  if state_get '.swap.created_by_script' | grep -qx true; then
    [ "$(stat -c '%d' "$SWAP_FILE" 2>/dev/null || true)" = "$(state_get '.swap.device')" ] || { error 'swap 设备号与所有权状态不匹配。'; failures=$((failures + 1)); }
    [ "$(stat -c '%i' "$SWAP_FILE" 2>/dev/null || true)" = "$(state_get '.swap.inode')" ] || { error 'swap inode 与所有权状态不匹配。'; failures=$((failures + 1)); }
    swapon --show=NAME --noheadings | awk '{$1=$1;print}' | grep -Fxq "$SWAP_FILE" || { error '脚本创建的 swap 未激活。'; failures=$((failures + 1)); }
    grep -Fqx "${SWAP_FILE} none swap sw 0 0" /etc/fstab || { error 'swap 的 fstab 行缺失。'; failures=$((failures + 1)); }
  fi
  verify_proxy_services || failures=$((failures + 1))
  show_xray_socket_options
  [ "$failures" -eq 0 ] || return 1
  info "验证通过；警告数：${WARNINGS}。"
}

restore_fq_codel() {
  local iface="$1" scope="$2" parent="$3" json="$4" value
  local cmd=(tc qdisc replace dev "$iface")
  if [ "$scope" = 'root' ]; then cmd+=(root); else cmd+=(parent "$parent"); fi
  value="$(jq -r '.handle // empty' <<<"$json")"
  if [ -n "$value" ] && [ "$value" != '0:' ]; then cmd+=(handle "$value"); fi
  cmd+=(fq_codel)
  value="$(jq -r '.options.limit // empty' <<<"$json")"; [ -z "$value" ] || cmd+=(limit "$value")
  value="$(jq -r '.options.flows // empty' <<<"$json")"; [ -z "$value" ] || cmd+=(flows "$value")
  value="$(jq -r '.options.quantum // empty' <<<"$json")"; [ -z "$value" ] || cmd+=(quantum "$value")
  value="$(jq -r '.options.target // empty' <<<"$json")"; if [ -n "$value" ]; then [[ "$value" =~ ^[0-9]+$ ]] && value="${value}us"; cmd+=(target "$value"); fi
  value="$(jq -r '.options.interval // empty' <<<"$json")"; if [ -n "$value" ]; then [[ "$value" =~ ^[0-9]+$ ]] && value="${value}us"; cmd+=(interval "$value"); fi
  value="$(jq -r '.options.memory_limit // empty' <<<"$json")"; [ -z "$value" ] || cmd+=(memory_limit "$value")
  value="$(jq -r '.options.drop_batch // empty' <<<"$json")"; [ -z "$value" ] || cmd+=(drop_batch "$value")
  value="$(jq -r '.options.ce_threshold // empty' <<<"$json")"; if [ -n "$value" ]; then [[ "$value" =~ ^[0-9]+$ ]] && value="${value}us"; cmd+=(ce_threshold "$value"); fi
  if jq -e '.options | has("ecn")' <<<"$json" >/dev/null 2>&1; then
    if jq -e '.options.ecn == true' <<<"$json" >/dev/null 2>&1; then cmd+=(ecn); else cmd+=(noecn); fi
  fi
  if ! "${cmd[@]}"; then
    printf '[x] fq_codel 恢复命令失败：' >&2
    printf '%q ' "${cmd[@]}" >&2
    printf '\n' >&2
    return 1
  fi
}

restore_qdiscs() {
  [ -f "$QDISC_STATE_FILE" ] || { error "qdisc 原始快照不存在：${QDISC_STATE_FILE}"; return 1; }
  local expected_hash actual_hash
  expected_hash="$(state_get '.qdisc.sha256')"
  actual_hash="$(sha256sum "$QDISC_STATE_FILE" | awk '{print $1}')"
  [ "$actual_hash" = "$expected_hash" ] || {
    error "qdisc 原始快照哈希不匹配：expected=${expected_hash} actual=${actual_hash}"
    return 1
  }
  local count i iface root_json root_kind leaf_count j leaf_json parent kind
  count="$(jq 'length' "$QDISC_STATE_FILE")"
  for ((i=0; i<count; i++)); do
    iface="$(jq -r ".[$i].interface" "$QDISC_STATE_FILE")"
    root_json="$(jq -c ".[$i].qdiscs[] | select(.root == true)" "$QDISC_STATE_FILE" | head -n1)"
    root_kind="$(jq -r '.kind' <<<"$root_json")"
    case "$root_kind" in
      fq) : ;;
      fq_codel) restore_fq_codel "$iface" root '' "$root_json" || return 1 ;;
      pfifo_fast) tc qdisc replace dev "$iface" root pfifo_fast || return 1 ;;
      noqueue) ;;
      mq)
        [ "$(tc -j qdisc show dev "$iface" | jq -r '.[] | select(.root == true) | .kind' | head -n1)" = 'mq' ] || return 1
        leaf_count="$(jq ".[$i].qdiscs | map(select(has(\"parent\"))) | length" "$QDISC_STATE_FILE")"
        for ((j=0; j<leaf_count; j++)); do
          leaf_json="$(jq -c ".[$i].qdiscs | map(select(has(\"parent\"))) | .[$j]" "$QDISC_STATE_FILE")"
          parent="$(jq -r '.parent' <<<"$leaf_json")"; kind="$(jq -r '.kind' <<<"$leaf_json")"
          case "$kind" in fq) : ;; fq_codel) restore_fq_codel "$iface" leaf "$parent" "$leaf_json" || return 1 ;; *) return 1 ;; esac
        done
        ;;
      *) return 1 ;;
    esac
  done
}

remove_fstab_swap_line() {
  local fstab_file="$FSTAB_FILE" line="${SWAP_FILE} none swap sw 0 0" tmp grep_rc
  [ -f "$fstab_file" ] && [ ! -L "$fstab_file" ] || return 1
  if grep -Fqx "$line" "$fstab_file"; then
    :
  else
    grep_rc=$?
    [ "$grep_rc" -eq 1 ] && return 0
    return 1
  fi
  tmp="$(mktemp "${fstab_file}.proxy-vps-tuning.XXXXXX")" || return 1
  if ! awk -v wanted="$line" '$0 != wanted' "$fstab_file" >"$tmp"; then
    rm -f -- "$tmp"
    return 1
  fi
  if [ ! -s "$tmp" ] && grep -Fvxq "$line" "$fstab_file"; then
    rm -f -- "$tmp"
    return 1
  fi
  if grep -Fqx "$line" "$tmp" ||
    ! chown --reference="$fstab_file" "$tmp" ||
    ! chmod --reference="$fstab_file" "$tmp" ||
    ! mv -fT -- "$tmp" "$fstab_file"; then
    rm -f -- "$tmp"
    return 1
  fi
}

purge_owned_swap() {
  state_get '.swap.created_by_script' | grep -qx true || return 0
  [ "$(state_get '.swap.path')" = "$SWAP_FILE" ] || return 1
  if [ ! -e "$SWAP_FILE" ]; then
    remove_fstab_swap_line || return 1
    return 0
  fi
  [ -f "$SWAP_FILE" ] && [ ! -L "$SWAP_FILE" ] || return 1
  [ "$(stat -c '%d' "$SWAP_FILE")" = "$(state_get '.swap.device')" ] || return 1
  [ "$(stat -c '%i' "$SWAP_FILE")" = "$(state_get '.swap.inode')" ] || return 1
  if swapon --show=NAME --noheadings | awk '{$1=$1;print}' | grep -Fxq "$SWAP_FILE"; then
    swapoff "$SWAP_FILE" || return 1
  fi
  remove_fstab_swap_line || return 1
  rm -f -- "$SWAP_FILE"
}

sysctl_defined_elsewhere() {
  local key="$1" file escaped
  escaped="${key//./\\.}"
  shopt -s nullglob
  for file in /etc/sysctl.conf /etc/sysctl.d/*.conf /run/sysctl.d/*.conf /usr/local/lib/sysctl.d/*.conf /usr/lib/sysctl.d/*.conf; do
    [ "$file" = "$SYSCTL_FILE" ] && continue
    [ -f "$file" ] || continue
    if grep -Eq "^[[:space:]]*${escaped}[[:space:]]*=" "$file"; then shopt -u nullglob; return 0; fi
  done
  shopt -u nullglob
  return 1
}

restore_original_sysctls() {
  local key value failures=0
  for key in "${PROFILE_SYSCTL_KEYS[@]}"; do
    sysctl_defined_elsewhere "$key" && continue
    value="$(jq -r --arg key "$key" '.original_sysctls[$key] // empty' "$STATE_FILE")"
    [ -n "$value" ] || continue
    if ! sysctl -q -w "${key}=${value}"; then
      error "回滚步骤失败：无法恢复 sysctl ${key}。"
      failures=$((failures + 1))
    fi
  done
  [ "$failures" -eq 0 ]
}

project_managed_files_exist() {
  local path
  for path in "$SYSCTL_FILE" "$JOURNAL_FILE" "$FQ_HELPER" "$FQ_SERVICE" "$XUI_DROPIN"; do
    if [ -e "$path" ] || [ -L "$path" ]; then return 0; fi
  done
  return 1
}

qdisc_snapshot_file_is_valid() {
  [ -f "$QDISC_STATE_FILE" ] && [ ! -L "$QDISC_STATE_FILE" ] || return 1
  [ "$(stat -c '%u' "$QDISC_STATE_FILE" 2>/dev/null || true)" = '0' ] || return 1
  [ -s "$QDISC_STATE_FILE" ] || return 1
  jq -e -s '
    length == 1 and
    (.[0] | type == "array" and length > 0) and
    all(.[0][];
      (.interface | type == "string") and (.interface | length > 0) and
      (.qdiscs | type == "array") and (.qdiscs | length > 0) and
      ([.qdiscs[] | select(.root == true)] | length == 1))
  ' "$QDISC_STATE_FILE" >/dev/null 2>&1
}

qdisc_snapshot_semantically_matches_current() {
  QDISC_MATCH_REASON=''
  qdisc_snapshot_file_is_valid || { QDISC_MATCH_REASON="快照缺失、为空、所有权异常或结构无效：${QDISC_STATE_FILE}"; return 1; }
  local count i iface saved current filter
  filter='map({base:{kind,parent:(.parent // ""),root:(.root // false),options:((.options // {}) | del(.target,.interval,.ce_threshold))},handle:(.handle // ""),times:{target:(.options.target // null),interval:(.options.interval // null),ce_threshold:(.options.ce_threshold // null)}}) | sort_by([.base.root,.base.parent,.base.kind])'
  count="$(jq 'length' "$QDISC_STATE_FILE")"
  for ((i=0; i<count; i++)); do
    iface="$(jq -r ".[$i].interface" "$QDISC_STATE_FILE")"
    saved="$(jq -cS ".[$i].qdiscs | ${filter}" "$QDISC_STATE_FILE")" || {
      QDISC_MATCH_REASON="无法解析 ${iface} 的原始快照"; return 1;
    }
    current="$(tc -j qdisc show dev "$iface" | jq -cS "$filter")" || {
      QDISC_MATCH_REASON="无法读取 ${iface} 的当前 qdisc"; return 1;
    }
    if ! jq -en --argjson saved "$saved" --argjson current "$current" '
      def close_time($a; $b):
        ($a == $b) or
        (($a | type) == "number" and ($b | type) == "number" and
         (($a - $b) >= -1 and ($a - $b) <= 1));
      def handle_matches($saved_handle; $current_handle):
        ($saved_handle == "" or $saved_handle == "0:" or
         $saved_handle == $current_handle);
      ($saved | length) == ($current | length) and
      all(range(0; $saved | length);
        $saved[.].base == $current[.].base and
        handle_matches($saved[.].handle; $current[.].handle) and
        close_time($saved[.].times.target; $current[.].times.target) and
        close_time($saved[.].times.interval; $current[.].times.interval) and
        close_time($saved[.].times.ce_threshold; $current[.].times.ce_threshold))
    ' >/dev/null; then
      QDISC_MATCH_REASON="${iface} 语义不一致：saved=${saved} current=${current}"
      return 1
    fi
  done
}

qdisc_snapshot_matches_current() {
  QDISC_MATCH_REASON=''
  local expected_hash actual_hash
  expected_hash="$(state_get '.qdisc.sha256')" || { QDISC_MATCH_REASON='状态中缺少 qdisc.sha256'; return 1; }
  actual_hash="$(sha256sum "$QDISC_STATE_FILE" 2>/dev/null | awk '{print $1}')"
  if [ -z "$expected_hash" ] || [ "$actual_hash" != "$expected_hash" ]; then
    QDISC_MATCH_REASON="快照哈希不匹配：expected=${expected_hash:-missing} actual=${actual_hash:-missing}"
    return 1
  fi
  qdisc_snapshot_semantically_matches_current
}

original_sysctls_match_current() {
  local key expected actual
  for key in "${PROFILE_SYSCTL_KEYS[@]}"; do
    sysctl_defined_elsewhere "$key" && continue
    expected="$(jq -r --arg key "$key" '.original_sysctls[$key] // empty' "$STATE_FILE")"
    [ -n "$expected" ] || continue
    actual="$(sysctl -n "$key" 2>/dev/null || true)"
    [ "$(normalize_sysctl_value "$actual")" = "$(normalize_sysctl_value "$expected")" ] || return 1
  done
}

rollback_already_restored() {
  project_managed_files_exist && return 1
  state_get '.swap.created_by_script' | grep -qx false || return 1
  qdisc_snapshot_matches_current || return 1
  original_sysctls_match_current
}

recover_empty_legacy_state() {
  [ "$ALLOW_EMPTY_STATE_RECOVERY" = '1' ] ||
    die "$EXIT_CONFLICT" 'recover 只用于已确认的 rc.2 首次系统写入前空状态；确认历史证据后设置 ALLOW_EMPTY_STATE_RECOVERY=1。'
  state_exists || die "$EXIT_CONFLICT" '没有需要恢复的 state.json。'
  state_file_is_valid && die "$EXIT_CONFLICT" 'state.json 有效；请使用 rollback，不得使用 recover。'
  if [ ! -d "$STATE_DIR" ] || [ -L "$STATE_DIR" ] ||
    [ "$(stat -c '%u' "$STATE_DIR" 2>/dev/null || true)" != '0' ]; then
    die "$EXIT_CONFLICT" "状态目录所有权或类型异常：${STATE_DIR}"
  fi
  if ! jq -e -s 'length == 0' "$STATE_FILE" >/dev/null 2>&1; then
    die "$EXIT_CONFLICT" 'state.json 不是空 JSON 流；拒绝把一般损坏状态当作 rc.2 遗留状态恢复。'
  fi
  project_managed_files_exist &&
    die "$EXIT_CONFLICT" '仍存在项目管理文件；无法证明 rc.2 在首次系统写入前失败。'
  if [ -e "$SWAP_FILE" ] || [ -L "$SWAP_FILE" ]; then
    die "$EXIT_CONFLICT" "检测到 ${SWAP_FILE}；空状态无法证明 swap 所有权，拒绝恢复。"
  fi
  grep -Fqx "${SWAP_FILE} none swap sw 0 0" /etc/fstab 2>/dev/null &&
    die "$EXIT_CONFLICT" "检测到 ${SWAP_FILE} 的 fstab 行；拒绝恢复。"
  if systemctl is-active --quiet "$FQ_SERVICE_NAME" 2>/dev/null; then
    die "$EXIT_CONFLICT" "${FQ_SERVICE_NAME} 仍在运行；拒绝恢复。"
  fi
  if ! qdisc_snapshot_semantically_matches_current; then
    die "$EXIT_CONFLICT" "当前 qdisc 与 rc.2 快照不一致；拒绝恢复：${QDISC_MATCH_REASON}"
  fi
  local quarantine
  quarantine="${STATE_DIR}.recovered-$(date -u +'%Y%m%dT%H%M%SZ')"
  [ ! -e "$quarantine" ] || die "$EXIT_CONFLICT" "恢复证据目录已存在：${quarantine}"
  mv -- "$STATE_DIR" "$quarantine" || die "$EXIT_CONFLICT" '无法隔离空状态目录。'
  info "已隔离 rc.2 空状态；没有删除证据：${quarantine}"
  info 'State: UNMANAGED。现在可重新执行 preflight。'
}

rollback_internal() {
  local force_purge="$1" path failures=0 phase
  validate_state_file || return 1
  phase="$(state_get '.state')"
  if [ "$phase" = 'SWAP_RETAINED' ]; then
    if [ "$force_purge" = '1' ] || [ "$PURGE_CREATED_SWAP" = '1' ]; then
      purge_owned_swap || { state_set_phase 'DEGRADED' || true; return 1; }
      rm -rf -- "$STATE_DIR"
      info '保留的应急 swap 已清理，管理状态已删除。'
    else
      info "系统配置已处于回滚状态；应急 swap 仍保留：${SWAP_FILE}"
    fi
    return 0
  fi
  case "$phase" in
    PREPARED | ROLLBACK_PENDING | DEGRADED)
      if rollback_already_restored; then
        rm -rf -- "$STATE_DIR"
        info "状态 ${phase} 未检测到仍生效的项目配置；已清理残留事务状态。"
        return 0
      fi
      ;;
  esac
  for path in "$SYSCTL_FILE" "$JOURNAL_FILE" "$FQ_HELPER" "$FQ_SERVICE" "$XUI_DROPIN"; do
    [ -e "$path" ] || continue
    assert_owned_file "$path"
  done
  state_set_phase 'ROLLBACK_PENDING' || return 1
  if [ -e "$FQ_SERVICE" ]; then
    if ! systemctl disable --now "$FQ_SERVICE_NAME" >/dev/null 2>&1; then
      error "回滚步骤失败：无法停止或禁用 ${FQ_SERVICE_NAME}。"
      failures=$((failures + 1))
    fi
  fi
  if qdisc_snapshot_matches_current; then
    info '当前 qdisc 已与原始快照一致，无需重建。'
  else
    warn "当前 qdisc 与原始快照未判定为一致：${QDISC_MATCH_REASON}"
    if ! restore_qdiscs; then
      error '回滚步骤失败：无法恢复原始 qdisc。'
      failures=$((failures + 1))
    elif ! qdisc_snapshot_semantically_matches_current; then
      error "回滚步骤失败：qdisc 恢复后与原始快照不一致：${QDISC_MATCH_REASON}"
      failures=$((failures + 1))
    else
      info 'qdisc 已恢复并通过原始快照语义验证。'
    fi
  fi
  if ! rm -f -- "$SYSCTL_FILE" "$JOURNAL_FILE" "$FQ_HELPER" "$FQ_SERVICE" "$XUI_DROPIN"; then
    error '回滚步骤失败：无法删除一个或多个项目管理文件。'
    failures=$((failures + 1))
  fi
  rmdir -- "$XUI_DROPIN_DIR" >/dev/null 2>&1 || true
  if ! systemctl daemon-reload; then
    error '回滚步骤失败：systemctl daemon-reload。'
    failures=$((failures + 1))
  fi
  if ! sysctl --system >/dev/null; then
    error '回滚步骤失败：sysctl --system；请检查上方内核参数错误。'
    failures=$((failures + 1))
  fi
  restore_original_sysctls || failures=$((failures + 1))
  systemctl try-restart systemd-journald.service >/dev/null 2>&1 || true
  if [ "$force_purge" = '1' ] || [ "$PURGE_CREATED_SWAP" = '1' ]; then
    if ! purge_owned_swap; then
      error '回滚步骤失败：无法安全清理脚本创建的 swap。'
      failures=$((failures + 1))
    fi
  fi
  if [ "$failures" -ne 0 ]; then
    state_set_phase 'DEGRADED' || error '同时无法记录 DEGRADED；原状态文件已保留。'
    return 1
  fi
  if state_get '.swap.created_by_script' | grep -qx true && [ -e "$SWAP_FILE" ]; then
    state_set_phase 'SWAP_RETAINED' || return 1
    rm -f -- "$QDISC_STATE_FILE"
    info "系统配置已回滚；应急 swap 保留：${SWAP_FILE}"
  else
    rm -rf -- "$STATE_DIR"
    info '回滚完成，管理状态已清理。'
  fi
}

apply_failure_handler() {
  local rc="$1"
  trap - EXIT ERR INT TERM
  [ "$APPLY_ACTIVE" -eq 1 ] || exit "$rc"
  error "应用中断或失败（exit=${rc}）。"
  if state_exists && rollback_internal 1; then
    error '自动回滚完成。'
  elif ! state_exists && cleanup_uncommitted_state; then
    error '事务状态尚未提交，未写入系统配置；不完整状态已清理。'
  else
    error "自动回滚不完整；请保留 ${STATE_DIR} 并执行 status。"
  fi
  exit "$rc"
}

apply_settings() {
  run_preflight apply
  if state_exists; then
    local state saved_version saved_port saved_rtt saved_buf
    state="$(state_get '.state')"
    saved_version="$(state_get '.script_version')"
    if [ "$saved_version" != "$SCRIPT_VERSION" ]; then
      die "$EXIT_CONFLICT" "已安装状态属于 ${saved_version}，当前脚本为 ${SCRIPT_VERSION}；verify 可继续只读核验，升级配置必须先 rollback。"
    fi
    saved_port="$(state_get '.network.port_speed_mbps')"; saved_rtt="$(state_get '.network.target_rtt_ms')"; saved_buf="$(state_get '.network.buffer_max_bytes')"
    if [ "$saved_port" != "$PORT_SPEED_MBPS" ] || [ "$saved_rtt" != "$BUFFER_TARGET_RTT_MS" ] || [ "$saved_buf" != "$BUF_MAX" ]; then
      die "$EXIT_CONFLICT" "已安装参数与当前参数不同：saved(port=${saved_port},rtt=${saved_rtt},buf=${saved_buf}) current(port=${PORT_SPEED_MBPS},rtt=${BUFFER_TARGET_RTT_MS},buf=${BUF_MAX})；请先 rollback。"
    fi
    if [ "$state" = 'VERIFIED' ]; then verify_settings || die "$EXIT_VERIFY" '已安装配置验证失败。'; info '配置已存在且验证通过，无需重复写入。'; return 0; fi
    die "$EXIT_CONFLICT" "存在状态 ${state}；重新应用前请先完成 rollback，保留 swap 时需显式 purge 后再 apply。"
  fi
  APPLY_ACTIVE=1
  trap 'rc=$?; [ "$rc" -eq 0 ] || apply_failure_handler "$rc"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  write_initial_state || die "$EXIT_CONFLICT" '无法建立初始事务状态。'
  state_set_phase 'APPLYING' || die "$EXIT_CONFLICT" '无法记录 APPLYING。'
  write_sysctl_profile || die "$EXIT_CONFLICT" '无法写入 sysctl 配置。'
  refresh_managed_files || die "$EXIT_CONFLICT" '无法记录 sysctl 文件所有权。'
  write_journal_profile || die "$EXIT_CONFLICT" '无法写入 journald 配置。'
  refresh_managed_files || die "$EXIT_CONFLICT" '无法记录 journald 文件所有权。'
  write_xui_dropin || die "$EXIT_CONFLICT" '无法预置 x-ui.service 的 LimitNOFILE drop-in。'
  refresh_managed_files || die "$EXIT_CONFLICT" '无法记录 x-ui.service drop-in 所有权。'
  write_fq_helper || die "$EXIT_CONFLICT" '无法写入或记录 fq helper。'
  apply_kernel_settings || die "$EXIT_CONFLICT" '无法应用内核或 systemd 配置。'
  create_swap_if_needed || die "$EXIT_CONFLICT" 'swap 处理失败。'
  state_set_phase 'APPLIED' || die "$EXIT_CONFLICT" '无法记录 APPLIED。'
  refresh_managed_files || die "$EXIT_CONFLICT" '无法刷新管理文件所有权。'
  if ! verify_settings; then
    die "$EXIT_VERIFY" '应用后验证失败。'
  fi
  state_set_phase 'VERIFIED' || die "$EXIT_CONFLICT" '无法记录 VERIFIED。'
  APPLY_ACTIVE=0
  trap - EXIT ERR INT TERM
  info '应用完成。建议重启后再次执行 verify。'
}

show_status() {
  ensure_required_tools
  check_supported_os
  if ! state_exists; then info 'State: UNMANAGED'; return 0; fi
  validate_state_file
  jq '{script_version,state,profile,network,swap,timestamps,managed_files}' "$STATE_FILE"
  printf '[runtime] congestion_control=%s default_qdisc=%s\n' \
    "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)" \
    "$(sysctl -n net.core.default_qdisc 2>/dev/null || true)"
  tc qdisc show 2>/dev/null || true
  swapon --show 2>/dev/null || true
  ss -lntup 2>/dev/null || true
}

softnet_snapshot() {
  local source="${1:-/proc/net/softnet_stat}"
  local cpu=0 processed dropped squeezed
  while IFS=$' \t' read -r processed dropped squeezed _; do
    [ -n "$processed" ] || continue
    printf '%s\t%s\t%s\t%s\n' "$cpu" \
      "$((16#$processed))" "$((16#$dropped))" "$((16#$squeezed))"
    cpu=$((cpu + 1))
  done <"$source"
}

tcp_counter_snapshot() {
  local snmp_file="${1:-/proc/net/snmp}" netstat_file="${2:-/proc/net/netstat}"
  awk '
    FNR % 2 == 1 {
      prefix=$1
      sub(/:$/, "", prefix)
      for (i=2; i<=NF; i++) header[i]=$i
      next
    }
    {
      prefix=$1
      sub(/:$/, "", prefix)
      for (i=2; i<=NF; i++) {
        key=prefix header[i]
        if (key ~ /^(IpInDiscards|IpOutDiscards|TcpRetransSegs|TcpExtListenDrops|TcpExtListenOverflows|TcpExtTCPLostRetransmit|TcpExtTCPTimeouts|TcpExtTCPSpuriousRTOs|TcpExtTCPSynRetrans|TcpExtTCPFastOpenActive|TcpExtTCPFastOpenActiveFail|TcpExtTCPFastOpenPassive|TcpExtTCPFastOpenPassiveFail|TcpExtTCPFastOpenListenOverflow)$/) {
          print key "\t" $i
        }
      }
    }
  ' "$snmp_file" "$netstat_file" 2>/dev/null
}

show_counter_delta() {
  local before="$1" after="$2" prefix="$3"
  awk -F '\t' -v prefix="$prefix" '
    NR == FNR {old[$1]=$2; next}
    {delta=$2-(old[$1]+0); printf "[%s] %s=%d\n", prefix, $1, delta}
  ' "$before" "$after"
}

show_softnet_delta() {
  local before="$1" after="$2"
  awk -F '\t' '
    NR == FNR {processed[$1]=$2; dropped[$1]=$3; squeezed[$1]=$4; next}
    {
      printf "[softnet-delta] cpu=%s processed=%d dropped=%d time_squeeze=%d\n",
        $1, $2-(processed[$1]+0), $3-(dropped[$1]+0), $4-(squeezed[$1]+0)
    }
  ' "$before" "$after"
}

show_queue_cpu_evidence() {
  local iface="$1" queue file value
  for queue in "/sys/class/net/${iface}/queues"/rx-*; do
    [ -d "$queue" ] || continue
    printf '[queue] %s/%s' "$iface" "${queue##*/}"
    for file in rps_cpus rps_flow_cnt; do
      if [ -r "${queue}/${file}" ]; then
        IFS= read -r value <"${queue}/${file}" || value='unreadable'
        printf ' %s=%s' "$file" "$value"
      fi
    done
    printf '\n'
  done
  for queue in "/sys/class/net/${iface}/queues"/tx-*; do
    [ -d "$queue" ] || continue
    printf '[queue] %s/%s' "$iface" "${queue##*/}"
    for file in xps_cpus xps_rxqs; do
      if [ -r "${queue}/${file}" ]; then
        IFS= read -r value <"${queue}/${file}" || value='unreadable'
        printf ' %s=%s' "$file" "$value"
      fi
    done
    printf '\n'
  done
  awk -v iface="$iface" 'index($0, iface) {print "[interrupt] " $0}' /proc/interrupts 2>/dev/null || true
}

show_xray_socket_options() {
  local config='/usr/local/x-ui/bin/config.json' tfo keep_idle keep_interval
  if [ ! -r "$config" ]; then
    printf '[xray] generated_config=%s status=not-readable-or-not-installed\n' "$config"
    return 0
  fi
  if ! jq -e 'type == "object"' "$config" >/dev/null 2>&1; then
    printf '[xray] generated_config=%s status=invalid-json\n' "$config"
    return 0
  fi
  tfo="$(jq -r '[.. | objects | select(has("tcpFastOpen")) | .tcpFastOpen] | unique | map(tostring) | join(",")' "$config")"
  keep_idle="$(jq -r '[.. | objects | select(has("tcpKeepAliveIdle")) | .tcpKeepAliveIdle] | unique | map(tostring) | join(",")' "$config")"
  keep_interval="$(jq -r '[.. | objects | select(has("tcpKeepAliveInterval")) | .tcpKeepAliveInterval] | unique | map(tostring) | join(",")' "$config")"
  if [ -n "$tfo" ]; then
    printf '[xray] tcpFastOpen=%s source=generated-config\n' "$tfo"
  else
    printf '[xray] tcpFastOpen=not-explicit; kernel net.ipv4.tcp_fastopen alone does not prove Xray listener TFO\n'
  fi
  printf '[xray] tcpKeepAliveIdle=%s tcpKeepAliveInterval=%s source=generated-config\n' \
    "${keep_idle:-not-explicit}" "${keep_interval:-not-explicit}"
}

show_diagnostics() {
  local diagnostic_state='UNMANAGED' iface tmp_dir
  ensure_required_tools
  check_supported_os
  if ! report_sysctl_conflicts; then
    warn '只读诊断发现重复 sysctl 配置归属；请先按文件归属合并或移除，再执行 verify/apply。'
  fi
  [[ "$DIAG_INTERVAL_SECONDS" =~ ^[0-9]{1,2}$ ]] ||
    die "$EXIT_USAGE" 'DIAG_INTERVAL_SECONDS 必须是 1–60 的整数。'
  DIAG_INTERVAL_SECONDS=$((10#$DIAG_INTERVAL_SECONDS))
  if [ "$DIAG_INTERVAL_SECONDS" -lt 1 ] || [ "$DIAG_INTERVAL_SECONDS" -gt 60 ]; then
    die "$EXIT_USAGE" 'DIAG_INTERVAL_SECONDS 必须在 1–60 之间。'
  fi
  is_bool "$DIAG_INCLUDE_SOCKET_DETAILS" ||
    die "$EXIT_USAGE" 'DIAG_INCLUDE_SOCKET_DETAILS 只能为 0 或 1。'
  umask 077
  tmp_dir="$(mktemp -d)" || die "$EXIT_UNSUPPORTED" '无法创建诊断临时目录。'
  softnet_snapshot >"${tmp_dir}/softnet.before"
  tcp_counter_snapshot >"${tmp_dir}/tcp.before"
  if [ -e "$STATE_FILE" ] || [ -L "$STATE_FILE" ]; then
    diagnostic_state="$(jq -er '.state | select(type == "string")' "$STATE_FILE" 2>/dev/null || printf 'INVALID')"
  fi
  info '只读诊断：不会修改 sysctl、qdisc、systemd、swap 或代理服务。'
  printf '[system] version=%s profile=%s kernel=%s arch=%s cpu=%s memory_mib=%s\n' \
    "$SCRIPT_VERSION" "$PROFILE_ID" "$(uname -r)" "$(uname -m)" "$(nproc)" "$(memory_mib)"
  printf '[system] root_fs=%s state=%s\n' \
    "$(findmnt -n -o FSTYPE / 2>/dev/null || true)" \
    "$diagnostic_state"
  printf '[network] congestion_control=%s available_cc=%s default_qdisc=%s\n' \
    "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)" \
    "$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)" \
    "$(sysctl -n net.core.default_qdisc 2>/dev/null || true)"
  ip -br address show 2>/dev/null || true
  ip -4 route show default 2>/dev/null || true
  ip -6 route show default 2>/dev/null || true
  while IFS= read -r iface; do
    [ -n "$iface" ] || continue
    printf '[interface] %s rx_queues=%s tx_queues=%s\n' "$iface" \
      "$(find "/sys/class/net/${iface}/queues" -maxdepth 1 -type d -name 'rx-*' 2>/dev/null | wc -l)" \
      "$(find "/sys/class/net/${iface}/queues" -maxdepth 1 -type d -name 'tx-*' 2>/dev/null | wc -l)"
    ip -s link show dev "$iface" 2>/dev/null || true
    printf '[qdisc-before] interface=%s\n' "$iface"
    tc -s -d qdisc show dev "$iface" 2>/dev/null || true
    show_queue_cpu_evidence "$iface"
    if command -v ethtool >/dev/null 2>&1; then
      ethtool -k "$iface" 2>/dev/null | grep -E '^(receive-hashing|tcp-segmentation-offload|generic-segmentation-offload|generic-receive-offload):' || true
      ethtool -S "$iface" 2>/dev/null |
        grep -Ei 'drop|discard|miss|error|timeout|no.?buffer|overrun' || true
    fi
  done < <(default_route_ifaces)
  show_xray_socket_options
  ss -s 2>/dev/null || true
  if [ "$DIAG_INCLUDE_SOCKET_DETAILS" = '1' ]; then
    ss -tinp 2>/dev/null || true
  fi
  info "开始 ${DIAG_INTERVAL_SECONDS} 秒增量采样；期间可复现实际 VLESS + REALITY + TCP 负载。"
  sleep "$DIAG_INTERVAL_SECONDS"
  softnet_snapshot >"${tmp_dir}/softnet.after"
  tcp_counter_snapshot >"${tmp_dir}/tcp.after"
  show_counter_delta "${tmp_dir}/tcp.before" "${tmp_dir}/tcp.after" 'tcp-delta'
  show_softnet_delta "${tmp_dir}/softnet.before" "${tmp_dir}/softnet.after"
  while IFS= read -r iface; do
    [ -n "$iface" ] || continue
    printf '[qdisc-after] interface=%s\n' "$iface"
    tc -s -d qdisc show dev "$iface" 2>/dev/null || true
  done < <(default_route_ifaces)
  swapon --show 2>/dev/null || true
  rm -rf -- "$tmp_dir"
  info '诊断完成；增量计数是采样证据，不单独证明端到端业务性能。'
}

run_network_benchmark() {
  local host="${BENCHMARK_HOST:-}" port="${BENCHMARK_PORT:-5201}"
  local seconds="${BENCHMARK_SECONDS:-10}" parallel="${BENCHMARK_PARALLEL:-1}"
  local direction="${BENCHMARK_DIRECTION:-both}" tmp_dir rc=0 current_rc iface
  ensure_required_tools
  check_supported_os
  command -v iperf3 >/dev/null 2>&1 ||
    die "$EXIT_UNSUPPORTED" 'benchmark 需要已安装 iperf3；脚本不会自动安装软件包。'
  [ -n "$host" ] || die "$EXIT_USAGE" 'benchmark 必须显式设置 BENCHMARK_HOST。'
  [[ "$host" =~ ^[A-Za-z0-9][A-Za-z0-9._:%-]*$ ]] ||
    die "$EXIT_USAGE" 'BENCHMARK_HOST 含不支持的字符。'
  [[ "$port" =~ ^[0-9]{1,5}$ ]] || die "$EXIT_USAGE" 'BENCHMARK_PORT 必须是 1–65535 的整数。'
  port=$((10#$port)); [ "$port" -ge 1 ] && [ "$port" -le 65535 ] ||
    die "$EXIT_USAGE" 'BENCHMARK_PORT 必须在 1–65535 之间。'
  [[ "$seconds" =~ ^[0-9]{1,3}$ ]] || die "$EXIT_USAGE" 'BENCHMARK_SECONDS 必须是 5–120 的整数。'
  seconds=$((10#$seconds)); [ "$seconds" -ge 5 ] && [ "$seconds" -le 120 ] ||
    die "$EXIT_USAGE" 'BENCHMARK_SECONDS 必须在 5–120 之间。'
  [[ "$parallel" =~ ^[0-9]$ ]] || die "$EXIT_USAGE" 'BENCHMARK_PARALLEL 必须是 1–4 的整数。'
  parallel=$((10#$parallel)); [ "$parallel" -ge 1 ] && [ "$parallel" -le 4 ] ||
    die "$EXIT_USAGE" 'BENCHMARK_PARALLEL 必须在 1–4 之间。'
  case "$direction" in upload | download | both) ;; *) die "$EXIT_USAGE" 'BENCHMARK_DIRECTION 只能为 upload、download 或 both。' ;; esac

  info 'benchmark 不修改系统配置，但会向用户指定的 iperf3 服务器产生高带宽 TCP 流量。'
  info '该测试测量 VPS 到 iperf3 服务端的直连 TCP，不等同于 VLESS + REALITY + TCP 业务链路。'
  umask 077
  tmp_dir="$(mktemp -d)" || die "$EXIT_UNSUPPORTED" '无法创建 benchmark 临时目录。'
  softnet_snapshot >"${tmp_dir}/softnet.before"
  tcp_counter_snapshot >"${tmp_dir}/tcp.before"
  while IFS= read -r iface; do
    [ -n "$iface" ] || continue
    printf '[qdisc-before] interface=%s\n' "$iface"
    tc -s -d qdisc show dev "$iface" 2>/dev/null || true
  done < <(default_route_ifaces)

  set +e
  if [ "$direction" = 'upload' ] || [ "$direction" = 'both' ]; then
    iperf3 --client "$host" --port "$port" --time "$seconds" --parallel "$parallel" --json
    current_rc=$?; [ "$current_rc" -eq 0 ] || rc="$current_rc"
  fi
  if [ "$direction" = 'download' ] || [ "$direction" = 'both' ]; then
    iperf3 --client "$host" --port "$port" --time "$seconds" --parallel "$parallel" --reverse --json
    current_rc=$?; [ "$current_rc" -eq 0 ] || rc="$current_rc"
  fi
  set -e

  softnet_snapshot >"${tmp_dir}/softnet.after"
  tcp_counter_snapshot >"${tmp_dir}/tcp.after"
  show_counter_delta "${tmp_dir}/tcp.before" "${tmp_dir}/tcp.after" 'benchmark-tcp-delta'
  show_softnet_delta "${tmp_dir}/softnet.before" "${tmp_dir}/softnet.after"
  while IFS= read -r iface; do
    [ -n "$iface" ] || continue
    printf '[qdisc-after] interface=%s\n' "$iface"
    tc -s -d qdisc show dev "$iface" 2>/dev/null || true
  done < <(default_route_ifaces)
  rm -rf -- "$tmp_dir"
  [ "$rc" -eq 0 ] || die "$EXIT_VERIFY" "iperf3 benchmark 失败，退出码：${rc}。"
  info 'benchmark 完成；请结合业务流量下的 diagnose 和客户端指标判断。'
}

usage() {
  cat <<EOF_USAGE
Usage: $0 {preflight|apply|verify|status|diagnose|benchmark|rollback|recover}

Environment:
  PORT_SPEED_MBPS=100..1000       default 200
  BUFFER_TARGET_RTT_MS=20..500    default 200
  BUF_MAX=auto|262144..${MAX_BUF_MAX}   default auto; profile memory cap
  ENABLE_SWAP=0|1                 default 1
  SWAP_MB=512..${SWAP_MAX_MIB}             default 1024
  PURGE_CREATED_SWAP=0|1          default 0
  ALLOW_EMPTY_STATE_RECOVERY=0|1  default 0; only for confirmed rc.2 pre-write empty state
  PROXY_SERVICE_UNITS='x-ui.service ...'
  REQUIRE_PROXY_SERVICE=0|1       default 0
  DIAG_INTERVAL_SECONDS=1..60     default 5
  DIAG_INCLUDE_SOCKET_DETAILS=0|1 default 0; 1 may expose peer addresses/processes
  BENCHMARK_HOST=host             required by benchmark; user-authorized iperf3 server
  BENCHMARK_PORT=1..65535         default 5201
  BENCHMARK_SECONDS=5..120        default 10
  BENCHMARK_PARALLEL=1..4         default 1
  BENCHMARK_DIRECTION=upload|download|both   default both
EOF_USAGE
}

main() {
  local action="${1:-}"
  case "$action" in
    preflight)
      need_root; acquire_lock; run_preflight
      ;;
    apply)
      need_root; acquire_lock; apply_settings
      ;;
    verify)
      need_root; acquire_lock
      state_exists || die "$EXIT_VERIFY" '当前主机尚未安装本项目配置；请先执行 preflight，确认通过后再执行 apply。'
      ensure_required_tools; check_supported_os; validate_inputs
      validate_state_file
      verify_settings || die "$EXIT_VERIFY" '验证失败。'
      ;;
    status)
      need_root; acquire_lock; show_status
      ;;
    diagnose)
      need_root; acquire_lock; show_diagnostics
      ;;
    benchmark)
      need_root; acquire_lock; run_network_benchmark
      ;;
    rollback)
      need_root; acquire_lock; ensure_required_tools; check_supported_os
      state_exists || { info '没有可回滚的管理状态。'; exit 0; }
      rollback_internal 0 || die "$EXIT_ROLLBACK" '回滚不完整；状态已保留。'
      ;;
    recover)
      need_root; acquire_lock; ensure_required_tools; check_supported_os
      recover_empty_legacy_state
      ;;
    -h | --help | help) usage ;;
    *) usage >&2; exit "$EXIT_USAGE" ;;
  esac
}

main "$@"
