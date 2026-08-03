#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=debian-vps-tuning.sh
source "$repo_root/debian-vps-tuning.sh"

test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

fail() { printf 'controller test failed: %s\n' "$*" >&2; exit 1; }

write_os_release() {
  local file="$1" id="$2" version="$3"
  printf 'ID=%q\nVERSION_ID=%q\nPRETTY_NAME=%q\n' \
    "$id" "$version" "Test OS ${version}" >"$file"
}

write_meminfo() {
  local file="$1" mib="$2"
  printf 'MemTotal:       %s kB\n' "$((mib * 1024))" >"$file"
}

assert_profile() {
  local version="$1" cpus="$2" memory="$3" expected="$4" expected_class="$5"
  local os_file="$test_root/os-${version}-${cpus}-${memory}" mem_file="$test_root/mem-${memory}" result actual actual_class
  write_os_release "$os_file" debian "$version"
  write_meminfo "$mem_file" "$memory"
  result="$(detect_profile_from "$os_file" "$mem_file" x86_64 "$cpus")" ||
    fail "profile detection failed for Debian ${version}, ${cpus} vCPU, ${memory} MiB"
  IFS=$'\t' read -r actual _ _ _ actual_class <<<"$result"
  [ "$actual" = "$expected" ] ||
    fail "Debian ${version}, ${cpus} vCPU, ${memory} MiB selected ${actual}, expected ${expected}"
  [ "$actual_class" = "$expected_class" ] ||
    fail "Debian ${version}, ${cpus} vCPU, ${memory} MiB selected class ${actual_class}, expected ${expected_class}"
}

assert_profile 12 1 384 debian12-1c512m 1C512MB
assert_profile 12 1 512 debian12-1c512m 1C512MB
assert_profile 12 1 767 debian12-1c512m 1C512MB
assert_profile 12 1 768 debian12-1c1g 1C1GB
assert_profile 12 1 1024 debian12-1c1g 1C1GB
assert_profile 12 1 1535 debian12-1c1g 1C1GB
assert_profile 12 1 1536 debian12-1c2g 1C2GB
assert_profile 12 1 2048 debian12-1c2g 1C2GB
assert_profile 12 2 1536 debian12-1c2g 2C2GB
assert_profile 12 2 2048 debian12-1c2g 2C2GB
assert_profile 13 1 512 debian13-1c512m 1C512MB
assert_profile 13 1 1024 debian13-1c1g 1C1GB
assert_profile 13 1 2048 debian13-1c2g 1C2GB
assert_profile 13 2 2048 debian13-1c2g 2C2GB

state_profile_matches_detected debian12-1c1g debian12-1c1g || fail 'matching state profile was rejected'
if state_profile_matches_detected debian12-1c1g debian12-1c2g; then
  fail 'mismatched state profile was accepted'
fi

unsupported_os="$test_root/os-unsupported"
supported_mem="$test_root/mem-supported"
write_os_release "$unsupported_os" ubuntu 24.04
write_meminfo "$supported_mem" 1024
set +e
detect_profile_from "$unsupported_os" "$supported_mem" x86_64 1 >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "unsupported OS returned ${rc}, expected 2"

supported_os="$test_root/os-supported"
write_os_release "$supported_os" debian 12
set +e
detect_profile_from "$supported_os" "$supported_mem" aarch64 1 >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "unsupported architecture returned ${rc}, expected 2"

unsupported_mem="$test_root/mem-unsupported"
write_meminfo "$unsupported_mem" 4096
set +e
detect_profile_from "$supported_os" "$unsupported_mem" x86_64 1 >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 3 ] || fail "unsupported memory returned ${rc}, expected 3"

for unsupported_resource in '1 383' '2 512' '2 1024' '3 2048'; do
  IFS=' ' read -r test_cpus test_mem <<<"$unsupported_resource"
  test_mem_file="$test_root/mem-unsupported-${test_cpus}-${test_mem}"
  write_meminfo "$test_mem_file" "$test_mem"
  set +e
  detect_profile_from "$supported_os" "$test_mem_file" x86_64 "$test_cpus" >/dev/null 2>&1
  rc=$?
  set -e
  [ "$rc" -eq 3 ] || fail "unsupported ${test_cpus} vCPU/${test_mem} MiB returned ${rc}, expected 3"
done

set +e
detect_profile_from "$supported_os" "$supported_mem" x86_64 invalid >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 1 ] || fail "invalid CPU count returned ${rc}, expected 1"

for valid_port in 100 200 500 1000 0200; do
  validate_port_speed "$valid_port" || fail "valid port rejected: ${valid_port}"
done
for invalid_port in 99 1001 20000 abc 20.0 ''; do
  if validate_port_speed "$invalid_port"; then
    fail "invalid port accepted: ${invalid_port:-empty}"
  fi
done

ACTION=preflight
CLI_PORT_SPEED_MBPS=''
PORT_SPEED_MBPS_SELECTED=''
unset PORT_SPEED_MBPS || true
select_port_speed
[ "$PORT_SPEED_MBPS_SELECTED" -eq 200 ] || fail 'non-interactive default is not 200 Mbps'

CLI_PORT_SPEED_MBPS=1000
PORT_SPEED_MBPS_SELECTED=''
select_port_speed
[ "$PORT_SPEED_MBPS_SELECTED" -eq 1000 ] || fail '--port did not override the default'

# shellcheck disable=SC2034  # Consumed by sourced select_port_speed.
CLI_PORT_SPEED_MBPS=''
# shellcheck disable=SC2034  # Consumed by sourced select_port_speed.
PORT_SPEED_MBPS=100
PORT_SPEED_MBPS_SELECTED=''
select_port_speed
[ "$PORT_SPEED_MBPS_SELECTED" -eq 100 ] || fail 'PORT_SPEED_MBPS was not preserved'
unset PORT_SPEED_MBPS

ACTION=''
ACTION_FROM_MENU=0
choose_action_interactively <<<'' >/dev/null
[ "$ACTION" = guided ] && [ "$ACTION_FROM_MENU" -eq 1 ] || fail 'default menu action is not guided'

PORT_SPEED_MBPS_SELECTED=''
choose_port_interactively <<<'' >/dev/null
[ "$PORT_SPEED_MBPS_SELECTED" -eq 200 ] || fail 'default interactive port is not 200 Mbps'

fixture="$test_root/profile.sh"
manifest="$test_root/SHA256SUMS"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$fixture"
fixture_hash="$(sha256sum "$fixture" | awk '{print $1}')"
printf '%s  %s\n' "$fixture_hash" 'profile.sh' >"$manifest"
PROFILE_SHA256=''
verify_manifest_entry "$manifest" "$fixture" profile.sh || fail 'valid manifest entry was rejected'
[ "$PROFILE_SHA256" = "$fixture_hash" ] || fail 'verified hash was not recorded'

printf '%s  %s\n%s  %s\n' "$fixture_hash" profile.sh "$fixture_hash" profile.sh >"$manifest"
if verify_manifest_entry "$manifest" "$fixture" profile.sh; then
  fail 'duplicate manifest entries were accepted'
fi

printf '%064d  %s\n' 0 profile.sh >"$manifest"
if verify_manifest_entry "$manifest" "$fixture" profile.sh; then
  fail 'mismatched SHA-256 was accepted'
fi

capture="$test_root/capture"
runner="$test_root/runner.sh"
cat >"$runner" <<'EOF_RUNNER'
#!/usr/bin/env bash
printf '%s|%s\n' "${PORT_SPEED_MBPS:-unset}" "$1" >"$CAPTURE_FILE"
exit "${RUNNER_EXIT:-0}"
EOF_RUNNER
chmod 0700 "$runner"
export CAPTURE_FILE="$capture"
# shellcheck disable=SC2034  # Consumed by sourced run_profile.
PROFILE_PATH="$runner"
PORT_SPEED_MBPS_SELECTED=200
run_profile preflight
[ "$(<"$capture")" = '200|preflight' ] || fail 'preflight dispatch lost port/action'
run_profile verify
[ "$(<"$capture")" = 'unset|verify' ] || fail 'verify dispatch unexpectedly injected a port'
run_profile diagnose
[ "$(<"$capture")" = 'unset|diagnose' ] || fail 'diagnose dispatch unexpectedly injected a port'

RUNNER_EXIT=37
export RUNNER_EXIT
set +e
run_profile status
rc=$?
set -e
[ "$rc" -eq 37 ] || fail "profile exit code was changed: ${rc}"
unset RUNNER_EXIT

PROFILE_FILE='debian12-1c1g-vps-tuning.sh'
DETECTED_PROFILE='debian12-1c1g'
PROFILE_PATH=''
PROFILE_SOURCE=''
PROFILE_SHA256=''
TEMP_DIR=''
resolve_profile_script
[ "$PROFILE_SOURCE" = local ] || fail 'complete repository did not use local profile mode'
[ "$PROFILE_PATH" = "$repo_root/$PROFILE_FILE" ] || fail 'local profile path is incorrect'
[ -n "$PROFILE_SHA256" ] || fail 'local profile SHA-256 was not recorded'

# shellcheck disable=SC2329  # Invoked indirectly by sourced download_file.
curl() { return 22; }
if download_file 'https://example.invalid/file' "$test_root/download" 2>/dev/null; then
  fail 'download failure was accepted'
fi
unset -f curl

remote_controller_dir="$test_root/remote-controller"
remote_fixture_dir="$test_root/remote-fixtures"
mkdir "$remote_controller_dir" "$remote_fixture_dir"
cp "$repo_root/debian-vps-tuning.sh" "$remote_controller_dir/controller.sh"
# Re-source the controller copy so BASH_SOURCE resolves to a directory without
# sibling profiles and exercises the remote branch.
# shellcheck source=/dev/null
source "$remote_controller_dir/controller.sh"

PROFILE_FILE='debian13-1c2g-vps-tuning.sh'
DETECTED_PROFILE='debian13-1c2g'
fixture_remote_profile="$remote_fixture_dir/$PROFILE_FILE"
fixture_remote_manifest="$remote_fixture_dir/SHA256SUMS"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  "SCRIPT_VERSION='${CONTROLLER_VERSION}'" \
  "PROFILE_ID='${DETECTED_PROFILE}'" \
  'exit 0' >"$fixture_remote_profile"
remote_hash="$(sha256sum "$fixture_remote_profile" | awk '{print $1}')"
printf '%s  %s\n' "$remote_hash" "$PROFILE_FILE" >"$fixture_remote_manifest"

MOCK_DOWNLOAD_DIR="$test_root/download-success"
mktemp() {
  mkdir -p "$MOCK_DOWNLOAD_DIR"
  printf '%s\n' "$MOCK_DOWNLOAD_DIR"
}
# shellcheck disable=SC2329  # Invoked indirectly by sourced download_file.
curl() {
  local output='' url=''
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --output) output="$2"; shift 2 ;;
      *) url="$1"; shift ;;
    esac
  done
  case "$url" in
    */SHA256SUMS) cp "$fixture_remote_manifest" "$output" ;;
    */"$PROFILE_FILE") cp "$fixture_remote_profile" "$output" ;;
    *) return 22 ;;
  esac
}

TEMP_DIR=''
PROFILE_PATH=''
PROFILE_SOURCE=''
PROFILE_SHA256=''
resolve_profile_script >/dev/null
[ "$PROFILE_SOURCE" = "release:$RELEASE_TAG" ] || fail 'remote profile source was not recorded'
[ "$PROFILE_SHA256" = "$remote_hash" ] || fail 'remote profile SHA-256 was not verified'
[ -s "$PROFILE_PATH" ] || fail 'remote profile was not downloaded'

printf '%s\n' '#!/usr/bin/env bash' 'exit 99' >"$fixture_remote_profile"
MOCK_DOWNLOAD_DIR="$test_root/download-mismatch"
set +e
( TEMP_DIR=''; PROFILE_PATH=''; PROFILE_SOURCE=''; PROFILE_SHA256=''; resolve_profile_script >/dev/null 2>&1 )
rc=$?
set -e
[ "$rc" -eq "$EXIT_INTEGRITY" ] || fail "remote hash mismatch returned ${rc}, expected ${EXIT_INTEGRITY}"

unset -f curl mktemp

printf 'controller checks passed\n'
