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
  grep -Fq "SCRIPT_VERSION='0.1.0-rc.1'" "$script"
  grep -Fq "STATE_SCHEMA_VERSION=3" "$script"
  grep -Fq "SWAP_FILE='/swapfile-proxy'" "$script"
  grep -Fq 'x-ui.service' "$script"
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT
for script in "${scripts[@]}"; do
  helper="$tmp_dir/${script}.helper"
  awk "/^  write_managed_file .*FQ_HELPER.*<<'EOF_HELPER'/ {inside=1; next} /^EOF_HELPER$/ {inside=0} inside" "$script" >"$helper"
  [ -s "$helper" ] || { printf 'failed to extract helper: %s\n' "$script" >&2; exit 1; }
  bash -n "$helper"
done

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "${scripts[@]}" tests/static-check.sh
  for helper in "$tmp_dir"/*.helper; do shellcheck -x "$helper"; done
else
  printf '[WARN] shellcheck not found; syntax and structural checks only\n' >&2
fi

printf 'static checks passed for %s scripts\n' "${#scripts[@]}"
