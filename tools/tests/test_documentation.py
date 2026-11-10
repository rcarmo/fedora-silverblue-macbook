#!/usr/bin/env python3
"""Check maintained Markdown links in the workspace or a public export.

MACBOOK_DOCS_ROOT=/path/to/export python3 -m unittest discover -s tools/tests -v
Historical source mirrors/archive contents are not treated as maintained guides.
"""
import os
from pathlib import Path
import re
import unittest
from urllib.parse import unquote, urlsplit

ROOT = Path(os.environ.get('MACBOOK_DOCS_ROOT', Path(__file__).resolve().parents[2])).resolve()
GUIDES = [
    'README.md', 'PROGRESS.md', 'packaging/README.md', 'rebuild-kit/README.md',
    'sleep/README.md', 'docs/README.md', 'docs/CLEAN-INSTALL.md',
    'docs/KNOWN-ISSUES.md', 'docs/SLEEP.md', 'docs/ASPM-RESULTS.md',
    'docs/ASPM-EXPERIMENT.md', 'docs/T1-IDLE-AND-ASPM.md', 'docs/TIMELINE.md',
    'docs/FILE-MAP.md',
]
LINK = re.compile(r'(?<!!)\[[^\]\n]*\]\(([^)\n]+)\)')


class DocumentationTests(unittest.TestCase):
    def test_maintained_relative_links_resolve(self):
        for name in GUIDES:
            with self.subTest(document=name):
                document = ROOT / name
                self.assertTrue(document.is_file(), f'Missing maintained guide: {name}')
                for target in LINK.findall(document.read_text()):
                    parsed = urlsplit(target.strip().strip('<>'))
                    if parsed.scheme or parsed.netloc or not parsed.path:
                        continue
                    dest = (document.parent / unquote(parsed.path)).resolve()
                    with self.subTest(document=name, target=target):
                        self.assertTrue(dest.is_relative_to(ROOT), f'Link escapes repository: {target}')
                        self.assertTrue(dest.exists(), f'{name}: missing link target {target}')

    def test_exporter_keeps_canonical_front_page(self):
        exporter = (ROOT / 'tools/make-public-export.sh').read_text()
        self.assertNotIn('README.public.md', exporter)
        self.assertFalse((ROOT / 'tools/public/README.public.md').exists())
        self.assertTrue((ROOT / 'LICENSE').is_file())


if __name__ == '__main__':
    unittest.main()
