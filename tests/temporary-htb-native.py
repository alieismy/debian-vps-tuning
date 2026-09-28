#!/usr/bin/env python3
"""在专有 client netns 内验证真实 tc；由 temporary-htb-check.sh 调用。"""
import importlib.util
import json
from pathlib import Path
import signal
import re
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
    assert h.snapshot(IFACE) == original, 'restore syntax preflight changed qdisc'
    state, _ = h.load(transaction.checkpoint)
    assert state['restore_fq_argv'] in h.fq_restore_arg_variants(original['qdiscs'][0]['options'])
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
                for event in events:
                    if event.get('issues'):
                        directory = output / event['directory']
                        raw = json.loads((directory / 'upload.iperf3.json').read_text())
                        print('resource evidence:', measure.resource_observation(directory, raw), flush=True)
                assert_restored(output / 'htb-transaction', original)
                budget = json.loads(ledger.read_text())
                assert budget['reserved_bytes'] == 0 and budget['accounted_bytes'] > 0, budget
                wait_for(collector_gone, 5)
                if sig:
                    assert (output / 'INCOMPLETE').exists() and not (output / 'COMPLETED').exists()
                else:
                    result = measure.verify_report(output)
                    observation = result['configuration_observation']
                    # default_qdisc 只在初始 netns 暴露；不能伪造为已观察，也不能丢掉产品门禁。
                    assert not observation['changed_fields'], observation
                    assert set(observation['unavailable_fields']) <= {'default_qdisc'}, observation
                    if observation['unavailable_fields']:
                        assert observation['status'] == 'UNAVAILABLE', observation
                        assert result['analysis']['status'] == 'INSUFFICIENT_EVIDENCE'
                        assert result['analysis']['candidate_interval'] is None
                    else:
                        assert observation['status'] == 'UNCHANGED', observation
                    assert result['configuration_changed']
                    assert len(result['samples']) >= 24, len(result['samples'])
                    assert all(row['htb_overlimits_delta'] > 0 for row in result['samples'])
                    assert any(row['eligible'] for row in result['samples'])
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


def low_rate_window_cases():
    """低速短窗对照；所有 sysctl 和流量仅在测试专用 netns 内。"""
    h.execute(['sysctl', '-w', 'net.ipv4.tcp_wmem=4096 65536 67108864'])
    available = h.execute(['sysctl', '-n', 'net.ipv4.tcp_available_congestion_control'])
    # 已部署主机使用 BBR；若 runner 未提供则显式报告实际算法。
    if 'bbr' in available.split():
        h.execute(['sysctl', '-w', 'net.ipv4.tcp_congestion_control=bbr'])
    print('sampling congestion control:', h.execute(['sysctl', '-n', 'net.ipv4.tcp_congestion_control']), flush=True)
    results = []
    for name, seconds, extra in (
        ('default', 5, []), ('block16k', 5, ['--length', '16384']),
        ('window64k', 5, ['--window', '65536']), ('window32k', 5, ['--window', '32768']),
        ('window32k-block16k', 5, ['--window', '32768', '--length', '16384']),
        ('long-window', 30, []),
    ):
        original = reset_fq()
        transaction = h.Transaction(IFACE, ROOT / ('sampling-' + name), 90)
        transaction.begin()
        try:
            transaction.set_rate(2)
            child = subprocess.Popen(['iperf3', '-c', '192.0.2.2', '-p', '5201', '-t', str(seconds),
                                      '-b', '5M', '-J', *extra], stdout=subprocess.PIPE, text=True)
            notsent = []
            while child.poll() is None:
                socket = h.execute(['ss', '-tinm', 'dst', '192.0.2.2'])
                notsent += [int(v) for v in re.findall(r'notsent:(\d+)', socket)]
                time.sleep(.2)
            stdout, _ = child.communicate(timeout=3)
            assert child.returncode == 0, stdout
            raw = json.loads(stdout)
            (ROOT / (name + '-sampling.json')).write_text(stdout)
            sent, received = raw['end']['sum_sent'], raw['end']['sum_received']
            result = dict(case=name, seconds=seconds, sent=sent['bytes'], received=received['bytes'],
                          sender_mbps=sent['bits_per_second'] / 1e6,
                          receiver_mbps=received['bits_per_second'] / 1e6,
                          sender_seconds=sent['seconds'], receiver_seconds=received['seconds'],
                          max_notsent=max(notsent, default=0))
            results.append(result)
            print('low-rate sampling:', json.dumps(result), flush=True)
        finally:
            if 'child' in locals() and child.poll() is None:
                child.terminate()
                child.wait(timeout=5)
            transaction.close()
        assert_restored(transaction.checkpoint, original)
    assert results[0]['receiver_mbps'] < results[0]['sender_mbps'] * .8, results[0]
    print('PASS reproduced short-window send backlog in isolated Linux', flush=True)


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
        low_rate_window_cases()
        measurement_cases()
        print('temporary HTB native checks passed', flush=True)
