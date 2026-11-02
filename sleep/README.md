# sleep/ — S3 work (current design: `../docs/SLEEP.md`)

| Dir | Installed | What changed | Receipt (`undo-*.sh <receipt>`) |
|---|---|---|---|
| `phase1/` | 12:20 | deep, NVMe d3cold rule, hook + Thunderbolt helper, USB-C rule by ID, karg | `/var/lib/macbook-sleep-phase1-csZYkCwn` |
| `phase1b/` | 12:48 | hook: XHC1 S3 wake off | `/var/lib/macbook-sleep-phase1b-AdZWV5ky` |
| `phase1c/` | 12:58 | hook: T1 SOCW(0)/(1) + Touch Bar re-send; `/usr/local` socw module | `/var/lib/macbook-sleep-phase1c-YllmQR8Y` |
| `phase1d/` | 14:17 | hook: `modprobe macbook_t1_socw` (akmod) first | `/var/lib/macbook-sleep-phase1d-45SAYdLD` |
| `phase1e/` | 19:45 | hook: LID0 wake off when lid open at suspend (GPE 0x6F instant wake) | `/var/lib/macbook-sleep-phase1e-junYcbME` |

Current files = `../rebuild-kit/files/`. New tests: `pkexec /usr/bin/bash ../tools/run-s3-test.sh 120` → `tests/`.
Phase installers refuse unless the previous phase's hook is installed (historical; use the kit now).
`research-20261101/` raw sources from other owners; `suspend-audit/` pre-fix failures (s2idle, stock image, NVMe trial, USB-C runtime-PM research).
