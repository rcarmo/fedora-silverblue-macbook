# Repository and evidence map

[Documentation index](README.md) · [Project overview](../README.md)

## Current entry points

| Path | Contents |
|---|---|
| [README](../README.md) | Public overview and reading path; also the source of the exported front page |
| [Current status](../PROGRESS.md) | Reference versions, completed checks and next work |
| [docs](README.md) | Current guides, optional experiment, timeline and historical index |
| [rebuild kit](../rebuild-kit/README.md) | Current configuration/RPMs, installer and checksums |
| [packaging](../packaging/README.md) | Canonical specs, prepared sources, patches, Source0 archives and build notes |
| [sleep](../sleep/README.md) | Historical phase installers, tests and investigation records |
| `wifi/`, `audio/`, `touchbar/` | Topic research and earlier tooling; not alternative installation paths |
| `build/` | Recorded build procedure, prepared inputs and reference build tooling |
| `misc/` | Miscellaneous hardware tests and earlier audit notes |

## Tools

Run from the checkout; read each guide's prerequisites before privileged use.

| Tool | Purpose |
|---|---|
| `tools/audit.sh` | Read-only reference-set consistency audit: source → package → deployment → live files/modules |
| `tools/run-s3-test.sh` | Attended **real S3** test; writes a record under `sleep/tests/` |
| `tools/aspm-experiment.py` | Inspect/sample read-only, or explicitly opted-in reversible L1 trial/recovery |
| `packaging/tests/test-touchbar-idle.py` | Mocked worker/input regression test |
| `tools/tests/` | Hardware-free ASPM and maintained-documentation tests |
| `tools/make-public-export.sh` | Produce a sanitised publication snapshot; recreates its destination |
| `tools/publish-public.sh` | Update the separate public checkout, review, commit and normal push |

Nothing installed on the host needs this checkout to remain at its original path.
The configured hooks run from `/usr/local/sbin`, not from the source directory.

## Public vs local evidence

The public export retains the current kit, prepared source, patches, specs,
selected build/audit logs and historical notes. It excludes recordings, full
journals, raw web/ACPI dumps, local build-test outputs and redundant RPM copies.
The generated `.excluded-files.txt` lists omitted tracked paths.

In particular, `tools/logs/` is **local-only**: result pages reproduce the useful
measurements rather than linking to missing raw files. Upstream clones and the
saved Podman container are also not shipped. Some older notes retain historical
paths and hypotheses; their presence does not make them current instructions.

## Reference hardware

MacBookPro13,2; board `Mac-66E35819EE2D0D05`; firmware `529.120.1.0.0`;
Intel Iris 550 graphics; BCM43602 Wi-Fi (subsystem `106b:0157`); Cirrus CS8409
audio; Apple S3X NVMe (`106b:2003`); two Alpine Ridge Thunderbolt 3 controllers.
These identify the tested configuration, not additional supported models.

## Upstream inputs

The prepared package trees record their own provenance. Local ignored clones
were checked out at these commits:

| Input | Upstream | Commit |
|---|---|---|
| T1 Touch Bar | [AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar) | `20d65c7b0fe6d05ea9734f869b27384a62de5109` |
| SPI/reference Touch Bar | [roadrunner2/macbook12-spi-driver](https://github.com/roadrunner2/macbook12-spi-driver) | `ddfbc7733542b8474a0e8f593aba91e06542be4f` |
| Apple audio | [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro) | `89b22ff90b86468b186706861dd18663562defa7` |
| Audio packaging reference | [egorenar/snd-hda-codec-cs8409-akmod](https://github.com/egorenar/snd-hda-codec-cs8409-akmod) | `47cdd3011892baefd0a1cd544901264d36746a22` |

Linux 7.2.13 source archive SHA256:
`08e7b0c4f2dd1971f972da274b5e589a98989390ac56acd7a1a5af922363ea6c`.
The [Touch Bar follow-up](T1-IDLE-AND-ASPM.md) identifies the later idle-fix source.

## Host state, not installation inputs

- `/var/lib/macbook-rebuild-kit-*`: current installer receipts and backups.
- `/var/lib/macbook-sleep-phase1*-*`: historical phase receipts.
- `/var/lib/macbook-wifi-recovery/`, `/var/lib/macbook-usb-runtime-*`: older receipts.
- `/var/lib/macbook-aspm-experiment/`: root-only trial plans, CSVs and undo state.
- `/usr/local/lib/macbook-t1-socw/<kernel>/`: optional old fallback module,
  superseded by the akmod. Its SELinux label must be `modules_object_t` if used.

Do not copy another machine's receipts as recovery state. They describe the
hardware/files present when that particular operation ran.
