#!/usr/bin/env bash
# Debian VPS Tuning controller. Selects and verifies one generated profile.

set -Eeuo pipefail
IFS=$'\n\t'
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH

CONTROLLER_VERSION='0.1.0-rc.10'
RELEASE_TAG='v0.1.0-rc.10'
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
UPDATE_TEMP_DIR=''
CLI_UPDATE_TAG=''
UPDATE_TAG_SELECTED=''
UPDATE_CONTROLLER_PATH=''
UPDATE_CONTROLLER_SHA256=''
SOURCE_PROFILE_PATH=''
SOURCE_PROFILE_SHA256=''

info() { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
error() { printf '[x] %s\n' "$*" >&2; }
die() { local code="$1"; shift; error "$*"; exit "$code"; }

cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf -- "$TEMP_DIR"
  fi
  if [ -n "$UPDATE_TEMP_DIR" ] && [ -d "$UPDATE_TEMP_DIR" ]; then
    rm -rf -- "$UPDATE_TEMP_DIR"
  fi
}

usage() {
  cat <<'EOF_USAGE'
Usage:
  debian-vps-tuning.sh
  debian-vps-tuning.sh {guided|preflight|apply|verify|status|diagnose|benchmark|update|rollback|recover} [options]

Options:
  --port MBPS    provider port cap for guided/preflight/apply; default 200
  --target TAG    update target, for example v0.1.0-rc.11; default is the
                  highest non-draft Release in the installed major.minor line;
                  stable installations ignore prereleases automatically
  -h, --help     show this help
  --version      show controller and pinned release versions

Behavior:
  - With a terminal and no action, shows an interactive menu.
  - Without a terminal, an explicit action is required.
  - guided runs preflight first and asks before apply.
  - benchmark requires BENCHMARK_HOST and an existing iperf3 server; it changes
    no system configuration but deliberately generates high-bandwidth traffic.
  - update is read-only: it verifies the source and target Release assets, runs
    source verify and target update-preflight, then prints a manual handoff plan.
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
      guided | preflight | apply | verify | status | diagnose | benchmark | update | rollback | recover)
        [ -z "$ACTION" ] || die "$EXIT_USAGE" '只能指定一个 action。'
        ACTION="$1"
        ;;
      --port)
        [ "$#" -ge 2 ] || die "$EXIT_USAGE" '--port 缺少数值。'
        CLI_PORT_SPEED_MBPS="$2"
        shift
        ;;
      --port=*) CLI_PORT_SPEED_MBPS="${1#*=}" ;;
      --target)
        [ "$#" -ge 2 ] || die "$EXIT_USAGE" '--target 缺少 Release tag。'
        CLI_UPDATE_TAG="$2"
        shift
        ;;
      --target=*) CLI_UPDATE_TAG="${1#*=}" ;;
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
  6) diagnose（5 秒只读增量诊断）
  7) benchmark（需 BENCHMARK_HOST，会产生测试流量）
  8) update（只读检查并生成升级计划）
  9) rollback
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
    7) ACTION='benchmark' ;;
    8) ACTION='update' ;;
    9) ACTION='rollback' ;;
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
  if [ -n "$CLI_UPDATE_TAG" ] && [ "$ACTION" != 'update' ]; then
    die "$EXIT_USAGE" '--target 只能与 update 一起使用。'
  fi
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
  elif [ "$ACTION" = 'apply' ] && [ -n "$STATE_PROFILE" ]; then
    validate_port_speed "$STATE_PORT_SPEED_MBPS" ||
      die "$EXIT_CONFLICT" '已安装状态缺少有效的端口带宽；请执行 status/diagnose 并人工检查状态。'
    PORT_SPEED_MBPS_SELECTED=$((10#$STATE_PORT_SPEED_MBPS))
  elif is_interactive_terminal; then
    choose_port_interactively
  else
    PORT_SPEED_MBPS_SELECTED=$DEFAULT_PORT_SPEED_MBPS
  fi
}

parse_release_version() {
  local value="${1#v}" stable rc part
  if [[ "$value" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-rc\.([0-9]+))?$ ]]; then
    for part in "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[5]}"; do
      [ -z "$part" ] && continue
      [ "${#part}" -le 9 ] || return 1
      [ "$part" = '0' ] || [[ "$part" != 0* ]] || return 1
    done
    if [ -n "${BASH_REMATCH[4]}" ]; then stable=0; rc="$((10#${BASH_REMATCH[5]}))"; else stable=1; rc=0; fi
    printf '%d\t%d\t%d\t%d\t%d\n' \
      "$((10#${BASH_REMATCH[1]}))" "$((10#${BASH_REMATCH[2]}))" \
      "$((10#${BASH_REMATCH[3]}))" "$stable" "$rc"
    return 0
  fi
  return 1
}

release_is_newer() {
  local candidate current c_major c_minor c_patch c_stable c_rc o_major o_minor o_patch o_stable o_rc
  candidate="$(parse_release_version "$1")" || return 2
  current="$(parse_release_version "$2")" || return 2
  IFS=$'\t' read -r c_major c_minor c_patch c_stable c_rc <<<"$candidate"
  IFS=$'\t' read -r o_major o_minor o_patch o_stable o_rc <<<"$current"
  [ "$c_major" -gt "$o_major" ] && return 0
  [ "$c_major" -lt "$o_major" ] && return 1
  [ "$c_minor" -gt "$o_minor" ] && return 0
  [ "$c_minor" -lt "$o_minor" ] && return 1
  [ "$c_patch" -gt "$o_patch" ] && return 0
  [ "$c_patch" -lt "$o_patch" ] && return 1
  [ "$c_stable" -gt "$o_stable" ] && return 0
  [ "$c_stable" -lt "$o_stable" ] && return 1
  [ "$c_rc" -gt "$o_rc" ]
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

select_highest_release_tag() {
  local releases_json="$1" current_version="${2:-$CONTROLLER_VERSION}"
  local tag best='' candidate parsed current_parsed current_major current_minor current_stable tag_major tag_minor tag_stable
  current_parsed="$(parse_release_version "$current_version")" || return 1
  IFS=$'\t' read -r current_major current_minor _ current_stable _ <<<"$current_parsed"
  while IFS= read -r tag; do
    parsed="$(parse_release_version "$tag")" || continue
    IFS=$'\t' read -r tag_major tag_minor _ tag_stable _ <<<"$parsed"
    [ "$tag_major" -eq "$current_major" ] && [ "$tag_minor" -eq "$current_minor" ] || continue
    [ "$current_stable" -eq 0 ] || [ "$tag_stable" -eq 1 ] || continue
    if [ -z "$best" ] || release_is_newer "$tag" "$best"; then
      best="$tag"
    fi
  done < <(jq -r '.[] | select(.draft == false) | .tag_name // empty' "$releases_json")
  [ -n "$best" ] || return 1
  candidate="${best#v}"
  printf 'v%s\n' "$candidate"
}

resolve_update_release() {
  local releases_json requested
  [ -n "$STATE_PROFILE" ] || die "$EXIT_CONFLICT" '当前没有已安装的管理状态；update 只用于升级已应用的配置。'
  parse_release_version "$STATE_VERSION" >/dev/null 2>&1 ||
    die "$EXIT_CONFLICT" "状态版本无法参与安全升级比较：${STATE_VERSION}"
  need_command curl
  need_command jq
  need_command sha256sum
  umask 077
  UPDATE_TEMP_DIR="$(mktemp -d)" || die "$EXIT_DOWNLOAD" '无法创建 update 临时目录。'

  requested="${CLI_UPDATE_TAG:-${UPDATE_TAG:-}}"
  if [ -n "$requested" ]; then
    parse_release_version "$requested" >/dev/null 2>&1 ||
      die "$EXIT_USAGE" '目标 Release 必须符合 vMAJOR.MINOR.PATCH 或 vMAJOR.MINOR.PATCH-rc.N。'
    UPDATE_TAG_SELECTED="v${requested#v}"
  else
    releases_json="${UPDATE_TEMP_DIR}/releases.json"
    if [[ "$STATE_VERSION" == *-rc.* ]]; then
      info '查询 GitHub Releases（rc 通道接受更高 rc 或同版本线稳定版）。'
    else
      info '查询 GitHub Releases（稳定通道自动排除 prerelease）。'
    fi
    curl --fail --show-error --silent --location \
      --proto '=https' --proto-redir '=https' \
      --connect-timeout 15 --max-time 120 --max-redirs 5 \
      --header 'Accept: application/vnd.github+json' \
      --header 'X-GitHub-Api-Version: 2022-11-28' \
      --remove-on-error --output "$releases_json" \
      "https://api.github.com/repos/${REPOSITORY}/releases?per_page=30" ||
      die "$EXIT_DOWNLOAD" '无法查询 GitHub Releases；可用 --target 显式指定目标 tag。'
    jq -e 'type == "array"' "$releases_json" >/dev/null 2>&1 ||
      die "$EXIT_DOWNLOAD" 'GitHub Releases 响应不是预期的 JSON 数组。'
    UPDATE_TAG_SELECTED="$(select_highest_release_tag "$releases_json" "$STATE_VERSION")" ||
      die "$EXIT_DOWNLOAD" '没有找到同一 major.minor 发布线且符合项目版本格式的非草稿 Release。'
  fi

  if ! release_is_newer "$UPDATE_TAG_SELECTED" "$STATE_VERSION"; then
    if [ "${UPDATE_TAG_SELECTED#v}" = "${STATE_VERSION#v}" ]; then
      info "当前已是目标版本：${STATE_VERSION}"
      UPDATE_TAG_SELECTED=''
      return 0
    fi
    die "$EXIT_CONFLICT" "目标版本 ${UPDATE_TAG_SELECTED} 不高于已安装版本 ${STATE_VERSION}；拒绝降级或重复迁移。"
  fi
}

resolve_update_controller() {
  local target_base manifest expected_version
  target_base="https://github.com/${REPOSITORY}/releases/download/${UPDATE_TAG_SELECTED}"
  manifest="${UPDATE_TEMP_DIR}/SHA256SUMS"
  UPDATE_CONTROLLER_PATH="${UPDATE_TEMP_DIR}/debian-vps-tuning.sh"
  info "下载目标发布清单：${UPDATE_TAG_SELECTED}/SHA256SUMS"
  download_file "${target_base}/SHA256SUMS" "$manifest" ||
    die "$EXIT_DOWNLOAD" "无法下载目标发布清单：${UPDATE_TAG_SELECTED}"
  info "下载目标总控脚本：${UPDATE_TAG_SELECTED}/debian-vps-tuning.sh"
  download_file "${target_base}/debian-vps-tuning.sh" "$UPDATE_CONTROLLER_PATH" ||
    die "$EXIT_DOWNLOAD" "无法下载目标总控脚本：${UPDATE_TAG_SELECTED}"
  PROFILE_SHA256=''
  verify_manifest_entry "$manifest" "$UPDATE_CONTROLLER_PATH" 'debian-vps-tuning.sh' ||
    die "$EXIT_INTEGRITY" "目标总控脚本未通过 SHA-256 校验：${UPDATE_TAG_SELECTED}"
  UPDATE_CONTROLLER_SHA256="$PROFILE_SHA256"
  expected_version="${UPDATE_TAG_SELECTED#v}"
  if ! grep -Fq "CONTROLLER_VERSION='${expected_version}'" "$UPDATE_CONTROLLER_PATH" ||
    ! grep -Fq "RELEASE_TAG='${UPDATE_TAG_SELECTED}'" "$UPDATE_CONTROLLER_PATH"; then
    die "$EXIT_INTEGRITY" '目标总控脚本的版本或 Release tag 契约不匹配。'
  fi
  chmod 0700 "$UPDATE_CONTROLLER_PATH"
}

resolve_installed_profile() {
  local source_tag source_base manifest expected_version
  expected_version="${STATE_VERSION#v}"
  source_tag="v${expected_version}"
  if [ "$expected_version" = "$CONTROLLER_VERSION" ]; then
    resolve_profile_script
    SOURCE_PROFILE_PATH="$PROFILE_PATH"
    SOURCE_PROFILE_SHA256="$PROFILE_SHA256"
    return 0
  fi

  source_base="https://github.com/${REPOSITORY}/releases/download/${source_tag}"
  manifest="${UPDATE_TEMP_DIR}/source-SHA256SUMS"
  SOURCE_PROFILE_PATH="${UPDATE_TEMP_DIR}/source-${PROFILE_FILE}"
  info "下载已安装版本清单：${source_tag}/SHA256SUMS"
  download_file "${source_base}/SHA256SUMS" "$manifest" ||
    die "$EXIT_DOWNLOAD" "无法下载已安装版本清单：${source_tag}"
  info "下载已安装版本档位脚本：${source_tag}/${PROFILE_FILE}"
  download_file "${source_base}/${PROFILE_FILE}" "$SOURCE_PROFILE_PATH" ||
    die "$EXIT_DOWNLOAD" "无法下载已安装版本档位脚本：${source_tag}/${PROFILE_FILE}"
  PROFILE_SHA256=''
  verify_manifest_entry "$manifest" "$SOURCE_PROFILE_PATH" "$PROFILE_FILE" ||
    die "$EXIT_INTEGRITY" "已安装版本档位脚本未通过 SHA-256 校验：${source_tag}/${PROFILE_FILE}"
  SOURCE_PROFILE_SHA256="$PROFILE_SHA256"
  if ! grep -Fq "SCRIPT_VERSION='${expected_version}'" "$SOURCE_PROFILE_PATH" ||
    ! grep -Fq "PROFILE_ID='${STATE_PROFILE}'" "$SOURCE_PROFILE_PATH"; then
    die "$EXIT_INTEGRITY" '已安装版本档位脚本的版本或 profile 契约不匹配。'
  fi
  chmod 0700 "$SOURCE_PROFILE_PATH"
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
      die "$EXIT_INTEGRITY" "检测到同目录 SHA256SUMS 和 ${PROFILE_FILE}，但当前总控不属于该清单；可能混用了不同 Release 的资产。请为每个版本使用独立临时目录；拒绝使用同目录 profile，也不会回退联网下载。"
    verify_manifest_entry "$local_manifest" "$local_profile" "$PROFILE_FILE" ||
      die "$EXIT_INTEGRITY" "本地 profile 未通过同目录清单校验：${PROFILE_FILE}；可能混用了不同 Release 的资产。请为每个版本使用独立临时目录。"
    verify_profile_contract "$local_profile" ||
      die "$EXIT_INTEGRITY" "本地 profile 的版本或档位契约不匹配：${PROFILE_FILE}；请确认总控、SHA256SUMS 和 profile 来自同一 Release。"
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

run_update() {
  local source_tag source_url target_url
  validate_port_speed "$STATE_PORT_SPEED_MBPS" ||
    die "$EXIT_CONFLICT" '已安装状态缺少有效端口带宽；无法生成安全升级计划。'
  resolve_update_release
  [ -n "$UPDATE_TAG_SELECTED" ] || return 0
  resolve_installed_profile
  resolve_update_controller

  printf '\n升级计划：\n'
  printf '  当前版本：%s\n' "$STATE_VERSION"
  printf '  当前 profile SHA-256：%s\n' "$SOURCE_PROFILE_SHA256"
  printf '  目标版本：%s\n' "$UPDATE_TAG_SELECTED"
  printf '  目标总控 SHA-256：%s\n' "$UPDATE_CONTROLLER_SHA256"
  printf '  保留端口带宽：%s Mbps\n' "$STATE_PORT_SPEED_MBPS"
  printf '  模式：只读检查；不会执行 rollback、purge、apply 或 reboot\n\n'

  info "先验证当前 ${STATE_VERSION} 配置。"
  bash "$SOURCE_PROFILE_PATH" verify
  info "用目标 ${UPDATE_TAG_SELECTED} 执行只读 update-preflight。"
  env UPDATE_PREFLIGHT=1 PORT_SPEED_MBPS="$STATE_PORT_SPEED_MBPS" \
    bash "$UPDATE_CONTROLLER_PATH" preflight --port "$STATE_PORT_SPEED_MBPS"
  source_tag="v${STATE_VERSION#v}"
  source_url="https://github.com/${REPOSITORY}/releases/download/${source_tag}/${PROFILE_FILE}"
  target_url="https://github.com/${REPOSITORY}/releases/download/${UPDATE_TAG_SELECTED}/debian-vps-tuning.sh"
  printf '\n升级检查通过；系统配置未修改。\n'
  printf '维护窗口迁移材料：\n'
  printf '  当前 profile URL：%s\n' "$source_url"
  printf '  当前 profile SHA-256：%s\n' "$SOURCE_PROFILE_SHA256"
  printf '  目标总控 URL：%s\n' "$target_url"
  printf '  目标总控 SHA-256：%s\n' "$UPDATE_CONTROLLER_SHA256"
  printf '  端口带宽：%s Mbps\n' "$STATE_PORT_SPEED_MBPS"
  printf '请按 README 的人工迁移顺序执行：rollback/purge → reboot → 目标 preflight/apply → reboot → verify。\n'
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
    benchmark)
      if [ "$ACTION_FROM_MENU" -eq 1 ]; then
        printf 'benchmark 会向 BENCHMARK_HOST 产生高带宽 TCP 流量。是否继续？[y/N]：'
        local answer
        IFS= read -r answer
        case "$answer" in
          y | Y | yes | YES) ;;
          *) info '已停止；没有产生 benchmark 流量。'; return 0 ;;
        esac
      fi
      run_profile benchmark
      ;;
    update) run_update ;;
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
  if [ "$ACTION" != 'update' ]; then
    resolve_profile_script
    print_execution_plan
  fi
  dispatch_action
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
