#!/usr/bin/python3
"""Read-only inspection of the staged Wi-Fi image and retained fallbacks."""
import hashlib
import json
from pathlib import Path
import subprocess


def command(*args):
    p = subprocess.run(args, capture_output=True, check=True)
    if p.stderr:
        print(p.stderr.decode(errors='replace').strip())
    return p.stdout


status = json.loads(command('/usr/bin/rpm-ostree', 'status', '--json'))
d = status['deployments'][0]
assert d.get('staged') and not d.get('booted'), 'Expected a staged trial first'
assert d['checksum'] == 'b0a3115661b67f83769723b4fdea41d9cc6fc267cea0b363cf4b0298fb999505', 'Unexpected trial'
root = Path('/sysroot/ostree/deploy/fedora/deploy') / f"{d['checksum']}.{d['serial']}"
image = root / 'usr/lib/modules/7.2.13-200.fc44.x86_64/initramfs.img'
listing = command('/usr/bin/lsinitrd', str(image)).decode()
print('Staged image:', image)
for fragment in ['extra/macbook-cs8409/snd-hda-codec-cs8409.ko', 'extra/macbook-t1-touchbar/apple-ibridge.ko', 'extra/macbook-t1-touchbar/apple-touchbar.ko', 'brcmfmac/brcmfmac.ko', 'brcm/brcmfmac43602-pcie.bin']:
    assert fragment in listing, f'Missing required content: {fragment}'
    print('Present:', fragment)


def extract(path):
    return command('/usr/bin/lsinitrd', '-f', path, str(image))


nvram = extract('usr/lib/firmware/brcm/brcmfmac43602-pcie.txt')
assert hashlib.sha256(nvram).hexdigest() == '90f3f15991fcd8dc3b29a3cfda7859fd4faf9fe275cbef7b522658ff9971fa74', 'NVRAM content mismatch'
print('Exact candidate NVRAM hash verified.')
# Inspect early-load instructions and the preserved Touch Bar ACPI guard.
cmdline_files = [line.split()[-1] for line in listing.splitlines() if 'etc/cmdline.d/' in line and line.split()[-1].endswith('.conf')]
cmdline = b'\n'.join(extract(p) for p in cmdline_files)
for module in ['brcmfmac', 'apple_ibridge', 'apple_touchbar']:
    assert ('rd.driver.pre=' + module).encode() in cmdline, f'No early load: {module}'
print('Early brcmfmac/Touch Bar loading verified.')
guard_files = [line.split()[-1] for line in listing.splitlines() if 'modprobe.d/' in line and 'touchbar' in line and line.split()[-1].endswith('.conf')]
assert guard_files and any(b'skip_acpi_power=1' in extract(p) for p in guard_files), 'Missing ACPI guard'
print('Touch Bar skip_acpi_power=1 verified.')
binary = next(line.split()[-1] for line in listing.splitlines() if 'brcm/brcmfmac43602-pcie.bin' in line and 'brcmfmac43602-pcie.bin' in line.split()[-1])
host = Path('/') / binary
assert hashlib.sha256(extract(binary)).digest() == hashlib.sha256(host.read_bytes()).digest(), 'Stock firmware binary changed'
print('Stock station firmware binary hash verified.')
assert not (Path('/usr/lib/firmware/brcm/brcmfmac43602-pcie.txt').exists()), 'Unexpected generic host override'

fallbacks = [
    '/boot/ostree/fedora-66919d634a47d21199e4fe697437da2a117812c49770727e610afae23e84564d/initramfs-7.2.13-200.fc44.x86_64.img',
    '/boot/ostree/fedora-49f4b4e2636850381b6c967c3439f88f42d6416d66ba148633c4abb9970a046b/initramfs-7.2.13-200.fc44.x86_64.img',
    '/boot/ostree/fedora-c4941fbacfc3518c3fe124d4b3e5ffa17d199ac5f8361e9223053b012bcbc0a9/initramfs-6.19.10-300.fc44.x86_64.img',
]
for fallback in fallbacks:
    contents = command('/usr/bin/lsinitrd', fallback).decode()
    assert 'brcmfmac43602-pcie.txt' not in contents, 'Fallback contains trial NVRAM'
    print('Fallback has no trial NVRAM:', fallback)
for checksum in ['43e45ec36e83466bf11fe72de61a2e844342182d820de150ddf99c880c38951f', 'f1365bcef08f98f305177529b4132dbef7c2a4d4ad1fc38de9b24fc85c306517', 'b8e75b708a972d784856f07d964202860088b1138ef9eadb01aa7d76c795104a']:
    assert any(x['checksum'] == checksum and x['pinned'] for x in status['deployments']), 'Fallback not pinned'
print('PASS: staged trial contents and all three pinned fallback images verified. No reboot performed.')
