#!/usr/bin/env bash
# Debian VPS Tuning controller. Selects and verifies one generated profile.

set -Eeuo pipefail
IFS=$'\n\t'
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH

CONTROLLER_VERSION='0.1.0-rc.9'
RELEASE_TAG='v0.1.0-rc.9'
REPOSITORY='alieismy/debian-vps-tuning'
RELEASE_BASE_URL="https://github.com/${REPOSITORY}/releases/download/${RELEASE_TAG}"

STATE_FILE='/var/lib/proxy-vps-tuning/state.json'
DEFAULT_PORT_SPEED_MBPS=200
MIN_PORT_SPEED_MBPS=100
MAX_PORT_SPEED_MBPS=1000

EXIT_USAGE=2
EXIT_UNSUPPORTED=3
EXIT_CONFLICT=4
EXIT_DOWNLOAD=10
EXIT_INTEGRITY=11

ACTION=''
ACTION_FROM_MENU=0
CLI_PORT_SPEED_MBPS=''
PORT_SPEED_MBPS_SELECTED=''
DETECTED_PROFILE=''
DETECTED_LABEL=''
DETECTED_PRETTY_NAME=''
DETECTED_MEMORY_MIB=''
DETECTED_ARCH=''
DETECTED_CPUS=''
DETECTED_RESOURCE_CLASS=''
STATE_PROFILE=''
STATE_VERSION=''
STATE_PORT_SPEED_MBPS=''
PROFILE_FILE=''
PROFILE_PATH=''
PROFILE_SHA256=''
PROFILE_SOURCE=''
TEMP_DIR=''

info() { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
error() { printf '[x] %s\n' "$*" >&2; }
die() { local code="$1"; shift; error "$*"; exit "$code"; }

cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf -- "$TEMP_DIR"
  fi
}

usage() {
  cat <<'EOF_USAGE'
Usage:
  debian-vps-tuning.sh
  debian-vps-tuning.sh {guided|preflight|apply|verify|status|diagnose|rollback|recover} [--port 100..1000]

Options:
  --port MBPS    provider port cap for guided/preflight/apply; default 200
  -h, --help     show this help
  --version      show controller and pinned release versions

Behavior:
  - With a terminal and no action, shows an interactive menu.
  - Without a terminal, an explicit action is required.
  - guided runs preflight first and asks before apply.
  - recover is an advanced rc.2 empty-state recovery action and is not shown
    in the normal interactive menu.

The controller selects Debian 12/13 and supported CPU/RAM combinations
automatically. It never changes the tuning configuration itself; it invokes
one verified profile script.
EOF_USAGE
}

is_interactive_terminal() { [ -t 0 ] && [ -t 1 ]; }

need_root() {
  [ "$(id -u)" -eq 0 ] || die "$EXIT_UNSUPPORTED" '请在 root shell 中运行；本项目命令不需要 sudo。'
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "$EXIT_UNSUPPORTED" "缺少必要命令：$1"
}

validate_port_speed() {
  local value="$1"
  [[ "$value" =~ ^[0-9]{3,4}$ ]] || return 1
  value=$((10#$value))
  [ "$value" -ge "$MIN_PORT_SPEED_MBPS" ] && [ "$value" -le "$MAX_PORT_SPEED_MBPS" ]
}

profile_metadata() {
  case "$1" in
    debian12-1c512m)
      printf '%s\t%s\n' 'debian12-1c512m-vps-tuning.sh' 'Debian 12 / 1 vCPU / 512 MiB'
      ;;
    debian12-1c1g)
      printf '%s\t%s\n' 'debian12-1c1g-vps-tuning.sh' 'Debian 12 / 1 vCPU / 1 GiB'
      ;;
    debian12-1c2g)
      printf '%s\t%s\n' 'debian12-1c2g-vps-tuning.sh' 'Debian 12 / 1–2 vCPU / 2 GiB'
      ;;
    debian13-1c512m)
      printf '%s\t%s\n' 'debian13-1c512m-vps-tuning.sh' 'Debian 13 / 1 vCPU / 512 MiB'
      ;;
    debian13-1c1g)
      printf '%s\t%s\n' 'debian13-1c1g-vps-tuning.sh' 'Debian 13 / 1 vCPU / 1 GiB'
      ;;
    debian13-1c2g)
      printf '%s\t%s\n' 'debian13-1c2g-vps-tuning.sh' 'Debian 13 / 1–2 vCPU / 2 GiB'
      ;;
    *) return 1 ;;
  esac
}

detect_profile_from() {
  local os_release_file="$1" meminfo_file="$2" arch="$3" cpus="$4"
  local os_id version_id pretty_name os_values mem_mib profile label metadata resource_class

  [ -r "$os_release_file" ] || return 1
  [ -r "$meminfo_file" ] || return 1

  # /etc/os-release is specified as shell-compatible variable assignments.
  # shellcheck disable=SC1090
  os_values="$(set +u; . "$os_release_file"; printf '%s\t%s\t%s' "${ID:-}" "${VERSION_ID:-}" "${PRETTY_NAME:-unknown}")"
  IFS=$'\t' read -r os_id version_id pretty_name <<<"$os_values"
  [ "$os_id" = 'debian' ] || return 2
  case "$version_id" in 12 | 13) ;; *) return 2 ;; esac
  [ "$arch" = 'x86_64' ] || return 2
  [[ "$cpus" =~ ^[1-9][0-9]*$ ]] || return 1

  mem_mib="$(awk '/^MemTotal:/ {printf "%d", $2 / 1024; found=1} END {if (!found) exit 1}' "$meminfo_file")" || return 1
  [[ "$mem_mib" =~ ^[0-9]+$ ]] || return 1

  if [ "$cpus" -eq 1 ] && [ "$mem_mib" -ge 384 ] && [ "$mem_mib" -le 767 ]; then
    profile="debian${version_id}-1c512m"
    resource_class='1C512MB'
  elif [ "$cpus" -eq 1 ] && [ "$mem_mib" -ge 768 ] && [ "$mem_mib" -le 1535 ]; then
    profile="debian${version_id}-1c1g"
    resource_class='1C1GB'
  elif [ "$cpus" -eq 1 ] && [ "$mem_mib" -ge 1536 ] && [ "$mem_mib" -le 3072 ]; then
    profile="debian${version_id}-1c2g"
    resource_class='1C2GB'
  elif [ "$cpus" -eq 2 ] && [ "$mem_mib" -ge 1536 ] && [ "$mem_mib" -le 3072 ]; then
    profile="debian${version_id}-1c2g"
    resource_class='2C2GB'
  else
    return 3
  fi

  metadata="$(profile_metadata "$profile")" || return 1
  IFS=$'\t' read -r _ label <<<"$metadata"
  printf '%s\t%s\t%s\t%s\t%s\n' "$profile" "$label" "$pretty_name" "$mem_mib" "$resource_class"
}

detect_environment() {
  local detected rc metadata
  DETECTED_ARCH="$(uname -m)"
  DETECTED_CPUS="$(nproc 2>/dev/null || printf '?')"
  DETECTED_MEMORY_MIB="$(awk '/^MemTotal:/ {printf "%d", $2 / 1024; found=1} END {if (!found) exit 1}' /proc/meminfo 2>/dev/null || printf '?')"
  set +e
  detected="$(detect_profile_from /etc/os-release /proc/meminfo "$DETECTED_ARCH" "$DETECTED_CPUS")"
  rc=$?
  set -e
  case "$rc" in
    0) ;;
    1) die "$EXIT_UNSUPPORTED" '无法读取或解析 /etc/os-release、/proc/meminfo 或可用逻辑 CPU 数。' ;;
    2) die "$EXIT_UNSUPPORTED" "只支持 Debian 12/13、amd64；检测到架构 ${DETECTED_ARCH}。" ;;
    3) die "$EXIT_UNSUPPORTED" "只支持四个资源档：1C512MB (384–767 MiB)、1C1GB (768–1535 MiB)、1C2GB 或 2C2GB (1536–3072 MiB)；检测到 ${DETECTED_CPUS} vCPU、${DETECTED_MEMORY_MIB} MiB RAM。" ;;
    *) die "$EXIT_UNSUPPORTED" '环境检测发生未知错误。' ;;
  esac
  IFS=$'\t' read -r DETECTED_PROFILE DETECTED_LABEL DETECTED_PRETTY_NAME DETECTED_MEMORY_MIB DETECTED_RESOURCE_CLASS <<<"$detected"
  metadata="$(profile_metadata "$DETECTED_PROFILE")" || die "$EXIT_UNSUPPORTED" '无法映射资源档位。'
  IFS=$'\t' read -r PROFILE_FILE _ <<<"$metadata"
}

read_existing_state() {
  [ -e "$STATE_FILE" ] || return 0
  need_command jq
  if ! jq -e 'type == "object" and (.profile.id | type == "string")' "$STATE_FILE" >/dev/null 2>&1; then
    warn "检测到不可解析的状态文件：${STATE_FILE}；将由目标脚本给出恢复诊断。"
    return 0
  fi
  STATE_PROFILE="$(jq -r '.profile.id' "$STATE_FILE")"
  STATE_VERSION="$(jq -r '.script_version // "unknown"' "$STATE_FILE")"
  STATE_PORT_SPEED_MBPS="$(jq -r '.network.port_speed_mbps // empty' "$STATE_FILE")"
  profile_metadata "$STATE_PROFILE" >/dev/null 2>&1 || die "$EXIT_CONFLICT" "状态文件包含未知档位：${STATE_PROFILE}"
  state_profile_matches_detected "$DETECTED_PROFILE" "$STATE_PROFILE" ||
    die "$EXIT_CONFLICT" "当前检测档位 ${DETECTED_PROFILE} 与已安装状态档位 ${STATE_PROFILE} 不一致；拒绝自动选择脚本。"
}

state_profile_matches_detected() { [ "$1" = "$2" ]; }

parse_arguments() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      guided | preflight | apply | verify | status | diagnose | rollback | recover)
        [ -z "$ACTION" ] || die "$EXIT_USAGE" '只能指定一个 action。'
        ACTION="$1"
        ;;
      --port)
        [ "$#" -ge 2 ] || die "$EXIT_USAGE" '--port 缺少数值。'
        CLI_PORT_SPEED_MBPS="$2"
        shift
        ;;
      --port=*) CLI_PORT_SPEED_MBPS="${1#*=}" ;;
      -h | --help) usage; exit 0 ;;
      --version)
        printf 'controller=%s release=%s\n' "$CONTROLLER_VERSION" "$RELEASE_TAG"
        exit 0
        ;;
      *) die "$EXIT_USAGE" "未知参数：$1" ;;
    esac
    shift
  done
}

choose_action_interactively() {
  local choice
  cat <<'EOF_MENU'

请选择操作：

  1) 安全引导：preflight，通过后询问是否 apply（推荐）
  2) 只执行 preflight
  3) 执行 apply
  4) verify
  5) status
  6) diagnose（只读诊断）
  7) rollback
  0) 退出
EOF_MENU
  printf '\n请选择 [默认 1]：'
  IFS= read -r choice
  case "${choice:-1}" in
    1) ACTION='guided' ;;
    2) ACTION='preflight' ;;
    3) ACTION='apply' ;;
    4) ACTION='verify' ;;
    5) ACTION='status' ;;
    6) ACTION='diagnose' ;;
    7) ACTION='rollback' ;;
    0) exit 0 ;;
    *) die "$EXIT_USAGE" '无效操作选择。' ;;
  esac
  ACTION_FROM_MENU=1
}

choose_port_interactively() {
  local choice custom
  cat <<'EOF_PORT'

请选择 VPS 服务商提供的端口带宽：

  1) 100 Mbps
  2) 200 Mbps（默认）
  3) 500 Mbps
  4) 1000 Mbps
  5) 自定义 100–1000 Mbps
EOF_PORT
  printf '\n请选择 [默认 2]：'
  IFS= read -r choice
  case "${choice:-2}" in
    1) PORT_SPEED_MBPS_SELECTED=100 ;;
    2) PORT_SPEED_MBPS_SELECTED=200 ;;
    3) PORT_SPEED_MBPS_SELECTED=500 ;;
    4) PORT_SPEED_MBPS_SELECTED=1000 ;;
    5)
      printf '请输入 100–1000 的整数：'
      IFS= read -r custom
      validate_port_speed "$custom" || die "$EXIT_USAGE" '带宽必须是 100–1000 的整数。'
      PORT_SPEED_MBPS_SELECTED=$((10#$custom))
      ;;
    *) die "$EXIT_USAGE" '无效带宽选择。' ;;
  esac
}

select_port_speed() {
  case "$ACTION" in
    guided | preflight | apply) ;;
    *)
      [ -z "$CLI_PORT_SPEED_MBPS" ] || die "$EXIT_USAGE" "${ACTION} 不接受 --port；它使用现有状态。"
      return 0
      ;;
  esac

  if [ -n "$CLI_PORT_SPEED_MBPS" ]; then
    validate_port_speed "$CLI_PORT_SPEED_MBPS" || die "$EXIT_USAGE" '带宽必须是 100–1000 的整数。'
    PORT_SPEED_MBPS_SELECTED=$((10#$CLI_PORT_SPEED_MBPS))
  elif [ -n "${PORT_SPEED_MBPS:-}" ]; then
    validate_port_speed "$PORT_SPEED_MBPS" || die "$EXIT_USAGE" 'PORT_SPEED_MBPS 必须是 100–1000 的整数。'
    PORT_SPEED_MBPS_SELECTED=$((10#$PORT_SPEED_MBPS))
  elif is_interactive_terminal; then
    choose_port_interactively
  else
    PORT_SPEED_MBPS_SELECTED=$DEFAULT_PORT_SPEED_MBPS
  fi
}

verify_manifest_entry() {
  local manifest="$1" file_path="$2" logical_name="$3"
  local count expected actual
  [ -s "$manifest" ] && [ -s "$file_path" ] || return 1
  count="$(awk -v name="$logical_name" '$2 == name {count++} END {print count+0}' "$manifest")"
  [ "$count" -eq 1 ] || return 1
  expected="$(awk -v name="$logical_name" '$2 == name {print $1; exit}' "$manifest")"
  [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || return 1
  actual="$(sha256sum "$file_path" | awk '{print $1}')"
  [ "${actual,,}" = "${expected,,}" ] || return 1
  PROFILE_SHA256="${actual,,}"
}

verify_profile_contract() {
  local file_path="$1"
  grep -Fq "SCRIPT_VERSION='${CONTROLLER_VERSION}'" "$file_path" &&
    grep -Fq "PROFILE_ID='${DETECTED_PROFILE}'" "$file_path"
}

controller_directory() {
  local source_path="${BASH_SOURCE[0]}"
  if [[ "$source_path" != /* ]]; then source_path="${PWD}/${source_path}"; fi
  cd -- "$(dirname -- "$source_path")" 2>/dev/null && pwd -P
}

download_file() {
  local url="$1" output="$2"
  curl --fail --show-error --silent --location \
    --proto '=https' --proto-redir '=https' \
    --connect-timeout 15 --max-time 120 --max-redirs 5 \
    --remove-on-error --output "$output" "$url"
}

resolve_profile_script() {
  local local_dir local_manifest local_profile controller_source remote_manifest
  need_command sha256sum
  local_dir="$(controller_directory)"
  local_manifest="${local_dir}/SHA256SUMS"
  local_profile="${local_dir}/${PROFILE_FILE}"
  controller_source="${BASH_SOURCE[0]}"
  if [[ "$controller_source" != /* ]]; then controller_source="${PWD}/${controller_source}"; fi

  if [ -f "$local_manifest" ] && [ -f "$local_profile" ]; then
    verify_manifest_entry "$local_manifest" "$controller_source" 'debian-vps-tuning.sh' ||
      die "$EXIT_INTEGRITY" '本地总控脚本未通过 SHA-256 校验；拒绝使用同目录 profile。'
    verify_manifest_entry "$local_manifest" "$local_profile" "$PROFILE_FILE" ||
      die "$EXIT_INTEGRITY" "本地文件未通过 SHA-256 校验：${PROFILE_FILE}"
    verify_profile_contract "$local_profile" ||
      die "$EXIT_INTEGRITY" "本地脚本的版本或档位契约不匹配：${PROFILE_FILE}"
    PROFILE_PATH="$local_profile"
    PROFILE_SOURCE='local'
    return 0
  fi

  need_command curl
  umask 077
  TEMP_DIR="$(mktemp -d)" || die "$EXIT_DOWNLOAD" '无法创建临时目录。'
  remote_manifest="${TEMP_DIR}/SHA256SUMS"
  PROFILE_PATH="${TEMP_DIR}/${PROFILE_FILE}"

  info "下载固定发布清单：${RELEASE_TAG}/SHA256SUMS"
  download_file "${RELEASE_BASE_URL}/SHA256SUMS" "$remote_manifest" ||
    die "$EXIT_DOWNLOAD" "无法下载固定发布清单；没有回退到 master/latest：${RELEASE_TAG}"
  info "下载固定档位脚本：${RELEASE_TAG}/${PROFILE_FILE}"
  download_file "${RELEASE_BASE_URL}/${PROFILE_FILE}" "$PROFILE_PATH" ||
    die "$EXIT_DOWNLOAD" "无法下载固定档位脚本；没有执行任何配置：${PROFILE_FILE}"
  verify_manifest_entry "$remote_manifest" "$PROFILE_PATH" "$PROFILE_FILE" ||
    die "$EXIT_INTEGRITY" "远程档位脚本未通过 SHA-256 校验：${PROFILE_FILE}"
  verify_profile_contract "$PROFILE_PATH" ||
    die "$EXIT_INTEGRITY" "远程脚本的版本或档位契约不匹配：${PROFILE_FILE}"
  chmod 0700 "$PROFILE_PATH"
  PROFILE_SOURCE="release:${RELEASE_TAG}"
}

print_environment_summary() {
  printf '\nDebian VPS Tuning %s\n\n' "$CONTROLLER_VERSION"
  printf '检测结果：\n'
  printf '  系统：%s\n' "$DETECTED_PRETTY_NAME"
  printf '  架构：%s\n' "$DETECTED_ARCH"
  printf '  CPU：%s vCPU\n' "$DETECTED_CPUS"
  printf '  内存：%s MiB\n' "$DETECTED_MEMORY_MIB"
  printf '  资源档：%s\n' "$DETECTED_RESOURCE_CLASS"
  printf '  实现档位：%s\n' "$DETECTED_LABEL"
  if [ -n "$STATE_PROFILE" ]; then
    printf '  已安装档位：%s\n' "$STATE_PROFILE"
    printf '  状态脚本版本：%s\n' "$STATE_VERSION"
    [ -z "$STATE_PORT_SPEED_MBPS" ] || printf '  已安装端口带宽：%s Mbps\n' "$STATE_PORT_SPEED_MBPS"
  fi
}

print_execution_plan() {
  printf '\n执行计划：\n'
  printf '  action：%s\n' "$ACTION"
  printf '  调用脚本：%s\n' "$PROFILE_FILE"
  printf '  脚本来源：%s\n' "$PROFILE_SOURCE"
  printf '  SHA-256：%s\n' "$PROFILE_SHA256"
  case "$ACTION" in
    guided | preflight | apply)
      printf '  端口带宽：%s Mbps\n' "$PORT_SPEED_MBPS_SELECTED"
      ;;
  esac
  printf '\n'
}

confirm_apply() {
  local answer
  is_interactive_terminal || return 1
  printf 'preflight 已通过。是否执行 apply？[y/N]：'
  IFS= read -r answer
  case "$answer" in y | Y | yes | YES) return 0 ;; *) return 1 ;; esac
}

run_profile() {
  local action="$1"
  case "$action" in
    preflight | apply)
      env PORT_SPEED_MBPS="$PORT_SPEED_MBPS_SELECTED" bash "$PROFILE_PATH" "$action"
      ;;
    *) bash "$PROFILE_PATH" "$action" ;;
  esac
}

dispatch_action() {
  local rc
  case "$ACTION" in
    guided)
      is_interactive_terminal || die "$EXIT_USAGE" 'guided 需要交互终端；自动化请分别执行 preflight 和 apply。'
      if run_profile preflight; then :; else rc=$?; return "$rc"; fi
      if confirm_apply; then
        run_profile apply
      else
        info '已停止；没有执行 apply。'
      fi
      ;;
    apply)
      if [ "$ACTION_FROM_MENU" -eq 1 ]; then
        printf 'apply 会写入系统配置。是否继续？[y/N]：'
        local answer
        IFS= read -r answer
        case "$answer" in
          y | Y | yes | YES) ;;
          *) info '已停止；没有执行 apply。'; return 0 ;;
        esac
      fi
      run_profile apply
      ;;
    preflight | verify | status | diagnose | rollback | recover) run_profile "$ACTION" ;;
    *) die "$EXIT_USAGE" "不支持的 action：${ACTION}" ;;
  esac
}

main() {
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  [ "$RELEASE_TAG" = "v${CONTROLLER_VERSION}" ] ||
    die "$EXIT_INTEGRITY" '总控版本与固定 Release tag 不一致。'
  parse_arguments "$@"
  need_root
  detect_environment
  read_existing_state
  print_environment_summary

  if [ -z "$ACTION" ]; then
    is_interactive_terminal || die "$EXIT_USAGE" '非交互环境必须明确指定 action。'
    choose_action_interactively
  fi
  select_port_speed
  resolve_profile_script
  print_execution_plan
  dispatch_action
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
