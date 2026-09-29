#!/usr/bin/env bash
# 仅供隔离、可丢弃的 CI 虚拟机；不在用户 VPS 上自动执行。
set -Eeuo pipefail
export LC_ALL=C
cd /root/dvt-bundle
evidence=/root/dvt-evidence
state=/var/lib/proxy-vps-tuning/state.json
mkdir -p "$evidence"

snapshot() {
  python3 - "$1" <<'PY'
import json, pathlib, re, subprocess, sys
source = pathlib.Path('debian13-1c1g-vps-tuning.sh').read_text()
keys = re.search(r'PROFILE_SYSCTL_KEYS=\((.*?)\n\)', source, re.S)[1].split()
values = {k: ' '.join(subprocess.check_output(['sysctl', '-n', k], text=True).split()) for k in keys}
pathlib.Path('/root/dvt-evidence/' + sys.argv[1] + '.sysctl.json').write_text(json.dumps(values, sort_keys=True))
qdiscs = json.loads(subprocess.check_output(['tc', '-j', 'qdisc', 'show'], text=True))
pathlib.Path('/root/dvt-evidence/' + sys.argv[1] + '.qdisc.json').write_text(json.dumps(qdiscs, sort_keys=True))
PY
}

case "$1" in
  apply)
    # 模块加载是 VM 的测试前置；没有伪造内核能力或替换系统识别。
    modprobe tcp_bbr
    modprobe sch_fq
    cat /etc/os-release >"$evidence/os-release"
    uname -a >"$evidence/uname.txt"
    getconf PAGESIZE >"$evidence/page-size.txt"
    cat /proc/meminfo >"$evidence/meminfo.txt"
    cat /proc/sys/kernel/random/boot_id >"$evidence/boot-before"
    test ! -e "$state"
    snapshot before
    bash install.sh --source-dir /root/dvt-bundle --no-launch
    bash install.sh --source-dir /root/dvt-bundle --no-launch
    dvt preflight --port 1
    dvt apply --port 1
    dvt verify
    cp "$state" "$evidence/initial-state.json"
    dvt apply --port 1
    # 第二次 apply 应只验证，不重写状态或受管文件。
    cmp "$state" "$evidence/initial-state.json"
    dvt reconfigure --port 10000
    dvt verify
    cp "$state" "$evidence/high-port-state.json"
    dvt reconfigure --port 1
    dvt verify
    cp "$state" "$evidence/before-reboot-state.json"
    ;;
  after-reboot)
    test "$(cat /proc/sys/kernel/random/boot_id)" != "$(cat "$evidence/boot-before")"
    cat /proc/sys/kernel/random/boot_id >"$evidence/boot-after"
    dvt verify
    dvt apply --port 1
    cp "$state" "$evidence/after-reboot-state.json"
    jq -e '.schema_version==4 and .state=="VERIFIED" and
      (.profile.os_id=="debian" or .profile.os_id=="ubuntu") and
      (.profile.architecture=="x86_64" or .profile.architecture=="aarch64") and
      (if .profile.os_id=="ubuntu" then .profile.debian_version==null else true end)' "$state" >/dev/null
    PURGE_CREATED_SWAP=1 dvt rollback
    test ! -e "$state"
    snapshot rollback
    cmp "$evidence/before.sysctl.json" "$evidence/rollback.sysctl.json"
    # managed_files 来自真实应用状态；逐个核对回滚后没有遗留。
    jq -r '.managed_files[].path' "$evidence/before-reboot-state.json" |
      while IFS= read -r path; do test ! -e "$path"; done
    test ! -e /swapfile-proxy
    cat /proc/sys/kernel/random/boot_id >"$evidence/rollback-boot-before"
    ;;
  after-rollback-reboot)
    test "$(cat /proc/sys/kernel/random/boot_id)" != "$(cat "$evidence/rollback-boot-before")"
    cat /proc/sys/kernel/random/boot_id >"$evidence/rollback-boot-after"
    test ! -e "$state"
    snapshot final
    cmp "$evidence/before.sysctl.json" "$evidence/final.sysctl.json"
    python3 - <<'PY'
import json, pathlib
p = pathlib.Path('/root/dvt-evidence')
def roots(name):
    return {q['dev']: q for q in json.loads((p / (name + '.qdisc.json')).read_text()) if q.get('root')}
before = roots('before')
for name in ('rollback', 'final'):
    after = roots(name)
    assert before.keys() == after.keys(), (name, 'interfaces changed')
    for dev, saved in before.items():
        current = after[dev]
        assert saved['kind'] == current['kind'], (name, dev, 'root kind changed')
        assert saved.get('options', {}) == current.get('options', {}), (name, dev, 'options changed')
print('PASS install/apply/idempotence/reconfigure/reboot/verify/rollback/reboot')
(p / 'COMPLETED').write_text('Functional VM lifecycle; no proxy business or performance acceptance\n')
PY
    ;;
  *) exit 2 ;;
esac
