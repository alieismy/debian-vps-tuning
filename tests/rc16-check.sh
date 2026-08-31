#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
chmod 0700 "$test_root"

budget_tool="${repo_root}/dvt-traffic-budget.sh"
ledger="${test_root}/ledger/window.json"
bash "$budget_tool" init --ledger "$ledger" --window-id fixture --budget-bytes 1000 >/dev/null
bash "$budget_tool" reserve --ledger "$ledger" --window-id fixture --budget-bytes 1000 \
  --tool probe --run-id run-1 --reservation-id reservation-1 --planned-bytes 600 >/dev/null
if bash "$budget_tool" reserve --ledger "$ledger" --window-id fixture --budget-bytes 1000 \
  --tool benchmark --run-id run-2 --reservation-id reservation-2 --planned-bytes 500 >/dev/null 2>&1; then
  printf 'over-budget reservation was accepted\n' >&2
  exit 1
fi
bash "$budget_tool" commit --ledger "$ledger" --reservation-id reservation-1 --actual-bytes 400 >/dev/null
bash "$budget_tool" reserve --ledger "$ledger" --window-id fixture --budget-bytes 1000 \
  --tool benchmark --run-id run-2 --reservation-id reservation-2 --planned-bytes 500 >/dev/null
bash "$budget_tool" fail --ledger "$ledger" --reservation-id reservation-2 >/dev/null
jq -e '.reserved_bytes==0 and .accounted_bytes==900 and .status=="OPEN" and
  ([.entries[].status] == ["COMMITTED","FAILED_CONSERVATIVE"])' "$ledger" >/dev/null

state_file="${test_root}/managed-state.json"
boot_file="${test_root}/boot-id"
source_profile="${test_root}/source-profile.sh"
target_profile="${test_root}/target-profile.sh"
checkpoint="${test_root}/checkpoint"
printf '%s\n' boot-a >"$boot_file"
printf '%s\n' '{"schema_version":4,"script_version":"0.1.0-rc.15","state":"VERIFIED","profile":{"id":"debian13-1c1g"},"network":{"port_speed_mbps":200}}' >"$state_file"
cat >"$source_profile" <<'EOF_SOURCE'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_VERSION='0.1.0-rc.15'
PROFILE_ID='debian13-1c1g'
case "$1" in
  verify) jq -e '.script_version=="0.1.0-rc.15" and .state=="VERIFIED"' "$DVT_STATE_FILE" >/dev/null ;;
  rollback) rm -f -- "$DVT_STATE_FILE" ;;
  *) exit 2 ;;
esac
EOF_SOURCE
cat >"$target_profile" <<'EOF_TARGET'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_VERSION='0.1.0-rc.16'
PROFILE_ID='debian13-1c1g'
case "$1" in
  preflight) [ ! -e "$DVT_STATE_FILE" ] || jq -e '.script_version=="0.1.0-rc.15"' "$DVT_STATE_FILE" >/dev/null ;;
  apply) printf '%s\n' '{"schema_version":4,"script_version":"0.1.0-rc.16","state":"APPLIED","profile":{"id":"debian13-1c1g"},"network":{"port_speed_mbps":200}}' >"$DVT_STATE_FILE" ;;
  verify) jq '.state="VERIFIED"' "$DVT_STATE_FILE" >"${DVT_STATE_FILE}.tmp"; mv -f "${DVT_STATE_FILE}.tmp" "$DVT_STATE_FILE" ;;
  *) exit 2 ;;
esac
EOF_TARGET
chmod 0700 "$source_profile" "$target_profile"
state_hash="$(sha256sum "$state_file" | awk '{print $1}')"
if env DVT_STATE_FILE="$state_file" DVT_BOOT_ID_FILE="$boot_file" \
  bash "${repo_root}/dvt-migrate.sh" prepare --checkpoint "${checkpoint}-downgrade" \
  --source-profile "$source_profile" --target-profile "$target_profile" \
  --source-version 0.1.0-rc.17 --target-version 0.1.0-rc.16 \
  --profile-id debian13-1c1g --port 200 --state-sha256 "$state_hash" >/dev/null 2>&1; then
  printf 'migration accepted a newer source version\n' >&2
  exit 1
fi
env DVT_STATE_FILE="$state_file" DVT_BOOT_ID_FILE="$boot_file" \
  bash "${repo_root}/dvt-migrate.sh" prepare --checkpoint "$checkpoint" \
  --source-profile "$source_profile" --target-profile "$target_profile" \
  --source-version 0.1.0-rc.15 --target-version 0.1.0-rc.16 \
  --profile-id debian13-1c1g --port 200 --state-sha256 "$state_hash" >/dev/null
env DVT_STATE_FILE="$state_file" DVT_BOOT_ID_FILE="$boot_file" \
  bash "$checkpoint/dvt-migrate.sh" rollback --checkpoint "$checkpoint" >/dev/null
if env DVT_STATE_FILE="$state_file" DVT_BOOT_ID_FILE="$boot_file" \
  bash "$checkpoint/dvt-migrate.sh" continue --checkpoint "$checkpoint" >/dev/null 2>&1; then
  printf 'first reboot gate accepted unchanged boot ID\n' >&2
  exit 1
fi
printf '%s\n' boot-b >"$boot_file"
env DVT_STATE_FILE="$state_file" DVT_BOOT_ID_FILE="$boot_file" \
  bash "$checkpoint/dvt-migrate.sh" continue --checkpoint "$checkpoint" >/dev/null
if env DVT_STATE_FILE="$state_file" DVT_BOOT_ID_FILE="$boot_file" \
  bash "$checkpoint/dvt-migrate.sh" continue --checkpoint "$checkpoint" >/dev/null 2>&1; then
  printf 'second reboot gate accepted unchanged boot ID\n' >&2
  exit 1
fi
printf '%s\n' boot-c >"$boot_file"
env DVT_STATE_FILE="$state_file" DVT_BOOT_ID_FILE="$boot_file" \
  bash "$checkpoint/dvt-migrate.sh" continue --checkpoint "$checkpoint" >/dev/null
jq -e '.phase=="COMPLETE" and ([.history[].phase] | index("ROLLBACK_RUNNING") != null) and
  ([.history[].phase] | index("TARGET_APPLIED_REBOOT_REQUIRED") != null)' "$checkpoint/migration.json" >/dev/null
jq -e '.script_version=="0.1.0-rc.16" and .state=="VERIFIED"' "$state_file" >/dev/null

profile="${repo_root}/debian13-1c1g-vps-tuning.sh"
process_fixture="${test_root}/benchmark-process-fixture.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^benchmark_reap_active_child\(\)/,/^}/' "$profile"
  awk '/^run_iperf3_with_timeout\(\)/,/^}/' "$profile"
  cat <<'EOF_PROCESS_FIXTURE'
BENCHMARK_ACTIVE_CHILD_PID=''
BENCHMARK_ACTIVE_CHILD_PGID=''
BENCHMARK_PHASE_TIMEOUT_RESOLVED=1
BENCHMARK_TIMEOUT_TERMINATE_GRACE_SECONDS=1
warn() { :; }
run_iperf3_with_timeout "$DVT_PROCESS_OUTPUT" --fixture
EOF_PROCESS_FIXTURE
} >"$process_fixture"
chmod 0700 "$process_fixture"

fake_bin="${test_root}/fake-bin"
mkdir -m 0700 "$fake_bin"
cat >"${fake_bin}/iperf3" <<'EOF_FAKE_IPERF'
#!/usr/bin/env bash
set -Eeuo pipefail
trap '' TERM
sleep 300 &
child=$!
printf '%s %s\n' "$$" "$child" >"$DVT_PROCESS_PIDS"
wait "$child"
EOF_FAKE_IPERF
chmod 0700 "${fake_bin}/iperf3"
set +e
env PATH="${fake_bin}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  DVT_PROCESS_OUTPUT="${test_root}/iperf-output.json" DVT_PROCESS_PIDS="${test_root}/iperf-pids" \
  bash "$process_fixture" >/dev/null 2>&1
process_rc=$?
set -e
[ "$process_rc" -eq 124 ] || { printf 'benchmark timeout fixture returned rc=%s\n' "$process_rc" >&2; exit 1; }
[ -s "${test_root}/iperf-pids" ] || { printf 'benchmark timeout fixture did not record child processes\n' >&2; exit 1; }
read -r iperf_pid sleep_pid <"${test_root}/iperf-pids"
for attempt in 1 2 3 4 5; do
  if ! kill -0 "$iperf_pid" 2>/dev/null && ! kill -0 "$sleep_pid" 2>/dev/null; then break; fi
  sleep 1
done
if kill -0 "$iperf_pid" 2>/dev/null || kill -0 "$sleep_pid" 2>/dev/null; then
  printf 'benchmark timeout left an iperf3 process-group member alive\n' >&2
  exit 1
fi

printf 'rc.16 traffic-budget, migration, and benchmark process checks passed\n'
