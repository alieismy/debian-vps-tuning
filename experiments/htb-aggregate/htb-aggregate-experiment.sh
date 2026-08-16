#!/usr/bin/env bash
# VMISS Basic 200-Mbps temporary aggregate HTB experiment.
# This tool is intentionally non-persistent. It does not change sysctl,
# routing, firewall, proxy services, or the managed systemd fq service.

set -Eeuo pipefail
IFS=$'\n\t'
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

TOOL_VERSION='0.4.0'
EXPECTED_IFACE='eth0'
EXPECTED_PORT_MBIT=200
EXPECTED_MANAGED_STATE_SCHEMA=4
EXPECTED_TUNING_VERSION='0.1.0-rc.12'
DEFAULT_RATE_MBIT=190
BURST_BYTES=262144
CBURST_BYTES=32768
QUANTUM_BYTES=15140
STATE_DIR='/run/htb-aggregate-experiment'
STATE_FILE="${STATE_DIR}/active.json"
LAST_STATE_FILE="${STATE_DIR}/last-session.json"
ORIGINAL_QDISC_FILE="${STATE_DIR}/original-qdisc.json"
START_TRACE_FILE="${STATE_DIR}/start-trace.log"
FAILURE_QDISC_FILE="${STATE_DIR}/failure-qdisc.json"
FAILURE_CLASS_FILE="${STATE_DIR}/failure-class.json"
LOCK_FILE='/run/lock/htb-aggregate-experiment.lock'
MANAGED_STATE_FILE='/var/lib/proxy-vps-tuning/state.json'
FQ_SERVICE='proxy-vps-fq.service'
WATCHDOG_UNIT_PREFIX='htb-aggregate-autorestore'
WATCHDOG_DELAY='40m'
INSTALL_PATH='/usr/local/sbin/htb-aggregate-experiment'

log() { printf '[htb-experiment] %s\n' "$*"; }
warn() { printf '[htb-experiment][WARN] %s\n' "$*" >&2; }
die() { printf '[htb-experiment][FAIL] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  htb-aggregate-experiment preflight
  htb-aggregate-experiment start [--rate MBIT]
  htb-aggregate-experiment assert-active [--rate MBIT]
  htb-aggregate-experiment smoke-test [--rate MBIT] [--hold-seconds SECONDS]
  htb-aggregate-experiment status
  htb-aggregate-experiment stop

The initial approved candidate is 190 Mbit/s. Values from 100 through 199
are accepted for later explicitly reviewed stages. Do not start a second rate
stage before analysing and closing the preceding A/B/A stage.
EOF
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

require_root() {
  [ "$(id -u)" -eq 0 ] || die '必须以 root 运行。'
}

prepare_runtime() {
  require_root
  for command in awk chmod date flock grep id install ip jq modprobe mv readlink \
    rm sha256sum sleep stat sysctl systemctl systemd-run tc; do
    need_command "$command"
  done
  install -d -o root -g root -m 0700 "$STATE_DIR"
  install -d -o root -g root -m 0755 /run/lock
  exec 9>"$LOCK_FILE"
  flock -n 9 || die '另一个 HTB 实验操作正在运行。'
}

default_route_iface() {
  local family="$1"
  ip "-$family" -o route show default 2>/dev/null |
    awk '{for (i=1; i<=NF; i++) if ($i == "dev" && (i+1) <= NF) print $(i+1)}' |
    awk 'NF && !seen[$0]++'
}

resolve_target_iface() {
  local -a v4_ifaces=() v6_ifaces=()
  mapfile -t v4_ifaces < <(default_route_iface 4)
  mapfile -t v6_ifaces < <(default_route_iface 6)
  [ "${#v4_ifaces[@]}" -eq 1 ] || die 'IPv4 默认路由接口不是唯一接口。'
  [ "${v4_ifaces[0]}" = "$EXPECTED_IFACE" ] ||
    die "IPv4 默认接口不是预期的 ${EXPECTED_IFACE}：${v4_ifaces[0]}"
  if [ "${#v6_ifaces[@]}" -gt 1 ]; then
    die 'IPv6 默认路由接口不是唯一接口。'
  fi
  if [ "${#v6_ifaces[@]}" -eq 1 ] && [ "${v6_ifaces[0]}" != "$EXPECTED_IFACE" ]; then
    die "IPv6 默认接口与 IPv4 不同：${v6_ifaces[0]}"
  fi
  ip link show dev "$EXPECTED_IFACE" | grep -q 'state UP' ||
    die "接口 ${EXPECTED_IFACE} 不是 UP 状态。"
  printf '%s\n' "$EXPECTED_IFACE"
}

normalized_sysctl() {
  sysctl -n "$1" 2>/dev/null | awk '{$1=$1; print}'
}

managed_profile_id() {
  jq -r '.profile.id // empty' "$MANAGED_STATE_FILE" 2>/dev/null
}

managed_state_sha256() {
  sha256sum "$MANAGED_STATE_FILE" | awk '{print $1}'
}

verify_managed_host_baseline() {
  [ -s "$MANAGED_STATE_FILE" ] || die "缺少调优状态：${MANAGED_STATE_FILE}"
  jq -e \
    --argjson schema "$EXPECTED_MANAGED_STATE_SCHEMA" \
    --arg version "$EXPECTED_TUNING_VERSION" \
    --argjson port "$EXPECTED_PORT_MBIT" '
    (.schema_version == $schema) and
    (.state == "VERIFIED") and
    (.script_version == $version) and
    ((.profile.id == "debian13-1c1g") or
     (.profile.id == "debian13-1c2g")) and
    (.network.port_speed_mbps == $port)
  ' "$MANAGED_STATE_FILE" >/dev/null ||
    die '调优状态不是 rc.12 schema-4 VERIFIED/debian13-1c1g-or-1c2g/200-Mbps 基线。'

  [ "$(normalized_sysctl net.ipv4.tcp_congestion_control)" = 'bbr' ] ||
    die '当前拥塞控制不是 bbr。'
  [ "$(normalized_sysctl net.core.default_qdisc)" = 'fq' ] ||
    die 'net.core.default_qdisc 不是 fq。'
  [ "$(normalized_sysctl net.ipv4.tcp_rmem)" = '4096 131072 16777216' ] ||
    die 'tcp_rmem 已偏离 S3 基线。'
  [ "$(normalized_sysctl net.ipv4.tcp_wmem)" = '4096 65536 16777216' ] ||
    die 'tcp_wmem 已偏离 S3 基线。'

  systemctl is-active --quiet "$FQ_SERVICE" ||
    die "${FQ_SERVICE} 不是 active。"
}

verify_active_managed_binding() {
  local expected_profile expected_hash actual_profile actual_hash
  expected_profile="$(jq -r '.managed_profile_id // empty' "$STATE_FILE")"
  expected_hash="$(jq -r '.managed_state_sha256 // empty' "$STATE_FILE")"
  [ -s "$MANAGED_STATE_FILE" ] || {
    warn '实验期间调优状态文件消失。'
    return 1
  }
  actual_profile="$(managed_profile_id)"
  actual_hash="$(managed_state_sha256)"
  [ "$actual_profile" = "$expected_profile" ] || {
    warn "实验期间 profile 漂移：expected=${expected_profile:-missing} actual=${actual_profile:-missing}"
    return 1
  }
  [ "$actual_hash" = "$expected_hash" ] || {
    warn '实验期间调优状态文件哈希发生变化。'
    return 1
  }
  verify_managed_host_baseline
}

current_qdisc_json() {
  tc -j -s -d qdisc show dev "$1"
}

current_class_json() {
  tc -j -s -d class show dev "$1"
}

verify_plain_fq_topology() {
  local iface="$1" qdisc_json class_json
  qdisc_json="$(current_qdisc_json "$iface")" || return 1
  class_json="$(current_class_json "$iface")" || return 1
  jq -e '
    (length == 1) and
    (.[0].root == true) and
    (.[0].kind == "fq")
  ' <<<"$qdisc_json" >/dev/null || return 1
  jq -e 'length == 0' <<<"$class_json" >/dev/null || return 1
}

verify_experiment_topology() {
  local iface="$1" expected_rate_mbit="$2" expected_rate_bps qdisc_json class_json
  [[ "$expected_rate_mbit" =~ ^[0-9]+$ ]] || return 1
  expected_rate_bps=$((10#$expected_rate_mbit * 125000))
  qdisc_json="$(current_qdisc_json "$iface")" || return 1
  class_json="$(current_class_json "$iface")" || return 1
  jq -e '
    ([.[] | select(.root == true)] | length == 1) and
    ([.[] | select(.root == true and .kind == "htb" and .handle == "1:")] | length == 1) and
    ([.[] | select(.parent == "1:10" and .kind == "fq" and .handle == "10:")] | length == 1)
  ' <<<"$qdisc_json" >/dev/null || return 1
  jq -e --argjson expected_rate_bps "$expected_rate_bps" '
    def class_kind: (.kind // .class // "");
    def class_id: (.classid // .handle // "");
    def class_rate: (.rate // .options.rate // -1);
    def class_ceil: (.ceil // .options.ceil // -1);
    ([.[] |
      select(
        class_kind == "htb" and
        class_id == "1:10" and
        class_rate == $expected_rate_bps and
        class_ceil == $expected_rate_bps
      )
    ] | length == 1)
  ' <<<"$class_json" >/dev/null || return 1
}

active_state_rate() {
  jq -r '.rate_mbit // empty' "$STATE_FILE" 2>/dev/null
}

assert_active_internal() {
  local expected_rate="$1" iface watchdog_unit actual_rate profile
  validate_active_state
  [ "$(jq -r '.phase' "$STATE_FILE")" = 'ACTIVE' ] || {
    warn '实验状态不是 ACTIVE。'
    return 1
  }
  iface="$(jq -r '.interface' "$STATE_FILE")"
  actual_rate="$(active_state_rate)"
  [ "$actual_rate" = "$expected_rate" ] || {
    warn "活动速率不匹配：expected=${expected_rate} actual=${actual_rate:-missing}"
    return 1
  }
  verify_active_managed_binding || {
    warn '活动状态与受管调优基线的绑定验证失败。'
    return 1
  }
  profile="$(jq -r '.managed_profile_id' "$STATE_FILE")"
  verify_experiment_topology "$iface" "$expected_rate" || {
    warn '运行时 HTB/class/fq 拓扑验证失败。'
    return 1
  }
  watchdog_unit="$(jq -r '.watchdog_unit // empty' "$STATE_FILE")"
  if [ -z "$watchdog_unit" ] || ! systemctl is-active --quiet "${watchdog_unit}.timer"; then
    warn '自动回滚 timer 不是 active。'
    return 1
  fi
  log "active-check=PASS profile=${profile} interface=${iface} rate=${actual_rate}Mbit root=htb class=1:10 leaf=fq watchdog=active"
}

write_json_atomically() {
  local target="$1" filter="$2" source="$3" tmp
  tmp="${target}.tmp.$$"
  jq "$filter" "$source" >"$tmp" || { rm -f -- "$tmp"; return 1; }
  chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$target" || { rm -f -- "$tmp"; return 1; }
}

validate_active_state() {
  [ -s "$STATE_FILE" ] || die '没有活动的 HTB 实验状态。'
  jq -e '
    (.schema_version == 2) and
    (.tool_version == "0.4.0") and
    ((.phase == "PREPARED") or (.phase == "ACTIVE")) and
    (.interface | type == "string") and
    (.rate_mbit | type == "number") and
    (.boot_id | type == "string") and
    (.watchdog_unit | type == "string" and length > 0) and
    ((.managed_profile_id == "debian13-1c1g") or
     (.managed_profile_id == "debian13-1c2g")) and
    (.managed_state_sha256 | test("^[0-9a-f]{64}$")) and
    (.original_qdisc_sha256 | test("^[0-9a-f]{64}$"))
  ' "$STATE_FILE" >/dev/null || die '活动状态文件无效。'
  [ "$(stat -c '%u:%g:%a' "$STATE_FILE")" = '0:0:600' ] ||
    die '活动状态文件所有权或权限异常。'
}

preflight_internal() {
  local iface root_hash profile state_hash
  [ ! -e "$STATE_FILE" ] || die '已经存在活动状态；请先执行 status 或 stop。'
  iface="$(resolve_target_iface)"
  verify_managed_host_baseline
  profile="$(managed_profile_id)"
  state_hash="$(managed_state_sha256)"
  verify_plain_fq_topology "$iface" ||
    die "${iface} 不是预期的单一根 fq/无 class 拓扑。"

  modprobe -n sch_htb >/dev/null 2>&1 ||
    warn 'modprobe -n sch_htb 未确认模块；start 将进行最终加载检查。'
  root_hash="$(current_qdisc_json "$iface" | sha256sum | awk '{print $1}')"
  log "preflight=PASS profile=${profile} managed_state_sha256=${state_hash} interface=${iface} provider_port=${EXPECTED_PORT_MBIT}Mbit root=fq qdisc_sha256=${root_hash}"
  log 'scope=egress IPv4+IPv6; persistence=none; sysctl/routes/firewall/proxy=unchanged'
}

arm_watchdog() {
  local watchdog_unit="$1" script_path
  script_path="$(readlink -f "$0")"
  if [ "$script_path" != "$INSTALL_PATH" ]; then
    warn "start 只能从 ${INSTALL_PATH} 运行，以保证自动回滚路径稳定。"
    return 1
  fi
  if ! systemd-run --quiet \
    --unit="$watchdog_unit" \
    --on-active="$WATCHDOG_DELAY" \
    "$INSTALL_PATH" stop --from-watchdog; then
    warn '无法创建 40 分钟自动回滚 timer。'
    return 1
  fi
  if ! systemctl is-active --quiet "${watchdog_unit}.timer"; then
    warn '40 分钟自动回滚 timer 未进入 active。'
    return 1
  fi
}

cancel_watchdog() {
  local watchdog_unit="$1"
  [ -n "$watchdog_unit" ] || return 0
  systemctl stop "${watchdog_unit}.timer" >/dev/null 2>&1 || true
  systemctl reset-failed "${watchdog_unit}.service" "${watchdog_unit}.timer" >/dev/null 2>&1 || true
}

restore_plain_fq() {
  local iface="$1"
  tc qdisc replace dev "$iface" root fq
  verify_plain_fq_topology "$iface"
}

capture_failure_runtime() {
  local iface="$1"
  current_qdisc_json "$iface" >"$FAILURE_QDISC_FILE" 2>/dev/null || true
  current_class_json "$iface" >"$FAILURE_CLASS_FILE" 2>/dev/null || true
  chmod 0600 "$FAILURE_QDISC_FILE" "$FAILURE_CLASS_FILE" 2>/dev/null || true
  {
    printf '\n===== FAILURE QDISC =====\n'
    tc -s -d qdisc show dev "$iface" 2>&1 || true
    printf '\n===== FAILURE CLASS =====\n'
    tc -s -d class show dev "$iface" 2>&1 || true
    printf '\n===== FAILURE QDISC JSON =====\n'
    jq . "$FAILURE_QDISC_FILE" 2>&1 || true
    printf '\n===== FAILURE CLASS JSON =====\n'
    jq . "$FAILURE_CLASS_FILE" 2>&1 || true
  } | tee -a "$START_TRACE_FILE" >&2
}

fail_started_transaction() {
  local iface="$1" watchdog_unit="$2" stage="$3" reason="$4"
  local rollback='FAILED' failed_tmp
  warn "start_stage=${stage} result=FAIL reason=${reason}"
  capture_failure_runtime "$iface"
  cancel_watchdog "$watchdog_unit"
  if restore_plain_fq "$iface"; then
    rollback='PASS'
  fi
  failed_tmp="${LAST_STATE_FILE}.tmp.$$"
  if [ -s "$STATE_FILE" ]; then
    jq --arg stage "$stage" \
      --arg reason "$reason" \
      --arg rollback "$rollback" \
      --arg failed "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '.phase = "FAILED" | .failed_stage = $stage | .failure_reason = $reason |
        .rollback_result = $rollback | .failed_utc = $failed' \
      "$STATE_FILE" >"$failed_tmp" 2>/dev/null || true
    if [ -s "$failed_tmp" ]; then
      chmod 0600 "$failed_tmp" || true
      mv -f -- "$failed_tmp" "$LAST_STATE_FILE" || true
    fi
  fi
  rm -f -- "$STATE_FILE" "${STATE_FILE}.tmp."* 2>/dev/null || true
  warn "rollback_root_fq=${rollback} trace=${START_TRACE_FILE}"
  die "HTB start 在 ${stage} 阶段失败：${reason}；已尝试恢复根 fq。"
}

run_tc_stage() {
  local stage="$1"
  shift
  log "start_stage=${stage} action=BEGIN"
  {
    printf '\n[%s] utc=%s command=' "$stage" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf ' %q' tc "$@"
    printf '\n'
  } >>"$START_TRACE_FILE"
  if tc "$@" 2>&1 | tee -a "$START_TRACE_FILE"; then
    log "start_stage=${stage} action=PASS"
    return 0
  fi
  warn "start_stage=${stage} action=FAIL"
  return 1
}

start_experiment() {
  local rate="$DEFAULT_RATE_MBIT" iface boot_id qdisc_sha state_tmp watchdog_unit profile managed_hash
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --rate)
        [ "$#" -ge 2 ] || die '--rate 缺少参数。'
        rate="$2"
        shift 2
        ;;
      *) die "未知 start 参数：$1" ;;
    esac
  done
  [[ "$rate" =~ ^[0-9]{3}$ ]] || die 'rate 必须是 100–200 的整数。'
  rate=$((10#$rate))
  [ "$rate" -ge 100 ] && [ "$rate" -le "$EXPECTED_PORT_MBIT" ] ||
    die 'rate 必须在 100–200 Mbit/s 之间。'

  preflight_internal
  iface="$(resolve_target_iface)"
  profile="$(managed_profile_id)"
  managed_hash="$(managed_state_sha256)"
  : >"$START_TRACE_FILE"
  chmod 0600 "$START_TRACE_FILE"
  printf '[start] tool_version=%s utc=%s interface=%s rate_mbit=%s\n' \
    "$TOOL_VERSION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$iface" "$rate" \
    >>"$START_TRACE_FILE"
  modprobe sch_htb >/dev/null 2>&1 || die '无法加载 sch_htb。'
  modprobe sch_fq >/dev/null 2>&1 || die '无法加载 sch_fq。'

  current_qdisc_json "$iface" >"${ORIGINAL_QDISC_FILE}.tmp"
  chmod 0600 "${ORIGINAL_QDISC_FILE}.tmp"
  mv -f -- "${ORIGINAL_QDISC_FILE}.tmp" "$ORIGINAL_QDISC_FILE"
  qdisc_sha="$(sha256sum "$ORIGINAL_QDISC_FILE" | awk '{print $1}')"
  boot_id="$(awk 'NR == 1 {print; exit}' /proc/sys/kernel/random/boot_id)"
  watchdog_unit="${WATCHDOG_UNIT_PREFIX}-$(date -u +%Y%m%d%H%M%S)-$$"
  state_tmp="${STATE_FILE}.tmp.$$"
  jq -n \
    --arg version "$TOOL_VERSION" \
    --arg phase PREPARED \
    --arg iface "$iface" \
    --arg boot "$boot_id" \
    --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg qhash "$qdisc_sha" \
    --arg watchdog_unit "$watchdog_unit" \
    --arg profile "$profile" \
    --arg managed_hash "$managed_hash" \
    --argjson provider "$EXPECTED_PORT_MBIT" \
    --argjson rate "$rate" \
    --argjson burst "$BURST_BYTES" \
    --argjson cburst "$CBURST_BYTES" \
    --argjson quantum "$QUANTUM_BYTES" \
    '{schema_version:2,tool_version:$version,phase:$phase,interface:$iface,
      boot_id:$boot,started_utc:$started,provider_port_mbit:$provider,
      managed_profile_id:$profile,managed_state_sha256:$managed_hash,
      rate_mbit:$rate,burst_bytes:$burst,cburst_bytes:$cburst,
      quantum_bytes:$quantum,original_qdisc_sha256:$qhash,
      watchdog_unit:$watchdog_unit}' >"$state_tmp"
  chmod 0600 "$state_tmp"
  mv -f -- "$state_tmp" "$STATE_FILE"

  if ! run_tc_stage root-htb \
    qdisc replace dev "$iface" root handle 1: htb default 10; then
    fail_started_transaction "$iface" "$watchdog_unit" root-htb '无法建立根 HTB。'
  fi
  if ! run_tc_stage class-1-10 \
    class replace dev "$iface" parent 1: classid 1:10 htb \
      rate "${rate}mbit" ceil "${rate}mbit" \
      burst "${BURST_BYTES}b" cburst "${CBURST_BYTES}b" quantum "$QUANTUM_BYTES"; then
    fail_started_transaction "$iface" "$watchdog_unit" class-1-10 '无法建立 HTB 1:10 class。'
  fi
  if ! run_tc_stage leaf-fq \
    qdisc replace dev "$iface" parent 1:10 handle 10: fq; then
    fail_started_transaction "$iface" "$watchdog_unit" leaf-fq '无法建立 1:10 的 fq 叶子。'
  fi
  {
    printf '\n===== APPLIED QDISC =====\n'
    tc -s -d qdisc show dev "$iface"
    printf '\n===== APPLIED CLASS =====\n'
    tc -s -d class show dev "$iface"
    printf '\n===== APPLIED QDISC JSON =====\n'
    current_qdisc_json "$iface" | jq .
    printf '\n===== APPLIED CLASS JSON =====\n'
    current_class_json "$iface" | jq .
  } >>"$START_TRACE_FILE" 2>&1 ||
    fail_started_transaction "$iface" "$watchdog_unit" topology-capture '无法保存 HTB 运行时证据。'
  if ! verify_experiment_topology "$iface" "$rate"; then
    fail_started_transaction "$iface" "$watchdog_unit" topology-verify 'HTB/class/fq 运行时拓扑不匹配。'
  fi
  if ! arm_watchdog "$watchdog_unit"; then
    fail_started_transaction "$iface" "$watchdog_unit" watchdog '无法建立 40 分钟自动回滚 timer。'
  fi
  if ! write_json_atomically "$STATE_FILE" '.phase = "ACTIVE"' "$STATE_FILE"; then
    fail_started_transaction "$iface" "$watchdog_unit" state-commit '无法提交 ACTIVE 状态。'
  fi
  if ! assert_active_internal "$rate"; then
    fail_started_transaction "$iface" "$watchdog_unit" active-assert 'ACTIVE 状态、拓扑或 watchdog 联合门禁失败。'
  fi
  log "start=PASS profile=${profile} interface=${iface} aggregate_rate=${rate}Mbit leaf=fq watchdog=${WATCHDOG_DELAY}"
  log "紧急回滚：tc qdisc replace dev ${iface} root fq"
  show_status
}

assert_active_command() {
  local rate="$DEFAULT_RATE_MBIT"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --rate)
        [ "$#" -ge 2 ] || die '--rate 缺少参数。'
        rate="$2"
        shift 2
        ;;
      *) die "未知 assert-active 参数：$1" ;;
    esac
  done
  [[ "$rate" =~ ^[0-9]{3}$ ]] || die 'rate 必须是 100–200 的整数。'
  rate=$((10#$rate))
  [ "$rate" -ge 100 ] && [ "$rate" -le "$EXPECTED_PORT_MBIT" ] ||
    die 'rate 必须在 100–200 Mbit/s 之间。'
  assert_active_internal "$rate" || die 'ACTIVE 联合门禁失败。'
}

smoke_test() {
  local rate="$DEFAULT_RATE_MBIT" hold_seconds=10 smoke_active=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --rate)
        [ "$#" -ge 2 ] || die '--rate 缺少参数。'
        rate="$2"
        shift 2
        ;;
      --hold-seconds)
        [ "$#" -ge 2 ] || die '--hold-seconds 缺少参数。'
        hold_seconds="$2"
        shift 2
        ;;
      *) die "未知 smoke-test 参数：$1" ;;
    esac
  done
  [[ "$rate" =~ ^[0-9]{3}$ ]] || die 'rate 必须是 100–200 的整数。'
  rate=$((10#$rate))
  [ "$rate" -ge 100 ] && [ "$rate" -le "$EXPECTED_PORT_MBIT" ] ||
    die 'rate 必须在 100–200 Mbit/s 之间。'
  [[ "$hold_seconds" =~ ^[0-9]+$ ]] || die 'hold-seconds 必须是 5–30 的整数。'
  hold_seconds=$((10#$hold_seconds))
  [ "$hold_seconds" -ge 5 ] && [ "$hold_seconds" -le 30 ] ||
    die 'hold-seconds 必须在 5–30 秒之间。'

  smoke_cleanup() {
    if [ "$smoke_active" -eq 1 ] && [ -s "$STATE_FILE" ]; then
      warn 'smoke-test 中断；正在恢复根 fq。'
      stop_experiment || true
    fi
  }
  trap smoke_cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  log "smoke-test=BEGIN rate=${rate}Mbit hold_seconds=${hold_seconds}"
  start_experiment --rate "$rate"
  smoke_active=1
  assert_active_internal "$rate" || die 'smoke-test ACTIVE 门禁失败。'
  sleep "$hold_seconds"
  stop_experiment
  smoke_active=0
  preflight_internal
  trap - EXIT INT TERM
  log "smoke-test=PASS rate=${rate}Mbit restored=root-fq"
}

show_status() {
  local iface="$EXPECTED_IFACE" watchdog_unit=''
  if [ -s "$STATE_FILE" ]; then
    jq . "$STATE_FILE"
    iface="$(jq -r '.interface' "$STATE_FILE")"
    watchdog_unit="$(jq -r '.watchdog_unit // empty' "$STATE_FILE")"
  else
    log 'state=INACTIVE'
    if [ -s "$LAST_STATE_FILE" ]; then
      printf '\n===== LAST SESSION =====\n'
      jq . "$LAST_STATE_FILE"
    fi
  fi
  printf '\n===== QDISC =====\n'
  tc -s -d qdisc show dev "$iface"
  printf '\n===== CLASS =====\n'
  tc -s -d class show dev "$iface"
  printf '\n===== QDISC JSON =====\n'
  tc -j -s -d qdisc show dev "$iface" | jq .
  printf '\n===== CLASS JSON =====\n'
  tc -j -s -d class show dev "$iface" | jq .
  printf '\n===== WATCHDOG =====\n'
  if [ -n "$watchdog_unit" ]; then
    printf 'unit=%s.timer\n' "$watchdog_unit"
    systemctl is-active "${watchdog_unit}.timer" 2>/dev/null || true
  else
    printf 'inactive\n'
  fi
}

stop_experiment() {
  local from_watchdog=0 already_restored=0 iface rate profile boot_id expected_boot qhash actual_qhash stopped_tmp watchdog_unit
  if [ "${1:-}" = '--from-watchdog' ]; then
    from_watchdog=1
    shift
  fi
  [ "$#" -eq 0 ] || die "未知 stop 参数：$*"
  validate_active_state
  verify_active_managed_binding || die '活动状态与受管调优基线的绑定验证失败；拒绝根据旧假设修改 qdisc。'
  iface="$(jq -r '.interface' "$STATE_FILE")"
  rate="$(jq -r '.rate_mbit' "$STATE_FILE")"
  profile="$(jq -r '.managed_profile_id' "$STATE_FILE")"
  watchdog_unit="$(jq -r '.watchdog_unit // empty' "$STATE_FILE")"
  expected_boot="$(jq -r '.boot_id' "$STATE_FILE")"
  boot_id="$(awk 'NR == 1 {print; exit}' /proc/sys/kernel/random/boot_id)"
  [ "$boot_id" = "$expected_boot" ] ||
    die 'boot_id 已变化；拒绝根据旧状态修改当前 qdisc。'
  [ -s "$ORIGINAL_QDISC_FILE" ] || die '原始 qdisc 快照缺失。'
  qhash="$(jq -r '.original_qdisc_sha256' "$STATE_FILE")"
  actual_qhash="$(sha256sum "$ORIGINAL_QDISC_FILE" | awk '{print $1}')"
  [ "$qhash" = "$actual_qhash" ] || die '原始 qdisc 快照哈希不匹配。'
  if verify_experiment_topology "$iface" "$rate"; then
    current_qdisc_json "$iface" >"${STATE_DIR}/pre-stop-qdisc.json"
    current_class_json "$iface" >"${STATE_DIR}/pre-stop-class.json"
    chmod 0600 "${STATE_DIR}/pre-stop-qdisc.json" "${STATE_DIR}/pre-stop-class.json"
    if ! restore_plain_fq "$iface"; then
      write_json_atomically "$STATE_FILE" '.phase = "DEGRADED"' "$STATE_FILE" || true
      die "恢复根 fq 失败；请从控制台执行：tc qdisc replace dev ${iface} root fq"
    fi
  elif verify_plain_fq_topology "$iface"; then
    already_restored=1
    warn '当前已经是单一根 fq；将只对账并关闭残留实验状态。'
  else
    die '当前 qdisc 既不是本实验 HTB，也不是已恢复的单一根 fq；拒绝盲目覆盖。'
  fi

  stopped_tmp="${LAST_STATE_FILE}.tmp.$$"
  jq --arg stopped "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson watchdog "$from_watchdog" \
    --argjson already_restored "$already_restored" \
    '.phase = "STOPPED" | .stopped_utc = $stopped |
      .stopped_by_watchdog = ($watchdog == 1) |
      .already_restored_before_stop = ($already_restored == 1)' \
    "$STATE_FILE" >"$stopped_tmp"
  chmod 0600 "$stopped_tmp"
  mv -f -- "$stopped_tmp" "$LAST_STATE_FILE"
  rm -f -- "$STATE_FILE"
  [ "$from_watchdog" -eq 1 ] || cancel_watchdog "$watchdog_unit"
  log "stop=PASS profile=${profile} interface=${iface} restored=root-fq watchdog=${from_watchdog}"
  show_status
}

main() {
  local command="${1:-}"
  [ -n "$command" ] || { usage; exit 2; }
  shift
  case "$command" in
    -h|--help|help) usage ;;
    preflight)
      [ "$#" -eq 0 ] || die 'preflight 不接受参数。'
      prepare_runtime
      preflight_internal
      ;;
    start)
      prepare_runtime
      start_experiment "$@"
      ;;
    assert-active)
      prepare_runtime
      assert_active_command "$@"
      ;;
    smoke-test)
      prepare_runtime
      smoke_test "$@"
      ;;
    status)
      [ "$#" -eq 0 ] || die 'status 不接受参数。'
      prepare_runtime
      show_status
      ;;
    stop)
      prepare_runtime
      stop_experiment "$@"
      ;;
    *) usage; die "未知命令：${command}" ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
