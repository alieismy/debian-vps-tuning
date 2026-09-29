#!/usr/bin/env python3
"""在 CI runner 内创建隔离 QEMU 客体，验证原生平台与两次真实重启。"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def run(argv, **kwargs):
    return subprocess.run(argv, check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', choices=['debian12', 'debian13', 'ubuntu2404'], required=True)
    parser.add_argument('--arch', choices=['amd64', 'arm64'], required=True)
    args = parser.parse_args()
    work = ROOT / '.tmp/platform-vm'
    work.mkdir(parents=True, exist_ok=False)
    evidence = work / 'evidence'
    evidence.mkdir()
    os.chmod(work, 0o700)
    spec = json.loads((ROOT / 'tests/platform-images.json').read_text())[args.platform][args.arch]
    (evidence / 'image.json').write_text(json.dumps(spec, indent=2))
    image = work / 'base.qcow2'
    urllib.request.urlretrieve(spec['url'], image)
    with image.open('rb') as f:
        digest = hashlib.file_digest(f, spec['algorithm']).hexdigest()
    assert digest == spec['digest'], 'official image checksum mismatch'
    run(['qemu-img', 'create', '-f', 'qcow2', '-F', 'qcow2', '-b', str(image), str(work / 'disk.qcow2'), '12G'])
    for name in ('client', 'host'):
        run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(work / name)])
    user_data = {
        'disable_root': False, 'ssh_pwauth': False,
        'users': [{'name': 'root', 'lock_passwd': True,
                   'ssh_authorized_keys': [(work / 'client.pub').read_text().strip()]}],
        'ssh_keys': {'ed25519_private': (work / 'host').read_text(),
                     'ed25519_public': (work / 'host.pub').read_text().strip()},
        'package_update': True,
        'packages': ['jq', 'iproute2', 'procps', 'kmod', 'util-linux', 'python3', 'curl'],
        'runcmd': [['touch', '/root/dvt-cloud-ready']],
    }
    (work / 'user-data').write_text('#cloud-config\n' + json.dumps(user_data))
    (work / 'meta-data').write_text('instance-id: dvt-lifecycle\nlocal-hostname: dvt-ci\n')
    run(['cloud-localds', str(work / 'seed.img'), str(work / 'user-data'), str(work / 'meta-data')])
    (work / 'known-hosts').write_text('[127.0.0.1]:2222 ' + (work / 'host.pub').read_text())
    ssh = ['ssh', '-i', str(work / 'client'), '-o', 'BatchMode=yes', '-o', 'IdentitiesOnly=yes',
           '-o', 'StrictHostKeyChecking=yes', '-o', 'UserKnownHostsFile=' + str(work / 'known-hosts'),
           '-o', 'ConnectTimeout=5', '-p', '2222', 'root@127.0.0.1']
    qemu = ['qemu-system-' + ('x86_64' if args.arch == 'amd64' else 'aarch64')]
    kvm = os.access('/dev/kvm', os.R_OK | os.W_OK)
    qemu += ['-accel', 'kvm' if kvm else 'tcg', '-cpu', 'host' if kvm else ('max' if args.arch == 'arm64' else 'qemu64')]
    if args.arch == 'arm64':
        qemu += ['-machine', 'virt', '-bios', '/usr/share/qemu-efi-aarch64/QEMU_EFI.fd']
    # KVM 覆盖 4C4G；TCG 的 ARM 客体用 2C1.5G 降低软件模拟内存初始化开销。
    # 两者都超出旧组合表；更大 RAM 的封顶另有架构无关的边界回归。
    vcpus, ram_mib = (4, 4096) if kvm else (2, 1536)
    qemu += ['-smp', str(vcpus), '-m', str(ram_mib), '-nographic',
             '-drive', f'file={work / "disk.qcow2"},if=virtio,format=qcow2',
             '-drive', f'file={work / "seed.img"},if=virtio,format=raw',
             '-nic', 'user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22']
    (evidence / 'hypervisor.json').write_text(json.dumps({'arch': args.arch, 'acceleration': 'kvm' if kvm else 'tcg',
                                                       'vcpus': vcpus, 'ram_mib': ram_mib}))
    serial = (evidence / 'serial.log').open('wb')
    vm = subprocess.Popen(qemu, stdout=serial, stderr=subprocess.STDOUT)

    def wait_guest(command, timeout=1500):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if vm.poll() is not None:
                raise RuntimeError('QEMU exited; see serial.log')
            try:
                result = subprocess.run(ssh + [command], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=45)
            except subprocess.TimeoutExpired:
                # TCG 冷启动可能在建立连接后长时间等待 CPU；仍受整轮期限约束。
                continue
            if b'REMOTE HOST IDENTIFICATION HAS CHANGED' in result.stderr:
                raise RuntimeError('guest host key mismatch')
            if result.returncode == 0:
                return result.stdout.decode().strip()
            time.sleep(5)
        raise TimeoutError('guest readiness timeout; see serial.log')

    def phase(name):
        with (evidence / (name + '.log')).open('wb') as log:
            run(ssh + ['bash /root/dvt-bundle/tests/platform-guest.sh ' + name], stdout=log, stderr=subprocess.STDOUT, timeout=600)

    def reboot():
        old_boot = wait_guest('cat /proc/sys/kernel/random/boot_id')
        run(ssh + ['systemctl reboot'], timeout=20)
        wait_guest('test "$(cat /proc/sys/kernel/random/boot_id)" != ' + old_boot + ' && systemctl is-active ssh', timeout=600)

    try:
        wait_guest('test -f /root/dvt-cloud-ready')
        # tar stdin 只传固定资产和客体用例，避免复制私有临时材料。
        names = [line.split('  ', 1)[1] for line in (ROOT / 'SHA256SUMS').read_text().splitlines()]
        bundle = work / 'bundle.tar'
        run(['tar', '-cf', str(bundle), 'install.sh', 'SHA256SUMS', 'tests/platform-guest.sh',
             'tests/platform-htb-native.py', *names], cwd=ROOT)
        with bundle.open('rb') as f:
            run(ssh + ['mkdir /root/dvt-bundle && tar --no-same-owner -xf - -C /root/dvt-bundle'], stdin=f)
        phase('apply')
        reboot()
        phase('after-reboot')
        reboot()
        phase('after-rollback-reboot')
        (evidence / 'COMPLETED').write_text('PASS native guest lifecycle\n')
    finally:
        try:
            with (evidence / 'guest-evidence.tar').open('wb') as f:
                subprocess.run(ssh + ['tar -cf - -C /root dvt-evidence'], stdout=f, stderr=subprocess.DEVNULL, timeout=30)
        finally:
            vm.terminate()
            try:
                vm.wait(timeout=20)
            except subprocess.TimeoutExpired:
                vm.kill()
                vm.wait()
            serial.close()
    print('PASS', args.platform, args.arch, 'two real guest reboots', flush=True)


if __name__ == '__main__':
    main()
