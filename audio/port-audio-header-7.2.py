#!/usr/bin/env python3
"""Apply only the three functional Apple header additions to Linux 7.2.

The upstream first hunk only adds comments to enums. It conflicts with new
RECEIVER names, so omit it. The last hunk conflicts with new speaker_muted and
component-binding fields; preserve those fields and insert before exec_verb.
Run only on an unpatched header in the isolated build tree.
"""
import re
import sys
from pathlib import Path

header = Path(sys.argv[1])
patch = Path(sys.argv[2]).read_text()
hunks = re.split(r'^@@.*@@.*\n', patch, flags=re.MULTILINE)[1:]
assert len(hunks) == 4, 'Unexpected upstream patch layout'
additions = [''.join(line[1:] for line in hunk.splitlines(keepends=True)
                     if line.startswith('+') and not line.startswith('+++'))
             for hunk in hunks]
text = header.read_text()
assert 'struct unsol_item' not in text, 'Header already patched'
for anchor, addition in [
    ('struct sub_codec {\n', additions[1]),
    ('\tunsigned int suspended:1;\n', additions[2]),
    ('\t/* verb exec op override */\n', additions[3]),
]:
    assert text.count(anchor) == 1, f'Unexpected anchor: {anchor!r}'
    text = text.replace(anchor, addition + anchor)
header.write_text(text)
