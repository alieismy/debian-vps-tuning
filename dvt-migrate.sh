#!/usr/bin/env bash
# Persistent checkpoint/resume migration across DVT Release versions and reboots.

set -Eeuo pipefail
IFS=$'\n\t'
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH

TOOL_VERSION='0.1.0-rc.15'
STATE_FILE="${DVT_STATE_FILE:-/var/lib/proxy-vps-tuning/state.json}"

action=''
checkpoint=''
source_profile=''
target_profile=''
source_version=''
target_version=''
profile_id=''
port_mbps=''
state_sha256=''

die() { printf '[dvt-migrate][FAIL] %s\n' "$*" >&2; exit 2; }
info() { printf '[dvt-migrate] %s\n' "$*"; }
need_command() { command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"; }
boot_id() { awk 'NR==1 {print; exit}' "${DVT_BOOT_ID_FILE:-/proc/sys/kernel/random/boot_id}"; }

usage() {
  cat <<'EOF'
Usage:
  dvt-migrate.sh prepare --checkpoint /absolute/new/path
    --source-profile PATH --target-profile PATH --source-version VERSION
    --target-version VERSION --profile-id ID --port MBPS --state-sha256 HEX
  dvt-migrate.sh rollback --checkpoint PATH
  dvt-migrate.sh continue --checkpoint PATH
  dvt-migrate.sh status --checkpoint PATH

prepare is read-only. rollback runs the pinned old profile with
PURGE_CREATED_SWAP=1 and stops at the first reboot gate. continue checks that
the boot ID changed, applies the pinned target profile, stops at the second
reboot gate, and finally runs strict verify after another boot-ID change.
No command reboots the host or claims console/business-path acceptance.
EOF
}

parse_args() {
  [ "$#" -gt 0 ] || { usage >&2; exit 2; }
  action="$1"; shift
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --checkpoint) [ "$#" -ge 2 ] || die '--checkpoint 缺少参数。'; checkpoint="$2"; shift 2 ;;
      --source-profile) [ "$#" -ge 2 ] || die '--source-profile 缺少参数。'; source_profile="$2"; shift 2 ;;
      --target-profile) [ "$#" -ge 2 ] || die '--target-profile 缺少参数。'; target_profile="$2"; shift 2 ;;
      --source-version) [ "$#" -ge 2 ] || die '--source-version 缺少参数。'; source_version="$2"; shift 2 ;;
      --target-version) [ "$#" -ge 2 ] || die '--target-version 缺少参数。'; target_version="$2"; shift 2 ;;
      --profile-id) [ "$#" -ge 2 ] || die '--profile-id 缺少参数。'; profile_id="$2"; shift 2 ;;
      --port) [ "$#" -ge 2 ] || die '--port 缺少参数。'; port_mbps="$2"; shift 2 ;;
      --state-sha256) [ "$#" -ge 2 ] || die '--state-sha256 缺少参数。'; state_sha256="$2"; shift 2 ;;
      -h | --help | help) usage; exit 0 ;;
      *) die "未知参数：$1" ;;
    esac
  done
}

validate_file() {
  local label="$1" path="$2"
  [[ "$path" = /* ]] && [ -f "$path" ] && [ ! -L "$path" ] || die "${label} 必须是绝对路径普通文件且不能是符号链接。"
  [ "$(stat -c '%u' "$path")" = 0 ] && [ $((8#$(stat -c '%a' "$path") & 0022)) -eq 0 ] ||
    die "${label} 必须由 root 所有且不能被 group/world 写入。"
}

validate_checkpoint() {
  [ -n "$checkpoint" ] && [[ "$checkpoint" = /* ]] && [ -d "$checkpoint" ] && [ ! -L "$checkpoint" ] ||
    die 'checkpoint 必须是已存在的绝对路径目录且不能是符号链接。'
  [ "$(stat -c '%u' "$checkpoint")" = 0 ] && [ $((8#$(stat -c '%a' "$checkpoint") & 0022)) -eq 0 ] ||
    die 'checkpoint 必须由 root 所有且不能被 group/world 写入。'
  [ -f "${checkpoint}/migration.json" ] && [ ! -L "${checkpoint}/migration.json" ] || die 'checkpoint 缺少 migration.json。'
  jq -e --arg version "$TOOL_VERSION" '
    .schema_version == 1 and .tool_version == $version and
    (.phase | type=="string") and (.assets.source_profile.sha256|type=="string") and
    (.assets.target_profile.sha256|type=="string") and (.assets.migration_tool.sha256|type=="string")
  ' "${checkpoint}/migration.json" >/dev/null || die 'migration.json schema 或工具版本无效。'
  for name in source-profile.sh target-profile.sh dvt-migrate.sh; do validate_file "$name" "${checkpoint}/${name}"; done
  [ "$(sha256sum "${checkpoint}/source-profile.sh" | awk '{print $1}')" = "$(jq -r '.assets.source_profile.sha256' "${checkpoint}/migration.json")" ] || die 'source profile hash 漂移。'
  [ "$(sha256sum "${checkpoint}/target-profile.sh" | awk '{print $1}')" = "$(jq -r '.assets.target_profile.sha256' "${checkpoint}/migration.json")" ] || die 'target profile hash 漂移。'
  [ "$(sha256sum "${checkpoint}/dvt-migrate.sh" | awk '{print $1}')" = "$(jq -r '.assets.migration_tool.sha256' "${checkpoint}/migration.json")" ] || die 'migration tool hash 漂移。'
}

update_phase() {
  local phase="$1" gate_boot="${2:-}" temp="${checkpoint}/migration.json.tmp"
  jq --arg phase "$phase" --arg utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg gate "$gate_boot" '
    .phase=$phase | .updated_utc=$utc |
    (if $gate != "" then .reboot_gate_boot_id=$gate else . end) |
    .history += [{phase:$phase,utc:$utc,boot_id:(if $gate!="" then $gate else null end)}]
  ' "${checkpoint}/migration.json" >"$temp"
  chmod 0600 "$temp"; mv -f "$temp" "${checkpoint}/migration.json"
}

prepare() {
  local parent name source_hash target_hash tool_hash now current_boot
  [ -n "$checkpoint" ] && [[ "$checkpoint" = /* ]] || die 'prepare 必须指定绝对 --checkpoint。'
  [ ! -e "$checkpoint" ] && [ ! -L "$checkpoint" ] || die 'checkpoint 已存在，拒绝覆盖。'
  validate_file source-profile "$source_profile"; validate_file target-profile "$target_profile"
  [[ "$source_version" =~ ^0\.1\.0-rc\.[0-9]+$ ]] && [[ "$target_version" =~ ^0\.1\.0-rc\.[0-9]+$ ]] || die 'source/target version 格式无效。'
  [ "$target_version" = '0.1.0-rc.15' ] && [ "$source_version" != "$target_version" ] || die '本版迁移器只接受低版本来源并迁移到 0.1.0-rc.15。'
  [[ "$profile_id" =~ ^debian1[23]-[A-Za-z0-9-]+$ ]] || die 'profile-id 格式无效。'
  [[ "$port_mbps" =~ ^[0-9]+$ ]] && [ "$((10#$port_mbps))" -ge 100 ] && [ "$((10#$port_mbps))" -le 1000 ] || die 'port 必须是 100..1000。'
  [[ "$state_sha256" =~ ^[0-9a-f]{64}$ ]] || die 'state-sha256 格式无效。'
  [ -f "$STATE_FILE" ] && [ "$(sha256sum "$STATE_FILE" | awk '{print $1}')" = "$state_sha256" ] || die '当前 managed state 与准备输入不一致。'
  grep -Fq "SCRIPT_VERSION='${source_version}'" "$source_profile" || die 'source profile 版本契约不匹配。'
  grep -Fq "SCRIPT_VERSION='${target_version}'" "$target_profile" || die 'target profile 版本契约不匹配。'
  if ! grep -Fq "PROFILE_ID='${profile_id}'" "$source_profile" ||
    ! grep -Fq "PROFILE_ID='${profile_id}'" "$target_profile"; then
    die 'profile-id 契约不匹配。'
  fi
  bash "$source_profile" verify >/dev/null
  env UPDATE_PREFLIGHT=1 PORT_SPEED_MBPS="$port_mbps" bash "$target_profile" preflight >/dev/null
  parent="$(dirname "$checkpoint")"; name="$(basename "$checkpoint")"
  [ -d "$parent" ] || install -d -o root -g root -m 0700 "$parent"
  [ ! -L "$parent" ] && [ "$(stat -c '%u' "$parent")" = 0 ] && [ $((8#$(stat -c '%a' "$parent") & 0022)) -eq 0 ] || die 'checkpoint 父目录不安全。'
  checkpoint="$(readlink -f "$parent")/${name}"; install -d -o root -g root -m 0700 "$checkpoint"
  install -o root -g root -m 0700 "$source_profile" "${checkpoint}/source-profile.sh"
  install -o root -g root -m 0700 "$target_profile" "${checkpoint}/target-profile.sh"
  install -o root -g root -m 0700 "${BASH_SOURCE[0]}" "${checkpoint}/dvt-migrate.sh"
  source_hash="$(sha256sum "${checkpoint}/source-profile.sh" | awk '{print $1}')"; target_hash="$(sha256sum "${checkpoint}/target-profile.sh" | awk '{print $1}')"; tool_hash="$(sha256sum "${checkpoint}/dvt-migrate.sh" | awk '{print $1}')"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; current_boot="$(boot_id)"
  jq -n --arg version "$TOOL_VERSION" --arg utc "$now" --arg source "$source_version" --arg target "$target_version" \
    --arg profile "$profile_id" --argjson port "$port_mbps" --arg state "$state_sha256" --arg boot "$current_boot" \
    --arg source_hash "$source_hash" --arg target_hash "$target_hash" --arg tool_hash "$tool_hash" \
    '{schema_version:1,tool_version:$version,phase:"PREPARED",created_utc:$utc,updated_utc:$utc,source_version:$source,target_version:$target,profile_id:$profile,port_speed_mbps:$port,source_state_sha256:$state,prepare_boot_id:$boot,reboot_gate_boot_id:null,assets:{source_profile:{file:"source-profile.sh",sha256:$source_hash},target_profile:{file:"target-profile.sh",sha256:$target_hash},migration_tool:{file:"dvt-migrate.sh",sha256:$tool_hash}},history:[{phase:"PREPARED",utc:$utc,boot_id:$boot}]}' >"${checkpoint}/migration.json"
  chmod 0600 "${checkpoint}/migration.json"
  info "checkpoint 已准备且未修改系统：${checkpoint}"
  info "下一步：bash ${checkpoint}/dvt-migrate.sh rollback --checkpoint ${checkpoint}"
}

rollback_stage() {
  local phase current_hash
  validate_checkpoint; phase="$(jq -r '.phase' "${checkpoint}/migration.json")"
  case "$phase" in
    PREPARED)
      current_hash="$(sha256sum "$STATE_FILE" 2>/dev/null | awk '{print $1}')"
      [ "$current_hash" = "$(jq -r '.source_state_sha256' "${checkpoint}/migration.json")" ] || die 'rollback 前 managed state 已漂移。'
      update_phase ROLLBACK_RUNNING
      PURGE_CREATED_SWAP=1 bash "${checkpoint}/source-profile.sh" rollback
      ;;
    ROLLBACK_RUNNING) [ ! -e "$STATE_FILE" ] || PURGE_CREATED_SWAP=1 bash "${checkpoint}/source-profile.sh" rollback ;;
    *) die "当前 phase=${phase} 不能执行 rollback。" ;;
  esac
  [ ! -e "$STATE_FILE" ] && [ ! -L "$STATE_FILE" ] || die '旧版 rollback 后 managed state 仍存在；停止迁移。'
  update_phase ROLLED_BACK_REBOOT_REQUIRED "$(boot_id)"
  info '旧版已回退。现在必须重启；重启前不得执行 continue。'
}

continue_stage() {
  local phase gate current target_version profile port state_version state_phase
  validate_checkpoint; phase="$(jq -r '.phase' "${checkpoint}/migration.json")"; current="$(boot_id)"
  target_version="$(jq -r '.target_version' "${checkpoint}/migration.json")"; profile="$(jq -r '.profile_id' "${checkpoint}/migration.json")"; port="$(jq -r '.port_speed_mbps' "${checkpoint}/migration.json")"
  case "$phase" in
    ROLLED_BACK_REBOOT_REQUIRED)
      gate="$(jq -r '.reboot_gate_boot_id' "${checkpoint}/migration.json")"; [ "$current" != "$gate" ] || die '第一次重启尚未发生；boot ID 未变化。'
      [ ! -e "$STATE_FILE" ] || die '第一次重启后出现非预期 managed state。'
      update_phase APPLY_RUNNING
      env PORT_SPEED_MBPS="$port" bash "${checkpoint}/target-profile.sh" preflight
      env PORT_SPEED_MBPS="$port" bash "${checkpoint}/target-profile.sh" apply
      ;;
    APPLY_RUNNING)
      if [ ! -e "$STATE_FILE" ]; then
        env PORT_SPEED_MBPS="$port" bash "${checkpoint}/target-profile.sh" preflight
        env PORT_SPEED_MBPS="$port" bash "${checkpoint}/target-profile.sh" apply
      fi
      ;;
    TARGET_APPLIED_REBOOT_REQUIRED) ;;
    VERIFY_RUNNING) ;;
    *) die "当前 phase=${phase} 不能执行 continue。" ;;
  esac
  if [ "$phase" = ROLLED_BACK_REBOOT_REQUIRED ] || [ "$phase" = APPLY_RUNNING ]; then
    state_version="$(jq -r '.script_version // empty' "$STATE_FILE")"; state_phase="$(jq -r '.state // empty' "$STATE_FILE")"
    if [ "$state_version" != "$target_version" ] ||
      [ "$(jq -r '.profile.id // empty' "$STATE_FILE")" != "$profile" ] ||
      { [ "$state_phase" != APPLIED ] && [ "$state_phase" != VERIFIED ]; }; then
      die '目标 apply 后 managed state 契约不匹配。'
    fi
    update_phase TARGET_APPLIED_REBOOT_REQUIRED "$current"
    info '目标版已 apply。现在必须第二次重启；重启前不得再次执行 continue。'
    return 0
  fi
  if [ "$phase" = TARGET_APPLIED_REBOOT_REQUIRED ]; then
    gate="$(jq -r '.reboot_gate_boot_id' "${checkpoint}/migration.json")"; [ "$current" != "$gate" ] || die '第二次重启尚未发生；boot ID 未变化。'
    update_phase VERIFY_RUNNING
  fi
  bash "${checkpoint}/target-profile.sh" verify
  state_version="$(jq -r '.script_version // empty' "$STATE_FILE")"; state_phase="$(jq -r '.state // empty' "$STATE_FILE")"
  [ "$state_version" = "$target_version" ] && [ "$state_phase" = VERIFIED ] || die '最终 verify 未形成目标版本 VERIFIED 状态。'
  update_phase COMPLETE
  info '迁移 checkpoint 已完成。目标 VPS 的控制台可达性和真实业务链路仍需独立验收。'
}

main() {
  parse_args "$@"; [ "$(id -u)" -eq 0 ] || die '必须以 root 运行。'
  for command in awk bash chmod date dirname grep id install jq mv readlink sha256sum stat; do need_command "$command"; done
  case "$action" in
    prepare) prepare ;;
    rollback) rollback_stage ;;
    continue) continue_stage ;;
    status) validate_checkpoint; jq '.' "${checkpoint}/migration.json" ;;
    *) usage >&2; die "未知 action：$action" ;;
  esac
}

main "$@"
