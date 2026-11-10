#!/usr/bin/env python3
"""Hardware-free tests: all PCI reads/writes are mocked against a fake sysfs."""
import argparse
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

SPEC = importlib.util.spec_from_file_location('aspm', Path(__file__).resolve().parents[1] / 'aspm-experiment.py')
aspm = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(aspm)


class ExperimentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        base = Path(self.temp.name)
        self.pci = base / 'pci'
        self.pci.mkdir()
        self.state = base / 'state'
        self.state.mkdir()
        self.registers = {}
        self.writes = []
        self.patches = [patch.object(aspm, 'PCI', self.pci), patch.object(aspm, 'STATE', self.state),
                        patch.object(aspm, 'run', side_effect=self.run_command),
                        patch.object(aspm, 'lighting', return_value={'screen': '40'}),
                        patch.object(aspm, 'idle_warmup', return_value=0)]
        for p in self.patches:
            p.start()
        self.addCleanup(self.temp.cleanup)
        for p in self.patches:
            self.addCleanup(p.stop)
        self.roots = []
        for index, (bdf, device_id) in enumerate(aspm.ROOTS.items()):
            root = self.device(base / f'tree{index}' / bdf, device_id, 4)
            upstream = self.device(root / f'0000:{index + 3:02x}:00.0', '8086:1578', 5)
            down = self.device(upstream / f'0000:{index + 5:02x}:00.0', '8086:15d3', 6)
            self.device(down / f'0000:{index + 7:02x}:00.0', '8086:15d2', 0)
            self.device(upstream / f'0000:{index + 5:02x}:01.0', '8086:15d3', 6)
            self.roots.append(root)

    def device(self, path, device_id, pcie_type):
        path.mkdir(parents=True)
        vendor, device = device_id.split(':')
        (path / 'vendor').write_text('0x' + vendor)
        (path / 'device').write_text('0x' + device)
        (self.pci / path.name).symlink_to(path)
        self.registers[path.name] = {'CAP_EXP+02.w': pcie_type << 4,
                                    'CAP_EXP+0c.L': 0x800, 'CAP_EXP+10.w': 0x140}
        return path

    def run_command(self, command, *args):
        if command == '/usr/bin/rpm':
            return '0.1.20261110'
        self.assertEqual(command, '/usr/sbin/setpci')
        self.assertEqual(args[0], '-s')
        bdf, reg = args[1:]
        if '=' in reg:
            key, value = reg.split('=')
            bit, mask = (int(s, 16) for s in value.split(':'))
            self.assertEqual(key, 'CAP_EXP+10.w')
            self.assertEqual(mask, 2)
            self.writes.append((bdf, bit, mask))
            self.registers[bdf][key] = (self.registers[bdf][key] & ~mask) | (bit & mask)
            return ''
        return f'{self.registers[bdf][reg]:08x}'

    def receipt(self):
        _, links = aspm.inventory()
        return {'boot_id': 'test-boot', 'session': 'test', 'nodes': aspm.targets(links)}

    def mock_boot(self):
        original = aspm.text
        fixed = {'/proc/sys/kernel/random/boot_id': 'test-boot',
                 '/sys/module/pcie_aspm/parameters/policy': '[default] powersave'}
        return patch.object(aspm, 'text', side_effect=lambda p: fixed.get(str(p))
                            if str(p) in fixed else original(p))

    def args(self):
        return argparse.Namespace(touchbar_tested=True, unplugged=True, saved_work=True,
                                  native_control_unavailable=True, seconds=60, interval=5, settle=0)

    def test_inventory_pairs_only_real_links(self):
        nodes, links = aspm.inventory()
        self.assertEqual(len(nodes), 10)
        self.assertEqual(len(links), 4)
        plan = aspm.targets(links)
        self.assertEqual(len(plan), 8)
        self.assertFalse(any(n['bdf'].endswith(':01.0') for n in plan))
        self.assertFalse(self.writes)

    def test_unknown_external_device_rejected(self):
        self.device(self.roots[0] / '0000:20:00.0', '1234:5678', 0)
        with self.assertRaisesRegex(RuntimeError, 'unknown/external'):
            aspm.inventory()
        self.assertFalse(self.writes)

    def test_both_ends_must_support_l1(self):
        self.registers['0000:07:00.0']['CAP_EXP+0c.L'] = 0
        _, links = aspm.inventory()
        self.assertEqual(len(aspm.targets(links)), 6)

    def test_enable_restore_only_changes_l1(self):
        receipt = self.receipt()
        before = {b: r['CAP_EXP+10.w'] for b, r in self.registers.items()}
        # Preserve an originally enabled L1 bit too.
        node = receipt['nodes'][0]
        node['ctl'] |= 2
        self.registers[node['bdf']]['CAP_EXP+10.w'] |= 2
        before[node['bdf']] |= 2
        aspm.save(receipt)
        aspm.enable(receipt)
        self.assertTrue(all(self.registers[n['bdf']]['CAP_EXP+10.w'] == before[n['bdf']] | 2
                            for n in receipt['nodes']))
        # An unrelated bit changed by the kernel must survive restore.
        for n in receipt['nodes']:
            self.registers[n['bdf']]['CAP_EXP+10.w'] |= 0x10
        with self.mock_boot():
            aspm.restore(receipt)
        for b, r in self.registers.items():
            expected = before[b] | 0x10 if any(n['bdf'] == b for n in receipt['nodes']) else before[b]
            self.assertEqual(r['CAP_EXP+10.w'], expected)
        self.assertFalse((self.state / 'active.json').exists())

    def test_stale_identity_refuses_write(self):
        receipt = self.receipt()
        receipt['nodes'][-1]['inode'] = -1
        with self.assertRaisesRegex(RuntimeError, 'topology changed'):
            aspm.enable(receipt)
        self.assertFalse(self.writes)  # validates entire plan before the first write

    def test_other_boot_refuses_restore(self):
        receipt = self.receipt()
        receipt['boot_id'] = 'another-boot'
        aspm.save(receipt)
        with self.mock_boot(), self.assertRaisesRegex(RuntimeError, 'another boot'):
            aspm.restore(receipt)
        self.assertFalse(self.writes)
        self.assertTrue((self.state / 'active.json').exists())

    def test_partial_restore_keeps_receipt_and_restores_others(self):
        receipt = self.receipt()
        aspm.save(receipt)
        aspm.enable(receipt)
        receipt['nodes'][0]['inode'] = -1
        with self.mock_boot(), self.assertRaisesRegex(RuntimeError, 'Incomplete restoration'):
            aspm.restore(receipt)
        self.assertTrue((self.state / 'active.json').exists())
        for n in receipt['nodes'][1:]:
            self.assertFalse(self.registers[n['bdf']]['CAP_EXP+10.w'] & 2)

    def test_confirmation_and_driver_gates(self):
        args = self.args()
        args.native_control_unavailable = False
        with self.assertRaisesRegex(RuntimeError, 'Confirm'):
            aspm.preflight(args)
        with patch.object(aspm, 'run', return_value='0.1.20261101'):
            with self.assertRaisesRegex(RuntimeError, 'Reboot'):
                aspm.preflight(self.args())
        self.assertFalse(self.writes)

    def test_trial_rolls_back_after_measurement_failure(self):
        inhibitor = Mock()
        receipt = self.receipt()
        with self.mock_boot(), patch.object(aspm, 'battery'), patch.object(aspm, 'inhibit', return_value=inhibitor), \
                patch.object(aspm.time, 'sleep'), patch.object(aspm, 'sample', side_effect=[{}, RuntimeError('lost AC state')]):
            with self.assertRaisesRegex(RuntimeError, 'lost AC state'):
                aspm.trial(self.args())
        self.assertTrue(self.writes)
        self.assertFalse((self.state / 'active.json').exists())
        for n in receipt['nodes']:
            self.assertEqual(self.registers[n['bdf']]['CAP_EXP+10.w'], n['ctl'])
        inhibitor.stdin.close.assert_called_once()
        inhibitor.wait.assert_called_once()

    def test_partial_apply_failure_uses_durable_receipt_to_restore(self):
        inhibitor = Mock()
        def partial_apply(receipt):
            saved = json.loads((self.state / 'active.json').read_text())
            self.assertEqual(saved, receipt)
            aspm.write_l1(receipt['nodes'][0], 2)
            raise RuntimeError('simulated partial write failure')
        with self.mock_boot(), patch.object(aspm, 'battery'), patch.object(aspm, 'inhibit', return_value=inhibitor), \
                patch.object(aspm.time, 'sleep'), patch.object(aspm, 'sample', return_value={}), \
                patch.object(aspm, 'enable', side_effect=partial_apply):
            with self.assertRaisesRegex(RuntimeError, 'partial write failure'):
                aspm.trial(self.args())
        self.assertFalse((self.state / 'active.json').exists())
        self.assertTrue(all(not r['CAP_EXP+10.w'] & 2 for r in self.registers.values()))

    def test_successful_trial_has_three_phases(self):
        inhibitor = Mock()
        with self.mock_boot(), patch.object(aspm, 'battery'), patch.object(aspm, 'inhibit', return_value=inhibitor), \
                patch.object(aspm.time, 'sleep'), patch.object(aspm, 'sample', return_value={'mean_w': 8.0}) as sample:
            aspm.trial(self.args())
        self.assertEqual(sample.call_count, 3)
        self.assertFalse((self.state / 'active.json').exists())
        self.assertEqual(len(list(self.state.glob('*-summary.json'))), 1)

    def test_battery_conversion_and_safety(self):
        bat = Path(self.temp.name) / 'battery'
        bat.mkdir()
        data = {'status': 'Discharging', 'charge_now': '250', 'charge_full': '1000',
                'current_now': '1000000', 'voltage_now': '12000000'}
        for key, value in data.items():
            (bat / key).write_text(value)
        with patch.object(aspm, 'BAT', bat):
            self.assertEqual(aspm.battery(), (12.0, 0.25))
            (bat / 'status').write_text('Charging')
            with self.assertRaisesRegex(RuntimeError, 'discharging'):
                aspm.battery()
            (bat / 'status').write_text('Discharging')
            (bat / 'charge_now').write_text('100')
            with self.assertRaisesRegex(RuntimeError, 'below 20%'):
                aspm.battery()

    def test_lighting_change_aborts_measurement(self):
        with patch.object(aspm, 'battery', return_value=(8.5, 0.6)):
            with self.assertRaisesRegex(RuntimeError, 'Backlight state changed'):
                aspm.sample(60, 5, io.StringIO(), {'screen': '20'})
        self.assertFalse(self.writes)

    def test_readback_failure_is_reported(self):
        node = self.receipt()['nodes'][0]
        real_run = aspm.run
        def ignore_writes(command, *args):
            if '=' in args[-1]:
                return ''
            return real_run(command, *args)
        with patch.object(aspm, 'run', side_effect=ignore_writes):
            with self.assertRaisesRegex(RuntimeError, 'readback mismatch'):
                aspm.write_l1(node, 2)

    def test_sampler_csv_and_summary(self):
        now = [0.0]
        def sleep(seconds):
            now[0] += seconds
        output = io.StringIO()
        with patch.object(aspm, 'battery', return_value=(8.5, 0.6)), \
                patch.object(aspm.time, 'monotonic', side_effect=lambda: now[0]), \
                patch.object(aspm.time, 'sleep', side_effect=sleep):
            result = aspm.sample(60, 5, output)
        self.assertEqual(result['samples'], 13)
        self.assertEqual(result['mean_w'], 8.5)
        self.assertIn('60.000,8.5000,0.6000', output.getvalue())
        self.assertFalse(self.writes)


if __name__ == '__main__':
    unittest.main()
