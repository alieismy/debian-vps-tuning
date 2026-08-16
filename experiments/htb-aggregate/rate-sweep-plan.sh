#!/usr/bin/env bash
# Generate a read-only, machine-readable candidate-rate discovery schedule.
# This script does not inspect or modify qdisc, sysctl, routes, services, or traffic.

set -Eeuo pipefail
IFS=$'\n\t'
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

PLAN_TOOL_VERSION='0.1.0'
DEFAULT_PORT_RATE_MBIT=200
DEFAULT_RATES='150,170,180,190,195'
DEFAULT_SAMPLES_PER_STATE=3
DEFAULT_COOLDOWN_SECONDS=300
DEFAULT_BENCHMARK_SECONDS=10
DEFAULT_OMIT_SECONDS=3
DEFAULT_PARALLEL=1
DEFAULT_FAMILY=4

die() { printf '[rate-sweep-plan][FAIL] %s\n' "$*" >&2; exit 2; }

usage() {
  cat <<'EOF'
Usage:
  rate-sweep-plan.sh [--port-rate 200] [--rates 150,170,180,190,195]
                     [--samples-per-state 2..5]
                     [--cooldown-seconds 300..3600]
                     [--benchmark-seconds 5..120]
                     [--omit-seconds 0..10]
                     [--parallel 1..4] [--family auto|4|6]

The command only prints JSON. It does not run traffic, change qdisc, select an
iperf3 endpoint, recommend a production rate, or authorize persistent shaping.
The current executor is deliberately limited to the reviewed 200-Mbit/s
Debian 13 HTB experiment boundary. Rates are sampled in forward/reverse rounds
between repeated root-fq baselines to reduce monotonic time-order bias.
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

main() {
  local port_rate="$DEFAULT_PORT_RATE_MBIT" rates_csv="$DEFAULT_RATES"
  local samples="$DEFAULT_SAMPLES_PER_STATE" cooldown="$DEFAULT_COOLDOWN_SECONDS"
  local seconds="$DEFAULT_BENCHMARK_SECONDS" omit="$DEFAULT_OMIT_SECONDS"
  local parallel="$DEFAULT_PARALLEL" family="$DEFAULT_FAMILY"
  local rates_json generated_utc plan_tool_sha256 rate_count input_rate_count

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --port-rate) [ "$#" -ge 2 ] || die '--port-rate 缺少参数。'; port_rate="$2"; shift 2 ;;
      --rates) [ "$#" -ge 2 ] || die '--rates 缺少参数。'; rates_csv="$2"; shift 2 ;;
      --samples-per-state) [ "$#" -ge 2 ] || die '--samples-per-state 缺少参数。'; samples="$2"; shift 2 ;;
      --cooldown-seconds) [ "$#" -ge 2 ] || die '--cooldown-seconds 缺少参数。'; cooldown="$2"; shift 2 ;;
      --benchmark-seconds) [ "$#" -ge 2 ] || die '--benchmark-seconds 缺少参数。'; seconds="$2"; shift 2 ;;
      --omit-seconds) [ "$#" -ge 2 ] || die '--omit-seconds 缺少参数。'; omit="$2"; shift 2 ;;
      --parallel) [ "$#" -ge 2 ] || die '--parallel 缺少参数。'; parallel="$2"; shift 2 ;;
      --family) [ "$#" -ge 2 ] || die '--family 缺少参数。'; family="$2"; shift 2 ;;
      -h | --help | help) usage; return 0 ;;
      *) die "未知参数：$1" ;;
    esac
  done

  command -v jq >/dev/null 2>&1 || die '缺少命令：jq'
  command -v sha256sum >/dev/null 2>&1 || die '缺少命令：sha256sum'
  port_rate="$(validate_uint_range port-rate "$port_rate" 200 200)"
  samples="$(validate_uint_range samples-per-state "$samples" 2 5)"
  cooldown="$(validate_uint_range cooldown-seconds "$cooldown" 300 3600)"
  seconds="$(validate_uint_range benchmark-seconds "$seconds" 5 120)"
  omit="$(validate_uint_range omit-seconds "$omit" 0 10)"
  parallel="$(validate_uint_range parallel "$parallel" 1 4)"
  case "$family" in auto | 4 | 6) ;; *) die 'family 只能为 auto、4 或 6。' ;; esac

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
    die '每个 rate 必须是 100–199 Mbit/s 的整数。'

  generated_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  plan_tool_sha256="$(sha256sum "${BASH_SOURCE[0]}" | awk '{print $1}')"
  jq -n \
    --arg tool_version "$PLAN_TOOL_VERSION" \
    --arg plan_tool_sha256 "$plan_tool_sha256" \
    --arg generated_utc "$generated_utc" \
    --argjson port_rate_mbit "$port_rate" \
    --argjson rates "$rates_json" \
    --argjson samples "$samples" \
    --argjson cooldown_seconds "$cooldown" \
    --argjson benchmark_seconds "$seconds" \
    --argjson omit_seconds "$omit" \
    --argjson parallel "$parallel" \
    --arg family "$family" '
      def stage($label; $condition; $phase; $rate; $cap; $sample; $round):
        {label:$label,condition:$condition,phase:$phase,rate_mbit:$rate,
         rate_cap_mbit:$cap,sample_index:$sample,round:$round,
         measurements_per_stage:1};
      ([range(1; $samples + 1) as $sample |
        stage("A-start-s\($sample)-fq"; "baseline-fq"; "baseline-start";
              null; $port_rate_mbit; $sample; 0)]) as $baseline_start |
      ([range(1; $samples + 1) as $round |
        (if ($round % 2) == 1 then $rates else ($rates | reverse) end)[] as $rate |
        stage("B-r\($round)-rate\($rate)"; "candidate-htb"; "sweep";
              $rate; $rate; $round; $round)]) as $sweep |
      ([range(1; $samples + 1) as $sample |
        stage("A-end-s\($sample)-fq"; "baseline-fq"; "baseline-end";
              null; $port_rate_mbit; $sample; 0)]) as $baseline_end |
      (($baseline_start + $sweep + $baseline_end) | to_entries |
        map(.value + {
          sequence:(.key + 1),
          minimum_cooldown_before_seconds:(if .key == 0 then 0 else $cooldown_seconds end)
        })) as $stages |
      ($benchmark_seconds + $omit_seconds) as $per_stage_seconds |
      ([$stages[].rate_cap_mbit] | add) as $rate_seconds_sum |
      ($rate_seconds_sum * 125000 * $per_stage_seconds) as $payload_upper_bound_bytes |
      {
        schema_version:1,
        plan_tool_version:$tool_version,
        plan_tool_sha256:$plan_tool_sha256,
        generated_utc:$generated_utc,
        mode:"candidate-rate-discovery-plan",
        scope:{provider_port_mbit:$port_rate_mbit,direction:"upload",persistent_shaping_authorized:false},
        rates_mbit:$rates,
        benchmark:{seconds:$benchmark_seconds,omit_seconds:$omit_seconds,
          parallel:$parallel,family:$family,direction:"upload"},
        controls:{samples_per_state:$samples,minimum_cooldown_seconds:$cooldown_seconds,
          order:"forward-reverse-rounds-between-repeated-baselines",
          explicit_authorized_endpoint_required:true,
          runner_execution_requires_explicit_invocation:true,
          qdisc_runtime_gate_before_and_after_each_shaped_stage:true,
          stop_on_first_failed_stage:true,
          automatic_candidate_persistence:false},
        traffic_budget:{available:true,method:"sum(stage_rate_cap_mbit)*125000*(seconds+omit)",
          stage_count:($stages|length),per_stage_seconds:$per_stage_seconds,
          payload_upper_bound_bytes:$payload_upper_bound_bytes,
          payload_upper_bound_gib:($payload_upper_bound_bytes/1073741824),
          protocol_overhead_included:false},
        stages:$stages,
        interpretation:{
          retransmission_metric:"use exact iperf3 sender bytes and retransmits_per_gib; do not infer packet-loss percentage",
          candidate_boundary:"analysis may produce a review shortlist only; a full A/B/A and reverse-window replication remain required",
          success_boundary:"a completed sweep does not prove provider policing, business-path improvement, or authorize persistence"
        }
      }
    '
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
