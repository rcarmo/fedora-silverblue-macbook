#!/usr/bin/env python3
"""GNOME extension packaging, installer policy and standalone GJS tests."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
UUID = 'lg-brightness@macbook-fedora-audit'
SOURCE = ROOT / 'extensions' / UUID
FILES = {'extension.js', 'controller.js', 'subprocess.js', 'metadata.json', 'stylesheet.css'}


class ExtensionTests(unittest.TestCase):
    def test_metadata_and_lifecycle_contract(self):
        metadata = json.loads((SOURCE / 'metadata.json').read_text())
        self.assertEqual(metadata['uuid'], UUID)
        self.assertEqual(metadata['shell-version'], ['50'])
        source = (SOURCE / 'extension.js').read_text()
        self.assertIn('addExternalIndicator(this._indicator, 2)', source)
        self.assertIn('monitors-changed', source)
        self.assertIn('this._controller?.stop()', source)
        self.assertIn('this._item?.destroy()', source)
        self.assertNotIn('spawn_command_line', source)
        self.assertNotIn('communicate_utf8_sync', source)
        backend = (SOURCE / 'subprocess.js').read_text()
        self.assertIn("'/usr/local/bin/lg-brightness'", backend)
        self.assertIn('communicate_utf8_async', backend)
        self.assertIn('process.force_exit()', backend)

    def test_public_export_keeps_required_json_manifest(self):
        exporter = (ROOT / 'tools/make-public-export.sh').read_text()
        keep = next(line for line in exporter.splitlines() if line.startswith('KEEP='))
        self.assertIn('^extensions/lg-brightness@macbook-fedora-audit/metadata\\.json$', keep)

    def test_user_installer_preserves_unrelated_extensions(self):
        source = (ROOT / 'tools/install-lg-brightness-extension.sh').read_text()
        self.assertIn('[[ $EUID != 0 ]]', source)
        self.assertIn("enabled + [uuid]", source)
        self.assertIn("[item for item in disabled if item != uuid]", source)
        self.assertNotIn("set_boolean('disable-user-extensions'", source)
        self.assertNotIn('pkill', source)
        self.assertNotIn('gnome-shell --replace', source)
        self.assertIn('XDG_DATA_HOME', source)
        self.assertIn('XDG_STATE_HOME', source)
        subprocess.run(['bash', '-n', str(ROOT / 'tools/install-lg-brightness-extension.sh')], check=True)

    @unittest.skipUnless(shutil.which('gjs'), 'GJS is required for JavaScript tests')
    def test_gjs_controller_and_async_backend(self):
        result = subprocess.run(
            ['gjs', '-m', str(ROOT / 'tools/tests/lg_brightness_extension_test.js')],
            capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('assertions passed', result.stdout)

    @unittest.skipUnless(shutil.which('gnome-extensions'), 'GNOME extension packaging tool required')
    def test_pack_contains_every_runtime_module(self):
        with tempfile.TemporaryDirectory() as output:
            subprocess.run(['gnome-extensions', 'pack', str(SOURCE), '--out-dir', output,
                            '--extra-source=controller.js', '--extra-source=subprocess.js'],
                           check=True, capture_output=True)
            with zipfile.ZipFile(Path(output) / f'{UUID}.shell-extension.zip') as archive:
                self.assertEqual(set(archive.namelist()), FILES)
                self.assertEqual(json.loads(archive.read('metadata.json'))['uuid'], UUID)


if __name__ == '__main__':
    unittest.main()
