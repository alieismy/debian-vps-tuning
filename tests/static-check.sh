#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

scripts=(
  debian12-1c1g-vps-tuning.sh
  debian12-1c2g-vps-tuning.sh
  debian13-1c1g-vps-tuning.sh
  debian13-1c2g-vps-tuning.sh
)

if command -v python3 >/dev/null 2>&1; then
  python_cmd=python3
elif command -v python >/dev/null 2>&1; then
  python_cmd=python
else
  printf 'python3/python is required for generated-file checks\n' >&2
  exit 1
fi
"$python_cmd" tools/render_profiles.py --check
bash -n "${scripts[@]}" tools/profile-template.sh.in tests/static-check.sh

for script in "${scripts[@]}"; do
  if LC_ALL=C grep -n $'\r' "$script"; then
    printf 'CRLF detected: %s\n' "$script" >&2
    exit 1
  fi
  if [ "$(od -An -tx1 -N3 "$script" | tr -d ' \n')" = 'efbbbf' ]; then
    printf 'UTF-8 BOM detected: %s\n' "$script" >&2
    exit 1
  fi
  set +e
  bash "$script" invalid-action >/dev/null 2>&1
  rc=$?
  set -e
  [ "$rc" -eq 2 ] || { printf 'invalid action did not return 2: %s (%s)\n' "$script" "$rc" >&2; exit 1; }
done

forbidden='ip_local_port_range|ip_local_reserved_ports|tcp_tw_reuse|tcp_tw_recycle|tcp_mem|tcp_fin_timeout|ip_forward|disable_ipv6|fs\.file-max|fs\.nr_open|nf_conntrack_max|busy_poll|busy_read'
if grep -nE "^[[:space:]]*(${forbidden})[[:space:]]*=" "${scripts[@]}"; then
  printf 'forbidden sysctl assignment detected\n' >&2
  exit 1
fi

expected_keys=17
for script in "${scripts[@]}"; do
  actual="$(awk '/^PROFILE_SYSCTL_KEYS=\(/,/^\)/ {if ($1 ~ /^(net\.|vm\.)/) count++} END {print count+0}' "$script")"
  [ "$actual" -eq "$expected_keys" ] || { printf 'unexpected managed-key count: %s (%s)\n' "$script" "$actual" >&2; exit 1; }
  grep -Fq "SCRIPT_VERSION='0.1.0-rc.8'" "$script"
  grep -Fq "STATE_SCHEMA_VERSION=3" "$script"
  grep -Fq "SWAP_FILE='/swapfile-proxy'" "$script"
  grep -Fq 'x-ui.service' "$script"
  grep -Fq "ext2 | ext3 | ext4 | xfs)" "$script"
  grep -Fq "ROOT_FS_TYPE='unknown'" "$script"
  grep -Fq "SWAP_CREATE_ALLOWED='0'" "$script"
  grep -Fq '当前主机尚未安装本项目配置' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq '检测到未完成的事务状态 ${phase}；请先执行 rollback，不要直接 apply。' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq '检测到现有管理状态 ${phase}；已安装配置请执行 verify' "$script"
  grep -Fq 'run_preflight apply' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq '[ "$context" = '\''apply'\'' ] || check_preflight_state' "$script"
  grep -Fq -- "--arg profile_label \"\$PROFILE_LABEL\"" "$script"
  grep -Fq "label:\$profile_label" "$script"
  if grep -Fq -- '--arg label ' "$script" || grep -Fq "label:\$label" "$script"; then
    printf 'reserved jq variable name label detected: %s\n' "$script" >&2
    exit 1
  fi
  grep -Fq 'cleanup_uncommitted_state' "$script"
  grep -Fq 'atomic_json_commit' "$script"
  grep -Fq 'ALLOW_EMPTY_STATE_RECOVERY=1 执行 recover' "$script"
  if grep -Fq 'atomic_json_write' "$script"; then
    printf 'stream-based JSON writer reintroduced: %s\n' "$script" >&2
    exit 1
  fi
  grep -Fq '事务状态尚未提交，未写入系统配置；不完整状态已清理。' "$script"
  grep -Fq "state_set_phase 'APPLYING'" "$script"
  grep -Fq "saved(port=\${saved_port},rtt=\${saved_rtt},buf=\${saved_buf})" "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  if grep -Fq 'value="${value}p"' "$script" || grep -Fq 'value="${value}b"' "$script"; then
    printf 'tc show unit suffix reused as fq_codel input: %s\n' "$script" >&2
    exit 1
  fi
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq 'fq_codel) restore_fq_codel "$iface" root' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq '"$root_json" || return 1 ;;' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq 'fq_codel) restore_fq_codel "$iface" leaf "$parent" "$leaf_json" || return 1' "$script"
  grep -Fq 'qdisc 恢复后与原始快照不一致' "$script"
  post_restore_line="$(grep -nF 'elif ! qdisc_snapshot_semantically_matches_current; then' "$script" | head -n1 | cut -d: -f1)"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  state_cleanup_line="$(grep -nF '    rm -rf -- "$STATE_DIR"' "$script" | tail -n1 | cut -d: -f1)"
  [ -n "$post_restore_line" ] && [ -n "$state_cleanup_line" ] && [ "$post_restore_line" -lt "$state_cleanup_line" ] || {
    printf 'qdisc post-restore verification must precede state cleanup: %s\n' "$script" >&2
    exit 1
  }
  applying_line="$(grep -nF "state_set_phase 'APPLYING'" "$script" | head -n1 | cut -d: -f1)"
  first_write_line="$(grep -nF '  write_sysctl_profile' "$script" | head -n1 | cut -d: -f1)"
  [ -n "$applying_line" ] && [ -n "$first_write_line" ] && [ "$applying_line" -lt "$first_write_line" ] || {
    printf 'APPLYING phase must be committed before the first system write: %s\n' "$script" >&2
    exit 1
  }
  verify_guard_line="$(grep -nF "state_exists || die \"\$EXIT_VERIFY\" '当前主机尚未安装本项目配置" "$script" | head -n1 | cut -d: -f1)"
  verify_tools_line="$(awk '/^    verify\)/,/^      ;;/ {if (/ensure_required_tools/) {print NR; exit}}' "$script")"
  [ -n "$verify_guard_line" ] && [ -n "$verify_tools_line" ] && [ "$verify_guard_line" -lt "$verify_tools_line" ] || {
    printf 'verify state guard must run before dependency checks: %s\n' "$script" >&2
    exit 1
  }
  [ "$(grep -Fc 'fq) : ;;' "$script")" -eq 2 ] || {
    printf 'existing fq qdisc is not preserved during rollback: %s\n' "$script" >&2
    exit 1
  }
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

if command -v jq >/dev/null 2>&1; then
  for script in "${scripts[@]}"; do
    state_filter_file="$tmp_dir/${script}.state-filter.jq"
    state_json_file="$tmp_dir/${script}.state.json"
    "$python_cmd" - "$script" >"$state_filter_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
start_marker = "    '{schema_version:$schema"
end_marker = "      managed_files:[],timestamps:{prepared:$now,last_update:$now}}"
start = text.find(start_marker)
end = text.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit(f"state jq filter not found: {sys.argv[1]}")
start += len("    '")
end += len("      managed_files:[],timestamps:{prepared:$now,last_update:$now}}")
sys.stdout.buffer.write(text[start:end].encode("utf-8") + b"\n")
PY
    jq -n \
      --argjson schema 3 --arg version 'test' \
      --arg profile 'test-profile' --arg profile_label 'Test Profile' \
      --arg debian '12' --arg arch 'x86_64' --arg kernel 'test-kernel' \
      --argjson mem 960 --argjson port 1000 --argjson rtt 200 \
      --argjson buf 33554432 --arg mode 'auto' \
      --arg qfile '/tmp/qdisc.json' --arg qhash 'test-hash' \
      --arg now '2026-08-01T00:00:00Z' --argjson original '{}' \
      "$(<"$state_filter_file")" >"$state_json_file"
    jq -e '.profile.label == "Test Profile" and .network.port_speed_mbps == 1000' \
      "$state_json_file" >/dev/null
  done
else
  printf '[WARN] jq not found; state constructor compile checks skipped\n' >&2
fi

transaction_test="$tmp_dir/transaction-state-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^atomic_json_commit\(\)/,/^}/' "${scripts[0]}"
  awk '/^cleanup_uncommitted_state\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_TRANSACTION_TEST'
chown() { :; }
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

target="$test_root/state.json"
printf '%s\n' '{"generation":"old"}' >"$target"
old_hash="$(sha256sum "$target" | awk '{print $1}')"
for fixture in empty invalid multiple; do
  tmp="$test_root/${fixture}.tmp"
  case "$fixture" in
    empty) : >"$tmp" ;;
    invalid) printf '%s\n' 'not-json' >"$tmp" ;;
    multiple) printf '%s\n%s\n' '{"one":1}' '{"two":2}' >"$tmp" ;;
  esac
  if atomic_json_commit "$target" "$tmp" 2>/dev/null; then
    printf 'atomic_json_commit accepted %s JSON\n' "$fixture" >&2
    exit 1
  fi
  [ "$(sha256sum "$target" | awk '{print $1}')" = "$old_hash" ] || {
    printf 'atomic_json_commit changed target after %s input\n' "$fixture" >&2
    exit 1
  }
done
valid_tmp="$test_root/valid.tmp"
printf '%s\n' '{"generation":"new"}' >"$valid_tmp"
atomic_json_commit "$target" "$valid_tmp"
jq -e '.generation == "new"' "$target" >/dev/null

STATE_DIR="$test_root/uncommitted"
STATE_FILE="$STATE_DIR/state.json"
QDISC_STATE_FILE="$STATE_DIR/qdisc-original.json"
STATE_DIR_CREATED=1
mkdir "$STATE_DIR"
: >"$QDISC_STATE_FILE"
: >"${STATE_FILE}.tmp.test"
cleanup_uncommitted_state
[ ! -e "$STATE_DIR" ]

STATE_DIR="$test_root/unexpected"
STATE_FILE="$STATE_DIR/state.json"
QDISC_STATE_FILE="$STATE_DIR/qdisc-original.json"
mkdir "$STATE_DIR"
: >"$STATE_DIR/unowned-file"
if cleanup_uncommitted_state 2>/dev/null; then
  printf 'cleanup removed a state directory containing an unknown file\n' >&2
  exit 1
fi
[ -e "$STATE_DIR/unowned-file" ]
EOF_TRANSACTION_TEST
} >"$transaction_test"
bash "$transaction_test"

state_validation_test="$tmp_dir/state-validation-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^state_file_is_valid\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_STATE_VALIDATION_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
STATE_FILE="$test_root/state.json"
STATE_SCHEMA_VERSION=3
PROFILE_ID='debian12-1c1g'
stat() { printf '%s\n' '0'; }

for fixture in empty whitespace null object multiple; do
  case "$fixture" in
    empty) : >"$STATE_FILE" ;;
    whitespace) printf '  \n' >"$STATE_FILE" ;;
    null) printf '%s\n' 'null' >"$STATE_FILE" ;;
    object) printf '%s\n' '{}' >"$STATE_FILE" ;;
    multiple) printf '%s\n%s\n' '{}' '{}' >"$STATE_FILE" ;;
  esac
  if state_file_is_valid; then
    printf 'state validator accepted %s state\n' "$fixture" >&2
    exit 1
  fi
done

printf '%s\n' '{"schema_version":3,"profile":{"id":"debian12-1c1g"},"state":"PREPARED","network":{},"original_sysctls":{},"qdisc":{"file":"/tmp/qdisc","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"swap":{},"managed_files":[],"timestamps":{}}' >"$STATE_FILE"
state_file_is_valid
EOF_STATE_VALIDATION_TEST
} >"$state_validation_test"
bash "$state_validation_test"

state_transition_test="$tmp_dir/state-transition-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^atomic_json_commit\(\)/,/^}/' "${scripts[0]}"
  awk '/^state_set_phase\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_STATE_TRANSITION_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
STATE_FILE="$test_root/state.json"
printf '%s\n' '{"state":"PREPARED","timestamps":{}}' >"$STATE_FILE"
old_hash="$(sha256sum "$STATE_FILE" | awk '{print $1}')"
error() { :; }
jq() { return 3; }
if state_set_phase APPLYING; then
  printf 'state_set_phase accepted a failed jq transform\n' >&2
  exit 1
fi
[ "$(sha256sum "$STATE_FILE" | awk '{print $1}')" = "$old_hash" ] || {
  printf 'state_set_phase replaced state after jq failure\n' >&2
  exit 1
}
EOF_STATE_TRANSITION_TEST
} >"$state_transition_test"
bash "$state_transition_test"

state_recovery_test="$tmp_dir/state-recovery-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^recover_empty_legacy_state\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_STATE_RECOVERY_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
STATE_DIR="$test_root/state"
STATE_FILE="$STATE_DIR/state.json"
QDISC_STATE_FILE="$STATE_DIR/qdisc-original.json"
SWAP_FILE="$test_root/swapfile"
FQ_SERVICE_NAME='proxy-vps-fq.service'
EXIT_CONFLICT=4
QDISC_MATCH_REASON=''
ALLOW_EMPTY_STATE_RECOVERY=1
mkdir "$STATE_DIR"
: >"$STATE_FILE"
printf '%s\n' '[]' >"$QDISC_STATE_FILE"
state_exists() { [ -f "$STATE_FILE" ]; }
state_file_is_valid() { return 1; }
project_managed_files_exist() { return 1; }
qdisc_snapshot_semantically_matches_current() { return 0; }
systemctl() { return 1; }
stat() { printf '%s\n' '0'; }
date() { printf '%s\n' '20260802T000000Z'; }
info() { :; }
die() { exit "$1"; }
recover_empty_legacy_state
[ ! -e "$STATE_DIR" ]
[ -d "${STATE_DIR}.recovered-20260802T000000Z" ]
EOF_STATE_RECOVERY_TEST
} >"$state_recovery_test"
bash "$state_recovery_test"

sysctl_normalization_test="$tmp_dir/sysctl-normalization-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^normalize_sysctl_value\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_SYSCTL_NORMALIZATION_TEST'
expected='4096 131072 33554432'
actual=$'4096\t      131072  \t33554432'
[ "$(normalize_sysctl_value "$actual")" = "$expected" ] || {
  printf 'sysctl whitespace normalization rejected an equivalent triplet\n' >&2
  exit 1
}
[ "$(normalize_sysctl_value '4096 131072 16777216')" != "$expected" ] || {
  printf 'sysctl normalization ignored a numeric value change\n' >&2
  exit 1
}
EOF_SYSCTL_NORMALIZATION_TEST
} >"$sysctl_normalization_test"
bash "$sysctl_normalization_test"

nofile_parse_test="$tmp_dir/nofile-parse-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail' 'IFS=$'\''\n\t'\'''
  awk '/^read_nofile_limits\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_NOFILE_PARSE_TEST'
limits_file="$(mktemp)"
trap 'rm -f -- "$limits_file"' EXIT
printf '%s\n' \
  'Limit                     Soft Limit           Hard Limit           Units' \
  'Max open files            524287               524288               files' >"$limits_file"
soft=''; hard=''
IFS=$'\t' read -r soft hard < <(read_nofile_limits "$limits_file")
[ "$soft" = '524287' ] && [ "$hard" = '524288' ] || {
  printf 'NOFILE parser returned soft=%s hard=%s\n' "$soft" "$hard" >&2
  exit 1
}
EOF_NOFILE_PARSE_TEST
} >"$nofile_parse_test"
bash "$nofile_parse_test"

preflight_state_test="$tmp_dir/preflight-state-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^check_preflight_state\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_PREFLIGHT_STATE_TEST'
EXIT_CONFLICT=4
STATE_PRESENT=0
PHASE=''
state_exists() { [ "$STATE_PRESENT" -eq 1 ]; }
state_get() { printf '%s\n' "$PHASE"; }
die() { exit "$1"; }
check_preflight_state
STATE_PRESENT=1
for PHASE in VERIFIED APPLIED SWAP_RETAINED DEGRADED ROLLBACK_PENDING; do
  set +e
  (check_preflight_state >/dev/null 2>&1)
  rc=$?
  set -e
  [ "$rc" -eq "$EXIT_CONFLICT" ] || {
    printf 'preflight accepted existing state %s (exit=%s)\n' "$PHASE" "$rc" >&2
    exit 1
  }
done
EOF_PREFLIGHT_STATE_TEST
} >"$preflight_state_test"
bash "$preflight_state_test"

qdisc_match_test="$tmp_dir/qdisc-match-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^qdisc_snapshot_file_is_valid\(\)/,/^}/' "${scripts[0]}"
  awk '/^qdisc_snapshot_semantically_matches_current\(\)/,/^}/' "${scripts[0]}"
  awk '/^qdisc_snapshot_matches_current\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_QDISC_MATCH_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
QDISC_STATE_FILE="$test_root/qdisc-original.json"
cat >"$QDISC_STATE_FILE" <<'EOF_QDISC_SNAPSHOT'
[{"interface":"eth0","qdiscs":[{"dev":"eth0","kind":"fq_codel","handle":"0:","root":true,"refcnt":2,"options":{"limit":10240,"ecn":true,"target":5000,"interval":100000}}]}]
EOF_QDISC_SNAPSHOT
fixture_hash="$(sha256sum "$QDISC_STATE_FILE" | awk '{print $1}')"
state_get() { printf '%s\n' "$fixture_hash"; }
stat() { printf '%s\n' '0'; }
TC_VARIANT='auto_handle'
tc() {
  case "$TC_VARIANT" in
    auto_handle) printf '%s\n' '[{"dev":"eth0","kind":"fq_codel","handle":"8001:","root":true,"refcnt":99,"options":{"ecn":true,"limit":10240,"target":4999,"interval":99999}}]' ;;
    different) printf '%s\n' '[{"dev":"eth0","kind":"fq_codel","handle":"8001:","root":true,"refcnt":99,"options":{"ecn":true,"limit":9999,"target":4999,"interval":99999}}]' ;;
    explicit_match) printf '%s\n' '[{"dev":"eth0","kind":"fq_codel","handle":"1234:","root":true,"refcnt":99,"options":{"ecn":true,"limit":10240,"target":4999,"interval":99999}}]' ;;
  esac
}
qdisc_snapshot_matches_current
TC_VARIANT='different'
if qdisc_snapshot_matches_current; then
  printf 'qdisc matcher ignored a semantic option change\n' >&2
  exit 1
fi

printf '%s\n' '[{"interface":"eth0","qdiscs":[{"dev":"eth0","kind":"fq_codel","handle":"1234:","root":true,"refcnt":2,"options":{"limit":10240,"ecn":true,"target":5000,"interval":100000}}]}]' >"$QDISC_STATE_FILE"
fixture_hash="$(sha256sum "$QDISC_STATE_FILE" | awk '{print $1}')"
TC_VARIANT='auto_handle'
if qdisc_snapshot_matches_current; then
  printf 'qdisc matcher ignored an explicit saved handle change\n' >&2
  exit 1
fi
TC_VARIANT='explicit_match'
qdisc_snapshot_matches_current
EOF_QDISC_MATCH_TEST
} >"$qdisc_match_test"
bash "$qdisc_match_test"

fq_codel_restore_test="$tmp_dir/fq-codel-restore-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^restore_fq_codel\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_FQ_CODEL_RESTORE_TEST'
capture="$(mktemp)"
trap 'rm -f -- "$capture"' EXIT
tc() { printf '%s\n' "$@" >"$capture"; }
json='{"handle":"0:","options":{"limit":10240,"flows":1024,"quantum":1514,"target":4999,"interval":99999,"memory_limit":33554432,"drop_batch":64,"ecn":true}}'
restore_fq_codel eth0 root '' "$json"
actual="$(paste -sd' ' "$capture")"
expected='qdisc replace dev eth0 root fq_codel limit 10240 flows 1024 quantum 1514 target 4999us interval 99999us memory_limit 33554432 drop_batch 64 ecn'
[ "$actual" = "$expected" ] || {
  printf 'unexpected fq_codel restore command\nexpected: %s\nactual:   %s\n' "$expected" "$actual" >&2
  exit 1
}

json='{"handle":"1234:","options":{"limit":10240,"ecn":true}}'
restore_fq_codel eth0 root '' "$json"
actual="$(paste -sd' ' "$capture")"
expected='qdisc replace dev eth0 root handle 1234: fq_codel limit 10240 ecn'
[ "$actual" = "$expected" ] || {
  printf 'explicit fq_codel handle was not restored\nexpected: %s\nactual:   %s\n' "$expected" "$actual" >&2
  exit 1
}
EOF_FQ_CODEL_RESTORE_TEST
} >"$fq_codel_restore_test"
bash "$fq_codel_restore_test"

rollback_postcheck_test="$tmp_dir/rollback-postcheck-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^rollback_internal\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_ROLLBACK_POSTCHECK_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
STATE_DIR="$test_root/state"
mkdir "$STATE_DIR"
SYSCTL_FILE="$test_root/sysctl"
JOURNAL_FILE="$test_root/journal"
FQ_HELPER="$test_root/helper"
FQ_SERVICE="$test_root/service"
FQ_SERVICE_NAME='proxy-vps-fq.service'
QDISC_STATE_FILE="$STATE_DIR/qdisc-original.json"
SWAP_FILE="$test_root/swap"
PURGE_CREATED_SWAP=0
QDISC_MATCH_REASON='restored options differ'
PHASES=''
validate_state_file() { return 0; }
state_get() { [ "$1" = '.state' ] && printf '%s\n' 'VERIFIED'; }
state_set_phase() { PHASES="${PHASES} $1"; }
assert_owned_file() { :; }
qdisc_snapshot_matches_current() { return 1; }
restore_qdiscs() { return 0; }
qdisc_snapshot_semantically_matches_current() { QDISC_MATCH_REASON='restored options differ'; return 1; }
restore_original_sysctls() { return 0; }
purge_owned_swap() { return 0; }
systemctl() { return 0; }
sysctl() { return 0; }
error() { :; }
warn() { :; }
info() { :; }

if rollback_internal 0; then
  printf 'rollback accepted a failed qdisc post-restore comparison\n' >&2
  exit 1
fi
[ -d "$STATE_DIR" ] || {
  printf 'rollback deleted state after qdisc post-restore failure\n' >&2
  exit 1
}
case "$PHASES" in
  *' ROLLBACK_PENDING'*) : ;;
  *) printf 'rollback did not record ROLLBACK_PENDING\n' >&2; exit 1 ;;
esac
case "$PHASES" in
  *' DEGRADED'*) : ;;
  *) printf 'rollback did not preserve a DEGRADED state\n' >&2; exit 1 ;;
esac
EOF_ROLLBACK_POSTCHECK_TEST
} >"$rollback_postcheck_test"
bash "$rollback_postcheck_test"

for script in "${scripts[@]}"; do
  helper="$tmp_dir/${script}.helper"
  awk "/^  write_managed_file .*FQ_HELPER.*<<'EOF_HELPER'/ {inside=1; next} /^EOF_HELPER$/ {inside=0} inside" "$script" >"$helper"
  [ -s "$helper" ] || { printf 'failed to extract helper: %s\n' "$script" >&2; exit 1; }
  bash -n "$helper"
  grep -Fq 'select(has("parent") and .kind == "fq_codel")' "$helper"
  if grep -Fq 'select(has("parent")) | .parent' "$helper"; then
    printf 'helper still replaces every mq leaf: %s\n' "$script" >&2
    exit 1
  fi
done

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "${scripts[@]}" tests/static-check.sh
  for helper in "$tmp_dir"/*.helper; do shellcheck -x "$helper"; done
else
  printf '[WARN] shellcheck not found; syntax and structural checks only\n' >&2
fi

printf 'static checks passed for %s scripts\n' "${#scripts[@]}"
