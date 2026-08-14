#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
experiment_dir="$(cd -- "${test_dir}/.." && pwd)"
script="${experiment_dir}/htb-aggregate-experiment.sh"
plan_script="${experiment_dir}/experiment-plan.sh"
doc="${experiment_dir}/../../docs/experiments/vmiss-basic-200mbps-htb-aba.md"

bash -n "$script"
bash -n "$plan_script"
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
grep -Fq 'A1-fq' "$plan_script"
grep -Fq 'B2-htb-candidate' "$plan_script"
grep -Fq 'C1-htb-control' "$plan_script"
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

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "$script" "$plan_script" "$0"
fi

printf 'HTB aggregate experiment static checks passed\n'
