#!/usr/bin/env bash
# Narrow wrapper around the existing non-persistent HTB experiment bundle.

set -Eeuo pipefail
IFS=$'\n\t'
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH

bundle_dir=''
tuning_script=''
htb_tool=''
budget_tool=''
HTB_INSTALL_PATH='/usr/local/sbin/htb-aggregate-experiment'
command_name=''
host=''
port=5201
output_dir=''
reference_evidence=''
rates='180,190,195'
samples=3
cooldown=300
seconds=10
omit=3
parallel=1
family=4
minimum_rate_exposure_percent=90
minimum_cpu_idle_percent=5
maximum_cpu_steal_percent=5
ledger=''
window_id=''
budget_mib=''
ack_reference_reviewed=0
declare -a pass_args=()

die() { printf '[dvt-htb][FAIL] %s\n' "$*" >&2; exit 2; }
info() { printf '[dvt-htb] %s\n' "$*"; }

usage() {
  cat <<'EOF'
Usage:
  dvt htb preflight
  dvt htb smoke [--rate 190] [--hold-seconds 10]
  dvt htb status
  dvt htb stop
  dvt htb reference --host AUTHORIZED_IPERF3_HOST --output-dir /absolute/new/path [scan options]
  dvt htb sweep --host AUTHORIZED_IPERF3_HOST --output-dir /absolute/new/path
                --reference-evidence /absolute/reference/path
                --ack-reference-reviewed [scan options]
  dvt htb analyze /absolute/evidence/path
  dvt htb plan [rate-sweep-plan options]
  dvt htb aba-plan [experiment-plan options]

Scan options:
  --server-port PORT --rates 180,190,195 --samples 2..5
  --cooldown-seconds 300..3600 --seconds 5..120 --omit 0..10
  --parallel 1..4 --family auto|4|6
  --minimum-rate-exposure-percent 90..100
  --minimum-cpu-idle-percent 0..100 --maximum-cpu-steal-percent 0..100
  --ledger /absolute/path --window-id ID --budget-mib MIB

Boundary: this wrapper supports only the existing Debian 13 rc.15, eth0,
200 Mbps, 1C1G/1C2G experiment contract. It never creates persistent HTB and
never converts a shortlist into a production recommendation. reference/sweep
temporarily replace root fq, produce deliberate traffic, and restore fq after
each stage. State-changing commands require a root-owned, non-symlink executor
at /usr/local/sbin/htb-aggregate-experiment whose SHA-256 matches this Release;
the read-only wrapper never installs it implicitly. Use only an iperf3 endpoint
you control or may explicitly use.
EOF
}

require_asset() {
  local file="$1"
  [ -f "$file" ] && [ ! -L "$file" ] || die "缺少实验资产：${file}"
}

bind_stable_htb_tool() {
  local require_bundle_match="${1:-1}" uid mode mode_decimal installed_sha bundle_sha command
  for command in awk bash sha256sum stat; do
    command -v "$command" >/dev/null 2>&1 || die "缺少命令：${command}"
  done
  [ -f "$HTB_INSTALL_PATH" ] && [ ! -L "$HTB_INSTALL_PATH" ] ||
    die "缺少稳定 HTB 执行器：${HTB_INSTALL_PATH}；先按当前 SOP 显式安装并校验。"
  uid="$(stat -c '%u' "$HTB_INSTALL_PATH")"
  mode="$(stat -c '%a' "$HTB_INSTALL_PATH")"
  [ "$uid" = '0' ] || die "HTB 执行器必须由 root 所有：${HTB_INSTALL_PATH}"
  mode_decimal=$((8#$mode))
  [ $((mode_decimal & 0022)) -eq 0 ] ||
    die "HTB 执行器不能被 group/world 写入：${HTB_INSTALL_PATH}"
  bash -n "$HTB_INSTALL_PATH" || die '稳定 HTB 执行器未通过 Bash 语法检查。'
  if [ "$require_bundle_match" -eq 1 ]; then
    installed_sha="$(sha256sum "$HTB_INSTALL_PATH" | awk '{print $1}')"
    bundle_sha="$(sha256sum "$bundle_dir/htb-aggregate-experiment.sh" | awk '{print $1}')"
    [ "$installed_sha" = "$bundle_sha" ] ||
      die '稳定 HTB 执行器与当前 Release 资产 SHA-256 不一致；无活动实验时重新安装当前资产。'
  fi
  htb_tool="$HTB_INSTALL_PATH"
}

parse_common() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --bundle-dir) [ "$#" -ge 2 ] || die '--bundle-dir 缺少参数。'; bundle_dir="$2"; shift 2 ;;
      --tuning-script) [ "$#" -ge 2 ] || die '--tuning-script 缺少参数。'; tuning_script="$2"; shift 2 ;;
      --budget-tool) [ "$#" -ge 2 ] || die '--budget-tool 缺少参数。'; budget_tool="$2"; shift 2 ;;
      preflight | smoke | smoke-test | status | stop | reference | sweep | analyze | plan | aba-plan)
        command_name="$1"; shift; pass_args=("$@"); break ;;
      -h | --help | help) usage; exit 0 ;;
      *) die "未知命令：$1" ;;
    esac
  done
}

parse_scan_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --host) [ "$#" -ge 2 ] || die '--host 缺少参数。'; host="$2"; shift 2 ;;
      --server-port | --port) [ "$#" -ge 2 ] || die '--server-port 缺少参数。'; port="$2"; shift 2 ;;
      --output-dir) [ "$#" -ge 2 ] || die '--output-dir 缺少参数。'; output_dir="$2"; shift 2 ;;
      --reference-evidence) [ "$#" -ge 2 ] || die '--reference-evidence 缺少参数。'; reference_evidence="$2"; shift 2 ;;
      --ledger) [ "$#" -ge 2 ] || die '--ledger 缺少参数。'; ledger="$2"; shift 2 ;;
      --window-id) [ "$#" -ge 2 ] || die '--window-id 缺少参数。'; window_id="$2"; shift 2 ;;
      --budget-mib) [ "$#" -ge 2 ] || die '--budget-mib 缺少参数。'; budget_mib="$2"; shift 2 ;;
      --ack-reference-reviewed) ack_reference_reviewed=1; shift ;;
      --rates) [ "$#" -ge 2 ] || die '--rates 缺少参数。'; rates="$2"; shift 2 ;;
      --samples) [ "$#" -ge 2 ] || die '--samples 缺少参数。'; samples="$2"; shift 2 ;;
      --cooldown-seconds) [ "$#" -ge 2 ] || die '--cooldown-seconds 缺少参数。'; cooldown="$2"; shift 2 ;;
      --seconds) [ "$#" -ge 2 ] || die '--seconds 缺少参数。'; seconds="$2"; shift 2 ;;
      --omit) [ "$#" -ge 2 ] || die '--omit 缺少参数。'; omit="$2"; shift 2 ;;
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
      *) die "未知扫描参数：$1" ;;
    esac
  done
}

run_scan() {
  local mode="$1" temp_dir plan_file run_rc=0
  local reference_manifest_sha256='' reference_analysis_sha256=''
  local reference_completed_sha256=''
  local command
  for command in grep jq mktemp rm sha256sum; do
    command -v "$command" >/dev/null 2>&1 || die "缺少命令：${command}"
  done
  parse_scan_args "${pass_args[@]}"
  [ -n "$host" ] && [ -n "$output_dir" ] || die "${mode} 必须指定 --host 和 --output-dir。"
  [ -n "$budget_tool" ] && [ -n "$ledger" ] && [ -n "$window_id" ] && [ -n "$budget_mib" ] ||
    die "${mode} 必须指定 --ledger、--window-id 和 --budget-mib，并通过总控绑定预算工具。"
  [[ "$budget_mib" =~ ^[0-9]+$ ]] && [ "$((10#$budget_mib))" -ge 1 ] || die '--budget-mib 必须是正整数。'
  [[ "$host" =~ ^[A-Za-z0-9][A-Za-z0-9._:%-]*$ ]] || die 'host 含不支持的字符。'
  if [ "$mode" = candidate-sweep ]; then
    [ "$ack_reference_reviewed" -eq 1 ] || die 'sweep 必须显式添加 --ack-reference-reviewed。'
    [ -n "$reference_evidence" ] && [ -d "$reference_evidence" ] || die 'sweep 必须指定有效的 --reference-evidence。'
    [ -f "${reference_evidence}/COMPLETED" ] && [ ! -e "${reference_evidence}/INCOMPLETE" ] ||
      die 'reference evidence 不是 COMPLETED 终态。'
    (cd "$reference_evidence" && sha256sum -c SHA256SUMS >/dev/null) || die 'reference evidence SHA256SUMS 校验失败。'
    jq -e '.schema_version == 3 and .plan_mode == "reference-screen" and
      .status == "REVIEW_REQUIRED" and .persistence_authorized == false and
      .measurement_gate.valid == true and .shaping_exposure_gate.valid == true and
      .resource_gate.valid == true' "${reference_evidence}/sweep-analysis.json" >/dev/null ||
      die 'reference evidence 未通过测量、HTB 暴露或资源门禁，不能开始 candidate sweep。'
    reference_manifest_sha256="$(sha256sum "${reference_evidence}/SHA256SUMS" | awk '{print $1}')"
    reference_analysis_sha256="$(sha256sum "${reference_evidence}/sweep-analysis.json" | awk '{print $1}')"
    grep -Fxq "evidence_manifest_sha256=${reference_manifest_sha256}" \
      "${reference_evidence}/COMPLETED" ||
      die 'reference COMPLETED 未绑定当前证据 manifest。'
    grep -Fxq "analysis_sha256=${reference_analysis_sha256}" \
      "${reference_evidence}/COMPLETED" ||
      die 'reference COMPLETED 未绑定当前分析结果。'
    reference_completed_sha256="$(sha256sum "${reference_evidence}/COMPLETED" | awk '{print $1}')"
    info "已验证 reference evidence；ack 只表示已人工复核，不授权持久化：${reference_evidence}"
  fi
  temp_dir="$(mktemp -d)"
  plan_file="${temp_dir}/plan.json"
  if [ "$mode" = reference-screen ]; then
    "$bundle_dir/rate-sweep-plan.sh" --mode reference-screen --samples-per-state "$samples" \
      --cooldown-seconds "$cooldown" --benchmark-seconds "$seconds" --omit-seconds "$omit" \
      --parallel "$parallel" --family "$family" \
      --minimum-rate-exposure-percent "$minimum_rate_exposure_percent" \
      --minimum-cpu-idle-percent "$minimum_cpu_idle_percent" \
      --maximum-cpu-steal-percent "$maximum_cpu_steal_percent" >"$plan_file"
  else
    "$bundle_dir/rate-sweep-plan.sh" --mode candidate-sweep --rates "$rates" --samples-per-state "$samples" \
      --cooldown-seconds "$cooldown" --benchmark-seconds "$seconds" --omit-seconds "$omit" \
      --parallel "$parallel" --family "$family" \
      --minimum-rate-exposure-percent "$minimum_rate_exposure_percent" \
      --minimum-cpu-idle-percent "$minimum_cpu_idle_percent" \
      --maximum-cpu-steal-percent "$maximum_cpu_steal_percent" \
      --ack-reference-reviewed \
      --reference-manifest-sha256 "$reference_manifest_sha256" \
      --reference-analysis-sha256 "$reference_analysis_sha256" \
      --reference-completed-sha256 "$reference_completed_sha256" >"$plan_file"
  fi
  chmod 0600 "$plan_file"
  info "即将运行 ${mode}；这是非持久化 HTB 流量实验。"
  if "$bundle_dir/rate-sweep-run.sh" --plan "$plan_file" --output-dir "$output_dir" \
    --tuning-script "$tuning_script" --htb-tool "$htb_tool" \
    --analyzer "$bundle_dir/rate-sweep-analyze.sh" --host "$host" --port "$port" \
    --budget-tool "$budget_tool" --ledger "$ledger" --window-id "$window_id" \
    --budget-bytes "$((10#$budget_mib * 1024 * 1024))"; then
    run_rc=0
  else
    run_rc=$?
  fi
  rm -rf -- "$temp_dir"
  return "$run_rc"
}

main() {
  local choice
  parse_common "$@"
  if [ -z "$command_name" ] && [ -t 0 ] && [ -t 1 ]; then
    cat <<'EOF'

HTB 非持久化实验菜单：
  1) preflight（只读，推荐先执行）
  2) 10 秒 smoke-test（临时 HTB 190，自动恢复）
  3) status
  4) stop（恢复 root fq）
  5) 显示 reference/sweep 命令帮助
  0) 返回
EOF
    printf '请选择 [默认 1]：'
    IFS= read -r choice
    case "${choice:-1}" in
      1) command_name=preflight ;;
      2) command_name=smoke ;;
      3) command_name=status ;;
      4) command_name=stop ;;
      5) usage; return 0 ;;
      0) return 0 ;;
      *) die '无效 HTB 菜单选择。' ;;
    esac
  fi
  [ -n "$command_name" ] || { usage >&2; die '缺少 HTB 子命令。'; }
  [ -n "$bundle_dir" ] || bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/experiments/htb-aggregate" && pwd -P)"
  for asset in htb-aggregate-experiment.sh rate-sweep-plan.sh rate-sweep-run.sh rate-sweep-analyze.sh experiment-plan.sh; do
    require_asset "${bundle_dir}/${asset}"
  done
  case "$command_name" in
    status | stop)
      bind_stable_htb_tool 0
      "$htb_tool" "$command_name" "${pass_args[@]}"
      ;;
    preflight)
      bind_stable_htb_tool 1
      "$htb_tool" preflight "${pass_args[@]}"
      ;;
    smoke | smoke-test)
      bind_stable_htb_tool 1
      "$htb_tool" smoke-test "${pass_args[@]}"
      ;;
    reference)
      [ -n "$tuning_script" ] || die 'reference 缺少经总控校验的 tuning script。'
      bind_stable_htb_tool 1
      run_scan reference-screen
      ;;
    sweep)
      [ -n "$tuning_script" ] || die 'sweep 缺少经总控校验的 tuning script。'
      bind_stable_htb_tool 1
      run_scan candidate-sweep
      ;;
    analyze)
      [ "${#pass_args[@]}" -eq 1 ] || die 'analyze 需要一个 evidence 目录。'
      "${bundle_dir}/rate-sweep-analyze.sh" "${pass_args[0]}"
      ;;
    plan) "${bundle_dir}/rate-sweep-plan.sh" "${pass_args[@]}" ;;
    aba-plan) "${bundle_dir}/experiment-plan.sh" "${pass_args[@]}" ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
