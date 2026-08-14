#!/usr/bin/env bash

# Explicit TcpQuality evidence harness. This wrapper contains no host tuning,
# package-manager or service mutations and never overwrites an evidence set;
# the pinned upstream --all workload still performs its documented network I/O.

set -Eeuo pipefail
IFS=$'\n\t'
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
umask 077

TOOL_VERSION='0.1.0-rc.12'
SUPPORTED_COMMIT='5d1f85a6b8916b73ec0389dbc9b4ed4aa27dae01'
SUPPORTED_RUN_SHA256='e374bdcb3dceab0164d42443b0cf5b006ecc8e5bbcb5ee348f216bb6f8ccbfc3'
SUPPORTED_ROOTFS_RUNNER_SHA256='89944d708abaa55c0ef1833e1de49627da932f810848cb3aa73493bfee03e207'
SUPPORTED_CORE_SHA256='4f611c8419c5b6ca23d36c102b4e20bac80f51e751c6fc9ebb7220cc30416f06'
SUPPORTED_ROOTFS_SHA256='db92956873d674e65a573721ec6a3db4995f7cf648f61954380e0bfa53ce71a1'
GET_NODES_URL="${TCPQUALITY_GET_NODES_URL:-https://tcpquality.ibsgss.uk/getNodes}"
PIN_DIR="${TCPQUALITY_PIN_DIR:-}"
EVIDENCE_DIR="${TCPQUALITY_EVIDENCE_DIR:-}"
COMMIT="${TCPQUALITY_COMMIT:-}"
ROOTFS_SHA256="${TCPQUALITY_ROOTFS_SHA256:-}"
RUNS="${TCPQUALITY_RUNS:-3}"
DELAY_SECONDS="${TCPQUALITY_DELAY_SECONDS:-60}"
COUNT="${TCPQUALITY_COUNT:-30}"
PACKET_SIZE="${TCPQUALITY_PACKET_SIZE:-0}"
PARALLEL="${TCPQUALITY_PARALLEL:-16}"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少必要命令：$1"
}

validate_integer() {
  local name="$1" value="$2" minimum="$3" maximum="$4"
  [[ "$value" =~ ^[0-9]+$ ]] || fail "${name} 必须是整数。"
  value=$((10#$value))
  [ "$value" -ge "$minimum" ] && [ "$value" -le "$maximum" ] ||
    fail "${name} 必须在 ${minimum}–${maximum} 之间。"
}

write_incomplete_marker() {
  local signal="$1"
  if [ -n "$EVIDENCE_DIR" ] && [ -d "$EVIDENCE_DIR" ]; then
    printf 'status=INCOMPLETE\nsignal=%s\nutc=%s\n' \
      "$signal" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"${EVIDENCE_DIR}/INCOMPLETE"
  fi
}

snapshot_nodes() {
  local scope="$1" output="$2"
  local tmp="${output}.tmp"
  curl -4 --fail --silent --show-error --location \
    --proto '=https' --proto-redir '=https' \
    --connect-timeout 5 --max-time 30 \
    "${GET_NODES_URL}?format=tsv&scope=${scope}" >"$tmp" || { rm -f -- "$tmp"; return 1; }
  awk -F '\t' -v expected_scope="$scope" '
    NR == 1 {
      expected="type\tfamily\tprovince\tisp\thost\tip\tport\ttarget\tbackup_host\tbackup_ip\tbackup_port\tbackup_target"
      if ($0 != expected || NF != 12) exit 50
      next
    }
    {
      if (NF != 12 || $1 == "" || $2 !~ /^[46]$/ || $5 == "" || $6 == "" || $7 !~ /^[0-9]+$/) exit 51
      if (expected_scope == "tos" && $1 != "tos") exit 52
      rows++
    }
    END {if (rows == 0) exit 53}
  ' "$tmp" || { rm -f -- "$tmp"; return 1; }
  chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$output" || { rm -f -- "$tmp"; return 1; }
}

record_node_snapshot() {
  local run="$1" scope="$2" phase="$3" file="$4" hash
  hash="$(sha256sum "$file" | awk '{print $1}')" || return 1
  printf '%s\t%s\t%s\t%s\t%s\n' "$run" "$scope" "$phase" "${file##*/}" "$hash" \
    >>"${EVIDENCE_DIR}/node-inventory.tsv" || return 1
}

logical_node_keys() {
  local source="$1"
  awk -F '\t' '
    NR == 1 {
      for (i=1; i<=NF; i++) keep[i]=($i != "ip" && $i != "backup_ip")
      next
    }
    {
      key=""
      for (i=1; i<=NF; i++) if (keep[i]) key=key (key == "" ? "" : "\t") $i
      print key
    }
  ' "$source" | LC_ALL=C sort -u
}

node_ip_change_count() {
  local before="$1" after="$2"
  awk -F '\t' '
    NR == FNR {
      if (FNR == 1) {
        for (i=1; i<=NF; i++) {
          keep_before[i]=($i != "ip" && $i != "backup_ip")
          if ($i == "ip") ip_before=i
          if ($i == "backup_ip") backup_before=i
        }
        next
      }
      key=""
      for (i=1; i<=NF; i++) if (keep_before[i]) key=key (key == "" ? "" : "\t") $i
      address_before[key]=$(ip_before) "|" $(backup_before)
      next
    }
    FNR == 1 {
      for (i=1; i<=NF; i++) {
        keep_after[i]=($i != "ip" && $i != "backup_ip")
        if ($i == "ip") ip_after=i
        if ($i == "backup_ip") backup_after=i
      }
      next
    }
    {
      key=""
      for (i=1; i<=NF; i++) if (keep_after[i]) key=key (key == "" ? "" : "\t") $i
      if (key in address_before && address_before[key] != $(ip_after) "|" $(backup_after)) changed++
    }
    END {print changed+0}
  ' "$before" "$after"
}

record_node_drift() {
  local run="$1" scope="$2" before="$3" after="$4"
  local before_keys="${EVIDENCE_DIR}/.nodes-${scope}-r${run}-before.keys"
  local after_keys="${EVIDENCE_DIR}/.nodes-${scope}-r${run}-after.keys"
  local removed added ip_changed exact_equal=0
  logical_node_keys "$before" >"$before_keys" || return 1
  logical_node_keys "$after" >"$after_keys" || return 1
  removed="$(comm -23 "$before_keys" "$after_keys" | wc -l)" || return 1
  added="$(comm -13 "$before_keys" "$after_keys" | wc -l)" || return 1
  ip_changed="$(node_ip_change_count "$before" "$after")" || return 1
  cmp -s "$before" "$after" && exact_equal=1
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$run" "$scope" "$(( $(wc -l <"$before") - 1 ))" "$(( $(wc -l <"$after") - 1 ))" \
    "$removed" "$added" "$ip_changed" "$exact_equal" >>"${EVIDENCE_DIR}/node-drift.tsv" || return 1
  rm -f -- "$before_keys" "$after_keys" || return 1
}

capture_host_state() {
  local phase="$1"
  printf '== %s host state ==\n' "$phase"
  printf 'utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'boot_id=%s\n' "$(awk 'NR == 1 {print; exit}' /proc/sys/kernel/random/boot_id 2>/dev/null || true)"
  uname -a || return 1
  uptime || return 1
  free -h || return 1
  sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc net.ipv4.tcp_rmem net.ipv4.tcp_wmem || return 1
  ip -s -s link show || return 1
  tc -s -d qdisc show || return 1
  nstat -az || return 1
  swapon --show --bytes || return 1
}

find_csv_inventory() {
  find "$EVIDENCE_DIR" -maxdepth 1 -type f -name 'zstatic_nping_*.csv' -printf '%f\n' | LC_ALL=C sort
}

run_one() {
  local run="$1" log
  log="${EVIDENCE_DIR}/tcpquality-r${run}.log"
  local all_before="${EVIDENCE_DIR}/nodes-all-r${run}-before.tsv"
  local tos_before="${EVIDENCE_DIR}/nodes-tos-r${run}-before.tsv"
  local all_after="${EVIDENCE_DIR}/nodes-all-r${run}-after.tsv"
  local tos_after="${EVIDENCE_DIR}/nodes-tos-r${run}-after.tsv"
  local csv_before="${EVIDENCE_DIR}/.csv-r${run}-before" csv_after="${EVIDENCE_DIR}/.csv-r${run}-after"
  local new_csv csv_hash rc=0

  find_csv_inventory >"$csv_before" || return 1
  {
    printf 'tool_version=%s\nrun=%s\nutc_start=%s\n' "$TOOL_VERSION" "$run" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'tcpquality_commit=%s\nargs=-c %s -s %s -p %s --all\n' "$COMMIT" "$COUNT" "$PACKET_SIZE" "$PARALLEL"
    printf '\n== pinned assets ==\n'
    (cd "$PIN_DIR" && sha256sum -c SHA256SUMS) || return 1
    printf '\n== node snapshots before ==\n'
    snapshot_nodes all "$all_before" || return 1
    snapshot_nodes tos "$tos_before" || return 1
    sha256sum "$all_before" "$tos_before" || return 1
    record_node_snapshot "$run" all before "$all_before" || return 1
    record_node_snapshot "$run" tos before "$tos_before" || return 1
    printf '\n'
    capture_host_state pre-run || return 1
    printf '\n== TcpQuality output ==\n'
    set +e
    env TERM=xterm \
      TCPQUALITY_RAW_BASE="https://raw.githubusercontent.com/ibsgss/TcpQuality/${COMMIT}" \
      TCPQUALITY_ROOTFS_URL="file://${PIN_DIR}/tcpquality-rootfs-amd64.tar.gz" \
      TCPQUALITY_ROOTFS_SHA256="$ROOTFS_SHA256" \
      TCPQUALITY_OUTPUT_DIR="$EVIDENCE_DIR" \
      GET_NODES_URL="$GET_NODES_URL" \
      bash "${PIN_DIR}/runTcpQuality.sh" -c "$COUNT" -s "$PACKET_SIZE" -p "$PARALLEL" --all
    rc=$?
    set -e
    printf 'tcpquality_exit=%s\n' "$rc"
    printf '\n== node snapshots after ==\n'
    snapshot_nodes all "$all_after" || rc=1
    snapshot_nodes tos "$tos_after" || rc=1
    if [ -s "$all_after" ] && [ -s "$tos_after" ]; then
      sha256sum "$all_after" "$tos_after" || rc=1
      record_node_snapshot "$run" all after "$all_after" || rc=1
      record_node_snapshot "$run" tos after "$tos_after" || rc=1
    else
      rc=1
    fi
    printf '\n'
    capture_host_state post-run || rc=1
    printf 'utc_end=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } >"$log" 2>&1

  find_csv_inventory >"$csv_after" || return 1
  new_csv="$(comm -13 "$csv_before" "$csv_after")" || return 1
  rm -f -- "$csv_before" "$csv_after"
  [ "$rc" -eq 0 ] || return "$rc"
  [ "$(printf '%s\n' "$new_csv" | sed '/^$/d' | wc -l)" -eq 1 ] || {
    printf '[FAIL] run %s 未产生且仅产生一个新 CSV。\n' "$run" >>"$log"
    return 1
  }
  [ -s "${EVIDENCE_DIR}/${new_csv}" ] || return 1
  csv_hash="$(sha256sum "${EVIDENCE_DIR}/${new_csv}" | awk '{print $1}')" || return 1
  printf '%s  %s\n' "$csv_hash" "${EVIDENCE_DIR}/${new_csv}" >>"$log" || return 1
  printf '%s\t%s\t%s\n' "$run" "$new_csv" "$csv_hash" \
    >>"${EVIDENCE_DIR}/csv-inventory.tsv" || return 1
  record_node_drift "$run" all "$all_before" "$all_after" || return 1
  record_node_drift "$run" tos "$tos_before" "$tos_after" || return 1
}

finalize_manifest() {
  (
    cd "$EVIDENCE_DIR" || return 1
    : >SHA256SUMS.tmp || return 1
    while IFS= read -r -d '' file; do
      sha256sum "${file#./}" >>SHA256SUMS.tmp || return 1
    done < <(find . -maxdepth 1 -type f \
      ! -name SHA256SUMS ! -name SHA256SUMS.tmp \
      ! -name INCOMPLETE ! -name COMPLETED ! -name COMPLETED.tmp -print0 | sort -z)
    [ -s SHA256SUMS.tmp ] || return 1
    chmod 0600 SHA256SUMS.tmp || return 1
    mv -f SHA256SUMS.tmp SHA256SUMS || return 1
    sha256sum -c SHA256SUMS || return 1
  )
}

main() {
  local run successful=0 run_rc=0 manifest_sha
  [ "$(id -u)" -eq 0 ] || fail '必须以 root 运行。'
  for command in awk bash chmod cmp comm curl date dirname find free grep id ip mv nstat sed sha256sum sleep sort swapon sysctl tc uptime wc; do
    need_command "$command"
  done
  [[ "$COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail 'TCPQUALITY_COMMIT 必须是 40 位小写十六进制 commit。'
  [[ "$ROOTFS_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail 'TCPQUALITY_ROOTFS_SHA256 必须是 64 位小写十六进制 SHA256。'
  [ "$COMMIT" = "$SUPPORTED_COMMIT" ] || fail "本版工具只接受已审计 commit：${SUPPORTED_COMMIT}。"
  [ "$ROOTFS_SHA256" = "$SUPPORTED_ROOTFS_SHA256" ] || fail 'rootfs SHA256 不属于本版已审计依赖。'
  [ -n "$PIN_DIR" ] && [[ "$PIN_DIR" = /* ]] || fail 'TCPQUALITY_PIN_DIR 必须是绝对路径。'
  [ -d "$PIN_DIR" ] && [ ! -L "$PIN_DIR" ] || fail 'TCPQUALITY_PIN_DIR 不存在或是符号链接。'
  [ -n "$EVIDENCE_DIR" ] && [[ "$EVIDENCE_DIR" = /* ]] || fail 'TCPQUALITY_EVIDENCE_DIR 必须是绝对路径。'
  [ ! -e "$EVIDENCE_DIR" ] && [ ! -L "$EVIDENCE_DIR" ] || fail '证据目录已经存在，拒绝覆盖。'
  [ -d "$(dirname "$EVIDENCE_DIR")" ] || fail '证据目录的父目录不存在。'
  validate_integer TCPQUALITY_RUNS "$RUNS" 1 10
  validate_integer TCPQUALITY_DELAY_SECONDS "$DELAY_SECONDS" 0 3600
  validate_integer TCPQUALITY_COUNT "$COUNT" 1 600
  validate_integer TCPQUALITY_PACKET_SIZE "$PACKET_SIZE" 0 65535
  validate_integer TCPQUALITY_PARALLEL "$PARALLEL" 1 31
  [[ "$GET_NODES_URL" =~ ^https://[A-Za-z0-9._:-]+(/[A-Za-z0-9._~:/%+-]*)?$ ]] ||
    fail 'TCPQUALITY_GET_NODES_URL 必须是不含查询参数、片段、userinfo 或空白的 HTTPS URL。'
  RUNS=$((10#$RUNS))
  DELAY_SECONDS=$((10#$DELAY_SECONDS))
  COUNT=$((10#$COUNT))
  PACKET_SIZE=$((10#$PACKET_SIZE))
  PARALLEL=$((10#$PARALLEL))
  [ -f "${PIN_DIR}/SHA256SUMS" ] || fail '固定目录缺少 SHA256SUMS。'
  [ -f "${PIN_DIR}/PINNED-METADATA.txt" ] || fail '固定目录缺少 PINNED-METADATA.txt。'
  [ -x "${PIN_DIR}/runTcpQuality.sh" ] || fail '固定目录缺少可执行 runTcpQuality.sh。'
  [ -x "${PIN_DIR}/runTcpQuality-rootfs.sh" ] || fail '固定目录缺少可执行 runTcpQuality-rootfs.sh。'
  [ -x "${PIN_DIR}/runTcpQuality-core.sh" ] || fail '固定目录缺少可执行 runTcpQuality-core.sh。'
  [ -f "${PIN_DIR}/tcpquality-rootfs-amd64.tar.gz" ] || fail '固定目录缺少 rootfs。'
  grep -Fqx "tcpquality_commit=${COMMIT}" "${PIN_DIR}/PINNED-METADATA.txt" ||
    fail 'PINNED-METADATA.txt 中的 commit 与 TCPQUALITY_COMMIT 不一致。'
  printf '%s  %s\n' \
    "$SUPPORTED_RUN_SHA256" "${PIN_DIR}/runTcpQuality.sh" \
    "$SUPPORTED_ROOTFS_RUNNER_SHA256" "${PIN_DIR}/runTcpQuality-rootfs.sh" \
    "$SUPPORTED_CORE_SHA256" "${PIN_DIR}/runTcpQuality-core.sh" \
    "$SUPPORTED_ROOTFS_SHA256" "${PIN_DIR}/tcpquality-rootfs-amd64.tar.gz" |
    sha256sum -c -
  (cd "$PIN_DIR" && sha256sum -c SHA256SUMS)

  mkdir -m 0700 -- "$EVIDENCE_DIR"
  printf 'status=INCOMPLETE\nstage=initialization\nutc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"${EVIDENCE_DIR}/INCOMPLETE"
  trap 'write_incomplete_marker ERR' ERR
  trap 'write_incomplete_marker INT; exit 130' INT
  trap 'write_incomplete_marker TERM; exit 143' TERM
  printf 'run\tcsv\tsha256\n' >"${EVIDENCE_DIR}/csv-inventory.tsv"
  printf 'run\tscope\tphase\tfile\tsha256\n' >"${EVIDENCE_DIR}/node-inventory.tsv"
  printf 'run\tscope\tbefore_rows\tafter_rows\tlogical_removed\tlogical_added\tip_changed\texact_equal\n' >"${EVIDENCE_DIR}/node-drift.tsv"
  {
    printf 'tool_version=%s\nutc_start=%s\n' "$TOOL_VERSION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'tcpquality_commit=%s\nrootfs_sha256=%s\nget_nodes_url=%s\nruns=%s\ndelay_seconds=%s\n' "$COMMIT" "$ROOTFS_SHA256" "$GET_NODES_URL" "$RUNS" "$DELAY_SECONDS"
    printf 'args=-c %s -s %s -p %s --all\n' "$COUNT" "$PACKET_SIZE" "$PARALLEL"
  } >"${EVIDENCE_DIR}/summary.txt"

  for ((run=1; run<=RUNS; run++)); do
    printf '[INFO] starting run %s/%s\n' "$run" "$RUNS"
    set +e
    (set -Eeuo pipefail; run_one "$run")
    run_rc=$?
    set -e
    if [ "$run_rc" -eq 0 ]; then
      successful=$((successful + 1))
    else
      printf 'successful_runs=%s\nbatch_result=FAIL\nfailed_run=%s\n' "$successful" "$run" >>"${EVIDENCE_DIR}/summary.txt"
      printf 'status=INCOMPLETE\nstage=run-%s\nexit_code=%s\nutc=%s\n' "$run" "$run_rc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"${EVIDENCE_DIR}/INCOMPLETE"
      finalize_manifest || true
      trap - ERR INT TERM
      fail "TcpQuality run ${run} 失败；保留证据目录并停止。"
    fi
    if [ "$run" -lt "$RUNS" ] && [ "$DELAY_SECONDS" -gt 0 ]; then
      sleep "$DELAY_SECONDS"
    fi
  done
  printf 'successful_runs=%s\nutc_end=%s\nbatch_result=PASS\n' \
    "$successful" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"${EVIDENCE_DIR}/summary.txt"
  if ! finalize_manifest; then
    printf 'manifest_result=FAIL\n' >>"${EVIDENCE_DIR}/summary.txt" 2>/dev/null || true
    printf 'status=INCOMPLETE\nstage=manifest\nutc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"${EVIDENCE_DIR}/INCOMPLETE" 2>/dev/null || true
    trap - ERR INT TERM
    fail '最终证据清单生成或校验失败。'
  fi
  manifest_sha="$(sha256sum "${EVIDENCE_DIR}/SHA256SUMS" | awk '{print $1}')" || fail '无法计算最终证据清单哈希。'
  printf 'status=COMPLETED\nevidence_manifest_sha256=%s\nutc=%s\n' \
    "$manifest_sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"${EVIDENCE_DIR}/COMPLETED.tmp" || fail '无法生成完成标记。'
  chmod 0600 "${EVIDENCE_DIR}/COMPLETED.tmp" || fail '无法设置完成标记权限。'
  mv -f "${EVIDENCE_DIR}/COMPLETED.tmp" "${EVIDENCE_DIR}/COMPLETED" || fail '无法提交完成标记。'
  rm -f "${EVIDENCE_DIR}/INCOMPLETE" || { rm -f "${EVIDENCE_DIR}/COMPLETED"; fail '无法移除未完成标记。'; }
  trap - ERR INT TERM
  printf '[PASS] evidence_dir=%s successful_runs=%s\n' "$EVIDENCE_DIR" "$successful"
}

main "$@"
