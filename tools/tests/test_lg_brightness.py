#!/usr/bin/env python3
"""Hardware-free tests for the narrowly scoped LG HID brightness control."""
import contextlib
import io
from pathlib import Path
import runpy
import struct
import tempfile
import unittest
from unittest.mock import patch

SOURCE = (Path(__file__).resolve().parents[2] /
          'rebuild-kit/files/usr/local/bin/lg-brightness')
MODULE = runpy.run_path(str(SOURCE))
# Functions created by run_path retain their own globals dictionary.
lg = MODULE['main'].__globals__


class BrightnessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.patch_globals = patch.dict(lg, SYSFS=self.root, DEV=Path('/dev'))
        self.patch_globals.start()
        self.addCleanup(self.patch_globals.stop)
        self.raw = 41984
        self.tail = b'\x12\x34'
        self.writes = []
        self.mock_ioctl = patch.object(lg['fcntl'], 'ioctl', side_effect=self.ioctl)
        self.mock_ioctl.start()
        self.addCleanup(self.mock_ioctl.stop)

    def node(self, name='hidraw2', descriptor=None, vendor='043E'):
        device = self.root / name / 'device'
        device.mkdir(parents=True)
        (device / 'uevent').write_text(f'HID_ID=0003:0000{vendor}:00009A40\n')
        (device / 'report_descriptor').write_bytes(
            lg['DESCRIPTOR'] if descriptor is None else descriptor)
        return Path('/dev') / name

    def ioctl(self, fd, request, report, mutate):
        self.assertEqual(len(report), 7)
        self.assertTrue(mutate)
        if request == lg['GET_REPORT']:
            report[:] = b'\0' + struct.pack('<I', self.raw) + self.tail
        elif request == lg['SET_REPORT']:
            self.assertEqual(report[0], 0)
            self.assertEqual(report[5:], self.tail)
            self.raw = struct.unpack_from('<I', report, 1)[0]
            self.writes.append(self.raw)
        else:
            self.fail(f'Unexpected ioctl {request}')
        return 7

    def monitor(self):
        monitor = lg['Monitor'](Path('/dev/hidraw2'))
        monitor.fd = 42
        return monitor

    def test_exact_discovery_excludes_other_interfaces_and_vendors(self):
        expected = self.node()
        self.node('hidraw1', descriptor=b'vendor interface')
        self.node('hidraw3', descriptor=b'ALS interface')
        self.node('hidraw4', vendor='1234')
        self.assertEqual(lg['discover'](), [expected])

    def test_no_device_or_ambiguous_device_is_rejected(self):
        with self.assertRaises(ValueError):
            lg['select_device']()
        one = self.node()
        self.node('hidraw5')
        with self.assertRaises(ValueError):
            lg['select_device']()
        self.assertEqual(lg['select_device'](str(one)), one)
        with self.assertRaises(ValueError):
            lg['select_device']('/dev/hidraw0')

    def test_read_is_read_only_and_uses_actual_wire_scale(self):
        self.assertAlmostEqual(self.monitor().get(), 77.7481481481)
        self.assertEqual(self.writes, [])

    def test_set_50_percent_and_preserve_unrelated_field(self):
        self.assertEqual(self.monitor().set(50), 50)
        self.assertEqual(self.writes, [27000])

    def test_boundaries(self):
        self.monitor().set(0)
        self.monitor().set(100)
        self.assertEqual(self.writes, [0, 54000])

    def test_reject_invalid_percentage_before_writing(self):
        for value in (-1, 101, float('nan'), float('inf'), 'bad'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.monitor().set(value)
        self.assertEqual(self.writes, [])

    def test_bad_current_report_prevents_write(self):
        self.raw = 54001
        with self.assertRaises(ValueError):
            self.monitor().set(50)
        self.assertEqual(self.writes, [])

    def test_short_report_prevents_write(self):
        with patch.object(lg['fcntl'], 'ioctl', return_value=6):
            with self.assertRaises(ValueError):
                self.monitor().set(50)
        self.assertEqual(self.writes, [])

    def test_readback_mismatch_is_error(self):
        monitor = self.monitor()
        with patch.object(monitor, 'read_report', return_value=(bytearray(5) + self.tail, 100)):
            with self.assertRaisesRegex(ValueError, 'did not confirm'):
                monitor.set(50)

    def cli(self, args):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return lg['main'](args)

    def test_cli_invalid_arguments_do_not_open_device(self):
        with patch.object(lg['os'], 'open') as op:
            for args in (['set'], ['get', '50'], ['set', 'nan'], ['set', '101']):
                self.assertEqual(self.cli(args), 1)
            op.assert_not_called()

    def test_cli_relative_adjustment_is_clamped_and_fd_closed(self):
        self.node()
        with patch.object(lg['os'], 'open', return_value=42), patch.object(lg['os'], 'close') as close:
            self.assertEqual(self.cli(['up', '100']), 0)
            self.assertEqual(self.raw, 54000)
            self.assertEqual(self.cli(['down', '100']), 0)
            self.assertEqual(self.raw, 0)
            self.assertEqual(close.call_count, 2)

    def test_reused_hidraw_number_is_rejected_before_open(self):
        path = self.node()
        (self.root / path.name / 'device/report_descriptor').write_bytes(b'other device')
        with patch.object(lg['os'], 'open') as op:
            with self.assertRaises(ValueError):
                with lg['Monitor'](path):
                    self.fail('Should not open a reused device number')
            op.assert_not_called()

    def test_incomplete_write_is_reported(self):
        monitor = self.monitor()
        with patch.object(lg['fcntl'], 'ioctl', side_effect=[7, 6]):
            with self.assertRaisesRegex(ValueError, 'Incomplete'):
                monitor.set(50)

    def test_context_closes_fd_on_io_failure(self):
        self.node()
        with patch.object(lg['os'], 'open', return_value=42), patch.object(lg['os'], 'close') as close:
            with patch.object(lg['fcntl'], 'ioctl', side_effect=OSError('unplugged')):
                with self.assertRaises(OSError):
                    with lg['Monitor'](Path('/dev/hidraw2')) as monitor:
                        monitor.set(50)
            close.assert_called_once_with(42)

    def test_permission_error_has_no_write(self):
        self.node()
        with patch.object(lg['os'], 'open', side_effect=PermissionError):
            self.assertEqual(self.cli(['set', '50']), 1)
        self.assertEqual(self.writes, [])


if __name__ == '__main__':
    unittest.main()
