# File map (layout since the 2026-11-01 tidy)

The workspace is a git repo (`git log` shows every move; `.tidy/moves.txt` = old → new paths,
`.tidy/manifest-before-20261101.sha256` = hashes of every file before the tidy).
Nothing installed on the system references this directory.

| Path | What |
|---|---|
| `README.md`, `PROGRESS.md` | Start here / current state + next steps |
| `docs/` | `CLEAN-INSTALL.md`, `KNOWN-ISSUES.md`, `SLEEP.md` (current sleep design), `SLEEP-RESUME-RESEARCH.md`, `TIMELINE.md`, `model-notes.md`, `archive/` (verbatim old logs) |
| `rebuild-kit/` | **Exact copy of the current install**: `files/` (absolute paths), `rpms/` (akmods 0.1.20261101), `install-files.sh`, `SHA256SUMS`, `README.md` |
| `tools/` | `audit.sh` (consistency: sources ↔ patches ↔ tarballs ↔ SRPMs ↔ staged/booted modules ↔ kit ↔ system), `run-s3-test.sh` (attended S3 test → `sleep/tests/`), `logs/` |
| `packaging/` | Driver packaging: canonical specs (`*-kmod.spec` = current), `sources/` (0.1.20261031 baseline + 0.1.20261101 current), `patches/`, `tarballs/`, `rpms/<version>/`, `akmods-tests/`, `logs/`, `superseded/` specs, `README.md` |
| `touchbar/` | T1 Touch Bar research (`touchbar-driver.md`, `touchbar-upstream.md`, `model-touchbar-packaging.md`), `t1-socw/` (SOCW module dev copy), `raw/`, `logs/`, `upstream/` (git-ignored clones) |
| `audio/` | CS8409 research (`audio-upstream.md`), `compile-audio-in-container.sh`, `port-audio-header-7.2.py`, `resume-fix-livetest/` (live-load test of the resume fix), `microphone-test/` (contains a voice recording — private), `logs/`, `raw/`, `upstream/` (git-ignored clones) |
| `build/` | How modules were built (Podman container `macbook-driver-build`): `driver-build-results.md`, `inputs/` (Linux 7.2.13 HDA source; tarball git-ignored), `artifacts/`, `reference/` (akmods/kmodtool), `logs/` (install receipts, deployment JSON) |
| `sleep/` | `phase1`, `phase1b`, `phase1c`, `phase1d` (README, installer, undo, files, test results), `tests/` (new tests), `research-20261101/` (raw hooks/modules from other owners), `suspend-audit/` (pre-fix failures, USB workaround research), `idle-trackpad-audit/`, `config-upower/` |
| `wifi/` | 5 GHz investigation + NVRAM research (`*.md`), `comment97/` (NVRAM bundle), `trial-v1/` (failed: missing WCC), `trial-v2/` (working), `research-20261101/`, `wpa3-audit/`, `WIFI-RECOVERY.md` + `Makefile` + `recover-wifi.sh` (host-specific recovery), `raw/` |
| `misc/` | Camera logs, LG UltraFine display test, `post-reboot-audit.md`, `kernel-current.log`, `session-reference.txt` |

## Upstream sources (git-ignored clones; re-clone at these commits)
| Local path | URL | Commit |
|---|---|---|
| `touchbar/upstream/t1-touchbar-src` | https://github.com/AJ-dev-i60/t1-touchbar.git | 20d65c7b0fe6d05ea9734f869b27384a62de5109 |
| `touchbar/upstream/touchbar-src` | https://github.com/roadrunner2/macbook12-spi-driver.git | ddfbc7733542b8474a0e8f593aba91e06542be4f |
| `audio/upstream/audio-src` | https://github.com/davidjo/snd_hda_macbookpro.git | 89b22ff90b86468b186706861dd18663562defa7 |
| `audio/upstream/audio-akmod-src` | https://github.com/egorenar/snd-hda-codec-cs8409-akmod.git | 47cdd3011892baefd0a1cd544901264d36746a22 |
| `build/inputs/linux-7.2.13.tar.xz` | kernel.org | SHA256 08e7b0c4f2dd1971f972da274b5e589a98989390ac56acd7a1a5af922363ea6c |

## Root-owned state on the CURRENT install (receipts/backups; not needed on a clean install)
- `/var/lib/macbook-sleep-phase1*-*` — sleep phase receipts (undo scripts take these).
- `/var/lib/macbook-wifi-recovery/`, `/var/lib/macbook-usb-runtime-*` — older receipts.
- `/usr/local/lib/macbook-t1-socw/7.2.13-200.fc44.x86_64/` — per-kernel SOCW fallback (superseded by the akmod).
- SELinux local fcontext: `/usr/local/lib/macbook-t1-socw(/.*)?` → `modules_object_t`.
