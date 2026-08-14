#!/usr/bin/env bash
# Generate a read-only, machine-readable HTB A/B/A experiment schedule.
# This script does not inspect or modify qdisc, sysctl, routes, services, or traffic.

set -Eeuo pipefail
IFS=$'\n\t'
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

PLAN_TOOL_VERSION='0.1.0'
DEFAULT_CANDIDATE_RATE_MBIT=190
DEFAULT_REPEAT_CYCLES=2
DEFAULT_COOLDOWN_SECONDS=300

die() { printf '[htb-plan][FAIL] %s\n' "$*" >&2; exit 2; }

usage() {
  cat <<'EOF'
Usage:
  experiment-plan.sh [--candidate-rate MBIT] [--repeat-cycles 1|2]
                     [--cooldown-seconds SECONDS]
                     [--control-rate MBIT|none]

The command only prints JSON. It does not run traffic, change qdisc, or
authorize a new shaping rate. Two cycles produce the balanced order
A1 -> B1 -> A2, then B2 -> A3 -> B3 in a separate comparable window.
An optional lower-rate control is emitted as a separate A -> C -> A stage
and is gated on closing the candidate-rate result first.
EOF
}

validate_rate() {
  local name="$1" value="$2"
  [[ "$value" =~ ^[0-9]{3}$ ]] || die "${name} 必须是 100–199 的整数。"
  value=$((10#$value))
  [ "$value" -ge 100 ] && [ "$value" -le 199 ] ||
    die "${name} 必须在 100–199 Mbit/s 之间。"
  printf '%s\n' "$value"
}

main() {
  local candidate_rate="$DEFAULT_CANDIDATE_RATE_MBIT"
  local repeat_cycles="$DEFAULT_REPEAT_CYCLES"
  local cooldown_seconds="$DEFAULT_COOLDOWN_SECONDS"
  local control_rate='' generated_utc plan_tool_sha256

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --candidate-rate)
        [ "$#" -ge 2 ] || die '--candidate-rate 缺少参数。'
        candidate_rate="$2"
        shift 2
        ;;
      --repeat-cycles)
        [ "$#" -ge 2 ] || die '--repeat-cycles 缺少参数。'
        repeat_cycles="$2"
        shift 2
        ;;
      --cooldown-seconds)
        [ "$#" -ge 2 ] || die '--cooldown-seconds 缺少参数。'
        cooldown_seconds="$2"
        shift 2
        ;;
      --control-rate)
        [ "$#" -ge 2 ] || die '--control-rate 缺少参数。'
        control_rate="$2"
        shift 2
        ;;
      -h | --help | help)
        usage
        return 0
        ;;
      *) die "未知参数：$1" ;;
    esac
  done

  command -v jq >/dev/null 2>&1 || die '缺少命令：jq'
  command -v sha256sum >/dev/null 2>&1 || die '缺少命令：sha256sum'
  candidate_rate="$(validate_rate candidate-rate "$candidate_rate")"
  case "$repeat_cycles" in
    1 | 2) ;;
    *) die 'repeat-cycles 只能为 1 或 2。' ;;
  esac
  [[ "$cooldown_seconds" =~ ^[0-9]{3,4}$ ]] ||
    die 'cooldown-seconds 必须是 300–3600 的整数。'
  cooldown_seconds=$((10#$cooldown_seconds))
  [ "$cooldown_seconds" -ge 300 ] && [ "$cooldown_seconds" -le 3600 ] ||
    die 'cooldown-seconds 必须在 300–3600 秒之间。'
  if [ "$control_rate" = 'none' ]; then
    control_rate=''
  elif [ -n "$control_rate" ]; then
    control_rate="$(validate_rate control-rate "$control_rate")"
    [ "$control_rate" -lt "$candidate_rate" ] ||
      die 'control-rate 必须低于 candidate-rate。'
  fi

  generated_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  plan_tool_sha256="$(sha256sum "${BASH_SOURCE[0]}" | awk '{print $1}')"
  jq -n \
    --arg tool_version "$PLAN_TOOL_VERSION" \
    --arg plan_tool_sha256 "$plan_tool_sha256" \
    --arg generated_utc "$generated_utc" \
    --argjson candidate_rate_mbit "$candidate_rate" \
    --argjson repeat_cycles "$repeat_cycles" \
    --argjson cooldown_seconds "$cooldown_seconds" \
    --arg control_rate "$control_rate" '
      def stage($sequence; $cycle; $label; $condition; $rate; $cooldown; $gate):
        {sequence:$sequence,cycle:$cycle,label:$label,condition:$condition,
         rate_mbit:$rate,minimum_cooldown_before_seconds:$cooldown,
         requires_previous_stage_pass:$gate,measurements_per_stage:1};
      ([
        stage(1;1;"A1-fq";"baseline-fq";null;0;false),
        stage(2;1;"B1-htb-candidate";"candidate-htb";$candidate_rate_mbit;$cooldown_seconds;true),
        stage(3;1;"A2-fq";"baseline-fq";null;$cooldown_seconds;true)
      ] +
      if $repeat_cycles == 2 then [
        stage(4;2;"B2-htb-candidate";"candidate-htb";$candidate_rate_mbit;$cooldown_seconds;true),
        stage(5;2;"A3-fq";"baseline-fq";null;$cooldown_seconds;true),
        stage(6;2;"B3-htb-candidate";"candidate-htb";$candidate_rate_mbit;$cooldown_seconds;true)
      ] else [] end) as $candidate_stages |
      (if $control_rate == "" then [] else [
        stage(1;"control";"A-control-before";"baseline-fq";null;0;false),
        stage(2;"control";"C1-htb-control";"lower-rate-control-htb";($control_rate|tonumber);$cooldown_seconds;true),
        stage(3;"control";"A-control-after";"baseline-fq";null;$cooldown_seconds;true)
      ] end) as $control_stages |
      {
        schema_version:1,
        plan_tool_version:$tool_version,
        plan_tool_sha256:$plan_tool_sha256,
        generated_utc:$generated_utc,
        mode:"read-only-plan",
        candidate:{rate_mbit:$candidate_rate_mbit,repeat_cycles:$repeat_cycles,stages:$candidate_stages},
        lower_rate_control:{
          enabled:($control_rate != ""),
          rate_mbit:(if $control_rate == "" then null else ($control_rate|tonumber) end),
          requires_candidate_result_closed:true,
          stages:$control_stages
        },
        controls:{
          minimum_cooldown_seconds:$cooldown_seconds,
          manual_idle_gate_required:true,
          one_measurement_per_stage:true,
          same_pinned_harness_nodes_parameters_required:true,
          qdisc_runtime_gate_before_and_after_candidate:true,
          automatic_execution:false,
          persistent_shaping_authorized:false
        },
        interpretation:{
          candidate_result:"compare normalized retransmissions, sender and receiver goodput, qdisc drops and overlimits, CPU, softnet and node drift across common evidence",
          lower_rate_control:"a separate mechanism check, not a new production recommendation",
          success_boundary:"a generated plan and completed stages do not prove business-path improvement or authorize persistence"
        }
      }
    '
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
