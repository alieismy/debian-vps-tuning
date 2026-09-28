#!/usr/bin/env python3
"""在专有 client netns 内验证真实 tc；由 temporary-htb-check.sh 调用。"""
import importlib.util
import json
from pathlib import Path
import signal
import subprocess
import sys
import time
from unittest.mock import patch

import dvt_htb_transaction as h

ROOT = Path(__file__).resolve().parent
IFACE = 'test0'


def wait_for(predicate, seconds=15):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(.1)
    raise AssertionError('native test timed out')


def phase(checkpoint):
    path = checkpoint / 'state.json'
    return json.loads(path.read_text())['phase'] if path.exists() else None


def collector_gone():
    namespace = Path('/proc/self/ns/net').stat().st_ino
    for proc in Path('/proc').iterdir():
        if not proc.name.isdigit():
            continue
        try:
            if (proc / 'comm').read_text().strip() == 'iperf3' and (proc / 'ns/net').stat().st_ino == namespace:
                return False
        except (FileNotFoundError, ProcessLookupError):
            pass
    return True


def reset_fq():
    h.execute(['tc', 'qdisc', 'replace', 'dev', IFACE, 'root', 'handle', '100:', 'fq',
               'limit', '2345', 'flow_limit', '80', 'quantum', '1600', 'initial_quantum', '6400',
               'maxrate', '100mbit', 'low_rate_threshold', '550kbit', 'refill_delay', '30ms',
               'timer_slack', '12000ns', 'horizon', '8s', 'horizon_cap'])
    return h.snapshot(IFACE)


def assert_restored(checkpoint, original):
    assert phase(checkpoint) == 'RESTORED', (checkpoint, phase(checkpoint))
    assert h.equivalent(original, h.snapshot(IFACE)), h.snapshot(IFACE)
    state, _ = h.load(checkpoint)
    ident = state['identity']
    assert not (Path('/run/dvt-temporary-htb') / f"{ident['netns']}-{ident['ifindex']}.json").exists()


def transaction_cases():
    original = reset_fq()
    transaction = h.Transaction(IFACE, ROOT / 'normal', 60)
    transaction.begin()
    contender = h.Transaction(IFACE, ROOT / 'contender', 60)
    try:
        contender.begin()
        raise AssertionError('concurrent transaction accepted')
    except BlockingIOError:
        pass
    transaction.set_rate(2)
    transaction.assert_active(2)
    transaction.set_rate(3)
    transaction.assert_active(3)
    # UP 是开始条件，不能阻断同一接口 down 后恢复。
    h.execute(['ip', 'link', 'set', IFACE, 'down'])
    transaction.close()
    h.execute(['ip', 'link', 'set', IFACE, 'up'])
    assert_restored(transaction.checkpoint, original)
    print('PASS customized fq, rate change, contention, interface-down recovery', flush=True)

    real_execute = h.execute
    for failure in ('root', 'class', 'leaf'):
        original = reset_fq()
        transaction = h.Transaction(IFACE, ROOT / ('failure-' + failure), 60)
        transaction.begin()

        def fail_one(argv):
            hit = (failure == 'root' and argv[:3] == ['tc', 'qdisc', 'replace'] and 'root' in argv or
                   failure == 'class' and argv[:3] == ['tc', 'class', 'replace'] or
                   failure == 'leaf' and argv[:3] == ['tc', 'qdisc', 'replace'] and 'parent' in argv)
            if hit:
                raise h.HTBError('injected ' + failure)
            return real_execute(argv)

        with patch.object(h, 'execute', side_effect=fail_one):
            try:
                transaction.set_rate(2)
                raise AssertionError('failure was not injected')
            except h.HTBError as exc:
                assert 'injected' in str(exc), exc
        transaction.close()
        assert_restored(transaction.checkpoint, original)
        print('PASS partial write recovery: ' + failure, flush=True)

    original = reset_fq()
    transaction = h.Transaction(IFACE, ROOT / 'foreign', 60)
    transaction.begin()
    transaction.set_rate(2)
    state, _ = h.load(transaction.checkpoint)
    h.execute(['tc', 'class', 'change', 'dev', IFACE, 'parent', state['root_handle'],
               'classid', state['root_handle'] + '1', 'htb', 'rate', '7mbit', 'ceil', '7mbit'])
    foreign = h.snapshot(IFACE)
    for restore in (transaction.close, lambda: h.restore(transaction.checkpoint)):
        try:
            restore()
            raise AssertionError('foreign parameters overwritten')
        except h.HTBError:
            assert h.normalized(h.snapshot(IFACE)) == h.normalized(foreign)
    assert phase(transaction.checkpoint) == 'RECOVERY_REQUIRED'
    # 仅测试夹具作为管理员恢复，不让产品越过 foreign gate。
    reset_fq()
    h.restore(transaction.checkpoint)
    assert_restored(transaction.checkpoint, original)
    transaction.watchdog.wait(timeout=5)
    print('PASS foreign parameter drift remains refused on retry', flush=True)


def watchdog_cases():
    for name, lifetime in (('kill-owner', 60), ('expiry', 2)):
        original = reset_fq()
        checkpoint = ROOT / name
        with (ROOT / (name + '.log')).open('w') as log:
            owner = subprocess.Popen([sys.executable, __file__, '--owner', str(checkpoint), str(lifetime),
                                      'ignore-term' if name == 'expiry' else 'default'],
                                     stdout=log, stderr=subprocess.STDOUT)
            try:
                wait_for(lambda: phase(checkpoint) == 'ACTIVE')
                if name == 'kill-owner':
                    owner.kill()
                owner.wait(timeout=15)
                wait_for(lambda: phase(checkpoint) == 'RESTORED')
                assert_restored(checkpoint, original)
            finally:
                if owner.poll() is None:
                    owner.kill()
                    owner.wait()
        print('PASS independent watchdog: ' + name, flush=True)


def measurement_cases():
    spec = importlib.util.spec_from_file_location('measure', ROOT / 'dvt-measure.py')
    measure = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(measure)
    for name, sig in (('complete', None), ('int', signal.SIGINT), ('term', signal.SIGTERM)):
        original = reset_fq()
        output = ROOT / ('measure-' + name)
        ledger = ROOT / ('budget-' + name) / 'ledger.json'
        command = [sys.executable, str(ROOT / 'dvt-measure.py'), 'htb-sweep', '--interface', IFACE,
                   '--lower', '10', '--upper', '20', '--rate-cap', '25', '--seconds', '5',
                   '--host', '192.0.2.2', '--family', '4', '--max-duration', '240', '--budget-mib', '600',
                   '--ledger', str(ledger), '--window-id', name, '--output-dir', str(output), '--yes']
        log_path = ROOT / (name + '-measurement.log')
        with log_path.open('w') as log:
            child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                if sig:
                    wait_for(lambda: phase(output / 'htb-transaction') == 'ACTIVE' or child.poll() is not None, 30)
                    assert child.poll() is None, log_path.read_text()
                    time.sleep(1)
                    child.send_signal(sig)
                code = child.wait(timeout=260)
                assert code == (130 if sig == signal.SIGINT else 143 if sig else 0), log_path.read_text()
                print(log_path.read_text(), flush=True)
                events = json.loads((output / 'attempts.json').read_text())
                print('attempt outcomes:', [{k: e.get(k) for k in ('role', 'status', 'issues', 'error')}
                                            for e in events], flush=True)
                assert_restored(output / 'htb-transaction', original)
                budget = json.loads(ledger.read_text())
                assert budget['reserved_bytes'] == 0 and budget['accounted_bytes'] > 0, budget
                wait_for(collector_gone, 5)
                if sig:
                    assert (output / 'INCOMPLETE').exists() and not (output / 'COMPLETED').exists()
                else:
                    result = measure.verify_report(output)
                    assert result['configuration_observation']['status'] == 'UNCHANGED', result
                    assert len(result['samples']) >= 18, result
                    assert all(row['htb_overlimits_delta'] > 0 for row in result['samples']), result
                    print('native sample eligibility:', sum(row['eligible'] for row in result['samples']),
                          '/', len(result['samples']), 'analysis:', result['analysis']['status'], flush=True)
            finally:
                if child.poll() is None:
                    child.terminate()
                    child.wait(timeout=20)
                if child.returncode not in (0, 130, 143):
                    print(log_path.read_text(), flush=True)
                    for error_log in output.glob('*.log'):
                        print(error_log.name, error_log.read_text(), flush=True)
        print('PASS real HTB collector / ledger / restoration: ' + name, flush=True)


if __name__ == '__main__':
    if len(sys.argv) == 5 and sys.argv[1] == '--owner':
        if sys.argv[4] == 'ignore-term':
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
        transaction = h.Transaction(IFACE, Path(sys.argv[2]), int(sys.argv[3]))
        transaction.begin()
        transaction.set_rate(2)
        while True:
            time.sleep(1)
    else:
        transaction_cases()
        watchdog_cases()
        measurement_cases()
        print('temporary HTB native checks passed', flush=True)
