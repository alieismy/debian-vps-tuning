#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

scripts=(
  debian12-1c512m-vps-tuning.sh
  debian12-1c1g-vps-tuning.sh
  debian12-1c2g-vps-tuning.sh
  debian13-1c512m-vps-tuning.sh
  debian13-1c1g-vps-tuning.sh
  debian13-1c2g-vps-tuning.sh
)
controller='debian-vps-tuning.sh'
tcpquality_tool='tcpquality-evidence.sh'
installer='install.sh'
probe_tool='dvt-probe.sh'
htb_wrapper='dvt-htb.sh'
invalid_receiver_fixture='experiments/htb-aggregate/tests/fixtures/iperf3-invalid-receiver-window.json'

if command -v python3 >/dev/null 2>&1; then
  python_cmd=python3
elif command -v python >/dev/null 2>&1; then
  python_cmd=python
else
  printf 'python3/python is required for generated-file checks\n' >&2
  exit 1
fi
"$python_cmd" tools/render_profiles.py --check
bash -n "${scripts[@]}" "$controller" "$tcpquality_tool" "$installer" "$probe_tool" "$htb_wrapper" tools/profile-template.sh.in \
  tests/static-check.sh tests/controller-check.sh tests/installer-check.sh

bash tests/controller-check.sh

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

if LC_ALL=C grep -n $'\r' "$controller"; then
  printf 'CRLF detected: %s\n' "$controller" >&2
  exit 1
fi
if [ "$(od -An -tx1 -N3 "$controller" | tr -d ' \n')" = 'efbbbf' ]; then
  printf 'UTF-8 BOM detected: %s\n' "$controller" >&2
  exit 1
fi

if LC_ALL=C grep -n $'\r' "$tcpquality_tool"; then
  printf 'CRLF detected: %s\n' "$tcpquality_tool" >&2
  exit 1
fi
if [ "$(od -An -tx1 -N3 "$tcpquality_tool" | tr -d ' \n')" = 'efbbbf' ]; then
  printf 'UTF-8 BOM detected: %s\n' "$tcpquality_tool" >&2
  exit 1
fi
grep -Fq "TOOL_VERSION='0.1.0-rc.12'" "$tcpquality_tool"
grep -Fq "SUPPORTED_COMMIT='5d1f85a6b8916b73ec0389dbc9b4ed4aa27dae01'" "$tcpquality_tool"
grep -Fq "SUPPORTED_ROOTFS_SHA256='db92956873d674e65a573721ec6a3db4995f7cf648f61954380e0bfa53ce71a1'" "$tcpquality_tool"
grep -Fq '证据目录已经存在，拒绝覆盖' "$tcpquality_tool"
grep -Fq 'TCPQUALITY_ROOTFS_SHA256' "$tcpquality_tool"
grep -Fq 'csv-inventory.tsv' "$tcpquality_tool"
grep -Fq 'node-drift.tsv' "$tcpquality_tool"
grep -Fq 'finalize_manifest' "$tcpquality_tool"
grep -Fq 'runTcpQuality-rootfs.sh' "$tcpquality_tool"
grep -Fq 'runTcpQuality-core.sh' "$tcpquality_tool"
if grep -Eq 'sysctl[[:space:]]+(-w|--write)|tc[[:space:]]+qdisc[[:space:]]+(add|change|replace|del)|apt(-get)?[[:space:]]+(install|remove|purge)|systemctl[[:space:]]+(start|stop|restart|enable|disable)' "$tcpquality_tool"; then
  printf 'mutating system operation detected in TcpQuality evidence tool\n' >&2
  exit 1
fi

forbidden='ip_local_port_range|ip_local_reserved_ports|tcp_tw_reuse|tcp_tw_recycle|tcp_mem|tcp_fin_timeout|ip_forward|disable_ipv6|fs\.file-max|fs\.nr_open|nf_conntrack_max|busy_poll|busy_read'
if grep -nE "^[[:space:]]*(${forbidden})[[:space:]]*=" "${scripts[@]}"; then
  printf 'forbidden sysctl assignment detected\n' >&2
  exit 1
fi

forbidden_features='rps_sock_flow_entries|smp_affinity|GOMAXPROCS|zram|irqbalance'
if grep -nE "${forbidden_features}" "${scripts[@]}" "$controller" tools/profile-template.sh.in; then
  printf 'out-of-scope CPU steering or compressed-swap feature detected\n' >&2
  exit 1
fi
if grep -nE '(echo|printf|tee).*(rps_cpus|rps_flow_cnt|xps_cpus|xps_rxqs)' "${scripts[@]}" tools/profile-template.sh.in; then
  printf 'CPU steering queue write detected\n' >&2
  exit 1
fi

expected_keys=17
for script in "${scripts[@]}"; do
  actual="$(awk '/^PROFILE_SYSCTL_KEYS=\(/,/^\)/ {if ($1 ~ /^(net\.|vm\.)/) count++} END {print count+0}' "$script")"
  [ "$actual" -eq "$expected_keys" ] || { printf 'unexpected managed-key count: %s (%s)\n' "$script" "$actual" >&2; exit 1; }
  grep -Fq "SCRIPT_VERSION='0.1.0-rc.12'" "$script"
  grep -Eq '^STATE_SCHEMA_VERSION=4$' "$script"
  grep -Eq '^LEGACY_STATE_SCHEMA_VERSION=3$' "$script"
  grep -Fq 'PROFILE_CPU_MIN=' "$script"
  grep -Fq 'PROFILE_CPU_MAX=' "$script"
  grep -Fq '无法读取可用逻辑 CPU 数' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq 'CPU：${cpus} vCPU' "$script"
  case "$script" in
    *-1c512m-*)
      grep -Fq "PROFILE_CPU_MIN=1" "$script"
      grep -Fq "PROFILE_CPU_MAX=1" "$script"
      grep -Fq "MAX_BUF_MAX=16777216" "$script"
      grep -Fq "JOURNAL_SYSTEM_MAX_USE='64M'" "$script"
      grep -Fq "JOURNAL_RUNTIME_MAX_USE='16M'" "$script"
      grep -Fq '/ 1 vCPU / 512 MiB' "$script"
      grep -Fq 'BUFFER_TARGET_NUMERATOR=1' "$script"
      grep -Fq 'BUFFER_TARGET_DENOMINATOR=1' "$script"
      ;;
    *-1c1g-*)
      grep -Fq "PROFILE_CPU_MIN=1" "$script"
      grep -Fq "PROFILE_CPU_MAX=1" "$script"
      grep -Fq "MAX_BUF_MAX=33554432" "$script"
      grep -Fq "JOURNAL_RUNTIME_MAX_USE='32M'" "$script"
      grep -Fq '/ 1 vCPU / 1 GiB' "$script"
      grep -Fq 'BUFFER_TARGET_NUMERATOR=5' "$script"
      grep -Fq 'BUFFER_TARGET_DENOMINATOR=4' "$script"
      ;;
    *-1c2g-*)
      grep -Fq "PROFILE_CPU_MIN=1" "$script"
      grep -Fq "PROFILE_CPU_MAX=2" "$script"
      grep -Fq "MAX_BUF_MAX=67108864" "$script"
      grep -Fq "JOURNAL_RUNTIME_MAX_USE='64M'" "$script"
      grep -Fq '/ 1–2 vCPU / 2 GiB' "$script"
      grep -Fq 'BUFFER_TARGET_NUMERATOR=3' "$script"
      grep -Fq 'BUFFER_TARGET_DENOMINATOR=2' "$script"
      ;;
  esac
  grep -Fq "SWAP_FILE='/swapfile-proxy'" "$script"
  grep -Fq 'x-ui.service' "$script"
  grep -Fq "XUI_DROPIN=\"\${XUI_DROPIN_DIR}/90-\${NAMESPACE}.conf\"" "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq 'LimitNOFILE=${XUI_NOFILE_LIMIT}' "$script"
  grep -Fq 'write_xui_dropin' "$script"
  grep -Fq '尚未安装代理服务；x-ui.service 的 LimitNOFILE drop-in 已预置' "$script"
  grep -Fq 'show_diagnostics' "$script"
  grep -Fq '只读诊断：不会修改 sysctl、qdisc、systemd、swap 或代理服务' "$script"
  grep -Fq 'show_cpu_delta' "$script"
  grep -Fq 'show_proxy_process_evidence' "$script"
  grep -Fq 'link_counter_snapshot' "$script"
  grep -Fq 'run_network_benchmark' "$script"
  grep -Fq 'BENCHMARK_OMIT_SECONDS' "$script"
  grep -Fq 'BENCHMARK_IP_FAMILY' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq 'benchmark-${label}-tcp-delta' "$script"
  grep -Fq 'tmp_dir rc=0 current_rc=0' "$script"
  grep -Fq 'BENCHMARK_OUTPUT_DIR' "$script"
  grep -Fq 'BENCHMARK_RATE_CAP_MBPS' "$script"
  grep -Fq 'benchmark_traffic_estimate_json' "$script"
  grep -Fq 'payload_upper_bound_bytes' "$script"
  grep -Fq 'build_benchmark_phase_summary' "$script"
  grep -Fq 'sender_retransmits_per_gib' "$script"
  grep -Fq 'qdisc_root_totals' "$script"
  grep -Fq 'dropped_per_gib' "$script"
  grep -Fq 'benchmark-result.json' "$script"
  grep -Fq 'SHA256SUMS.tmp' "$script"
  grep -Fq 'tcpFastOpen=not-explicit' "$script"
  grep -Fq 'report_sysctl_conflicts' "$script"
  grep -Fq 'PASS_WITH_PROVIDER_SYSCTL_TRANSFER' "$script"
  grep -Fq 'transfer_provider_sysctl_ownership' "$script"
  grep -Fq 'restore_provider_sysctl_ownership' "$script"
  grep -Fq 'provider_sysctl_transfer_is_restorable' "$script"
  grep -Fq 'verify_provider_sysctl_transfer' "$script"
  grep -Fq '仅 /etc/sysctl.conf 中唯一且值严格为 fq/bbr 的厂商基线可由 apply 事务化迁移' "$script"
  grep -Fq 'verify 拒绝通过' "$script"
  grep -Fq '只读诊断发现重复 sysctl 配置归属' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal jq variables.
  grep -Fq 'buffer_target_numerator:$target_numerator' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal jq variables.
  grep -Fq 'buffer_target_denominator:$target_denominator' "$script"
  grep -Fq "ext2 | ext3 | ext4 | xfs)" "$script"
  grep -Fq "ROOT_FS_TYPE='unknown'" "$script"
  grep -Fq "SWAP_CREATE_ALLOWED='0'" "$script"
  grep -Fq '当前主机尚未安装本项目配置' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq '检测到未完成的事务状态 ${phase}；请先执行 rollback，不要直接 apply。' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq '检测到现有管理状态 ${phase}；已安装配置请执行 verify' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq 'UPDATE_PREFLIGHT="${UPDATE_PREFLIGHT:-0}"' "$script"
  grep -Fq '进入只读 update-preflight，不执行任何系统写入' "$script"
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
  grep -Fq '本次 apply 尚未写入配置' "$script"
  grep -Fq 'PURGE_CREATED_SWAP=1 执行 rollback' "$script"
  grep -Fq '升级配置必须先 rollback' "$script"
  [ "$(grep -Fc 'remove_fstab_swap_line || return 1' "$script")" -eq 2 ] || {
    printf 'fstab removal failure is not propagated by both swap purge paths: %s\n' "$script" >&2
    exit 1
  }
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  if grep -Fq 'value="${value}p"' "$script" || grep -Fq 'value="${value}b"' "$script"; then
    printf 'tc show unit suffix reused as fq_codel input: %s\n' "$script" >&2
    exit 1
  fi
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq 'fq_codel) restore_fq_codel "$iface" root' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq 'pfifo_fast) tc qdisc replace dev "$iface" root pfifo_fast || return 1' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq 'fq_codel | pfifo_fast) tc qdisc replace dev "$iface" root fq' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq '"$root_json" || return 1 ;;' "$script"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  grep -Fq 'fq_codel) restore_fq_codel "$iface" leaf "$parent" "$leaf_json" || return 1' "$script"
  grep -Fq 'qdisc 恢复后与原始快照不一致' "$script"
  post_restore_line="$(grep -nF 'elif ! qdisc_snapshot_semantically_matches_current; then' "$script" | head -n1 | cut -d: -f1)"
  # shellcheck disable=SC2016  # Intentionally match literal shell source.
  state_cleanup_line="$(grep -nF '    rm -rf -- "$STATE_DIR"' "$script" | tail -n1 | cut -d: -f1)"
  if [ -z "$post_restore_line" ] || [ -z "$state_cleanup_line" ] || [ "$post_restore_line" -ge "$state_cleanup_line" ]; then
    printf 'qdisc post-restore verification must precede state cleanup: %s\n' "$script" >&2
    exit 1
  fi
  applying_line="$(grep -nF "state_set_phase 'APPLYING'" "$script" | head -n1 | cut -d: -f1)"
  first_write_line="$(grep -nF '  write_sysctl_profile' "$script" | head -n1 | cut -d: -f1)"
  if [ -z "$applying_line" ] || [ -z "$first_write_line" ] || [ "$applying_line" -ge "$first_write_line" ]; then
    printf 'APPLYING phase must be committed before the first system write: %s\n' "$script" >&2
    exit 1
  fi
  verify_guard_line="$(grep -nF "state_exists || die \"\$EXIT_VERIFY\" '当前主机尚未安装本项目配置" "$script" | head -n1 | cut -d: -f1)"
  verify_tools_line="$(awk '/^    verify\)/,/^      ;;/ {if (/ensure_required_tools/) {print NR; exit}}' "$script")"
  if [ -z "$verify_guard_line" ] || [ -z "$verify_tools_line" ] || [ "$verify_guard_line" -ge "$verify_tools_line" ]; then
    printf 'verify state guard must run before dependency checks: %s\n' "$script" >&2
    exit 1
  fi
  managed_paths_line="$(awk '/^run_preflight\(\)/,/^}/ {if (/^  check_managed_paths$/) {print NR; exit}}' "$script")"
  update_state_line="$(awk '/^run_preflight\(\)/,/^}/ {if (/check_preflight_state$/) {print NR; exit}}' "$script")"
  if [ -z "$managed_paths_line" ] || [ -z "$update_state_line" ] || [ "$managed_paths_line" -ge "$update_state_line" ]; then
    printf 'managed ownership checks must precede the update-preflight state gate: %s\n' "$script" >&2
    exit 1
  fi
  [ "$(grep -Fc 'fq) : ;;' "$script")" -eq 2 ] || {
    printf 'existing fq qdisc is not preserved during rollback: %s\n' "$script" >&2
    exit 1
  }
done

grep -Fq "CONTROLLER_VERSION='0.1.0-rc.12'" "$controller"
grep -Fq "RELEASE_TAG='v0.1.0-rc.12'" "$controller"
grep -Fq "DEFAULT_PORT_SPEED_MBPS=200" "$controller"
grep -Fq 'verify_profile_contract' "$controller"
grep -Fq 'debian12-1c512m-vps-tuning.sh' "$controller"
grep -Fq 'debian13-1c512m-vps-tuning.sh' "$controller"
grep -Fq "resource_class='2C2GB'" "$controller"
grep -Fq 'diagnose（5 秒只读增量诊断）' "$controller"
grep -Fq 'probe（重复、限速、advisory-only；需已授权 iperf3）' "$controller"
grep -Fq 'benchmark（高级单次证据入口；需 BENCHMARK_HOST）' "$controller"
grep -Fq 'HTB 实验（仅 Debian 13 / 200 Mbps / 非持久化）' "$controller"
grep -Fq 'update（只读检查并生成升级计划）' "$controller"
grep -Fq 'resolve_companion_assets' "$controller"
grep -Fq 'ACTION_ARGS=("$@")' "$controller"
grep -Fq 'env UPDATE_PREFLIGHT=1 PORT_SPEED_MBPS=' "$controller"
grep -Fq '系统配置未修改' "$controller"
grep -Fq 'select_highest_release_tag' "$controller"
grep -Fq '可能混用了不同 Release 的资产' "$controller"
grep -Fq '请为每个版本使用独立临时目录' "$controller"
# shellcheck disable=SC2016  # Intentionally match literal shell source.
grep -Fq '[ "$RELEASE_TAG" = "v${CONTROLLER_VERSION}" ]' "$controller"
grep -Fq -- "--proto '=https' --proto-redir '=https'" "$controller"
if grep -Eq 'raw\.githubusercontent\.com|/master/|/main/|releases/latest|http://' "$controller"; then
  printf 'mutable or insecure controller download source detected\n' >&2
  exit 1
fi

grep -Fq "RELEASE_TAG='v0.1.0-rc.12'" "$installer"
grep -Eq "EXPECTED_MANIFEST_SHA256='[0-9a-f]{64}'" "$installer"
if grep -Fq "EXPECTED_MANIFEST_SHA256='0000000000000000000000000000000000000000000000000000000000000000'" "$installer"; then
  printf 'installer manifest digest placeholder was not finalized\n' >&2
  exit 1
fi
grep -Fq -- "--proto '=https' --proto-redir '=https'" "$installer"
grep -Fq 'manifest_entry_valid' "$installer"
grep -Fq '安装过程没有执行 preflight/apply' "$installer"
manifest_hash="$(sha256sum SHA256SUMS | awk '{print $1}')"
grep -Fq "EXPECTED_MANIFEST_SHA256='${manifest_hash}'" "$installer"
installer_hash="$(sha256sum "$installer" | awk '{print $1}')"
grep -Fq "$installer_hash" README.md
grep -Fq "$manifest_hash" docs/releases/v0.1.0-rc.12.md
if grep -Eq 'raw\.githubusercontent\.com|/master/|/main/|releases/latest|http://' "$installer"; then
  printf 'mutable or insecure installer download source detected\n' >&2
  exit 1
fi

grep -Fq 'BENCHMARK_ENFORCE_RATE_CAP=1' "$probe_tool"
grep -Fq 'rate_cap_enforced == true' "$probe_tool"
grep -Fq 'advisory_only:true' "$probe_tool"
grep -Fq 'persistent_shaping_authorized:false' "$probe_tool"
grep -Fq -- '--plan-only' "$probe_tool"
grep -Fq -- '--ack-reference-reviewed' "$htb_wrapper"
grep -Fq '.measurement_gate.valid == true' "$htb_wrapper"
grep -Fq 'never creates persistent HTB' "$htb_wrapper"
grep -Fq 'rate_cap * 125000 * (seconds + omit) * direction_count * samples' "$probe_tool"
( command sha256sum -c SHA256SUMS >/dev/null )

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

resource_profile_test="$tmp_dir/resource-profile-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^check_resource_profile\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_RESOURCE_PROFILE_TEST'
EXIT_UNSUPPORTED=3
BUF_MAX=16777216
PROFILE_LABEL='Test profile'
warn() { :; }
die() { local code="$1"; shift; printf '%s\n' "$*" >&2; exit "$code"; }
nproc() { printf '%s\n' "$TEST_CPUS"; }
memory_mib() { printf '%s\n' "$TEST_MEMORY_MIB"; }

( TEST_CPUS=1; TEST_MEMORY_MIB=1024; PROFILE_CPU_MIN=1; PROFILE_CPU_MAX=1; PROFILE_RAM_MIN_MIB=768; PROFILE_RAM_MAX_MIB=1536; check_resource_profile )
( TEST_CPUS=2; TEST_MEMORY_MIB=2048; PROFILE_CPU_MIN=1; PROFILE_CPU_MAX=2; PROFILE_RAM_MIN_MIB=1536; PROFILE_RAM_MAX_MIB=3072; check_resource_profile )

if ( TEST_CPUS=2; TEST_MEMORY_MIB=1024; PROFILE_CPU_MIN=1; PROFILE_CPU_MAX=1; PROFILE_RAM_MIN_MIB=768; PROFILE_RAM_MAX_MIB=1536; check_resource_profile ) 2>/dev/null; then
  printf '2C1G was accepted by the 1C1G profile\n' >&2
  exit 1
fi
if ( TEST_CPUS=3; TEST_MEMORY_MIB=2048; PROFILE_CPU_MIN=1; PROFILE_CPU_MAX=2; PROFILE_RAM_MIN_MIB=1536; PROFILE_RAM_MAX_MIB=3072; check_resource_profile ) 2>/dev/null; then
  printf '3C2G was accepted by the 1-2C2G profile\n' >&2
  exit 1
fi
EOF_RESOURCE_PROFILE_TEST
} >"$resource_profile_test"
bash "$resource_profile_test"

buffer_profile_test="$tmp_dir/buffer-profile-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^is_bool\(\)/,/^}/' "${scripts[0]}"
  awk '/^validate_inputs\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_BUFFER_PROFILE_TEST'
EXIT_USAGE=2
DEFAULT_PORT_SPEED_MBPS=200
DEFAULT_BUFFER_TARGET_RTT_MS=200
BUFFER_TARGET_NUMERATOR=1
BUFFER_TARGET_DENOMINATOR=1
DEFAULT_SWAP_MB=1024
MIN_BUF_MAX=262144
SWAP_MAX_MIB=2048
PROFILE_LABEL='fixture'
ENABLE_SWAP=1
PURGE_CREATED_SWAP=0
REQUIRE_PROXY_SERVICE=0
UPDATE_PREFLIGHT=0
SWAP_MB_INPUT=1024
warn() { WARNED=1; }
die() { exit "$1"; }

PORT_SPEED_MBPS_INPUT=1000
BUFFER_TARGET_RTT_MS_INPUT=200
BUF_MAX_INPUT=auto
MAX_BUF_MAX=16777216
WARNED=0
validate_inputs
[ "$BUF_MAX" -eq 16777216 ] && [ "$BUF_MAX_MODE" = auto-clamped ] && [ "$WARNED" -eq 1 ] || {
  printf '512 MiB auto buffer was not clamped and warned\n' >&2
  exit 1
}

PORT_SPEED_MBPS_INPUT=1000
BUFFER_TARGET_RTT_MS_INPUT=200
BUF_MAX_INPUT=auto
MAX_BUF_MAX=33554432
BUFFER_TARGET_NUMERATOR=5
BUFFER_TARGET_DENOMINATOR=4
WARNED=0
validate_inputs
[ "$BUF_MAX" -eq 33554432 ] && [ "$BUF_MAX_MODE" = auto ] && [ "$WARNED" -eq 0 ] || {
  printf '1 GiB 1000 Mbps auto buffer did not select 32 MiB without a warning\n' >&2
  exit 1
}

PORT_SPEED_MBPS_INPUT=1000
BUFFER_TARGET_RTT_MS_INPUT=200
BUF_MAX_INPUT=auto
MAX_BUF_MAX=67108864
BUFFER_TARGET_NUMERATOR=3
BUFFER_TARGET_DENOMINATOR=2
WARNED=0
validate_inputs
[ "$BUF_MAX" -eq 67108864 ] && [ "$BUF_MAX_MODE" = auto ] && [ "$WARNED" -eq 0 ] || {
  printf '2 GiB auto buffer did not select 64 MiB\n' >&2
  exit 1
}

PORT_SPEED_MBPS_INPUT=500
BUFFER_TARGET_RTT_MS_INPUT=200
BUF_MAX_INPUT=auto
MAX_BUF_MAX=67108864
BUFFER_TARGET_NUMERATOR=3
BUFFER_TARGET_DENOMINATOR=2
WARNED=0
validate_inputs
[ "$BUF_MAX" -eq 33554432 ] && [ "$BUF_MAX_MODE" = auto ] && [ "$WARNED" -eq 0 ] || {
  printf '2 GiB 500 Mbps auto buffer did not select 32 MiB\n' >&2
  exit 1
}

PORT_SPEED_MBPS_INPUT=500
BUFFER_TARGET_RTT_MS_INPUT=200
BUF_MAX_INPUT=auto
MAX_BUF_MAX=33554432
BUFFER_TARGET_NUMERATOR=5
BUFFER_TARGET_DENOMINATOR=4
WARNED=0
validate_inputs
[ "$BUF_MAX" -eq 16777216 ] && [ "$BUF_MAX_MODE" = auto ] && [ "$WARNED" -eq 0 ] || {
  printf '1 GiB 500 Mbps auto buffer did not select 16 MiB\n' >&2
  exit 1
}

PORT_SPEED_MBPS_INPUT=200
BUFFER_TARGET_RTT_MS_INPUT=200
BUF_MAX_INPUT=auto
MAX_BUF_MAX=67108864
BUFFER_TARGET_NUMERATOR=3
BUFFER_TARGET_DENOMINATOR=2
WARNED=0
validate_inputs
[ "$BUF_MAX" -eq 16777216 ] && [ "$BUF_MAX_MODE" = auto ] && [ "$WARNED" -eq 0 ] || {
  printf '2 GiB 200 Mbps auto buffer did not select 16 MiB\n' >&2
  exit 1
}

if ( PORT_SPEED_MBPS_INPUT=200 BUFFER_TARGET_RTT_MS_INPUT=200 BUF_MAX_INPUT=33554432 MAX_BUF_MAX=16777216 validate_inputs ) 2>/dev/null; then
  printf '512 MiB profile accepted an explicit buffer above 16 MiB\n' >&2
  exit 1
fi
EOF_BUFFER_PROFILE_TEST
} >"$buffer_profile_test"
bash "$buffer_profile_test"

diagnostic_delta_test="$tmp_dir/diagnostic-delta-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^softnet_snapshot\(\)/,/^}/' "${scripts[0]}"
  awk '/^cpu_snapshot\(\)/,/^}/' "${scripts[0]}"
  awk '/^show_cpu_delta\(\)/,/^}/' "${scripts[0]}"
  awk '/^link_counter_snapshot\(\)/,/^}/' "${scripts[0]}"
  awk '/^tcp_counter_snapshot\(\)/,/^}/' "${scripts[0]}"
  awk '/^show_counter_delta\(\)/,/^}/' "${scripts[0]}"
  awk '/^show_softnet_delta\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_DIAGNOSTIC_DELTA_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
printf '00000064 00000002 00000003 00000000\n' >"$test_root/softnet.raw"
printf 'cpu 100 20 30 400 5 6 7 8 0 0\n' >"$test_root/cpu.before.raw"
printf 'cpu 120 20 40 450 7 7 12 11 0 0\n' >"$test_root/cpu.after.raw"
printf 'eth0\n' >"$test_root/ifaces"
mkdir -p "$test_root/sys/eth0/statistics"
for stat in rx_bytes rx_packets rx_dropped rx_errors tx_bytes tx_packets tx_dropped tx_errors; do
  printf '%s\n' 10 >"$test_root/sys/eth0/statistics/$stat"
done
cat >"$test_root/snmp.raw" <<'EOF_SNMP'
Ip: InDiscards OutDiscards
Ip: 7 8
Tcp: RetransSegs
Tcp: 9
EOF_SNMP
cat >"$test_root/netstat.raw" <<'EOF_NETSTAT'
TcpExt: ListenDrops TCPTimeouts TCPFastOpenPassive
TcpExt: 10 11 12
EOF_NETSTAT
softnet_snapshot "$test_root/softnet.raw" >"$test_root/softnet.snapshot"
cpu_snapshot "$test_root/cpu.before.raw" >"$test_root/cpu.before"
cpu_snapshot "$test_root/cpu.after.raw" >"$test_root/cpu.after"
link_counter_snapshot "$test_root/ifaces" "$test_root/sys" >"$test_root/link.snapshot"
tcp_counter_snapshot "$test_root/snmp.raw" "$test_root/netstat.raw" >"$test_root/tcp.snapshot"
grep -Fqx $'0\t100\t2\t3' "$test_root/softnet.snapshot"
grep -Fqx $'IpInDiscards\t7' "$test_root/tcp.snapshot"
grep -Fqx $'TcpRetransSegs\t9' "$test_root/tcp.snapshot"
grep -Fqx $'TcpExtListenDrops\t10' "$test_root/tcp.snapshot"
grep -Fqx $'TcpExtTCPTimeouts\t11' "$test_root/tcp.snapshot"
grep -Fqx $'TcpExtTCPFastOpenPassive\t12' "$test_root/tcp.snapshot"
grep -Fqx $'user\t100' "$test_root/cpu.before"
grep -Fqx $'steal\t8' "$test_root/cpu.before"
grep -Fqx $'eth0.rx_dropped\t10' "$test_root/link.snapshot"
printf 'TcpRetransSegs\t10\nTcpExtTCPTimeouts\t4\n' >"$test_root/tcp.before"
printf 'TcpRetransSegs\t13\nTcpExtTCPTimeouts\t4\n' >"$test_root/tcp.after"
printf '0\t100\t2\t3\n1\t200\t4\t5\n' >"$test_root/softnet.before"
printf '0\t150\t3\t5\n1\t260\t4\t8\n' >"$test_root/softnet.after"
show_counter_delta "$test_root/tcp.before" "$test_root/tcp.after" tcp-delta >"$test_root/tcp.out"
show_softnet_delta "$test_root/softnet.before" "$test_root/softnet.after" >"$test_root/softnet.out"
show_cpu_delta "$test_root/cpu.before" "$test_root/cpu.after" cpu-delta >"$test_root/cpu.out"
grep -Fqx '[tcp-delta] TcpRetransSegs=3' "$test_root/tcp.out"
grep -Fqx '[tcp-delta] TcpExtTCPTimeouts=0' "$test_root/tcp.out"
grep -Fqx '[softnet-delta] cpu=0 processed=50 dropped=1 time_squeeze=2' "$test_root/softnet.out"
grep -Fqx '[softnet-delta] cpu=1 processed=60 dropped=0 time_squeeze=3' "$test_root/softnet.out"
grep -Fq '[cpu-delta] total_ticks=91 user_ticks=20 user_pct=21.98' "$test_root/cpu.out"
grep -Fq 'system_ticks=10 system_pct=10.99' "$test_root/cpu.out"
grep -Fq 'steal_ticks=3 steal_pct=3.30' "$test_root/cpu.out"
EOF_DIAGNOSTIC_DELTA_TEST
} >"$diagnostic_delta_test"
bash "$diagnostic_delta_test"

benchmark_guard_test="$tmp_dir/benchmark-guard-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^benchmark_traffic_estimate_json\(\)/,/^}/' "${scripts[0]}"
  awk '/^run_network_benchmark\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_BENCHMARK_GUARD_TEST'
EXIT_USAGE=2
EXIT_UNSUPPORTED=3
EXIT_CONFLICT=4
EXIT_VERIFY=5
ensure_required_tools() { :; }
check_supported_os() { :; }
iperf3() { :; }
die() { exit "$1"; }
is_bool() { case "$1" in 0 | 1) return 0 ;; *) return 1 ;; esac; }

set +e
( unset BENCHMARK_HOST; run_network_benchmark ) >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq "$EXIT_USAGE" ] || { printf 'benchmark accepted an empty host\n' >&2; exit 1; }

set +e
( BENCHMARK_HOST=example.com BENCHMARK_PARALLEL=5 run_network_benchmark ) >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq "$EXIT_USAGE" ] || { printf 'benchmark accepted parallel=5\n' >&2; exit 1; }

set +e
( BENCHMARK_HOST=example.com BENCHMARK_OMIT_SECONDS=11 run_network_benchmark ) >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq "$EXIT_USAGE" ] || { printf 'benchmark accepted omit=11\n' >&2; exit 1; }

set +e
( BENCHMARK_HOST=example.com BENCHMARK_IP_FAMILY=dual run_network_benchmark ) >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq "$EXIT_USAGE" ] || { printf 'benchmark accepted an invalid IP family\n' >&2; exit 1; }

set +e
( BENCHMARK_HOST=example.com BENCHMARK_RUN_ID='unsafe id' run_network_benchmark ) >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq "$EXIT_USAGE" ] || { printf 'benchmark accepted an unsafe run id\n' >&2; exit 1; }

set +e
( BENCHMARK_HOST=example.com BENCHMARK_RATE_CAP_MBPS=0 run_network_benchmark ) >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq "$EXIT_USAGE" ] || { printf 'benchmark accepted rate cap 0\n' >&2; exit 1; }

set +e
( BENCHMARK_HOST=example.com BENCHMARK_ENFORCE_RATE_CAP=1 run_network_benchmark ) >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq "$EXIT_USAGE" ] || { printf 'benchmark enforced an unspecified rate cap\n' >&2; exit 1; }

set +e
( BENCHMARK_HOST=example.com BENCHMARK_ENFORCE_RATE_CAP=yes BENCHMARK_RATE_CAP_MBPS=200 run_network_benchmark ) >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq "$EXIT_USAGE" ] || { printf 'benchmark accepted invalid rate-cap boolean\n' >&2; exit 1; }

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) ;;
  *)
    set +e
    ( BENCHMARK_HOST=example.com BENCHMARK_OUTPUT_DIR='relative' run_network_benchmark ) >/dev/null 2>&1
    rc=$?
    set -e
    [ "$rc" -eq "$EXIT_USAGE" ] || { printf 'benchmark accepted a relative output directory (rc=%s)\n' "$rc" >&2; exit 1; }
    ;;
esac

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) ;;
  *)
    existing_output="$(mktemp -d)"
    set +e
    ( BENCHMARK_HOST=example.com BENCHMARK_OUTPUT_DIR="$existing_output" run_network_benchmark ) >/dev/null 2>&1
    rc=$?
    set -e
    rmdir "$existing_output"
    [ "$rc" -eq "$EXIT_CONFLICT" ] || { printf 'benchmark accepted an existing output directory\n' >&2; exit 1; }
    ;;
esac
EOF_BENCHMARK_GUARD_TEST
} >"$benchmark_guard_test"
bash "$benchmark_guard_test"

benchmark_traffic_estimate_test="$tmp_dir/benchmark-traffic-estimate-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^benchmark_traffic_estimate_json\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_BENCHMARK_TRAFFIC_ESTIMATE_TEST'
estimate="$(benchmark_traffic_estimate_json 200 explicit 10 3 both)"
jq -e '
  .available == true and
  .cap_mbps == 200 and
  .cap_source == "explicit" and
  .direction_count == 2 and
  .per_direction_seconds == 13 and
  .total_seconds == 26 and
  .payload_upper_bound_bytes == 650000000 and
  .protocol_overhead_included == false
' <<<"$estimate" >/dev/null

estimate="$(benchmark_traffic_estimate_json '' unavailable 5 0 download)"
jq -e '
  .available == false and
  .cap_mbps == null and
  .direction_count == 1 and
  .total_seconds == 5 and
  .payload_upper_bound_bytes == null
' <<<"$estimate" >/dev/null

if benchmark_traffic_estimate_json 200 explicit 10 3 invalid >/dev/null 2>&1; then
  printf 'traffic estimator accepted an invalid direction\n' >&2
  exit 1
fi
EOF_BENCHMARK_TRAFFIC_ESTIMATE_TEST
} >"$benchmark_traffic_estimate_test"
bash "$benchmark_traffic_estimate_test"

benchmark_phase_test="$tmp_dir/benchmark-phase-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^counter_delta_json\(\)/,/^}/' "${scripts[0]}"
  awk '/^link_total_delta\(\)/,/^}/' "${scripts[0]}"
  awk '/^qdisc_counter_snapshot\(\)/,/^}/' "${scripts[0]}"
  awk '/^build_benchmark_phase_summary\(\)/,/^}/' "${scripts[0]}"
  awk '/^run_benchmark_phase\(\)/,/^}/' "${scripts[0]}"
  printf 'INVALID_RECEIVER_FIXTURE=%q\n' "$invalid_receiver_fixture"
  cat <<'EOF_BENCHMARK_PHASE_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
printf 'eth0\n' >"$test_root/ifaces"
capture="$test_root/iperf.args"
EXIT_VERIFY=5
BENCHMARK_HOST_RESOLVED='2001:db8::1'
BENCHMARK_PORT_RESOLVED=5201
BENCHMARK_SECONDS_RESOLVED=10
BENCHMARK_OMIT_RESOLVED=3
BENCHMARK_PARALLEL_RESOLVED=1
BENCHMARK_FAMILY_ARGS=(--version6)
softnet_snapshot() { printf '0\t1\t0\t0\n'; }
tcp_counter_snapshot() { printf 'TcpRetransSegs\t1\n'; }
cpu_snapshot() { printf 'user\t1\nnice\t0\nsystem\t0\nidle\t1\niowait\t0\nirq\t0\nsoftirq\t0\nsteal\t0\n'; }
link_counter_snapshot() { printf 'eth0.rx_bytes\t1\neth0.tx_bytes\t1\n'; }
show_counter_delta() { :; }
show_softnet_delta() { :; }
show_cpu_delta() { :; }
tc() {
  printf '%s\n' \
    'qdisc fq 0: root refcnt 2 limit 10000p' \
    ' Sent 1000 bytes 10 pkt (dropped 0, overlimits 0 requeues 0)'
}
iperf3() {
  printf '%q ' "$@" >>"$capture"
  printf '\n' >>"$capture"
  printf '%s\n' '{"end":{"sum_sent":{"seconds":10,"bytes":250000000,"bits_per_second":200000000,"retransmits":2},"sum_received":{"seconds":10,"bytes":248750000,"bits_per_second":199000000}}}'
  return "${IPERF_RC:-0}"
}

run_benchmark_phase upload 0 "$test_root" "$test_root/ifaces" >/dev/null
run_benchmark_phase download 1 "$test_root" "$test_root/ifaces" >/dev/null
[ "$(wc -l <"$capture")" -eq 2 ] || { printf 'benchmark did not run two isolated phases\n' >&2; exit 1; }
sed -n '1p' "$capture" | grep -Fq -- '--omit 3 --parallel 1 --version6 --json' || {
  printf 'upload benchmark arguments changed: %s\n' "$(sed -n '1p' "$capture")" >&2
  exit 1
}
if sed -n '1p' "$capture" | grep -Fq -- '--reverse'; then
  printf 'upload unexpectedly used reverse mode\n' >&2
  exit 1
fi
sed -n '2p' "$capture" | grep -Fq -- '--version6 --reverse --json' || {
  printf 'download benchmark arguments changed: %s\n' "$(sed -n '2p' "$capture")" >&2
  exit 1
}
jq -e '.schema_version == 2 and .direction == "upload" and
  .measurement_window.status == "VALID" and .measurement_window.valid == true and
  .sender.seconds == 10 and .receiver.seconds == 10 and
  .sender.mbps == 200 and .sender.retransmits == 2 and
  .sender.retransmits_per_gib > 8.5 and .sender.retransmits_per_gib < 8.7' \
  "$test_root/upload.summary.json" >/dev/null
jq -e '.qdisc_root_totals.dropped_delta == 0 and .qdisc_root_totals.dropped_per_gib == null' \
  "$test_root/upload.summary.json" >/dev/null
jq -e '.qdisc_coverage.aggregation_source == "root" and .qdisc_active_totals.dropped_delta == 0' \
  "$test_root/upload.summary.json" >/dev/null
jq -e '.direction == "download" and .reverse == true' "$test_root/download.summary.json" >/dev/null

: >"$capture"
BENCHMARK_RATE_ARGS=(--bitrate 200M)
run_benchmark_phase upload 0 "$test_root" "$test_root/ifaces" >/dev/null
grep -Fq -- '--version6 --bitrate 200M --json' "$capture" || {
  printf 'benchmark did not forward the enforced iperf3 bitrate: %s\n' "$(<"$capture")" >&2
  exit 1
}

printf 'TcpRetransSegs\t10\n' >"$test_root/wrap.before"
printf 'TcpRetransSegs\t5\n' >"$test_root/wrap.after"
if counter_delta_json "$test_root/wrap.before" "$test_root/wrap.after" >/dev/null 2>&1; then
  printf 'counter delta accepted a negative/reset counter\n' >&2
  exit 1
fi

printf 'TcpRetransSegs\t10\n' >"$test_root/missing.before"
: >"$test_root/missing.after"
if counter_delta_json "$test_root/missing.before" "$test_root/missing.after" >/dev/null 2>&1; then
  printf 'counter delta accepted a missing after snapshot\n' >&2
  exit 1
fi

printf 'eth0.rx_bytes\t10\neth0.tx_bytes\t20\n' >"$test_root/keyset.before"
printf 'eth0.rx_bytes\t11\n' >"$test_root/keyset.after"
if counter_delta_json "$test_root/keyset.before" "$test_root/keyset.after" >/dev/null 2>&1; then
  printf 'counter delta accepted a changed key set\n' >&2
  exit 1
fi

for suffix in tcp.before tcp.after link.before link.after qdisc.before qdisc.after; do
  : >"$test_root/malformed.${suffix}"
done
printf '%s\n' '{}' >"$test_root/malformed.iperf3.json"
set +e
build_benchmark_phase_summary malformed 0 "$test_root" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq "$EXIT_VERIFY" ] || { printf 'malformed iperf3 JSON was accepted\n' >&2; exit 1; }

cp "$test_root/upload.tcp.before" "$test_root/partial.tcp.before"
cp "$test_root/upload.tcp.after" "$test_root/partial.tcp.after"
cp "$test_root/upload.link.before" "$test_root/partial.link.before"
cp "$test_root/upload.link.after" "$test_root/partial.link.after"
cp "$test_root/upload.qdisc.before" "$test_root/partial.qdisc.before"
cp "$test_root/upload.qdisc.after" "$test_root/partial.qdisc.after"
printf '%s\n' '{"end":{"sum_sent":{},"sum_received":{}}}' >"$test_root/partial.iperf3.json"
if build_benchmark_phase_summary partial 0 "$test_root" >/dev/null 2>&1; then
  printf 'partial iperf3 summary was accepted\n' >&2
  exit 1
fi

for suffix in tcp.before tcp.after link.before link.after qdisc.before qdisc.after; do
  cp "$test_root/upload.${suffix}" "$test_root/invalid-window.${suffix}"
done
cp "$INVALID_RECEIVER_FIXTURE" "$test_root/invalid-window.iperf3.json"
build_benchmark_phase_summary invalid-window 0 "$test_root" >/dev/null
jq -e '
  .schema_version == 2 and
  .measurement_window.status == "INVALID_MEASUREMENT_WINDOW" and
  .measurement_window.valid == false and
  (.measurement_window.issues | index("receiver-duration-mismatch") != null) and
  (.measurement_window.issues | index("sender-receiver-window-mismatch") != null) and
  (.measurement_window.issues | index("receiver-bytes-exceed-sender-tolerance") != null) and
  .sender.retransmits == 0
' "$test_root/invalid-window.summary.json" >/dev/null

cat >"$test_root/mq.tc" <<'EOF_MQ_TC'
qdisc mq 0: root
 Sent 2000 bytes 20 pkt (dropped 0, overlimits 0 requeues 0)
qdisc fq 8001: parent :1 limit 10000p
 Sent 1000 bytes 10 pkt (dropped 2, overlimits 3 requeues 0)
qdisc fq 8002: parent :2 limit 10000p
 Sent 1000 bytes 10 pkt (dropped 1, overlimits 4 requeues 0)
qdisc ingress ffff: parent ffff:fff1 ----------------
 Sent 50 bytes 1 pkt (dropped 5, overlimits 0 requeues 0)
EOF_MQ_TC
tc() { cat "$test_root/mq.tc"; }
qdisc_counter_snapshot "$test_root/ifaces" >"$test_root/mq.snapshot"
grep -Fqx $'eth0.root.mq.0:.bytes\t2000' "$test_root/mq.snapshot"
grep -Fqx $'eth0.leaf.fq.8001:.dropped\t2' "$test_root/mq.snapshot"
grep -Fqx $'eth0.leaf.fq.8002:.overlimits\t4' "$test_root/mq.snapshot"
grep -Fqx $'eth0.other.ingress.ffff:.dropped\t5' "$test_root/mq.snapshot"

cp "$test_root/upload.tcp.before" "$test_root/mqphase.tcp.before"
cp "$test_root/upload.tcp.after" "$test_root/mqphase.tcp.after"
cp "$test_root/upload.link.before" "$test_root/mqphase.link.before"
cp "$test_root/upload.link.after" "$test_root/mqphase.link.after"
cp "$test_root/upload.iperf3.json" "$test_root/mqphase.iperf3.json"
cat >"$test_root/mqphase.qdisc.before" <<'EOF_MQ_BEFORE'
eth0.root.mq.0:.bytes	2000
eth0.root.mq.0:.packets	20
eth0.root.mq.0:.dropped	0
eth0.root.mq.0:.overlimits	0
eth0.root.mq.0:.requeues	0
eth0.leaf.fq.8001:.bytes	1000
eth0.leaf.fq.8001:.packets	10
eth0.leaf.fq.8001:.dropped	2
eth0.leaf.fq.8001:.overlimits	3
eth0.leaf.fq.8001:.requeues	0
eth0.leaf.fq.8002:.bytes	1000
eth0.leaf.fq.8002:.packets	10
eth0.leaf.fq.8002:.dropped	1
eth0.leaf.fq.8002:.overlimits	4
eth0.leaf.fq.8002:.requeues	0
EOF_MQ_BEFORE
cat >"$test_root/mqphase.qdisc.after" <<'EOF_MQ_AFTER'
eth0.root.mq.0:.bytes	4000
eth0.root.mq.0:.packets	40
eth0.root.mq.0:.dropped	0
eth0.root.mq.0:.overlimits	0
eth0.root.mq.0:.requeues	0
eth0.leaf.fq.8001:.bytes	2000
eth0.leaf.fq.8001:.packets	20
eth0.leaf.fq.8001:.dropped	4
eth0.leaf.fq.8001:.overlimits	5
eth0.leaf.fq.8001:.requeues	0
eth0.leaf.fq.8002:.bytes	2000
eth0.leaf.fq.8002:.packets	20
eth0.leaf.fq.8002:.dropped	2
eth0.leaf.fq.8002:.overlimits	7
eth0.leaf.fq.8002:.requeues	0
EOF_MQ_AFTER
build_benchmark_phase_summary mqphase 0 "$test_root" >/dev/null
jq -e '.qdisc_coverage.aggregation_source == "leaf" and .qdisc_coverage.root_is_mq == true and .qdisc_root_totals.dropped_delta == 0 and .qdisc_active_totals.dropped_delta == 3' \
  "$test_root/mqphase.summary.json" >/dev/null

set +e
IPERF_RC=7 run_benchmark_phase upload 0 "$test_root" "$test_root/ifaces" >/dev/null
rc=$?
set -e
[ "$rc" -eq 7 ] || { printf 'benchmark phase did not preserve iperf3 failure\n' >&2; exit 1; }
EOF_BENCHMARK_PHASE_TEST
} >"$benchmark_phase_test"
bash "$benchmark_phase_test"

benchmark_persistence_test="$tmp_dir/benchmark-persistence-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^benchmark_traffic_estimate_json\(\)/,/^}/' "${scripts[0]}"
  awk '/^run_network_benchmark\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_BENCHMARK_PERSISTENCE_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
PATH="/usr/bin:/bin:${PATH}"
export PATH
EXIT_USAGE=2
EXIT_UNSUPPORTED=3
EXIT_CONFLICT=4
EXIT_VERIFY=5
SCRIPT_VERSION='0.1.0-rc.12'
PROFILE_ID='debian13-1c1g'
STATE_FILE="$test_root/no-state.json"
ensure_required_tools() { :; }
check_supported_os() { :; }
info() { :; }
die() { exit "$1"; }
is_bool() { case "$1" in 0 | 1) return 0 ;; *) return 1 ;; esac; }
default_route_ifaces() { printf 'eth0\n'; }
state_file_is_valid() { [ "${STATE_VALID:-0}" = '1' ]; }
sysctl() { printf 'stub\n'; }
ip() { :; }
iperf3() { printf 'iperf 3.test\n'; }
run_benchmark_phase() {
  local label="$1" tmp_dir="$3"
  printf '%s\n' '{"end":{"sum_sent":{"bytes":1,"bits_per_second":1,"retransmits":0},"sum_received":{"bytes":1,"bits_per_second":1}}}' >"${tmp_dir}/${label}.iperf3.json"
  printf '%s\n' '{"schema_version":1,"direction":"upload"}' >"${tmp_dir}/${label}.summary.json"
}
sha256sum() {
  if [ "${FAIL_MANIFEST:-0}" = '1' ] && [ "${1:-}" = '-c' ]; then return 9; fi
  command sha256sum "$@"
}

success_dir="$test_root/success"
BENCHMARK_HOST=example.com BENCHMARK_DIRECTION=upload BENCHMARK_RATE_CAP_MBPS=200 BENCHMARK_ENFORCE_RATE_CAP=1 BENCHMARK_OUTPUT_DIR="$success_dir" run_network_benchmark >/dev/null
[ -f "$success_dir/COMPLETED" ] && [ ! -e "$success_dir/INCOMPLETE" ]
jq -e '.status == "PASS" and .exit_code == 0 and (.evidence_manifest_sha256 | type == "string")' \
  "$success_dir/benchmark-result.json" >/dev/null
jq -e '.benchmark.traffic_estimate.available == true and .benchmark.traffic_estimate.cap_source == "explicit" and .benchmark.traffic_estimate.payload_upper_bound_bytes == 325000000 and .benchmark.rate_cap_enforced == true and .benchmark.rate_cap_method == "iperf3-bitrate" and .benchmark.rate_cap_scope == "aggregate-target-divided-across-streams" and .benchmark.rate_cap_per_stream_bps == 200000000' \
  "$success_dir/benchmark-meta.json" >/dev/null
(cd "$success_dir" && command sha256sum -c SHA256SUMS >/dev/null)

managed_dir="$test_root/managed"
printf '%s\n' '{"state":"VERIFIED","network":{"port_speed_mbps":500}}' >"$STATE_FILE"
STATE_VALID=1 BENCHMARK_HOST=example.com BENCHMARK_DIRECTION=download BENCHMARK_OUTPUT_DIR="$managed_dir" run_network_benchmark >/dev/null
jq -e '.benchmark.traffic_estimate.available == true and .benchmark.traffic_estimate.cap_mbps == 500 and .benchmark.traffic_estimate.cap_source == "managed-state" and .benchmark.traffic_estimate.payload_upper_bound_bytes == 812500000' \
  "$managed_dir/benchmark-meta.json" >/dev/null

failure_dir="$test_root/failure"
set +e
(FAIL_MANIFEST=1 BENCHMARK_HOST=example.com BENCHMARK_DIRECTION=upload BENCHMARK_RATE_CAP_MBPS=200 BENCHMARK_OUTPUT_DIR="$failure_dir" run_network_benchmark) >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq "$EXIT_VERIFY" ] || { printf 'manifest failure returned unexpected rc=%s\n' "$rc" >&2; exit 1; }
[ -f "$failure_dir/INCOMPLETE" ] && [ ! -e "$failure_dir/COMPLETED" ]
jq -e '.status == "FAIL" and .exit_code == 5' "$failure_dir/benchmark-result.json" >/dev/null
EOF_BENCHMARK_PERSISTENCE_TEST
} >"$benchmark_persistence_test"
bash "$benchmark_persistence_test"

tcpquality_node_test="$tmp_dir/tcpquality-node-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^snapshot_nodes\(\)/,/^}/' "$tcpquality_tool"
  awk '/^logical_node_keys\(\)/,/^}/' "$tcpquality_tool"
  awk '/^node_ip_change_count\(\)/,/^}/' "$tcpquality_tool"
  awk '/^record_node_drift\(\)/,/^}/' "$tcpquality_tool"
  cat <<'EOF_TCPQUALITY_NODE_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
PATH="/usr/bin:/bin:${PATH}"
export PATH
EVIDENCE_DIR="$test_root"
GET_NODES_URL='https://nodes.example.test/getNodes'
printf 'run\tscope\tbefore_rows\tafter_rows\tlogical_removed\tlogical_added\tip_changed\texact_equal\n' >"$test_root/node-drift.tsv"
cat >"$test_root/before.tsv" <<'EOF_BEFORE'
type	family	province	isp	host	ip	port	target	backup_host	backup_ip	backup_port	backup_target
cdn	4	A	CT	a.example	192.0.2.1	80	a-target
cdn	4	B	CU	b.example	192.0.2.2	80	b-target
EOF_BEFORE
cat >"$test_root/after.tsv" <<'EOF_AFTER'
type	family	province	isp	host	ip	port	target	backup_host	backup_ip	backup_port	backup_target
cdn	4	A	CT	a.example	192.0.2.9	80	a-target
cdn	4	C	CM	c.example	192.0.2.3	80	c-target
EOF_AFTER
record_node_drift 1 all "$test_root/before.tsv" "$test_root/after.tsv"
grep -Fqx $'1\tall\t2\t2\t1\t1\t1\t0' "$test_root/node-drift.tsv"

CURL_BODY=$'type\tfamily\tprovince\tisp\thost\tip\tport\ttarget\tbackup_host\tbackup_ip\tbackup_port\tbackup_target\ntos\t4\tA\tCT\ta.example\t192.0.2.1\t443\ttarget\tb.example\t192.0.2.2\t443\tbackup\n'
curl() { printf '%s' "$CURL_BODY"; }
snapshot_nodes tos "$test_root/valid.tsv"
[ -s "$test_root/valid.tsv" ]
CURL_BODY='<html>gateway error</html>'
if snapshot_nodes all "$test_root/html.tsv"; then
  printf 'node snapshot accepted non-TSV content\n' >&2
  exit 1
fi
CURL_BODY=$'type\tfamily\tprovince\ncdn\t4\tA\n'
if snapshot_nodes all "$test_root/bad-schema.tsv"; then
  printf 'node snapshot accepted an invalid schema\n' >&2
  exit 1
fi
EOF_TCPQUALITY_NODE_TEST
} >"$tcpquality_node_test"
bash "$tcpquality_node_test"

tcpquality_failure_test="$tmp_dir/tcpquality-failure-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^run_one\(\)/,/^}/' "$tcpquality_tool"
  cat <<'EOF_TCPQUALITY_FAILURE_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
EVIDENCE_DIR="$test_root/evidence"
PIN_DIR="$test_root/pin"
COMMIT='5d1f85a6b8916b73ec0389dbc9b4ed4aa27dae01'
COUNT=30
PACKET_SIZE=0
PARALLEL=16
ROOTFS_SHA256='db92956873d674e65a573721ec6a3db4995f7cf648f61954380e0bfa53ce71a1'
GET_NODES_URL='https://nodes.example.test/getNodes'
TOOL_VERSION='0.1.0-rc.12'
mkdir "$EVIDENCE_DIR" "$PIN_DIR"
: >"$PIN_DIR/SHA256SUMS"
find_csv_inventory() { :; }
sha256sum() {
  if [ "${1:-}" = '-c' ]; then return 7; fi
  command sha256sum "$@"
}
run_rc=0
run_one 1 || run_rc=$?
[ "$run_rc" -ne 0 ] || { printf 'run_one ignored pinned checksum failure\n' >&2; exit 1; }
EOF_TCPQUALITY_FAILURE_TEST
} >"$tcpquality_failure_test"
bash "$tcpquality_failure_test"

cross_version_apply_test="$tmp_dir/cross-version-apply-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^apply_settings\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_CROSS_VERSION_APPLY_TEST'
EXIT_CONFLICT=4
SCRIPT_VERSION='0.1.0-rc.12'
PORT_SPEED_MBPS=200
BUFFER_TARGET_RTT_MS=200
BUF_MAX=16777216
run_preflight() { :; }
state_exists() { return 0; }
state_get() {
  case "$1" in
    .state) printf 'VERIFIED\n' ;;
    .script_version) printf '0.1.0-rc.9\n' ;;
    *) printf '0\n' ;;
  esac
}
die() { local code="$1"; shift; printf '%s\n' "$*" >&2; exit "$code"; }

set +e
output="$(apply_settings 2>&1)"
rc=$?
set -e
[ "$rc" -eq "$EXIT_CONFLICT" ] || { printf 'cross-version apply was accepted\n' >&2; exit 1; }
grep -Fq '升级配置必须先 rollback' <<<"$output"
EOF_CROSS_VERSION_APPLY_TEST
} >"$cross_version_apply_test"
bash "$cross_version_apply_test"

parameter_mismatch_apply_test="$tmp_dir/parameter-mismatch-apply-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^apply_settings\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_PARAMETER_MISMATCH_APPLY_TEST'
EXIT_CONFLICT=4
SCRIPT_VERSION='0.1.0-rc.12'
PORT_SPEED_MBPS=100
BUFFER_TARGET_RTT_MS=200
BUF_MAX=16777216
run_preflight() { :; }
state_exists() { return 0; }
state_get() {
  case "$1" in
    .state) printf 'VERIFIED\n' ;;
    .script_version) printf '%s\n' "$SCRIPT_VERSION" ;;
    .network.port_speed_mbps) printf '500\n' ;;
    .network.target_rtt_ms) printf '200\n' ;;
    .network.buffer_max_bytes) printf '16777216\n' ;;
    *) printf '0\n' ;;
  esac
}
die() { local code="$1"; shift; printf '%s\n' "$*" >&2; exit "$code"; }
write_initial_state() { printf 'parameter mismatch reached write path\n' >&2; exit 99; }

set +e
output="$(apply_settings 2>&1)"
rc=$?
set -e
[ "$rc" -eq "$EXIT_CONFLICT" ] || { printf 'parameter mismatch apply returned %s\n' "$rc" >&2; exit 1; }
grep -Fq '本次 apply 尚未写入配置' <<<"$output"
grep -Fq 'PURGE_CREATED_SWAP=1 执行 rollback' <<<"$output"
EOF_PARAMETER_MISMATCH_APPLY_TEST
} >"$parameter_mismatch_apply_test"
bash "$parameter_mismatch_apply_test"

sysctl_conflict_test="$tmp_dir/sysctl-conflict-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^report_sysctl_conflicts\(\)/,/^}/' "${scripts[0]}"
  awk '/^verify_settings\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_SYSCTL_CONFLICT_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
SYSCTL_SCAN_ROOT="$test_root/etc"
mkdir -p "$SYSCTL_SCAN_ROOT/sysctl.d"
SYSCTL_FILE="$SYSCTL_SCAN_ROOT/sysctl.d/90-proxy-vps.conf"
JOURNAL_FILE="$test_root/journal.conf"
FQ_HELPER="$test_root/proxy-vps-fq"
FQ_SERVICE="$test_root/proxy-vps-fq.service"
FQ_SERVICE_NAME='proxy-vps-fq.service'
XUI_DROPIN="$test_root/x-ui.conf"
QDISC_STATE_FILE="$test_root/qdisc.json"
WARNINGS=0
PROFILE_SYSCTL_KEYS=(net.core.default_qdisc net.ipv4.tcp_congestion_control)
printf '%s\n' \
  'net.core.default_qdisc = fq' \
  'net.ipv4.tcp_congestion_control = bbr' >"$SYSCTL_FILE"
for file in "$JOURNAL_FILE" "$FQ_HELPER" "$FQ_SERVICE" "$XUI_DROPIN" "$QDISC_STATE_FILE"; do
  : >"$file"
done
managed_alias="$SYSCTL_SCAN_ROOT/sysctl.d/99-managed-alias.conf"
ln -s "$SYSCTL_FILE" "$managed_alias"
if [ ! -L "$managed_alias" ]; then
  # MSYS may materialize `ln -s` as a regular copy.  Do not let that
  # Windows-only behavior masquerade as a Linux symlink fixture.
  rm -f "$managed_alias"
fi

state_exists() { return 0; }
validate_state_file() { return 0; }
state_get() {
  case "$1" in
    .state) printf 'VERIFIED\n' ;;
    .qdisc.sha256) printf 'qhash\n' ;;
    .swap.created_by_script) printf 'false\n' ;;
    *) printf '0\n' ;;
  esac
}
normalize_sysctl_value() { printf '%s\n' "$1"; }
sysctl() {
  case "$2" in
    net.core.default_qdisc) printf 'fq\n' ;;
    net.ipv4.tcp_congestion_control) printf 'bbr\n' ;;
  esac
}
sha256sum() { printf 'qhash  %s\n' "$1"; }
assert_owned_file() { :; }
systemctl() { printf '%s\n' "$FQ_SERVICE"; }
verify_current_qdiscs() { return 0; }
verify_provider_sysctl_transfer() { return 0; }
verify_proxy_services() { return 0; }
show_xray_socket_options() { :; }
error() { printf '[x] %s\n' "$*" >&2; }
info() { :; }
warn() { WARNINGS=$((WARNINGS + 1)); printf '[!] %s\n' "$*" >&2; }
stat() {
  if [ "${1:-}" = '-c' ] && [ "${2:-}" = '%u' ]; then printf '0\n'; else command stat "$@"; fi
}

# A unique exact fq/bbr baseline in /etc/sysctl.conf is classified as
# transactionally migratable.  The read-only scan must not change the file.
provider="$SYSCTL_SCAN_ROOT/sysctl.conf"
printf '%s\n' \
  '# provider baseline' \
  'net.core.default_qdisc = fq' \
  'net.ipv4.tcp_congestion_control = bbr' >"$provider"
provider_hash_before="$(sha256sum "$provider" | awk '{print $1}')"
report_sysctl_conflicts >/dev/null 2>"$test_root/provider.err" || {
  cat "$test_root/provider.err" >&2
  printf 'exact provider fq/bbr baseline was not classified as migratable\n' >&2
  exit 1
}
[ "$PROVIDER_SYSCTL_TRANSFER_REQUIRED" -eq 1 ] || {
  printf 'provider transfer requirement was not recorded\n' >&2
  exit 1
}
[ "$(sha256sum "$provider" | awk '{print $1}')" = "$provider_hash_before" ] || {
  printf 'read-only sysctl conflict scan modified provider file\n' >&2
  exit 1
}
grep -Fq 'preflight 保持只读' "$test_root/provider.err"
rm -f -- "$provider"

# The managed file and an alias to it are both excluded from conflict checks.
verify_settings >/dev/null 2>"$test_root/managed-only.err" || {
  cat "$test_root/managed-only.err" >&2
  printf 'verify rejected its own managed sysctl file or alias\n' >&2
  exit 1
}

# An external file with the same values is still a duplicate owner and must fail verify.
external="$SYSCTL_SCAN_ROOT/sysctl.d/99-bbr-x-ui.conf"
printf '%s\n' \
  'net.core.default_qdisc = fq' \
  'net.ipv4.tcp_congestion_control = bbr' >"$external"
external_alias="$SYSCTL_SCAN_ROOT/sysctl.d/99-bbr-x-ui-alias.conf"
ln -s "$external" "$external_alias"
if [ ! -L "$external_alias" ]; then
  rm -f "$external_alias"
fi
if verify_settings >/dev/null 2>"$test_root/conflict.err"; then
  printf 'verify accepted an external same-value sysctl owner\n' >&2
  exit 1
fi
grep -Fq '仅 /etc/sysctl.conf 中唯一且值严格为 fq/bbr' "$test_root/conflict.err"
grep -Fq 'verify 拒绝通过' "$test_root/conflict.err"
[ "$(grep -Fc 'net.core.default_qdisc 已在' "$test_root/conflict.err")" -eq 1 ] || {
  printf 'canonical sysctl alias was reported more than once\n' >&2
  exit 1
}
EOF_SYSCTL_CONFLICT_TEST
} >"$sysctl_conflict_test"
bash "$sysctl_conflict_test"

if command -v jq >/dev/null 2>&1; then
  provider_transfer_test="$tmp_dir/provider-sysctl-transfer-test.sh"
  {
    printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
    awk '/^state_get\(\)/,/^}/' "${scripts[0]}"
    awk '/^atomic_json_commit\(\)/,/^}/' "${scripts[0]}"
    awk '/^set_provider_sysctl_transfer_state\(\)/,/^}/' "${scripts[0]}"
    awk '/^transfer_provider_sysctl_ownership\(\)/,/^}/' "${scripts[0]}"
    awk '/^provider_sysctl_transfer_is_restorable\(\)/,/^}/' "${scripts[0]}"
    awk '/^restore_provider_sysctl_ownership\(\)/,/^}/' "${scripts[0]}"
    cat <<'EOF_PROVIDER_TRANSFER_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/state"
source_file="$test_root/sysctl.conf"
backup_file="$test_root/state/provider-sysctl.conf.original"
original_copy="$test_root/sysctl.conf.expected"
migrated_copy="$test_root/sysctl.conf.migrated"
STATE_FILE="$test_root/state/state.json"
printf '%s\n' \
  '# provider baseline' \
  'vm.max_map_count = 262144' \
  'net.core.default_qdisc = fq' \
  'net.ipv4.tcp_congestion_control = bbr' >"$source_file"
cp -- "$source_file" "$original_copy"
original_hash="$(sha256sum "$source_file" | awk '{print $1}')"
uid="$(id -u)"; gid="$(id -g)"; mode="$(stat -c '%a' "$source_file")"
jq -n --arg source "$source_file" --arg backup "$backup_file" --arg original_hash "$original_hash" \
  --argjson uid "$uid" --argjson gid "$gid" --arg mode "$mode" '
  {provider_sysctl_transfer:{required:true,source_path:$source,backup_path:$backup,
    original_sha256:$original_hash,backup_sha256:null,transferred_sha256:null,
    original_uid:$uid,original_gid:$gid,original_mode:$mode,
    keys:[{key:"net.core.default_qdisc",value:"fq"},{key:"net.ipv4.tcp_congestion_control",value:"bbr"}],state:"DETECTED"},
   timestamps:{last_update:"test"}}
  ' >"$STATE_FILE"

state_file_is_valid() { return 0; }
error() { printf '[x] %s\n' "$*" >&2; }
info() { :; }
chown() { :; }
install() {
  local mode_arg='0600' source_arg='' target_arg=''
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -m) mode_arg="$2"; shift 2 ;;
      -o | -g) shift 2 ;;
      *) if [ -z "$source_arg" ]; then source_arg="$1"; else target_arg="$1"; fi; shift ;;
    esac
  done
  cp -- "$source_arg" "$target_arg" && chmod "$mode_arg" "$target_arg"
}
stat() {
  if [ "${1:-}" = '-c' ] && [ "${2:-}" = '%u' ] &&
    { [ "${3:-}" = "$backup_file" ] || [ "${3##*/}" = "${backup_file##*/}" ]; }; then
    printf '0\n'
    return 0
  fi
  command stat "$@"
}

transfer_provider_sysctl_ownership
[ "$(jq -r '.provider_sysctl_transfer.state' "$STATE_FILE")" = 'TRANSFERRED' ]
cp -- "$source_file" "$migrated_copy"
! grep -Eq '^[[:space:]]*net\.(core\.default_qdisc|ipv4\.tcp_congestion_control)[[:space:]]*=' "$source_file"
cmp -s "$backup_file" "$original_copy"

printf '%s\n' '# external administrator edit' >>"$source_file"
external_hash="$(sha256sum "$source_file" | awk '{print $1}')"
if provider_sysctl_transfer_is_restorable; then
  printf 'rollback precheck accepted an externally edited provider file\n' >&2
  exit 1
fi
if restore_provider_sysctl_ownership >/dev/null 2>&1; then
  printf 'provider sysctl rollback overwrote an external edit\n' >&2
  exit 1
fi
[ "$(sha256sum "$source_file" | awk '{print $1}')" = "$external_hash" ] || {
  printf 'failed rollback changed externally edited provider file\n' >&2
  exit 1
}

cp -- "$migrated_copy" "$source_file"
provider_sysctl_transfer_is_restorable
restore_provider_sysctl_ownership
cmp -s "$source_file" "$original_copy"
[ "$(jq -r '.provider_sysctl_transfer.state' "$STATE_FILE")" = 'RESTORED' ]
EOF_PROVIDER_TRANSFER_TEST
  } >"$provider_transfer_test"
  bash "$provider_transfer_test"
fi

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
      --argjson schema 4 --arg version 'test' \
      --arg profile 'test-profile' --arg profile_label 'Test Profile' \
      --arg debian '12' --arg arch 'x86_64' --arg kernel 'test-kernel' \
      --argjson mem 960 --argjson port 1000 --argjson rtt 200 \
      --argjson buf 33554432 --arg mode 'auto' \
      --argjson target_numerator 5 --argjson target_denominator 4 \
      --arg qfile '/tmp/qdisc.json' --arg qhash 'test-hash' \
      --arg now '2026-08-01T00:00:00Z' --argjson original '{}' \
      --argjson provider_required false --arg provider_file '/etc/sysctl.conf' \
      --arg provider_backup '/var/lib/proxy-vps-tuning/provider-sysctl.conf.original' \
      --arg provider_hash '' --argjson provider_uid 0 --argjson provider_gid 0 \
      --arg provider_mode '000' --arg provider_state 'NOT_REQUIRED' --argjson provider_keys '[]' \
      "$(<"$state_filter_file")" >"$state_json_file"
    jq -e '.schema_version == 4 and .profile.label == "Test Profile" and .network.port_speed_mbps == 1000 and .network.buffer_target_numerator == 5 and .network.buffer_target_denominator == 4 and .provider_sysctl_transfer.state == "NOT_REQUIRED" and .provider_sysctl_transfer.original_uid == null and .provider_sysctl_transfer.original_gid == null and .provider_sysctl_transfer.original_mode == null' \
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

fstab_remove_test="$tmp_dir/fstab-remove-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^remove_fstab_swap_line\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_FSTAB_REMOVE_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
SWAP_FILE='/swapfile-proxy-vps-tuning'
managed_line="${SWAP_FILE} none swap sw 0 0"
fstab="$test_root/fstab"
FSTAB_FILE="$fstab"

printf '%s\n' 'UUID=root / ext4 defaults 0 1' "$managed_line" "$managed_line" '# keep' >"$fstab"
chmod 0640 "$fstab"
remove_fstab_swap_line
expected="$test_root/expected"
printf '%s\n' 'UUID=root / ext4 defaults 0 1' '# keep' >"$expected"
cmp -s "$fstab" "$expected" || { printf 'managed fstab lines were not removed exactly\n' >&2; exit 1; }
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) ;;
  *) [ "$(stat -c '%a' "$fstab")" = '640' ] || { printf 'fstab mode was not preserved\n' >&2; exit 1; } ;;
esac

printf '%s\n' 'UUID=root / ext4 defaults 0 1' "$managed_line" >"$fstab"
old_hash="$(sha256sum "$fstab" | awk '{print $1}')"
awk() { return 42; }
if remove_fstab_swap_line 2>/dev/null; then
  printf 'fstab removal accepted an awk failure\n' >&2
  exit 1
fi
unset -f awk
[ "$(sha256sum "$fstab" | awk '{print $1}')" = "$old_hash" ] || { printf 'awk failure changed fstab\n' >&2; exit 1; }

awk() { :; }
if remove_fstab_swap_line 2>/dev/null; then
  printf 'fstab removal accepted unexpected empty output\n' >&2
  exit 1
fi
unset -f awk
[ "$(sha256sum "$fstab" | awk '{print $1}')" = "$old_hash" ] || { printf 'unexpected empty output changed fstab\n' >&2; exit 1; }

mv() { return 43; }
if remove_fstab_swap_line 2>/dev/null; then
  printf 'fstab removal accepted an atomic replace failure\n' >&2
  exit 1
fi
unset -f mv
[ "$(sha256sum "$fstab" | awk '{print $1}')" = "$old_hash" ] || { printf 'replace failure changed fstab\n' >&2; exit 1; }
if compgen -G "${fstab}.proxy-vps-tuning.*" >/dev/null; then
  printf 'fstab failure left a temporary file\n' >&2
  exit 1
fi

printf '%s\n' "$managed_line" >"$fstab"
remove_fstab_swap_line
[ ! -s "$fstab" ] || { printf 'single managed fstab line was not removed\n' >&2; exit 1; }
EOF_FSTAB_REMOVE_TEST
} >"$fstab_remove_test"
bash "$fstab_remove_test"

state_validation_test="$tmp_dir/state-validation-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^state_file_is_valid\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_STATE_VALIDATION_TEST'
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    export MSYS2_ARG_CONV_EXCL='/etc/sysctl.conf;/var/lib/proxy-vps-tuning/provider-sysctl.conf.original'
    ;;
esac
STATE_FILE="$test_root/state.json"
STATE_DIR='/var/lib/proxy-vps-tuning'
SYSCTL_SCAN_ROOT='/etc'
STATE_SCHEMA_VERSION=4
LEGACY_STATE_SCHEMA_VERSION=3
SCRIPT_VERSION='0.1.0-rc.12'
PROFILE_ID='debian12-1c1g'
UPDATE_PREFLIGHT=0
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

printf '%s\n' '{"schema_version":4,"script_version":"0.1.0-rc.12","profile":{"id":"debian12-1c1g"},"state":"PREPARED","network":{},"original_sysctls":{},"qdisc":{"file":"/tmp/qdisc","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"swap":{},"provider_sysctl_transfer":{"required":false,"source_path":"/etc/sysctl.conf","backup_path":"/var/lib/proxy-vps-tuning/provider-sysctl.conf.original","original_sha256":null,"backup_sha256":null,"transferred_sha256":null,"original_uid":null,"original_gid":null,"original_mode":null,"keys":[],"state":"NOT_REQUIRED"},"managed_files":[],"timestamps":{}}' >"$STATE_FILE"
state_file_is_valid

jq '.provider_sysctl_transfer.original_uid = 0 | .provider_sysctl_transfer.original_gid = 0 | .provider_sysctl_transfer.original_mode = "000"' \
  "$STATE_FILE" >"${STATE_FILE}.placeholder"
mv -- "${STATE_FILE}.placeholder" "$STATE_FILE"
state_file_is_valid

jq '.provider_sysctl_transfer.original_mode = "0644"' \
  "$STATE_FILE" >"${STATE_FILE}.placeholder"
mv -- "${STATE_FILE}.placeholder" "$STATE_FILE"
if state_file_is_valid; then
  printf 'state validator accepted inconsistent ownership for absent provider sysctl\n' >&2
  exit 1
fi

printf '%s\n' '{"schema_version":3,"script_version":"0.1.0-rc.11","profile":{"id":"debian12-1c1g"},"state":"VERIFIED","network":{},"original_sysctls":{},"qdisc":{"file":"/tmp/qdisc","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"swap":{},"managed_files":[],"timestamps":{}}' >"$STATE_FILE"
if state_file_is_valid; then
  printf 'state validator accepted legacy schema outside update-preflight\n' >&2
  exit 1
fi
UPDATE_PREFLIGHT=1
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

nofile_pending_test="$tmp_dir/nofile-pending-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail' 'IFS=$'\''\n\t'\'''
  awk '/^profile_service_units\(\)/,/^}/' "${scripts[0]}"
  awk '/^read_nofile_limits\(\)/,/^}/' "${scripts[0]}"
  awk '/^verify_proxy_services\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_NOFILE_PENDING_TEST'
DEFAULT_PROXY_SERVICE_UNITS=(x-ui.service)
PROXY_SERVICE_UNITS_INPUT=''
REQUIRE_PROXY_SERVICE=0
XUI_NOFILE_LIMIT=65536
EXIT_USAGE=2
OUTPUT=''
systemctl() { printf '%s\n' 'not-found'; }
info() { OUTPUT="${OUTPUT}$*"; }
warn() { printf 'unexpected warning: %s\n' "$*" >&2; exit 1; }
error() { :; }
die() { exit "$1"; }
verify_proxy_services
case "$OUTPUT" in *'LimitNOFILE drop-in 已预置'*) : ;; *) printf 'pre-install NOFILE state was not reported as pending\n' >&2; exit 1 ;; esac
REQUIRE_PROXY_SERVICE=1
if verify_proxy_services; then
  printf 'strict verification accepted a missing proxy service\n' >&2
  exit 1
fi
EOF_NOFILE_PENDING_TEST
} >"$nofile_pending_test"
bash "$nofile_pending_test"

nofile_active_test="$tmp_dir/nofile-active-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail' 'IFS=$'\''\n\t'\'''
  awk '/^read_nofile_limits\(\)/,/^}/' "${scripts[0]}"
  awk '/^verify_runtime_nofile\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_NOFILE_ACTIVE_TEST'
XUI_NOFILE_LIMIT=65536
warn() { :; }
error() { :; }
limits_file="$(mktemp)"
trap 'rm -f -- "$limits_file"' EXIT
printf '%s\n' 'Max open files            1024                 65536                 files' >"$limits_file"
if verify_runtime_nofile x-ui.service MainPID "$limits_file" 1 >/dev/null; then
  printf 'strict verification accepted x-ui runtime NOFILE soft=1024\n' >&2
  exit 1
fi
printf '%s\n' 'Max open files            65536                1024                  files' >"$limits_file"
if verify_runtime_nofile x-ui.service MainPID "$limits_file" 1 >/dev/null; then
  printf 'strict verification accepted x-ui runtime NOFILE hard=1024\n' >&2
  exit 1
fi
printf '%s\n' 'Max open files            65536                65536                 files' >"$limits_file"
verify_runtime_nofile x-ui.service MainPID "$limits_file" 1 >/dev/null
EOF_NOFILE_ACTIVE_TEST
} >"$nofile_active_test"
bash "$nofile_active_test"

preflight_state_test="$tmp_dir/preflight-state-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^check_preflight_state\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_PREFLIGHT_STATE_TEST'
EXIT_CONFLICT=4
STATE_PRESENT=0
PHASE=''
UPDATE_PREFLIGHT=0
state_exists() { [ "$STATE_PRESENT" -eq 1 ]; }
state_get() { printf '%s\n' "$PHASE"; }
info() { :; }
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
UPDATE_PREFLIGHT=1
for PHASE in VERIFIED APPLIED; do
  check_preflight_state >/dev/null 2>&1 || {
    printf 'update-preflight rejected valid installed state %s\n' "$PHASE" >&2
    exit 1
  }
done
for PHASE in SWAP_RETAINED DEGRADED ROLLBACK_PENDING; do
  set +e
  (check_preflight_state >/dev/null 2>&1)
  rc=$?
  set -e
  [ "$rc" -eq "$EXIT_CONFLICT" ] || {
    printf 'update-preflight accepted unsafe state %s (exit=%s)\n' "$PHASE" "$rc" >&2
    exit 1
  }
done
EOF_PREFLIGHT_STATE_TEST
} >"$preflight_state_test"
bash "$preflight_state_test"

pfifo_fast_test="$tmp_dir/pfifo-fast-test.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  awk '/^is_conventional_pfifo_fast_snapshot\(\)/,/^}/' "${scripts[0]}"
  cat <<'EOF_PFIFO_FAST_TEST'
default_snapshot='{"interface":"eth0","qdiscs":[{"kind":"pfifo_fast","handle":"0:","root":true,"options":{"bands":3,"multiqueue":false,"priomap":[1,2,2,2,1,2,0,0,1,1,1,1,1,1,1,1]}}]}'
is_conventional_pfifo_fast_snapshot "$default_snapshot" || {
  printf 'conventional pfifo_fast snapshot was rejected\n' >&2
  exit 1
}
for invalid in \
  '{"interface":"eth0","qdiscs":[{"kind":"pfifo_fast","root":true,"options":{"bands":4}}]}' \
  '{"interface":"eth0","qdiscs":[{"kind":"pfifo_fast","root":true,"options":{}},{"kind":"ingress","parent":"ffff:fff1"}]}' \
  '{"interface":"eth0","qdiscs":[{"kind":"pfifo_fast","root":true,"options":{"custom":1}}]}'; do
  if is_conventional_pfifo_fast_snapshot "$invalid"; then
    printf 'non-conventional pfifo_fast snapshot was accepted: %s\n' "$invalid" >&2
    exit 1
  fi
done
EOF_PFIFO_FAST_TEST
} >"$pfifo_fast_test"
bash "$pfifo_fast_test"

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
    pfifo_match) printf '%s\n' '[{"dev":"eth0","kind":"pfifo_fast","handle":"8002:","root":true,"refcnt":2,"options":{"bands":3,"multiqueue":false,"priomap":[1,2,2,2,1,2,0,0,1,1,1,1,1,1,1,1]}}]' ;;
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

printf '%s\n' '[{"interface":"eth0","qdiscs":[{"dev":"eth0","kind":"pfifo_fast","handle":"0:","root":true,"refcnt":2,"options":{"bands":3,"multiqueue":false,"priomap":[1,2,2,2,1,2,0,0,1,1,1,1,1,1,1,1]}}]}]' >"$QDISC_STATE_FILE"
fixture_hash="$(sha256sum "$QDISC_STATE_FILE" | awk '{print $1}')"
TC_VARIANT='pfifo_match'
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
XUI_DROPIN_DIR="$test_root/x-ui.service.d"
XUI_DROPIN="$XUI_DROPIN_DIR/90-proxy-vps.conf"
mkdir "$XUI_DROPIN_DIR"
: >"$XUI_DROPIN"
QDISC_STATE_FILE="$STATE_DIR/qdisc-original.json"
SWAP_FILE="$test_root/swap"
PURGE_CREATED_SWAP=0
QDISC_MATCH_REASON='restored options differ'
PHASES=''
validate_state_file() { return 0; }
state_get() { [ "$1" = '.state' ] && printf '%s\n' 'VERIFIED'; }
state_set_phase() { PHASES="${PHASES} $1"; }
assert_owned_file() { :; }
provider_sysctl_transfer_is_restorable() { return 0; }
restore_provider_sysctl_ownership() { return 0; }
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
[ ! -e "$XUI_DROPIN" ] && [ ! -d "$XUI_DROPIN_DIR" ] || {
  printf 'rollback did not remove the managed x-ui drop-in and empty directory\n' >&2
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
  shellcheck -x "${scripts[@]}" "$controller" "$tcpquality_tool" "$installer" "$probe_tool" "$htb_wrapper" \
    experiments/htb-aggregate/experiment-plan.sh \
    experiments/htb-aggregate/htb-aggregate-experiment.sh \
    experiments/htb-aggregate/rate-sweep-plan.sh \
    experiments/htb-aggregate/rate-sweep-run.sh \
    experiments/htb-aggregate/rate-sweep-analyze.sh \
    tests/static-check.sh tests/controller-check.sh tests/installer-check.sh
  for helper in "$tmp_dir"/*.helper; do shellcheck -x "$helper"; done
else
  printf '[WARN] shellcheck not found; syntax and structural checks only\n' >&2
fi

printf 'static checks passed for %s scripts\n' "${#scripts[@]}"
