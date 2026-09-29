#!/usr/bin/env bash
# 仅修改本测试创建的两个 netns/veth；流量不离开 runner。
set -Eeuo pipefail
[ "$(id -u)" -eq 0 ] || { echo 'temporary HTB native check requires root' >&2; exit 1; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d /tmp/dvt-native-htb.XXXXXXXX)"
client="dvt-htb-c-$$"
server="dvt-htb-s-$$"
client_created=0
server_created=0
cleanup() {
  local ns pid
  for ns in "$client" "$server"; do
    if { [ "$ns" = "$client" ] && [ "$client_created" = 1 ]; } ||
       { [ "$ns" = "$server" ] && [ "$server_created" = 1 ]; }; then
      while IFS= read -r pid; do kill "$pid" 2>/dev/null || true; done < <(ip netns pids "$ns")
      ip netns delete "$ns"
    fi
  done
  # root 私有 mktemp，只包含测试副本；失败日志已输出到 CI。
  rm -rf -- "$test_root"
}
trap cleanup EXIT
chmod 0700 "$test_root"
while IFS= read -r file; do
  mkdir -p -- "${test_root}/$(dirname "$file")"
  cp -- "${repo_root}/${file}" "${test_root}/${file}"
done < <(awk '{print $2}' "${repo_root}/SHA256SUMS")
cp -- "${repo_root}/SHA256SUMS" "${repo_root}/tests/temporary-htb-native.py" "$test_root/"
ip netns add "$client"
client_created=1
ip netns add "$server"
server_created=1
ip -n "$client" link add test0 type veth peer name peer0 netns "$server"
ip -n "$client" addr add 192.0.2.1/24 dev test0
ip -n "$server" addr add 192.0.2.2/24 dev peer0
ip -n "$client" link set lo up
ip -n "$server" link set lo up
ip -n "$client" link set test0 up
ip -n "$server" link set peer0 up
ip netns exec "$server" iperf3 --server --port 5201 >"${test_root}/server.log" 2>&1 &
ip netns exec "$client" python3 "${test_root}/temporary-htb-native.py"
