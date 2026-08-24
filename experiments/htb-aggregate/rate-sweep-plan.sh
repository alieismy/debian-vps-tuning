#!/usr/bin/env bash
# Generate a read-only, machine-readable HTB reference or candidate schedule.
# This script does not inspect or modify qdisc, sysctl, routes, services, or traffic.

set -Eeuo pipefail
IFS=$'\n\t'
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

PLAN_TOOL_VERSION='0.3.0'
DEFAULT_MODE='reference-screen'
DEFAULT_PORT_RATE_MBIT=200
DEFAULT_RATES='180,190,195'
DEFAULT_SAMPLES_PER_STATE=3
DEFAULT_COOLDOWN_SECONDS=300
DEFAULT_BENCHMARK_SECONDS=10
DEFAULT_OMIT_SECONDS=3
DEFAULT_PARALLEL=1
DEFAULT_FAMILY=4
DEFAULT_MINIMUM_RATE_EXPOSURE_PERCENT=90
DEFAULT_MINIMUM_CPU_IDLE_PERCENT=5
DEFAULT_MAXIMUM_CPU_STEAL_PERCENT=5

die() { printf '[rate-sweep-plan][FAIL] %s\n' "$*" >&2; exit 2; }

usage() {
  cat <<'EOF'
Usage:
  rate-sweep-plan.sh [--mode reference-screen|candidate-sweep]
                     [--port-rate 200] [--rates 180,190,195]
                     [--samples-per-state 2..5]
                     [--cooldown-seconds 300..3600]
                     [--benchmark-seconds 5..120]
                     [--omit-seconds 0..10]
                     [--parallel 1..4] [--family auto|4|6]
                     [--minimum-rate-exposure-percent 90..100]
                     [--minimum-cpu-idle-percent 0..100]
                     [--maximum-cpu-steal-percent 0..100]
                     [--ack-reference-reviewed
                      --reference-manifest-sha256 SHA256
                      --reference-analysis-sha256 SHA256
                      --reference-completed-sha256 SHA256]

The default reference-screen mode emits only repeated HTB200+fq stages. Use
candidate-sweep explicitly, after manual review of the reference screen, to
compare lower HTB rates. Every stage uses the same HTB class + fq topology;
only rate/ceil changes. The command only prints JSON and never runs traffic,
changes qdisc, selects an iperf3 endpoint, recommends a production rate, or
authorizes persistent shaping. A sample is ineligible unless HTB reports a
positive overlimits delta, sender goodput reaches the frozen exposure ratio,
and the CPU/softnet/link resource gate remains valid. Candidate mode also
requires hash-bound proof of one completed, manually reviewed reference run.
EOF
}

validate_uint_range() {
  local name="$1" value="$2" min="$3" max="$4"
  [[ "$value" =~ ^[0-9]+$ ]] || die "${name} 必须是 ${min}–${max} 的整数。"
  value=$((10#$value))
  [ "$value" -ge "$min" ] && [ "$value" -le "$max" ] ||
    die "${name} 必须在 ${min}–${max} 之间。"
  printf '%s\n' "$value"
}

validate_sha256() {
  local name="$1" value="$2"
  [[ "$value" =~ ^[0-9a-f]{64}$ ]] || die "${name} 必须是 64 位小写十六进制 SHA-256。"
}

main() {
  local mode="$DEFAULT_MODE" port_rate="$DEFAULT_PORT_RATE_MBIT"
  local rates_csv="$DEFAULT_RATES" rates_supplied=0
  local samples="$DEFAULT_SAMPLES_PER_STATE" cooldown="$DEFAULT_COOLDOWN_SECONDS"
  local seconds="$DEFAULT_BENCHMARK_SECONDS" omit="$DEFAULT_OMIT_SECONDS"
  local parallel="$DEFAULT_PARALLEL" family="$DEFAULT_FAMILY"
  local minimum_rate_exposure_percent="$DEFAULT_MINIMUM_RATE_EXPOSURE_PERCENT"
  local minimum_cpu_idle_percent="$DEFAULT_MINIMUM_CPU_IDLE_PERCENT"
  local maximum_cpu_steal_percent="$DEFAULT_MAXIMUM_CPU_STEAL_PERCENT"
  local reference_review_acknowledged=0 reference_manifest_sha256=''
  local reference_analysis_sha256='' reference_completed_sha256=''
  local rates_json='[]' generated_utc plan_tool_sha256 rate_count input_rate_count

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --mode) [ "$#" -ge 2 ] || die '--mode 缺少参数。'; mode="$2"; shift 2 ;;
      --port-rate) [ "$#" -ge 2 ] || die '--port-rate 缺少参数。'; port_rate="$2"; shift 2 ;;
      --rates) [ "$#" -ge 2 ] || die '--rates 缺少参数。'; rates_csv="$2"; rates_supplied=1; shift 2 ;;
      --samples-per-state) [ "$#" -ge 2 ] || die '--samples-per-state 缺少参数。'; samples="$2"; shift 2 ;;
      --cooldown-seconds) [ "$#" -ge 2 ] || die '--cooldown-seconds 缺少参数。'; cooldown="$2"; shift 2 ;;
      --benchmark-seconds) [ "$#" -ge 2 ] || die '--benchmark-seconds 缺少参数。'; seconds="$2"; shift 2 ;;
      --omit-seconds) [ "$#" -ge 2 ] || die '--omit-seconds 缺少参数。'; omit="$2"; shift 2 ;;
      --parallel) [ "$#" -ge 2 ] || die '--parallel 缺少参数。'; parallel="$2"; shift 2 ;;
      --family) [ "$#" -ge 2 ] || die '--family 缺少参数。'; family="$2"; shift 2 ;;
      --minimum-rate-exposure-percent)
        [ "$#" -ge 2 ] || die '--minimum-rate-exposure-percent 缺少参数。'
        minimum_rate_exposure_percent="$2"; shift 2 ;;
      --minimum-cpu-idle-percent)
        [ "$#" -ge 2 ] || die '--minimum-cpu-idle-percent 缺少参数。'
        minimum_cpu_idle_percent="$2"; shift 2 ;;
      --maximum-cpu-steal-percent)
        [ "$#" -ge 2 ] || die '--maximum-cpu-steal-percent 缺少参数。'
        maximum_cpu_steal_percent="$2"; shift 2 ;;
      --ack-reference-reviewed)
        reference_review_acknowledged=1; shift ;;
      --reference-manifest-sha256)
        [ "$#" -ge 2 ] || die '--reference-manifest-sha256 缺少参数。'
        reference_manifest_sha256="$2"; shift 2 ;;
      --reference-analysis-sha256)
        [ "$#" -ge 2 ] || die '--reference-analysis-sha256 缺少参数。'
        reference_analysis_sha256="$2"; shift 2 ;;
      --reference-completed-sha256)
        [ "$#" -ge 2 ] || die '--reference-completed-sha256 缺少参数。'
        reference_completed_sha256="$2"; shift 2 ;;
      -h | --help | help) usage; return 0 ;;
      *) die "未知参数：$1" ;;
    esac
  done

  command -v jq >/dev/null 2>&1 || die '缺少命令：jq'
  command -v sha256sum >/dev/null 2>&1 || die '缺少命令：sha256sum'
  case "$mode" in reference-screen | candidate-sweep) ;; *) die 'mode 只能为 reference-screen 或 candidate-sweep。' ;; esac
  port_rate="$(validate_uint_range port-rate "$port_rate" 200 200)"
  samples="$(validate_uint_range samples-per-state "$samples" 2 5)"
  cooldown="$(validate_uint_range cooldown-seconds "$cooldown" 300 3600)"
  seconds="$(validate_uint_range benchmark-seconds "$seconds" 5 120)"
  omit="$(validate_uint_range omit-seconds "$omit" 0 10)"
  parallel="$(validate_uint_range parallel "$parallel" 1 4)"
  minimum_rate_exposure_percent="$(validate_uint_range minimum-rate-exposure-percent "$minimum_rate_exposure_percent" 90 100)"
  minimum_cpu_idle_percent="$(validate_uint_range minimum-cpu-idle-percent "$minimum_cpu_idle_percent" 0 100)"
  maximum_cpu_steal_percent="$(validate_uint_range maximum-cpu-steal-percent "$maximum_cpu_steal_percent" 0 100)"
  case "$family" in auto | 4 | 6) ;; *) die 'family 只能为 auto、4 或 6。' ;; esac

  if [ "$mode" = 'reference-screen' ]; then
    [ "$rates_supplied" -eq 0 ] || die 'reference-screen 不接受 --rates；它只测试 HTB200 reference。'
    [ "$reference_review_acknowledged" -eq 0 ] &&
      [ -z "$reference_manifest_sha256" ] &&
      [ -z "$reference_analysis_sha256" ] &&
      [ -z "$reference_completed_sha256" ] ||
      die 'reference-screen 不接受 candidate reference 复核参数。'
  else
    [ "$reference_review_acknowledged" -eq 1 ] ||
      die 'candidate-sweep 必须显式提供 --ack-reference-reviewed。'
    validate_sha256 reference-manifest-sha256 "$reference_manifest_sha256"
    validate_sha256 reference-analysis-sha256 "$reference_analysis_sha256"
    validate_sha256 reference-completed-sha256 "$reference_completed_sha256"
    [[ "$rates_csv" =~ ^[0-9]+(,[0-9]+){2,7}$ ]] ||
      die 'rates 必须包含 3–8 个逗号分隔的整数，不能包含空格。'
    input_rate_count="$(awk -F, '{print NF}' <<<"$rates_csv")"
    rates_json="$(jq -cn --arg rates "$rates_csv" '$rates | split(",") | map(tonumber) | sort | unique')" ||
      die '无法解析 rates。'
    rate_count="$(jq -r 'length' <<<"$rates_json")"
    [ "$rate_count" -eq "$input_rate_count" ] || die 'rates 不能包含重复值。'
    jq -e --argjson port "$port_rate" '
      length >= 3 and length <= 8 and
      all(.[]; (type == "number") and (floor == .) and . >= 100 and . < $port)
    ' <<<"$rates_json" >/dev/null ||
      die '每个候选 rate 必须是 100–199 Mbit/s 的整数。'
  fi

  generated_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  plan_tool_sha256="$(sha256sum "${BASH_SOURCE[0]}" | awk '{print $1}')"
  jq -n \
    --arg tool_version "$PLAN_TOOL_VERSION" \
    --arg plan_tool_sha256 "$plan_tool_sha256" \
    --arg generated_utc "$generated_utc" \
    --arg mode "$mode" \
    --argjson port_rate_mbit "$port_rate" \
    --argjson rates "$rates_json" \
    --argjson samples "$samples" \
    --argjson cooldown_seconds "$cooldown" \
    --argjson benchmark_seconds "$seconds" \
    --argjson omit_seconds "$omit" \
    --argjson parallel "$parallel" \
    --argjson minimum_rate_exposure_percent "$minimum_rate_exposure_percent" \
    --argjson minimum_cpu_idle_percent "$minimum_cpu_idle_percent" \
    --argjson maximum_cpu_steal_percent "$maximum_cpu_steal_percent" \
    --argjson reference_review_acknowledged "$reference_review_acknowledged" \
    --arg reference_manifest_sha256 "$reference_manifest_sha256" \
    --arg reference_analysis_sha256 "$reference_analysis_sha256" \
    --arg reference_completed_sha256 "$reference_completed_sha256" \
    --arg family "$family" '
      def stage($label; $condition; $phase; $rate; $sample; $round):
        {label:$label,condition:$condition,phase:$phase,rate_mbit:$rate,
         rate_cap_mbit:$rate,sample_index:$sample,round:$round,
         measurements_per_stage:1,traffic_cap_enforced_by:"htb-class-rate-and-ceil"};
      (if $mode == "reference-screen" then
         [range(1; $samples + 1) as $sample |
          stage("R-s\($sample)-htb200"; "reference-htb"; "reference-screen";
                $port_rate_mbit; $sample; 0)]
       else
         ([range(1; $samples + 1) as $sample |
           stage("A-start-s\($sample)-htb200"; "reference-htb"; "reference-start";
                 $port_rate_mbit; $sample; 0)]) as $reference_start |
         ([range(1; $samples + 1) as $round |
           (if ($round % 2) == 1 then $rates else ($rates | reverse) end)[] as $rate |
           stage("B-r\($round)-rate\($rate)"; "candidate-htb"; "candidate-sweep";
                 $rate; $round; $round)]) as $sweep |
         ([range(1; $samples + 1) as $sample |
           stage("A-end-s\($sample)-htb200"; "reference-htb"; "reference-end";
                 $port_rate_mbit; $sample; 0)]) as $reference_end |
         ($reference_start + $sweep + $reference_end)
       end | to_entries |
       map(.value + {sequence:(.key + 1),
         minimum_cooldown_before_seconds:(if .key == 0 then 0 else $cooldown_seconds end)})) as $stages |
      ($benchmark_seconds + $omit_seconds) as $per_stage_seconds |
      ([$stages[].rate_cap_mbit] | add) as $rate_seconds_sum |
      ($rate_seconds_sum * 125000 * $per_stage_seconds) as $payload_upper_bound_bytes |
      {
        schema_version:3,
        plan_tool_version:$tool_version,
        plan_tool_sha256:$plan_tool_sha256,
        generated_utc:$generated_utc,
        mode:$mode,
        scope:{provider_port_mbit:$port_rate_mbit,direction:"upload",persistent_shaping_authorized:false},
        reference_rate_mbit:$port_rate_mbit,
        reference_gate:{
          external_reference_required:($mode == "candidate-sweep"),
          review_acknowledged:($reference_review_acknowledged == 1),
          evidence_manifest_sha256:(if $reference_manifest_sha256 == "" then null else $reference_manifest_sha256 end),
          analysis_sha256:(if $reference_analysis_sha256 == "" then null else $reference_analysis_sha256 end),
          completed_marker_sha256:(if $reference_completed_sha256 == "" then null else $reference_completed_sha256 end),
          reference_path_recorded:false,
          persistence_authorized:false},
        rates_mbit:$rates,
        benchmark:{seconds:$benchmark_seconds,omit_seconds:$omit_seconds,
          parallel:$parallel,family:$family,direction:"upload"},
        controls:{samples_per_state:$samples,minimum_cooldown_seconds:$cooldown_seconds,
          minimum_rate_exposure_ratio:($minimum_rate_exposure_percent/100),
          minimum_cpu_idle_percent:$minimum_cpu_idle_percent,
          maximum_cpu_steal_percent:$maximum_cpu_steal_percent,
          require_zero_softnet_drops:true,
          require_zero_softnet_time_squeeze:true,
          require_zero_link_drops_errors:true,
          order:(if $mode == "reference-screen" then "repeated-htb200-reference"
                 else "forward-reverse-candidates-between-repeated-htb200-references" end),
          explicit_authorized_endpoint_required:true,
          runner_execution_requires_explicit_invocation:true,
          qdisc_runtime_gate_before_and_after_every_stage:true,
          stop_on_first_failed_stage:true,
          automatic_candidate_persistence:false},
        traffic_budget:{available:true,
          method:"sum(actual_htb_stage_rate_mbit)*125000*(seconds+omit)",
          enforced_by:"htb-class-rate-and-ceil",
          stage_count:($stages|length),per_stage_seconds:$per_stage_seconds,
          payload_upper_bound_bytes:$payload_upper_bound_bytes,
          payload_upper_bound_gib:($payload_upper_bound_bytes/1073741824),
          protocol_overhead_included:false},
        stages:$stages,
        interpretation:{
          retransmission_metric:"use exact iperf3 sender bytes and retransmits_per_gib; do not infer packet-loss percentage",
          reference_boundary:"review HTB200 samples first; lower-rate scanning requires a separate hash-bound and explicitly acknowledged candidate-sweep plan",
          candidate_boundary:"analysis may produce a review shortlist only; a full A/B/A and reverse-window replication remain required",
          success_boundary:"completion does not prove provider policing, business-path improvement, or authorize persistence"
        }
      }
    '
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
