#!/usr/bin/env bash
# Test fixtures intentionally source reviewed scripts through computed paths,
# pass globals into sourced functions, and search source files for literal '$'.
# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2034,SC2154,SC2329

set -Eeuo pipefail
IFS=$'\n\t'

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
experiment_dir="$(cd -- "${test_dir}/.." && pwd)"
script="${experiment_dir}/htb-aggregate-experiment.sh"
plan_script="${experiment_dir}/experiment-plan.sh"
rate_sweep_plan_script="${experiment_dir}/rate-sweep-plan.sh"
rate_sweep_runner="${experiment_dir}/rate-sweep-run.sh"
rate_sweep_analyzer="${experiment_dir}/rate-sweep-analyze.sh"
legacy_doc="${experiment_dir}/../../docs/experiments/vmiss-basic-200mbps-htb-aba.md"
doc="${experiment_dir}/../../docs/experiments/vmiss-1c2g-200mbps-htb-aba.md"
rate_sweep_doc="${experiment_dir}/../../docs/experiments/htb-candidate-rate-sweep.md"

bash -n "$script"
bash -n "$plan_script"
bash -n "$rate_sweep_plan_script"
bash -n "$rate_sweep_runner"
bash -n "$rate_sweep_analyzer"
awk '
  /^run_b1_htb\(\) \($/ { capture=1 }
  capture { print }
  capture && /^\)$/ { exit }
' "$doc" | bash -n
awk '
  /^run_one_block\(\) \($/ { capture=1 }
  capture { print }
  capture && /^\)$/ { exit }
' "$doc" | bash -n
awk '
  /^run_smoke_gate\(\) \($/ { capture=1 }
  capture { print }
  capture && /^\)$/ { exit }
' "$doc" | bash -n
test_path="$PATH"
source "$script"
PATH="$test_path"

stage_trace="$(mktemp)"
START_TRACE_FILE="$stage_trace"
tc() {
  printf 'mock tc failure\n'
  return 42
}
if run_tc_stage mock-stage qdisc replace dev eth0 root fq; then
  printf 'run_tc_stage hid a tc pipeline failure\n' >&2
  exit 1
fi
grep -Fq 'mock tc failure' "$stage_trace"
rm -f -- "$stage_trace"

QDISC_JSON='[]'
CLASS_JSON='[]'
current_qdisc_json() { printf '%s\n' "$QDISC_JSON"; }
current_class_json() { printf '%s\n' "$CLASS_JSON"; }

QDISC_JSON='[
  {"kind":"htb","handle":"1:","root":true,"options":{"default":16}},
  {"kind":"fq","handle":"10:","parent":"1:10","options":{"limit":10000}},
  {"kind":"ingress","handle":"ffff:","parent":"ffff:fff1"}
]'
CLASS_JSON='[
  {"class":"htb","handle":"1:10","root":true,"leaf":"0x10","rate":23750000,"ceil":23750000}
]'
verify_experiment_topology eth0 190

CLASS_JSON='[
  {"kind":"htb","classid":"1:10","root":true,"options":{"rate":23750000,"ceil":23750000}}
]'
verify_experiment_topology eth0 190

CLASS_JSON='[
  {"class":"htb","handle":"1:10","root":true,"rate":22500000,"ceil":22500000}
]'
if verify_experiment_topology eth0 190; then
  printf 'topology validator accepted the wrong HTB rate and ceil\n' >&2
  exit 1
fi

QDISC_JSON='[
  {"kind":"htb","handle":"1:","root":true},
  {"kind":"pfifo","handle":"10:","parent":"1:10"}
]'
if verify_experiment_topology eth0 190; then
  printf 'topology validator accepted a non-fq leaf\n' >&2
  exit 1
fi

QDISC_JSON='[
  {"kind":"htb","handle":"1:","root":true},
  {"kind":"fq","handle":"10:","parent":"1:10"}
]'
CLASS_JSON='[]'
if verify_experiment_topology eth0 190; then
  printf 'topology validator accepted a missing HTB class\n' >&2
  exit 1
fi

QDISC_JSON='[{"kind":"fq","handle":"8001:","root":true}]'
CLASS_JSON='[]'
verify_plain_fq_topology eth0

fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$fixture_dir"' EXIT
MANAGED_STATE_FILE="${fixture_dir}/managed-state.json"
STATE_FILE="${fixture_dir}/active.json"
normalized_sysctl() {
  case "$1" in
    net.ipv4.tcp_congestion_control) printf 'bbr\n' ;;
    net.core.default_qdisc) printf 'fq\n' ;;
    net.ipv4.tcp_rmem) printf '4096 131072 16777216\n' ;;
    net.ipv4.tcp_wmem) printf '4096 65536 16777216\n' ;;
    *) return 1 ;;
  esac
}
systemctl() {
  [ "$1" = 'is-active' ]
}
write_managed_fixture() {
  local profile="$1" schema="${2:-4}" version="${3:-0.1.0-rc.12}" port="${4:-200}"
  jq -n \
    --arg profile "$profile" \
    --arg version "$version" \
    --argjson schema "$schema" \
    --argjson port "$port" \
    '{schema_version:$schema,script_version:$version,state:"VERIFIED",
      profile:{id:$profile},network:{port_speed_mbps:$port}}' >"$MANAGED_STATE_FILE"
}

write_managed_fixture debian13-1c1g
verify_managed_host_baseline
write_managed_fixture debian13-1c2g
verify_managed_host_baseline
for rejected_profile in debian12-1c2g debian13-2c2g arbitrary-profile; do
  write_managed_fixture "$rejected_profile"
  if (verify_managed_host_baseline) >/dev/null 2>&1; then
    printf 'managed baseline accepted unsupported profile: %s\n' "$rejected_profile" >&2
    exit 1
  fi
done
write_managed_fixture debian13-1c2g 3
if (verify_managed_host_baseline) >/dev/null 2>&1; then
  printf 'managed baseline accepted schema 3\n' >&2
  exit 1
fi
write_managed_fixture debian13-1c2g 4 0.1.0-rc.11
if (verify_managed_host_baseline) >/dev/null 2>&1; then
  printf 'managed baseline accepted rc.11\n' >&2
  exit 1
fi
write_managed_fixture debian13-1c2g 4 0.1.0-rc.12 500
if (verify_managed_host_baseline) >/dev/null 2>&1; then
  printf 'managed baseline accepted 500 Mbps\n' >&2
  exit 1
fi

write_managed_fixture debian13-1c2g
managed_hash="$(managed_state_sha256)"
jq -n --arg hash "$managed_hash" \
  '{managed_profile_id:"debian13-1c2g",managed_state_sha256:$hash}' >"$STATE_FILE"
verify_active_managed_binding
write_managed_fixture debian13-1c1g
if (verify_active_managed_binding) >/dev/null 2>&1; then
  printf 'active binding accepted managed profile/hash drift\n' >&2
  exit 1
fi

grep -Fq 'qdisc replace dev "$iface" parent 1:10 handle 10: fq' "$script"
if grep -Fq 'qdisc add dev ${iface} parent 1:10' "$script"; then
  printf 'legacy leaf qdisc add command is still present\n' >&2
  exit 1
fi
grep -Fq 'start_stage=${stage} action=FAIL' "$script"
grep -Fq 'tc "$@" 2>&1 | tee -a "$START_TRACE_FILE"' "$script"
grep -Fq 'active-check=PASS' "$script"
grep -Fq 'smoke-test=PASS' "$script"
grep -Fq '2>&1 | tee "$B1_START_LOG"' "$doc"
grep -Fq 'B1_START_RC=${PIPESTATUS[0]}' "$doc"
grep -Fq 'trap cleanup_b1 EXIT' "$doc"
grep -Fq '2>&1 | tee -a "$B1_AFTER_LOG"' "$doc"
grep -Fq 'if run_smoke_gate; then' "$doc"
grep -Fq 'SMOKE_GATE=FAIL' "$doc"
grep -Fq 'experiment-plan.sh' "$doc"
grep -Fq 'TOOL_VERSION='"'"'0.3.0'"'"'' "$script"
grep -Fq 'managed_state_sha256' "$script"
grep -Fq 'debian13-1c2g' "$script"
grep -Fq 'A1-fq' "$plan_script"
grep -Fq 'B2-htb-candidate' "$plan_script"
grep -Fq 'C1-htb-control' "$plan_script"
grep -Fq 'candidate-rate-discovery-plan' "$rate_sweep_plan_script"
grep -Fq 'forward-reverse-rounds-between-repeated-baselines' "$rate_sweep_plan_script"
grep -Fq 'BENCHMARK_DIRECTION='"'"'upload'"'"'' "$rate_sweep_runner"
grep -Fq '"$htb_tool" assert-active --rate "$rate"' "$rate_sweep_runner"
grep -Fq '"$htb_tool" stop' "$rate_sweep_runner"
grep -Fq 'fixed_global_retransmission_threshold_used:false' "$rate_sweep_analyzer"
grep -Fq 'persistence_authorized:false' "$rate_sweep_analyzer"
grep -Fq 'rate-sweep-plan.sh' "$rate_sweep_doc"
grep -Fq 'rate-sweep-run.sh' "$rate_sweep_doc"
grep -Fq 'rate-sweep-analyze.sh' "$rate_sweep_doc"
legacy_script_sha256='5b0bd160205f9408514d067e9faeb229f58b800f40e39412b9e221929772ca1a'
grep -Fq "'${legacy_script_sha256}'" "$legacy_doc"
script_sha256="$(sha256sum "$script" | awk '{print $1}')"
grep -Fq "'${script_sha256}'" "$doc"

run_plan_fixture() (
  local inherited_path="$PATH"
  # shellcheck disable=SC1090
  source "$plan_script"
  PATH="$inherited_path"
  main "$@"
)

plan_json="$(run_plan_fixture)"
jq -e '
  .mode == "read-only-plan" and
  (.plan_tool_sha256 | test("^[0-9a-f]{64}$")) and
  .candidate.rate_mbit == 190 and
  .candidate.repeat_cycles == 2 and
  (.candidate.stages | length) == 6 and
  .candidate.stages[0].label == "A1-fq" and
  .candidate.stages[3].label == "B2-htb-candidate" and
  .controls.minimum_cooldown_seconds == 300 and
  .controls.automatic_execution == false and
  .controls.persistent_shaping_authorized == false and
  .lower_rate_control.enabled == false
' <<<"$plan_json" >/dev/null

plan_json="$(run_plan_fixture --candidate-rate 190 --repeat-cycles 1 --cooldown-seconds 600 --control-rate 180)"
jq -e '
  (.candidate.stages | length) == 3 and
  .controls.minimum_cooldown_seconds == 600 and
  .lower_rate_control.enabled == true and
  .lower_rate_control.rate_mbit == 180 and
  .lower_rate_control.requires_candidate_result_closed == true and
  (.lower_rate_control.stages | length) == 3
' <<<"$plan_json" >/dev/null

if run_plan_fixture --control-rate 190 >/dev/null 2>&1; then
  printf 'experiment plan accepted control-rate equal to candidate-rate\n' >&2
  exit 1
fi
if run_plan_fixture --cooldown-seconds 299 >/dev/null 2>&1; then
  printf 'experiment plan accepted cooldown below 300 seconds\n' >&2
  exit 1
fi

run_rate_sweep_plan_fixture() (
  local inherited_path="$PATH"
  # shellcheck disable=SC1090
  source "$rate_sweep_plan_script"
  PATH="$inherited_path"
  main "$@"
)

rate_sweep_plan_json="$(run_rate_sweep_plan_fixture)"
jq -e '
  .mode == "candidate-rate-discovery-plan" and
  .scope.provider_port_mbit == 200 and
  .scope.direction == "upload" and
  .scope.persistent_shaping_authorized == false and
  .rates_mbit == [150,170,180,190,195] and
  .controls.samples_per_state == 3 and
  .controls.minimum_cooldown_seconds == 300 and
  .benchmark.direction == "upload" and
  (.stages | length) == 21 and
  .stages[0].label == "A-start-s1-fq" and
  .stages[3].label == "B-r1-rate150" and
  .stages[8].label == "B-r2-rate195" and
  .stages[-1].label == "A-end-s3-fq" and
  .traffic_budget.payload_upper_bound_bytes ==
    ([.stages[].rate_cap_mbit] | add) * 125000 *
    (.benchmark.seconds + .benchmark.omit_seconds) and
  (.interpretation.retransmission_metric | contains("retransmits_per_gib"))
' <<<"$rate_sweep_plan_json" >/dev/null

rate_sweep_plan_json="$(run_rate_sweep_plan_fixture \
  --rates 150,180,190 --samples-per-state 2 --cooldown-seconds 600 \
  --benchmark-seconds 12 --omit-seconds 0 --parallel 1 --family 6)"
jq -e '
  .rates_mbit == [150,180,190] and
  (.stages | length) == 10 and
  .controls.minimum_cooldown_seconds == 600 and
  .benchmark.seconds == 12 and .benchmark.omit_seconds == 0 and
  .benchmark.family == "6"
' <<<"$rate_sweep_plan_json" >/dev/null

for invalid_args in \
  '--port-rate 500' \
  '--rates 150,150,190' \
  '--rates 99,180,190' \
  '--rates 150,180,200' \
  '--rates 150,190' \
  '--samples-per-state 1' \
  '--cooldown-seconds 299'; do
  # shellcheck disable=SC2086
  if run_rate_sweep_plan_fixture $invalid_args >/dev/null 2>&1; then
    printf 'candidate rate plan accepted invalid arguments: %s\n' "$invalid_args" >&2
    exit 1
  fi
done

runner_plan="${fixture_dir}/runner-plan.json"
printf '%s\n' "$rate_sweep_plan_json" >"$runner_plan"
run_runner_plan_validation_fixture() (
  local_path="$PATH"
  # shellcheck disable=SC1090
  source "$rate_sweep_runner"
  PATH="$local_path"
  plan_file="$1"
  validate_plan
)
run_runner_plan_validation_fixture "$runner_plan"
invalid_runner_plan="${fixture_dir}/runner-plan-invalid.json"
jq '.traffic_budget.payload_upper_bound_bytes += 1' "$runner_plan" >"$invalid_runner_plan"
if run_runner_plan_validation_fixture "$invalid_runner_plan" >/dev/null 2>&1; then
  printf 'rate sweep runner accepted a plan with a mismatched traffic budget\n' >&2
  exit 1
fi

socket_metrics_fixture="$(
  (
  inherited_path="$PATH"
  # shellcheck disable=SC1090
  source "$rate_sweep_runner"
  PATH="$inherited_path"
  printf '%s\n' \
    'ESTAB 0 0 198.51.100.10:50123 192.0.2.10:5201 users:(("iperf3",pid=123,fd=4))' \
    ' cubic wscale:7,7 rto:204 rtt:2.5/0.4 mss:1448 pmtu:1500 cwnd:32 bytes_sent:1073741824 bytes_retrans:5792 segs_out:741000 retrans:0/4 reordering:3' |
    extract_socket_metrics
  )
)"
grep -Fq 'rto:204' <<<"$socket_metrics_fixture"
grep -Fq 'rtt:2.5/0.4' <<<"$socket_metrics_fixture"
grep -Fq 'bytes_retrans:5792' <<<"$socket_metrics_fixture"
grep -Fq 'metric_rows=1' <<<"$socket_metrics_fixture"
if grep -Eq '198\.51\.100\.|192\.0\.2\.|5201|iperf3|pid=|fd=' <<<"$socket_metrics_fixture"; then
  printf 'socket metric whitelist leaked endpoint or process details\n' >&2
  exit 1
fi

runner_fixture="${fixture_dir}/runner-execution"
mock_runtime="${runner_fixture}/runtime"
mock_output="${runner_fixture}/evidence"
mock_htb="${runner_fixture}/mock-htb"
mock_tuning="${runner_fixture}/mock-tuning.sh"
mkdir -p "$runner_fixture" "$mock_runtime" "${mock_output}/stages"
cat >"$mock_htb" <<'EOF_MOCK_HTB'
#!/usr/bin/env bash
set -Eeuo pipefail
case "$1" in
  preflight) [ ! -e "${MOCK_RUNTIME_DIR}/active.json" ] ;;
  start)
    printf '%s\n' '{"active":true}' >"${MOCK_RUNTIME_DIR}/active.json"
    printf '%s\n' '[{"kind":"fq","root":true}]' >"${MOCK_RUNTIME_DIR}/original-qdisc.json"
    printf '%s\n' 'mock start trace' >"${MOCK_RUNTIME_DIR}/start-trace.log"
    ;;
  assert-active) [ -s "${MOCK_RUNTIME_DIR}/active.json" ] ;;
  stop) rm -f -- "${MOCK_RUNTIME_DIR}/active.json" ;;
  *) exit 2 ;;
esac
EOF_MOCK_HTB
cat >"$mock_tuning" <<'EOF_MOCK_TUNING'
#!/usr/bin/env bash
set -Eeuo pipefail
[ "${1:-}" = benchmark ]
mkdir -p -- "$BENCHMARK_OUTPUT_DIR"
printf '%s\n' '{"schema_version":1,"direction":"upload","reverse":false}' \
  >"${BENCHMARK_OUTPUT_DIR}/upload.summary.json"
printf '%s\n' '{"schema_version":1,"status":"PASS","exit_code":0,"phases":{"upload":{},"download":null}}' \
  >"${BENCHMARK_OUTPUT_DIR}/benchmark-result.json"
(
  cd "$BENCHMARK_OUTPUT_DIR"
  sha256sum upload.summary.json >SHA256SUMS
)
result_sha="$(sha256sum "${BENCHMARK_OUTPUT_DIR}/benchmark-result.json" | awk '{print $1}')"
manifest_sha="$(sha256sum "${BENCHMARK_OUTPUT_DIR}/SHA256SUMS" | awk '{print $1}')"
printf 'status=COMPLETED\nevidence_manifest_sha256=%s\nresult_sha256=%s\n' \
  "$manifest_sha" "$result_sha" >"${BENCHMARK_OUTPUT_DIR}/COMPLETED"
EOF_MOCK_TUNING
chmod 0700 "$mock_htb" "$mock_tuning"
if ! (
  inherited_path="$PATH"
  # shellcheck disable=SC1090
  source "$rate_sweep_runner"
  PATH="$inherited_path"
  export MOCK_RUNTIME_DIR="$mock_runtime"
  RUNTIME_STATE_DIR="$mock_runtime"
  RUNTIME_STATE_FILE="${mock_runtime}/active.json"
  output_dir="$mock_output"
  plan_file="$runner_plan"
  htb_tool="$mock_htb"
  tuning_script="$mock_tuning"
  benchmark_host='192.0.2.10'
  benchmark_port=5201
  install() {
    local target="${*: -1}"
    mkdir -p -- "$target"
    chmod 0700 "$target"
  }
  sleep() { :; }
  ss() {
    printf '%s\n' \
      'ESTAB 0 0 198.51.100.10:50123 192.0.2.10:5201 users:(("iperf3",pid=123,fd=4))' \
      ' cubic rto:204 rtt:2.5/0.4 mss:1448 cwnd:32 bytes_retrans:5792 retrans:0/4 reordering:3'
  }
  candidate_stage="$(jq -c 'first(.stages[] | select(.condition == "candidate-htb"))' "$runner_plan")"
  run_stage "$candidate_stage"
  [ "$htb_started" -eq 0 ]
  [ ! -e "$RUNTIME_STATE_FILE" ]
); then
  printf 'mock rate sweep runner stage failed\n' >&2
  for runner_log in "${mock_output}"/stages/*/benchmark.log "${mock_output}"/stages/*/htb-*.log; do
    [ -f "$runner_log" ] || continue
    printf '%s\n' "===== ${runner_log} =====" >&2
    sed -n '1,160p' "$runner_log" >&2
  done
  exit 1
fi
runner_stage_dir="$(printf '%s\n' "${mock_output}"/stages/*-B-*/ | head -n 1)"
jq -e '.status == "PASS" and .qdisc_restored_to_root_fq == true and
  .persistent_shaping_created == false' "${runner_stage_dir}/stage-result.json" >/dev/null
grep -Fq 'rtt:2.5/0.4' "${runner_stage_dir}/socket-metrics.txt"
if grep -Eq '198\.51\.100\.|192\.0\.2\.|5201|iperf3|pid=|fd=' \
  "${runner_stage_dir}/socket-metrics.txt"; then
  printf 'runner socket metric evidence leaked endpoint or process details\n' >&2
  exit 1
fi

sweep_fixture="${fixture_dir}/sweep-evidence"
mkdir -p "${sweep_fixture}/stages"
cp "$runner_plan" "${sweep_fixture}/plan.json"
while IFS= read -r sweep_stage; do
  sequence="$(jq -r '.sequence' <<<"$sweep_stage")"
  label="$(jq -r '.label' <<<"$sweep_stage")"
  phase="$(jq -r '.phase' <<<"$sweep_stage")"
  rate="$(jq -r '.rate_mbit // 0' <<<"$sweep_stage")"
  stage_dir="${sweep_fixture}/stages/$(printf '%02d-%s' "$sequence" "$label")"
  benchmark_dir="${stage_dir}/benchmark"
  mkdir -p "$benchmark_dir"
  case "$phase:$rate" in
    baseline-start:* | baseline-end:*) receiver=198; sender=199; retrans_per_gib=100; retrans=10; overlimits=0 ;;
    sweep:150) receiver=149; sender=150; retrans_per_gib=10; retrans=1; overlimits=1000 ;;
    sweep:180) receiver=178; sender=180; retrans_per_gib=20; retrans=2; overlimits=1000 ;;
    sweep:190) receiver=188; sender=190; retrans_per_gib=40; retrans=4; overlimits=1000 ;;
    *) printf 'unexpected sweep fixture stage: %s\n' "$label" >&2; exit 1 ;;
  esac
  jq -n --argjson sender "$sender" --argjson receiver "$receiver" \
    --argjson retrans "$retrans" --argjson retrans_per_gib "$retrans_per_gib" \
    --argjson overlimits "$overlimits" '
      {schema_version:1,direction:"upload",reverse:false,
       sender:{bytes:1073741824,bits_per_second:($sender*1000000),mbps:$sender,
         retransmits:$retrans,retransmits_per_gib:$retrans_per_gib},
       receiver:{bytes:1073741824,bits_per_second:($receiver*1000000),mbps:$receiver},
       host:{tx_bytes_delta:1073741824,tcp_delta:{TcpRetransSegs:$retrans}},
       qdisc_active_totals:{dropped_delta:0,overlimits_delta:$overlimits,requeues_delta:0},
       qdisc_coverage:{aggregation_source:"root"}}
    ' >"${benchmark_dir}/upload.summary.json"
  printf '%s\n' '{"schema_version":1,"status":"PASS","exit_code":0,"phases":{"upload":{},"download":null}}' \
    >"${benchmark_dir}/benchmark-result.json"
  (
    cd "$benchmark_dir"
    sha256sum upload.summary.json benchmark-result.json >SHA256SUMS
  )
  benchmark_result_sha="$(sha256sum "${benchmark_dir}/benchmark-result.json" | awk '{print $1}')"
  benchmark_manifest_sha="$(sha256sum "${benchmark_dir}/SHA256SUMS" | awk '{print $1}')"
  printf 'status=COMPLETED\nevidence_manifest_sha256=%s\nresult_sha256=%s\n' \
    "$benchmark_manifest_sha" "$benchmark_result_sha" >"${benchmark_dir}/COMPLETED"
  jq -n --arg sha "$benchmark_result_sha" --argjson plan_stage "$sweep_stage" \
    '{schema_version:1,status:"PASS",plan_stage:$plan_stage,
      benchmark_result_sha256:$sha,qdisc_restored_to_root_fq:true,
      persistent_shaping_created:false}' \
    >"${stage_dir}/stage-result.json"
done < <(jq -c '.stages[]' "$runner_plan")

run_rate_sweep_analyzer_fixture() (
  local inherited_path="$PATH"
  # shellcheck disable=SC1090
  source "$rate_sweep_analyzer"
  PATH="$inherited_path"
  main "$@"
)

sweep_analysis="$(run_rate_sweep_analyzer_fixture "$sweep_fixture")"
jq -e '
  .status == "REVIEW_REQUIRED" and
  .persistence_authorized == false and
  .metric_contract.packet_loss_percentage_inferred == false and
  .metric_contract.fixed_mss_assumed == false and
  .metric_contract.fixed_global_retransmission_threshold_used == false and
  .baseline.comparable_by_median_mad_overlap == true and
  .review_shortlist.rate_mbit == 190 and
  .review_shortlist.eligible_rates_mbit == [190] and
  (.rates | length) == 3 and
  (.rates[] | select(.rate_mbit == 190) |
    .review_flags.retransmission_below_baseline_dispersion == true and
    .review_flags.receiver_goodput_within_observed_best_dispersion == true and
    .review_flags.all_local_qdisc_drop_samples_zero == true)
' <<<"$sweep_analysis" >/dev/null

missing_completed="$(printf '%s\n' "${sweep_fixture}"/stages/*/benchmark/COMPLETED | head -n 1)"
mv "$missing_completed" "${missing_completed}.fixture-missing"
if run_rate_sweep_analyzer_fixture "$sweep_fixture" >/dev/null 2>&1; then
  printf 'rate sweep analyzer accepted a benchmark without COMPLETED\n' >&2
  exit 1
fi
mv "${missing_completed}.fixture-missing" "$missing_completed"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "$script" "$plan_script" "$rate_sweep_plan_script" \
    "$rate_sweep_runner" "$rate_sweep_analyzer" "$0"
fi

printf 'HTB aggregate experiment static checks passed\n'
