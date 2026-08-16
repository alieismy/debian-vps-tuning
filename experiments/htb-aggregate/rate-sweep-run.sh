#!/usr/bin/env bash
# Execute an explicitly approved, non-persistent candidate-rate sweep.
# The runner delegates qdisc state transitions to htb-aggregate-experiment.sh
# and traffic/evidence collection to one pinned standalone tuning profile.

set -Eeuo pipefail
IFS=$'\n\t'
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

RUNNER_VERSION='0.2.0'
RUNTIME_STATE_DIR='/run/htb-aggregate-experiment'
RUNTIME_STATE_FILE="${RUNTIME_STATE_DIR}/active.json"
RUNNER_LOCK='/run/lock/htb-rate-sweep.lock'

plan_file=''
output_dir=''
tuning_script=''
htb_tool=''
analyzer=''
benchmark_host=''
benchmark_port='5201'
htb_started=0
current_stage='initialization'
session_created=0
socket_sampler_pid=''

log() { printf '[rate-sweep-run] %s\n' "$*"; }
warn() { printf '[rate-sweep-run][WARN] %s\n' "$*" >&2; }
die() { printf '[rate-sweep-run][FAIL] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  rate-sweep-run.sh --plan /absolute/plan.json
                    --output-dir /absolute/new/evidence-dir
                    --tuning-script /absolute/debian13-1c2g-vps-tuning.sh
                    --htb-tool /usr/local/sbin/htb-aggregate-experiment
                    --analyzer /absolute/rate-sweep-analyze.sh
                    --host AUTHORIZED_IPERF3_HOST [--port 5201]

The runner is non-persistent but it does produce high-bandwidth upload traffic
and temporarily replaces root fq with HTB for every reference/candidate stage. It never
installs packages, chooses a public server, changes sysctl/routing/firewall, or
creates persistent shaping. Every shaped stage is guarded by HTB preflight,
ACTIVE checks, normal stop, and root-fq postflight. The first failed stage stops
the session; an EXIT trap attempts restoration when this runner started HTB.
EOF
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

require_root() {
  [ "$(id -u)" -eq 0 ] || die '必须以 root 运行。'
}

validate_root_owned_file() {
  local name="$1" path="$2" uid mode mode_decimal
  [[ "$path" = /* ]] || die "${name} 必须是绝对路径。"
  [ -f "$path" ] && [ ! -L "$path" ] || die "${name} 不是普通文件或是符号链接：${path}"
  uid="$(stat -c '%u' "$path")"
  mode="$(stat -c '%a' "$path")"
  [ "$uid" = '0' ] || die "${name} 必须由 root 所有：${path}"
  mode_decimal=$((8#$mode))
  [ $((mode_decimal & 0022)) -eq 0 ] || die "${name} 不能被 group/world 写入：${path}"
}

validate_plan() {
  jq -e --argjson cooldown "$(jq -r '.controls.minimum_cooldown_seconds' "$plan_file")" '
    type == "object" and .schema_version == 2 and
    ((.mode == "reference-screen") or (.mode == "candidate-sweep")) and
    .scope.provider_port_mbit == 200 and
    .reference_rate_mbit == 200 and
    .scope.direction == "upload" and
    .scope.persistent_shaping_authorized == false and
    (.plan_tool_sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
    (.benchmark.seconds | type == "number" and floor == . and . >= 5 and . <= 120) and
    (.benchmark.omit_seconds | type == "number" and floor == . and . >= 0 and . <= 10) and
    (.benchmark.parallel | type == "number" and floor == . and . >= 1 and . <= 4) and
    ((.benchmark.family == "auto") or (.benchmark.family == "4") or (.benchmark.family == "6")) and
    .benchmark.direction == "upload" and
    (.controls.minimum_cooldown_seconds | type == "number" and floor == . and . >= 300 and . <= 3600) and
    (.controls.samples_per_state | type == "number" and floor == . and . >= 2 and . <= 5) and
    .controls.automatic_candidate_persistence == false and
    (.rates_mbit | type == "array") and
    ((.rates_mbit | length) == (.rates_mbit | unique | length)) and
    (if .mode == "reference-screen" then
       (.rates_mbit | length) == 0
     else
       (.rates_mbit | length) >= 3 and (.rates_mbit | length) <= 8 and
       all(.rates_mbit[]; type == "number" and floor == . and . >= 100 and . <= 199)
     end) and
    (.stages | type == "array" and length >= 2 and length <= 50) and
    (if .mode == "reference-screen" then
       (.stages | length) == .controls.samples_per_state
     else
       (.stages | length) == (.controls.samples_per_state * ((.rates_mbit | length) + 2))
     end) and
    ([.stages[].sequence] == [range(1; (.stages|length) + 1)]) and
    (([.stages[].label] | length) == ([.stages[].label] | unique | length)) and
    all(.stages[];
      (.label | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9-]{0,63}$")) and
      (.minimum_cooldown_before_seconds | type == "number" and floor == . and . >= 0 and . <= 3600) and
      (.measurements_per_stage == 1) and
      .traffic_cap_enforced_by == "htb-class-rate-and-ceil" and
      .rate_cap_mbit == .rate_mbit and
      (if .condition == "reference-htb" then
         (.rate_mbit == 200 and
          ((.phase == "reference-screen") or (.phase == "reference-start") or (.phase == "reference-end")))
       elif .condition == "candidate-htb" then
         (.phase == "candidate-sweep" and (.rate_mbit | type == "number" and floor == . and . >= 100 and . <= 199))
       else false end)) and
    .stages[0].minimum_cooldown_before_seconds == 0 and
    all(.stages[1:][]; .minimum_cooldown_before_seconds == $cooldown) and
    (if .mode == "reference-screen" then
       all(.stages[]; .condition == "reference-htb" and .phase == "reference-screen")
     else
       ([.stages[] | select(.phase == "reference-start")] | length) == .controls.samples_per_state and
       ([.stages[] | select(.phase == "reference-end")] | length) == .controls.samples_per_state and
       ([.rates_mbit[] as $rate |
         (([.stages[] | select(.condition == "candidate-htb" and .rate_mbit == $rate)] | length) ==
          .controls.samples_per_state)] | all)
     end) and
    .traffic_budget.enforced_by == "htb-class-rate-and-ceil" and
    .traffic_budget.stage_count == (.stages | length) and
    .traffic_budget.payload_upper_bound_bytes ==
      (([.stages[].rate_mbit] | add) * 125000 *
       (.benchmark.seconds + .benchmark.omit_seconds))
  ' "$plan_file" >/dev/null || die '候选扫描计划 schema、范围或阶段约束无效。'
}

capture_htb_runtime() {
  local destination="$1" file
  install -d -o root -g root -m 0700 "$destination"
  for file in active.json original-qdisc.json start-trace.log; do
    if [ -f "${RUNTIME_STATE_DIR}/${file}" ] && [ ! -L "${RUNTIME_STATE_DIR}/${file}" ]; then
      cp -a -- "${RUNTIME_STATE_DIR}/${file}" "${destination}/${file}"
    fi
  done
}

attempt_restore() {
  local log_file
  [ "$htb_started" -eq 1 ] || return 0
  log_file="${output_dir}/emergency-stop-${current_stage}.log"
  warn "阶段 ${current_stage} 未正常结束；尝试调用受管 HTB stop。"
  if "$htb_tool" stop >"$log_file" 2>&1; then
    htb_started=0
    "$htb_tool" preflight >>"$log_file" 2>&1 || true
    return 0
  fi
  warn "自动 stop 失败；保留运行状态。请从服务商控制台检查 ${RUNTIME_STATE_FILE} 和根 qdisc。"
  return 1
}

finish_incomplete() {
  local rc="$1" utc
  [ "$session_created" -eq 1 ] || return 0
  [ ! -f "${output_dir}/COMPLETED" ] || return 0
  utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'status=INCOMPLETE\nstage=%s\nexit_code=%s\nutc=%s\n' \
    "$current_stage" "$rc" "$utc" >"${output_dir}/INCOMPLETE.tmp" 2>/dev/null || return 0
  chmod 0600 "${output_dir}/INCOMPLETE.tmp" 2>/dev/null || true
  mv -f -- "${output_dir}/INCOMPLETE.tmp" "${output_dir}/INCOMPLETE" 2>/dev/null || true
}

on_exit() {
  local rc=$?
  trap - EXIT INT TERM
  if [ -n "$socket_sampler_pid" ]; then
    kill "$socket_sampler_pid" 2>/dev/null || true
    wait "$socket_sampler_pid" 2>/dev/null || true
    socket_sampler_pid=''
  fi
  if ! attempt_restore; then
    [ "$rc" -ne 0 ] || rc=1
  fi
  finish_incomplete "$rc"
  exit "$rc"
}

on_signal() {
  current_stage="signal-$1"
  case "$1" in INT) exit 130 ;; TERM) exit 143 ;; esac
}

write_stage_result() {
  local stage_dir="$1" stage_json="$2" started_utc="$3" completed_utc="$4"
  local benchmark_sha
  benchmark_sha="$(sha256sum "${stage_dir}/benchmark/benchmark-result.json" | awk '{print $1}')"
  jq -n --argjson plan_stage "$stage_json" \
    --arg started_utc "$started_utc" --arg completed_utc "$completed_utc" \
    --arg benchmark_result_sha256 "$benchmark_sha" \
    '{schema_version:2,status:"PASS",plan_stage:$plan_stage,
      started_utc:$started_utc,completed_utc:$completed_utc,
      benchmark_result_sha256:$benchmark_result_sha256,
      qdisc_rate_mbit:$plan_stage.rate_mbit,
      traffic_cap_enforced_by_htb:true,
      qdisc_restored_to_root_fq:true,persistent_shaping_created:false}' \
    >"${stage_dir}/stage-result.json"
  chmod 0600 "${stage_dir}/stage-result.json"
}

verify_benchmark_completion() {
  local benchmark_dir="$1" actual_result_sha actual_manifest_sha marker_result_sha marker_manifest_sha
  actual_result_sha="$(sha256sum "${benchmark_dir}/benchmark-result.json" | awk '{print $1}')"
  actual_manifest_sha="$(sha256sum "${benchmark_dir}/SHA256SUMS" | awk '{print $1}')"
  marker_result_sha="$(awk -F= '$1 == "result_sha256" {print $2}' "${benchmark_dir}/COMPLETED")"
  marker_manifest_sha="$(awk -F= '$1 == "evidence_manifest_sha256" {print $2}' "${benchmark_dir}/COMPLETED")"
  [ "$marker_result_sha" = "$actual_result_sha" ] &&
    [ "$marker_manifest_sha" = "$actual_manifest_sha" ]
}

extract_socket_metrics() {
  # Whitelist TCP_INFO-style tokens only. Socket headers, endpoints, ports,
  # PIDs, process names and inodes are never emitted.
  awk '
    function allowed(token) {
      return token ~ /^(rto|backoff|rtt|ato|mss|pmtu|rcvmss|advmss|cwnd|ssthresh|bytes_acked|bytes_received|bytes_sent|bytes_retrans|segs_out|segs_in|data_segs_out|data_segs_in|delivered|app_limited|busy|rwnd_limited|sndbuf_limited|reordering|retrans):/
    }
    {
      output=""
      for (i=1; i<=NF; i++) {
        if (allowed($i)) output=output (output == "" ? "" : " ") $i
      }
      if (output != "") {
        rows++
        printf "row=%d %s\n", rows, output
      }
    }
    END {printf "metric_rows=%d\n", rows+0}
  '
}

sample_socket_metrics_window() {
  local output="$1" duration="$2" sample
  : >"$output"
  chmod 0600 "$output"
  for ((sample=1; sample<=duration; sample++)); do
    printf 'sample=%s utc=%s\n' "$sample" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$output"
    ss -tinH state established 2>/dev/null | extract_socket_metrics >>"$output"
    [ "$sample" -eq "$duration" ] || sleep 1
  done
}

run_stage() {
  local stage_json="$1" sequence label condition rate rate_cap cooldown stage_dir
  local started_utc completed_utc benchmark_dir benchmark_rc=0 socket_sample_seconds
  sequence="$(jq -r '.sequence' <<<"$stage_json")"
  label="$(jq -r '.label' <<<"$stage_json")"
  condition="$(jq -r '.condition' <<<"$stage_json")"
  rate="$(jq -r '.rate_mbit // empty' <<<"$stage_json")"
  rate_cap="$(jq -r '.rate_cap_mbit' <<<"$stage_json")"
  cooldown="$(jq -r '.minimum_cooldown_before_seconds' <<<"$stage_json")"
  current_stage="$(printf '%02d-%s' "$sequence" "$label")"
  stage_dir="${output_dir}/stages/${current_stage}"
  benchmark_dir="${stage_dir}/benchmark"
  install -d -o root -g root -m 0700 "$stage_dir"
  jq . <<<"$stage_json" >"${stage_dir}/plan-stage.json"
  chmod 0600 "${stage_dir}/plan-stage.json"

  if [ "$cooldown" -gt 0 ]; then
    log "${current_stage}: 冷却 ${cooldown} 秒。"
    sleep "$cooldown"
  fi
  started_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  log "${current_stage}: condition=${condition} rate=${rate:-none}。"

  "$htb_tool" preflight >"${stage_dir}/htb-preflight-before.log" 2>&1
  htb_started=1
  "$htb_tool" start --rate "$rate" >"${stage_dir}/htb-start.log" 2>&1
  "$htb_tool" assert-active --rate "$rate" >"${stage_dir}/htb-active-before.log" 2>&1
  capture_htb_runtime "${stage_dir}/htb-runtime"

  socket_sample_seconds=$((
    $(jq -r '.benchmark.seconds' "$plan_file") +
    $(jq -r '.benchmark.omit_seconds' "$plan_file") + 2
  ))
  sample_socket_metrics_window "${stage_dir}/socket-metrics.txt" "$socket_sample_seconds" &
  socket_sampler_pid=$!

  if env \
    BENCHMARK_HOST="$benchmark_host" \
    BENCHMARK_PORT="$benchmark_port" \
    BENCHMARK_SECONDS="$(jq -r '.benchmark.seconds' "$plan_file")" \
    BENCHMARK_OMIT_SECONDS="$(jq -r '.benchmark.omit_seconds' "$plan_file")" \
    BENCHMARK_PARALLEL="$(jq -r '.benchmark.parallel' "$plan_file")" \
    BENCHMARK_IP_FAMILY="$(jq -r '.benchmark.family' "$plan_file")" \
    BENCHMARK_DIRECTION='upload' \
    BENCHMARK_RATE_CAP_MBPS="$rate_cap" \
    BENCHMARK_RUN_ID="$current_stage" \
    BENCHMARK_OUTPUT_DIR="$benchmark_dir" \
    bash "$tuning_script" benchmark >"${stage_dir}/benchmark.log" 2>&1; then
    benchmark_rc=0
  else
    benchmark_rc=$?
  fi
  wait "$socket_sampler_pid" || benchmark_rc=1
  socket_sampler_pid=''

  "$htb_tool" assert-active --rate "$rate" >"${stage_dir}/htb-active-after.log" 2>&1 || benchmark_rc=1
  capture_htb_runtime "${stage_dir}/htb-runtime-after"
  if "$htb_tool" stop >"${stage_dir}/htb-stop.log" 2>&1; then
    htb_started=0
  else
    benchmark_rc=1
  fi
  "$htb_tool" preflight >"${stage_dir}/htb-preflight-after.log" 2>&1 || benchmark_rc=1
  [ "$benchmark_rc" -eq 0 ] || die "${current_stage} benchmark、ACTIVE gate 或恢复失败；退出码 ${benchmark_rc}。"
  [ -f "${benchmark_dir}/COMPLETED" ] && [ ! -f "${benchmark_dir}/INCOMPLETE" ] ||
    die "${current_stage} benchmark 未形成 COMPLETED 终态。"
  (
    cd "$benchmark_dir"
    sha256sum -c SHA256SUMS
  ) >"${stage_dir}/benchmark-manifest-check.log" 2>&1 ||
    die "${current_stage} benchmark SHA256SUMS 校验失败。"
  verify_benchmark_completion "$benchmark_dir" ||
    die "${current_stage} benchmark COMPLETED 与 result/manifest hash 不匹配。"
  completed_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  write_stage_result "$stage_dir" "$stage_json" "$started_utc" "$completed_utc"
}

main() {
  local parent output_name plan_sha runner_sha tuning_sha htb_sha analyzer_sha
  local generated_utc stage_json analysis_sha manifest_sha

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --plan) [ "$#" -ge 2 ] || die '--plan 缺少参数。'; plan_file="$2"; shift 2 ;;
      --output-dir) [ "$#" -ge 2 ] || die '--output-dir 缺少参数。'; output_dir="$2"; shift 2 ;;
      --tuning-script) [ "$#" -ge 2 ] || die '--tuning-script 缺少参数。'; tuning_script="$2"; shift 2 ;;
      --htb-tool) [ "$#" -ge 2 ] || die '--htb-tool 缺少参数。'; htb_tool="$2"; shift 2 ;;
      --analyzer) [ "$#" -ge 2 ] || die '--analyzer 缺少参数。'; analyzer="$2"; shift 2 ;;
      --host) [ "$#" -ge 2 ] || die '--host 缺少参数。'; benchmark_host="$2"; shift 2 ;;
      --port) [ "$#" -ge 2 ] || die '--port 缺少参数。'; benchmark_port="$2"; shift 2 ;;
      -h | --help | help) usage; return 0 ;;
      *) die "未知参数：$1" ;;
    esac
  done

  require_root
  for command in awk bash chmod cp date env find flock id install jq mv readlink \
    sha256sum sleep sort ss stat; do
    need_command "$command"
  done
  [ -n "$plan_file" ] && [ -n "$output_dir" ] && [ -n "$tuning_script" ] &&
    [ -n "$htb_tool" ] && [ -n "$analyzer" ] && [ -n "$benchmark_host" ] || {
      usage >&2
      die '缺少必填参数。'
    }
  validate_root_owned_file plan "$plan_file"
  validate_root_owned_file tuning-script "$tuning_script"
  validate_root_owned_file htb-tool "$htb_tool"
  validate_root_owned_file analyzer "$analyzer"
  validate_root_owned_file runner "${BASH_SOURCE[0]}"
  [[ "$benchmark_host" =~ ^[A-Za-z0-9][A-Za-z0-9._:%-]*$ ]] ||
    die 'host 含不支持的字符。'
  [[ "$benchmark_port" =~ ^[0-9]{1,5}$ ]] || die 'port 必须是 1–65535 的整数。'
  benchmark_port=$((10#$benchmark_port))
  [ "$benchmark_port" -ge 1 ] && [ "$benchmark_port" -le 65535 ] ||
    die 'port 必须在 1–65535 之间。'
  validate_plan

  [[ "$output_dir" = /* ]] || die 'output-dir 必须是绝对路径。'
  [ ! -e "$output_dir" ] && [ ! -L "$output_dir" ] || die "output-dir 已存在：${output_dir}"
  parent="$(dirname "$output_dir")"
  [ -d "$parent" ] && [ ! -L "$parent" ] || die 'output-dir 的父目录不存在或是符号链接。'
  parent="$(readlink -f "$parent")"
  output_name="$(basename "$output_dir")"
  output_dir="${parent}/${output_name}"
  umask 077
  install -d -o root -g root -m 0755 /run/lock
  exec 8>"$RUNNER_LOCK"
  flock -n 8 || die '另一个候选速率扫描正在运行。'
  [ ! -e "$RUNTIME_STATE_FILE" ] || die "已有活动 HTB 状态：${RUNTIME_STATE_FILE}"
  "$htb_tool" preflight >/dev/null

  install -d -o root -g root -m 0700 "$output_dir" "${output_dir}/stages"
  session_created=1
  trap on_exit EXIT
  trap 'on_signal INT' INT
  trap 'on_signal TERM' TERM
  generated_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cp -a -- "$plan_file" "${output_dir}/plan.json"
  plan_file="${output_dir}/plan.json"
  plan_sha="$(sha256sum "$plan_file" | awk '{print $1}')"
  runner_sha="$(sha256sum "${BASH_SOURCE[0]}" | awk '{print $1}')"
  tuning_sha="$(sha256sum "$tuning_script" | awk '{print $1}')"
  htb_sha="$(sha256sum "$htb_tool" | awk '{print $1}')"
  analyzer_sha="$(sha256sum "$analyzer" | awk '{print $1}')"
  jq -n --arg version "$RUNNER_VERSION" --arg generated_utc "$generated_utc" \
    --arg plan_sha256 "$plan_sha" --arg runner_sha256 "$runner_sha" \
    --arg tuning_script "$tuning_script" --arg tuning_sha256 "$tuning_sha" \
    --arg htb_tool "$htb_tool" --arg htb_sha256 "$htb_sha" \
    --arg analyzer "$analyzer" --arg analyzer_sha256 "$analyzer_sha" \
    --arg host "$benchmark_host" --argjson port "$benchmark_port" \
    '{schema_version:1,runner_version:$version,started_utc:$generated_utc,
      plan_sha256:$plan_sha256,runner_sha256:$runner_sha256,
      tuning_script:{path:$tuning_script,sha256:$tuning_sha256},
      htb_tool:{path:$htb_tool,sha256:$htb_sha256},
      analyzer:{path:$analyzer,sha256:$analyzer_sha256},
      benchmark_endpoint:{host:$host,port:$port,explicitly_supplied:true},
      persistent_shaping_authorized:false}' >"${output_dir}/session-meta.json"
  chmod 0600 "${output_dir}/plan.json" "${output_dir}/session-meta.json"
  printf 'status=INCOMPLETE\nstage=initialization\nutc=%s\n' "$generated_utc" >"${output_dir}/INCOMPLETE"
  chmod 0600 "${output_dir}/INCOMPLETE"

  while IFS= read -r stage_json; do
    run_stage "$stage_json"
  done < <(jq -c '.stages[]' "$plan_file")

  current_stage='analysis'
  "$analyzer" "$output_dir" >"${output_dir}/sweep-analysis.json.tmp"
  jq -e '.schema_version == 2 and
    ((.status == "REVIEW_REQUIRED") or (.status == "REVIEW_BLOCKED")) and
    .persistence_authorized == false' \
    "${output_dir}/sweep-analysis.json.tmp" >/dev/null || die '候选扫描分析输出无效。'
  chmod 0600 "${output_dir}/sweep-analysis.json.tmp"
  mv -f -- "${output_dir}/sweep-analysis.json.tmp" "${output_dir}/sweep-analysis.json"

  current_stage='manifest'
  (
    cd "$output_dir"
    : >SHA256SUMS.tmp
    while IFS= read -r -d '' file; do
      sha256sum "${file#./}" >>SHA256SUMS.tmp
    done < <(find . -type f ! -name SHA256SUMS ! -name SHA256SUMS.tmp \
      ! -name manifest-check.log ! -name INCOMPLETE ! -name COMPLETED \
      ! -name COMPLETED.tmp -print0 | sort -z)
    [ -s SHA256SUMS.tmp ]
    chmod 0600 SHA256SUMS.tmp
    mv -f SHA256SUMS.tmp SHA256SUMS
    sha256sum -c SHA256SUMS
  ) >"${output_dir}/manifest-check.log" 2>&1 || die '扫描证据 SHA256SUMS 生成或校验失败。'
  # manifest-check.log is deliberately outside SHA256SUMS because it is written
  # while the manifest is being verified.
  analysis_sha="$(sha256sum "${output_dir}/sweep-analysis.json" | awk '{print $1}')"
  manifest_sha="$(sha256sum "${output_dir}/SHA256SUMS" | awk '{print $1}')"
  printf 'status=COMPLETED\nanalysis_sha256=%s\nevidence_manifest_sha256=%s\nutc=%s\n' \
    "$analysis_sha" "$manifest_sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"${output_dir}/COMPLETED.tmp"
  chmod 0600 "${output_dir}/COMPLETED.tmp"
  mv -f -- "${output_dir}/COMPLETED.tmp" "${output_dir}/COMPLETED"
  rm -f -- "${output_dir}/INCOMPLETE"
  current_stage='completed'
  trap - EXIT INT TERM
  log "扫描完成：${output_dir}"
  log 'sweep-analysis.json 仅提供人工复核 shortlist；不会授权持久化 HTB。'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
