# Sleep investigation records

For the installed setup and attended test procedure, read the
[current sleep guide](../docs/SLEEP.md). For installation, use the
[rebuild kit](../rebuild-kit/README.md), **not the phase installers here**.

## Historical phases (2026-11-01)

| Directory | Change tested |
|---|---|
| `phase1/` | Deep S3, NVMe D3cold rule, Thunderbolt/Wi-Fi handling and USB-C runtime rule |
| `phase1b/` | Disable XHC1 wake during S3 |
| `phase1c/` | T1 SOCW messaging and Touch Bar mode refresh; local fallback module |
| `phase1d/` | Load SOCW from the packaged akmod first |
| `phase1e/` | Mask LID0 wake only on lid-open entry |

Installers/undo scripts depend on phase-specific predecessor files and local
receipts under `/var/lib/macbook-sleep-phase1*`. They are preserved for provenance
and recovery of those historical operations, not as a clean-install sequence.

## Other records

- `tests/`: newer attended test records produced by `tools/run-s3-test.sh`.
- `suspend-audit/`: pre-fix failures, stock-image tests and USB-C PM investigation.
- `research-20261101/`: source review and raw community inputs; many raw files
  are omitted from the public export.
- `idle-trackpad-audit/`: phantom-input observations.

The [archived test table](../docs/archive/SLEEP-test-record-2026-11-01.md) and
[research plan](../docs/SLEEP-RESUME-RESEARCH.md) explain the original progression.
Current hooks/configuration are under `../rebuild-kit/files/`.
