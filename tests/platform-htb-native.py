#!/usr/bin/env python3
"""已应用 BBR+fq 的一次性 VM：不发测速流量，验证 root-zero 与看护恢复。"""
import json
from pathlib import Path
import signal
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import dvt_htb_transaction as h

ROOT = Path('/root/dvt-evidence/htb')


def phase(path):
    file = path / 'state.json'
    return json.loads(file.read_text())['phase'] if file.exists() else None


def wait_for(predicate, seconds=40):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(.2)
    raise TimeoutError('VM HTB lifecycle timed out')


def main():
    if len(sys.argv) == 5:
        _, iface, checkpoint, lifetime, mode = sys.argv
        if mode == 'expiry':
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
        transaction = h.Transaction(iface, Path(checkpoint), int(lifetime))
        transaction.begin()
        transaction.set_rate(2)
        while True:
            time.sleep(1)
    ROOT.mkdir(mode=0o700)
    route = json.loads(subprocess.check_output(['ip', '-j', 'route', 'get', '192.0.2.1']))
    iface = route[0]['dev']
    assert subprocess.check_output(['sysctl', '-n', 'net.core.default_qdisc'], text=True).strip() == 'fq'
    for mode in ('normal', 'kill-owner', 'expiry'):
        # VM 专属接口；内核根据持久 apply 的 default_qdisc 重新创建 fq 0:。
        h.execute(['tc', 'qdisc', 'del', 'dev', iface, 'root'])
        original = h.snapshot(iface)
        root = next(q for q in original['qdiscs'] if q.get('root'))
        assert root['kind'] == 'fq' and root['handle'] == '0:', original
        checkpoint = ROOT / mode
        if mode == 'normal':
            transaction = h.Transaction(iface, checkpoint, 60)
            transaction.begin()
            transaction.set_rate(2)
            transaction.assert_active(2)
            transaction.close()
        else:
            with (ROOT / (mode + '.log')).open('w') as log:
                owner = subprocess.Popen([sys.executable, __file__, iface, str(checkpoint),
                                          '5' if mode == 'expiry' else '60', mode],
                                         stdout=log, stderr=subprocess.STDOUT)
                try:
                    wait_for(lambda: phase(checkpoint) == 'ACTIVE')
                    if mode == 'kill-owner':
                        owner.kill()
                    owner.wait(timeout=40)
                    wait_for(lambda: phase(checkpoint) == 'RESTORED')
                finally:
                    if owner.poll() is None:
                        owner.kill()
                        owner.wait()
        assert phase(checkpoint) == 'RESTORED'
        assert h.equivalent(original, h.snapshot(iface))
        state, _ = h.load(checkpoint)
        ident = state['identity']
        registry = Path('/run/dvt-temporary-htb') / f"{ident['netns']}-{ident['ifindex']}.json"
        assert not registry.exists()
        print('PASS fq 0: with full options and', mode, flush=True)


if __name__ == '__main__':
    main()
