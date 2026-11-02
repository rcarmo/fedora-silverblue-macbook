#!/usr/bin/python3
"""Read-only image verification; temporary extraction only, never load modules."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

KERNEL = '7.2.13-200.fc44.x86_64'
RECOVERY = 'c4ebdd857316f64e6b97b3c29f64993fef8ebe82824484091bc4d848b2ae39bc'
FAILED = 'b0a3115661b67f83769723b4fdea41d9cc6fc267cea0b363cf4b0298fb999505'
FALLBACKS = [RECOVERY, '43e45ec36e83466bf11fe72de61a2e844342182d820de150ddf99c880c38951f', 'f1365bcef08f98f305177529b4132dbef7c2a4d4ad1fc38de9b24fc85c306517', 'b8e75b708a972d784856f07d964202860088b1138ef9eadb01aa7d76c795104a']

def cmd(*args):
    p = subprocess.run(args, capture_output=True, check=True)
    if p.stderr:
        print(p.stderr.decode(errors='replace').strip())
    return p.stdout

def digest(data):
    return hashlib.sha256(data).hexdigest()

assert sys.argv[1:] in [['--before'], ['--after']]
after = sys.argv[1] == '--after'
s = json.loads(cmd('/usr/bin/rpm-ostree', 'status', '--json'))
assert not s.get('transaction'), 'Transaction still running'
d = s['deployments']
booted = next(x for x in d if x.get('booted'))
assert booted['checksum'] == RECOVERY
entries = []
for f in Path('/boot/loader/entries').glob('*.conf'):
    lines = f.read_text().splitlines()
    fields = dict(line.split(' ', 1) for line in lines if ' ' in line)
    option = next(x for x in fields['options'].split() if x.startswith('ostree='))
    root = (Path('/sysroot') / option.split('=', 1)[1].lstrip('/')).resolve(strict=True)
    entries.append((root, fields['title'], Path('/boot') / fields['initrd'].lstrip('/')))

def image_for(deployment):
    root = Path('/sysroot/ostree/deploy/fedora/deploy') / f"{deployment['checksum']}.{deployment['serial']}"
    matches = [(title, image) for target, title, image in entries if target == root]
    assert len(matches) == 1, f'No unique BLS image: {root}'
    title, image = matches[0]
    print('BOOT MAPPING:', deployment['checksum'], title, image)
    return root, image, title

if after:
    trial = d[0]
    assert trial.get('staged') and not trial.get('booted')
    assert trial['checksum'] not in FALLBACKS + [FAILED]
    assert trial.get('regenerate-initramfs') and trial.get('initramfs-args') == ['--force']
    for key in ['base-checksum', 'requested-packages', 'requested-local-packages']:
        assert trial.get(key) == booted.get(key), f'Unrelated change: {key}'
    assert trial['checksum'] == '39e497fbe6383c8b5c9dda53c1bdaab1e3e77291c81cef20ceace9017ab5c936', 'Unexpected trial commit'
    root = Path('/sysroot/ostree/deploy/fedora/deploy') / f"{trial['checksum']}.{trial['serial']}"
    # OSTree staged deployments acquire BLS entries at shutdown finalization.
    image = root / 'usr/lib/modules' / KERNEL / 'initramfs.img'
    assert image.is_file()
    print('STAGED IMAGE (not yet BLS-finalized):', trial['checksum'], image)
    print('Expected next menu after successful finalization: trial :0, recovery :1, old FAILED image :2; recheck if any deployment changes.')
    listing = cmd('/usr/bin/lsinitrd', str(image)).decode()
    paths = {line.split()[-1] for line in listing.splitlines() if line.split()}
    def extract(path):
        return cmd('/usr/bin/lsinitrd', '-f', path, str(image))
    def unique(fragment):
        matches = [p for p in paths if fragment in p and not p.endswith('/')]
        assert len(matches) == 1, (fragment, matches)
        return matches[0]
    nvram = extract('usr/lib/firmware/brcm/brcmfmac43602-pcie.txt')
    assert digest(nvram) == '90f3f15991fcd8dc3b29a3cfda7859fd4faf9fe275cbef7b522658ff9971fa74'
    print('Exact c97 personalized NVRAM verified.')
    for fragment in ['extra/macbook-cs8409/snd-hda-codec-cs8409.ko', 'extra/macbook-t1-touchbar/apple-ibridge.ko', 'extra/macbook-t1-touchbar/apple-touchbar.ko', 'brcmfmac/brcmfmac.ko', 'brcmfmac/wcc/brcmfmac-wcc.ko', 'applespi.ko']:
        path = unique(fragment)
        assert digest(extract(path)) == digest((root / path).read_bytes()), f'Module mismatch: {path}'
        print('Verified module:', path)
    binary = unique('brcm/brcmfmac43602-pcie.bin')
    assert digest(extract(binary)) == digest((Path('/') / binary).read_bytes())
    print('Unchanged stock station binary verified.')
    cmdline = b'\n'.join(extract(p) for p in paths if p.startswith('etc/cmdline.d/') and p.endswith('.conf'))
    for module in ['brcmfmac', 'apple_ibridge', 'apple_touchbar']:
        assert ('rd.driver.pre=' + module).encode() in cmdline, f'Missing early-load: {module}'
    guards = [p for p in paths if 'modprobe.d/' in p and 'touchbar' in p and p.endswith('.conf')]
    assert any(b'skip_acpi_power=1' in extract(p) for p in guards)
    modprefix = f'usr/lib/modules/{KERNEL}/'
    dep = extract(modprefix + 'modules.dep').decode()
    helper = unique('brcmfmac/wcc/brcmfmac-wcc.ko')
    helper_rel = helper.removeprefix(modprefix)
    dep_lines = dict(line.split(':', 1) for line in dep.splitlines() if ':' in line)
    assert helper_rel in dep_lines and 'brcmfmac.ko' in dep_lines[helper_rel]
    # Test the real staged depmod binary index offline. Never insmod/modprobe live.
    with tempfile.TemporaryDirectory(prefix='macbook-wifi-verify-') as directory:
        temp = Path(directory)
        (temp / 'usr/lib/modules' / KERNEL).mkdir(parents=True)
        (temp / 'lib').symlink_to('usr/lib')
        for name in ['modules.dep', 'modules.dep.bin', 'modules.alias', 'modules.alias.bin', 'modules.softdep', 'modules.builtin', 'modules.builtin.bin', 'modules.builtin.modinfo']:
            p = modprefix + name
            if p in paths:
                (temp / p).write_bytes(extract(p))
        todo = [helper_rel]
        seen = set()
        while todo:
            rel = todo.pop()
            if rel in seen:
                continue
            seen.add(rel)
            destination = temp / modprefix / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(extract(modprefix + rel))
            assert digest(destination.read_bytes()) == digest((root / modprefix / rel).read_bytes())
            todo.extend(dep_lines.get(rel, '').split())
        metadata = cmd('/usr/sbin/modinfo', '-F', 'vermagic', str(temp / helper)).decode()
        assert metadata.startswith(KERNEL + ' ')
        dependencies = cmd('/usr/sbin/modprobe', '--show-depends', '--dirname', directory, '--set-version', KERNEL, 'brcmfmac-wcc').decode()
        assert 'brcmfmac-wcc.ko' in dependencies and 'brcmfmac.ko' in dependencies
        print('Offline staged WCC dependency index resolution PASS:\n' + dependencies)
    assert not Path('/usr/lib/firmware/brcm/brcmfmac43602-pcie.txt').exists()
    print('Early-load instructions and skip_acpi_power=1 verified.')
else:
    assert d[0].get('booted') and not any(x.get('staged') for x in d)

for checksum in FALLBACKS:
    deployment = next(x for x in d if x['checksum'] == checksum)
    if after or checksum != RECOVERY:
        assert deployment.get('pinned'), f'Fallback not pinned: {checksum}'
    root, image, title = image_for(deployment)
    listing = cmd('/usr/bin/lsinitrd', str(image)).decode()
    file_paths = {line.split()[-1] for line in listing.splitlines() if line and line[0] in '-dlbcps' and len(line.split()) >= 9}
    assert not any(p.endswith('/brcmfmac43602-pcie.txt') for p in file_paths), f'Fallback has trial NVRAM: {checksum}'
    if checksum in FALLBACKS[:2]:
        assert 'extra/macbook-cs8409/snd-hda-codec-cs8409.ko' in listing
        assert 'extra/macbook-t1-touchbar/apple-ibridge.ko' in listing
        guards = [line.split()[-1] for line in listing.splitlines() if 'modprobe.d/' in line and 'touchbar' in line and line.split()[-1].endswith('.conf')]
        assert any(b'skip_acpi_power=1' in cmd('/usr/bin/lsinitrd', '-f', p, str(image)) for p in guards)
    print('Fallback verified clean:', checksum[:12], 'image SHA256', digest(image.read_bytes()))
print('PASS: actual BLS boot image verification. No reboot or module load performed.')
