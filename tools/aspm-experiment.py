#!/usr/bin/env python3
"""MacBookPro13,2 Thunderbolt L1 diagnostics and attended A/B/A trial.

No boot service, native policy write, or suspend hook is installed. `inspect`
and `sample` never write PCI configuration. `trial` restores the L1 bit on exit;
`restore` recovers a saved receipt after an interrupted trial.
"""
import argparse
import csv
import fcntl
import json
import os
from pathlib import Path
import select
import signal
import statistics
import subprocess
import sys
import time

PCI = Path('/sys/bus/pci/devices')
BAT = Path('/sys/class/power_supply/BAT0')
STATE = Path('/var/lib/macbook-aspm-experiment')
ROOTS = {'0000:00:1c.4': '8086:9d14', '0000:00:1d.0': '8086:9d18'}
TB_IDS = {'8086:1578', '8086:15d3', '8086:15d2', '8086:15d4'}
L1 = 2


def text(path):
    return Path(path).read_text().strip()


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=10).strip()


def config(bdf, register):
    value = run('/usr/sbin/setpci', '-s', bdf, register)
    if not value or any(c not in '0123456789abcdefABCDEF' for c in value):
        raise RuntimeError(f'{bdf}: invalid PCI configuration read: {value!r}')
    result = int(value, 16)
    if result == (0xffff if register.endswith('.w') else 0xffffffff):
        raise RuntimeError(f'{bdf}: inaccessible PCI configuration')
    return result


def identity(path):
    return {
        'bdf': path.name,
        'id': f'{text(path / "vendor")[2:]}:{text(path / "device")[2:]}',
        'path': str(path.resolve()), 'inode': path.stat().st_ino,
    }


def inventory():
    """Physical links only: root/downstream port -> directly attached function.

    An upstream port -> switch downstream port edge is internal to the switch,
    not another physical PCIe link. Empty hotplug ports have no partner and are
    not enabled. Reject unknown/external PCI functions anywhere in either tree.
    """
    nodes = {}
    devices = list(PCI.iterdir())
    for root, expected in ROOTS.items():
        root_path = PCI / root
        if identity(root_path)['id'] != expected:
            raise RuntimeError(f'{root}: unexpected root-port ID')
        base = root_path.resolve()
        for path in devices:
            real = path.resolve()
            if real != base and base not in real.parents:
                continue
            item = identity(path)
            if path.name != root and item['id'] not in TB_IDS:
                raise RuntimeError(f'{path.name}: unknown/external device {item["id"]}; unplug it')
            item.update(type=(config(path.name, 'CAP_EXP+02.w') >> 4) & 15,
                        cap=config(path.name, 'CAP_EXP+0c.L'),
                        ctl=config(path.name, 'CAP_EXP+10.w'))
            nodes[path.name] = item
    links = []
    for parent in nodes.values():
        if parent['type'] not in (4, 6):  # root or downstream port
            continue
        for child in nodes.values():
            if Path(child['path']).parent != Path(parent['path']):
                continue
            if child['type'] not in (0, 1, 5):  # endpoint / legacy endpoint / upstream
                raise RuntimeError(f'{child["bdf"]}: unexpected PCIe partner type')
            links.append((parent, child))
    for root in ROOTS:
        partners = [c for p, c in links if p['bdf'] == root]
        if len(partners) != 1 or partners[0]['type'] != 5:
            raise RuntimeError(f'{root}: expected one internal Thunderbolt upstream partner')
    return nodes, links


def targets(links):
    result = {}
    for parent, child in links:
        if not (parent['cap'] & child['cap'] & (1 << 11)):
            continue
        for node in (parent, child):
            result[node['bdf']] = node
    if not result:
        raise RuntimeError('No paired L1-capable Thunderbolt links found')
    return list(result.values())


def check_model():
    if text('/sys/class/dmi/id/product_name') != 'MacBookPro13,2':
        raise RuntimeError('This tool is restricted to MacBookPro13,2')


def require_root():
    if os.geteuid() != 0:
        raise RuntimeError('Use pkexec /usr/bin/python3 for PCI inspection/trial/restore')


def battery():
    if text(BAT / 'status') != 'Discharging':
        raise RuntimeError('Battery must be discharging; do not connect AC during sampling')
    # Use charge, not the known-unreliable kernel capacity percentage.
    charge, full = int(text(BAT / 'charge_now')), int(text(BAT / 'charge_full'))
    if charge < 0 or full <= 0:
        raise RuntimeError('Invalid battery charge telemetry')
    fraction = charge / full
    if fraction < 0.20:
        raise RuntimeError('Battery below 20% of charge_full; charge before the experiment')
    watts = abs(int(text(BAT / 'current_now'))) * int(text(BAT / 'voltage_now')) / 1e12
    return watts, fraction


def lighting():
    paths = list(Path('/sys/class/backlight').glob('*/*brightness'))
    paths += list(Path('/sys/class/backlight').glob('*/bl_power'))
    paths += list(Path('/sys/class/leds').glob('*kbd*/brightness'))
    return {str(p): text(p) for p in paths}


def idle_warmup():
    # Launching the command is input too. Do not compare a lit-Touch-Bar
    # baseline with an L1 phase after the default 300-second timeout.
    values = [int(text(p)) for p in Path('/sys/bus/hid/drivers/apple-touchbar').glob('*/idle_timeout')]
    return max([0] + values) + 5


def sample(seconds, interval, out, expected_lighting=None):
    writer = csv.writer(out)
    writer.writerow(['elapsed_s', 'watts', 'charge_fraction'])
    values = []
    start = time.monotonic()
    while True:
        watts, fraction = battery()
        if expected_lighting is not None and lighting() != expected_lighting:
            raise RuntimeError('Backlight state changed; aborting invalid power comparison')
        elapsed = time.monotonic() - start
        writer.writerow([f'{elapsed:.3f}', f'{watts:.4f}', f'{fraction:.4f}'])
        out.flush()
        values.append(watts)
        if elapsed >= seconds:
            break
        time.sleep(min(interval, seconds - elapsed))
    return {'samples': len(values), 'mean_w': statistics.mean(values),
            'median_w': statistics.median(values),
            'stdev_w': statistics.pstdev(values)}


def inspect():
    require_root()
    nodes, links = inventory()
    print('Native policy:', text('/sys/module/pcie_aspm/parameters/policy'))
    print('Physical internal TB links (L1 support and enable bit at each end):')
    for p, c in links:
        print(f'  {p["bdf"]} -> {c["bdf"]}: '
              f'cap={bool(p["cap"] & 0x800)}/{bool(c["cap"] & 0x800)} '
              f'enabled={bool(p["ctl"] & L1)}/{bool(c["ctl"] & L1)}')
    paired = {n['bdf'] for n in targets(links)}
    print('Not targeted (empty/unpaired/non-L1 links):',
          ', '.join(sorted(set(nodes) - paired)) or 'none')
    print('NVMe/Wi-Fi are outside these trees and never targeted.')
    print('Kernel ownership/error diagnostics (absence is not proof of OS control):')
    result = subprocess.run(['/usr/bin/journalctl', '-b', '-k', '--no-pager',
                             '--grep=ASPM|_OSC|PCIe Bus Error|AER:'],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)
    print(result.stdout.strip())
    print('Read-only: no policy/configuration changes made.')


def save(receipt):
    temporary = STATE / 'active.tmp'
    with temporary.open('w') as stream:
        json.dump(receipt, stream, indent=2)
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(STATE / 'active.json')
    fd = os.open(STATE, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def same_device(node):
    return identity(PCI / node['bdf']) == {k: node[k] for k in ('bdf', 'id', 'path', 'inode')}


def write_l1(node, bit):
    if not same_device(node):
        raise RuntimeError(f'{node["bdf"]}: identity/topology changed; refusing PCI write')
    # setpci's masked RMW preserves L0s and every unrelated LnkCtl bit.
    run('/usr/sbin/setpci', '-s', node['bdf'], f'CAP_EXP+10.w={bit:04x}:0002')
    if config(node['bdf'], 'CAP_EXP+10.w') & L1 != bit:
        raise RuntimeError(f'{node["bdf"]}: L1 readback mismatch')


def enable(receipt):
    # Whole-plan identity check before the first write.
    for node in receipt['nodes']:
        if not same_device(node):
            raise RuntimeError(f'{node["bdf"]}: topology changed since planning')
    for node in receipt['nodes']:
        write_l1(node, L1)


def restore(receipt):
    if receipt['boot_id'] != text('/proc/sys/kernel/random/boot_id'):
        raise RuntimeError('Receipt is from another boot; refusing to restore stale PCI state')
    errors = []
    # Best effort for all saved devices even if one has disappeared.
    for node in reversed(receipt['nodes']):
        try:
            write_l1(node, node['ctl'] & L1)
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            errors.append(str(error))
    if errors:
        raise RuntimeError('Incomplete restoration; keep active.json: ' + '; '.join(errors))
    archive = STATE / f'{receipt["session"]}-restored.json'
    (STATE / 'active.json').replace(archive)
    print('Original L1 bits restored. Receipt:', archive, file=sys.stderr)


def preflight(args):
    if not (args.touchbar_tested and args.unplugged and args.saved_work
            and args.native_control_unavailable):
        raise RuntimeError('Confirm --touchbar-tested --unplugged --saved-work '
                           '--native-control-unavailable after reading the protocol')
    version = run('/usr/bin/rpm', '-q', '--qf', '%{VERSION}', 'akmod-macbook-t1-touchbar')
    if version != '0.1.20261110':
        raise RuntimeError('Reboot into Touch Bar 0.1.20261110 and test it before an ASPM trial')
    battery()


def inhibit():
    # cat exits on EOF if this process dies: no orphaned indefinite sleep inhibitor.
    process = subprocess.Popen([
        '/usr/bin/systemd-inhibit', '--what=sleep', '--mode=block',
        '--who=macbook-aspm-experiment', '--why=Attended reversible PCIe L1 trial',
        '/usr/bin/sh', '-c', 'printf "ready\\n"; exec /usr/bin/cat >/dev/null'],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    ready, _, _ = select.select([process.stdout], [], [], 10)
    if not ready or process.stdout.readline() != b'ready\n':
        process.stdin.close()
        process.terminate()
        process.wait(timeout=5)
        raise RuntimeError('Could not acquire sleep inhibitor')
    return process


def trial(args):
    preflight(args)
    if (STATE / 'active.json').exists():
        raise RuntimeError('An unfinished receipt exists; inspect it and run restore first')
    _, links = inventory()
    receipt = {'boot_id': text('/proc/sys/kernel/random/boot_id'),
               'session': time.strftime('%Y%m%d-%H%M%S'),
               'started_at': time.strftime('%Y-%m-%dT%H:%M:%S%z'), 'nodes': targets(links)}
    if all(n['ctl'] & L1 for n in receipt['nodes']):
        raise RuntimeError('L1 is already enabled on all eligible links; no experiment needed')
    inhibitor = inhibit()
    results = {}
    try:
        print('Keep brightness/workload fixed; do not hotplug, suspend or reboot.', file=sys.stderr)
        warmup = idle_warmup()
        print(f'Initial warmup: {warmup}s for the current Touch Bar idle timeout. No input.', file=sys.stderr)
        time.sleep(warmup)
        expected_lighting = lighting()
        (STATE / f'{receipt["session"]}-plan.json').write_text(json.dumps({
            **receipt, 'lighting': expected_lighting, 'kernel': os.uname().release,
            'policy': text('/sys/module/pcie_aspm/parameters/policy')}, indent=2) + '\n')
        for phase in ('baseline', 'l1', 'restored'):
            if phase == 'l1':
                battery()
                # Refuse hotplug/topology changes during baseline before touching PCI.
                fresh, _ = inventory()
                if any(fresh.get(n['bdf']) != n for n in receipt['nodes']):
                    raise RuntimeError('PCI topology/configuration changed during baseline')
                save(receipt)  # Durable undo state BEFORE the first config write.
                enable(receipt)
            elif phase == 'restored':
                restore(receipt)
            print(f'{phase}: {args.seconds}s (settling {args.settle}s)', file=sys.stderr)
            time.sleep(args.settle)
            with (STATE / f'{receipt["session"]}-{phase}.csv').open('w') as out:
                results[phase] = sample(args.seconds, args.interval, out, expected_lighting)
            print(phase, json.dumps(results[phase]), file=sys.stderr)
    finally:
        try:
            if (STATE / 'active.json').exists():
                restore(receipt)
        finally:
            inhibitor.stdin.close()
            inhibitor.wait(timeout=5)
    (STATE / f'{receipt["session"]}-summary.json').write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps(results, indent=2))
    print('Raw samples/receipts:', STATE, file=sys.stderr)
    print('Compare both baselines; this trial does NOT validate USB-C hotplug or S3.', file=sys.stderr)


def interrupted(signum, frame):
    raise KeyboardInterrupt(f'Signal {signum}: stopping trial and restoring L1')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('inspect', help='Read-only paired-link and kernel ownership diagnostics')
    sample_parser = sub.add_parser('sample', help='Read-only battery samples to stdout as CSV')
    trial_parser = sub.add_parser('trial', help='Baseline/L1/restored battery trial; automatic rollback')
    for item in (sample_parser, trial_parser):
        item.add_argument('--seconds', type=int, default=300, choices=range(60, 901), metavar='60..900')
        item.add_argument('--interval', type=int, default=5, choices=range(1, 31), metavar='1..30')
    trial_parser.add_argument('--settle', type=int, default=30, choices=range(0, 121), metavar='0..120')
    for name in ('touchbar-tested', 'unplugged', 'saved-work', 'native-control-unavailable'):
        trial_parser.add_argument('--' + name, action='store_true')
    sub.add_parser('restore', help='Restore only saved L1 bits after an interrupted same-boot trial')
    args = parser.parse_args()
    check_model()
    if args.command == 'sample':
        print(json.dumps(sample(args.seconds, args.interval, sys.stdout)), file=sys.stderr)
        return
    require_root()
    if args.command == 'inspect':
        inspect()
        return
    # Root-owned state and exclusive lock prevent simultaneous trial/restore.
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    if STATE.is_symlink() or STATE.stat().st_uid != 0 or STATE.stat().st_mode & 0o077:
        raise RuntimeError('Unsafe state directory ownership/mode')
    with (STATE / 'lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        signal.signal(signal.SIGTERM, interrupted)
        signal.signal(signal.SIGINT, interrupted)
        if args.command == 'restore':
            restore(json.loads((STATE / 'active.json').read_text()))
        else:
            trial(args)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, KeyboardInterrupt) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(1)
