#!/usr/bin/python3
"""Read (never change) the LG UltraFine's HID brightness feature report."""
import fcntl
import os
from pathlib import Path

for device in sorted(Path('/sys/class/hidraw').glob('hidraw*')):
    props = (device / 'device/uevent').read_text()
    if 'HID_ID=0003:0000043E:00009A40' not in props:
        continue
    descriptor = (device / 'device/report_descriptor').read_bytes()
    # Select the HID monitor-control interface, not vendor or sensor interfaces.
    if not descriptor.startswith(bytes.fromhex('05800901')):
        continue
    path = '/dev/' + device.name
    fd = os.open(path, os.O_RDONLY | os.O_CLOEXEC)
    try:
        report = bytearray(7)  # Report ID 0 + 32-bit luminance + 16-bit control.
        request = (3 << 30) | (len(report) << 16) | (ord('H') << 8) | 0x07
        count = fcntl.ioctl(fd, request, report, True)
        print(f'{path}: feature bytes={report.hex()}, returned={count}')
        print(f'Raw luminance={int.from_bytes(report[1:5], "little")}; control={int.from_bytes(report[5:7], "little")}')
    finally:
        os.close(fd)
