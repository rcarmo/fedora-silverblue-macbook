# Documentation

This project documents one **MacBookPro13,2 / Fedora Silverblue 44 / kernel 7.2.13**
installation. Start with the current guides below, not the investigation scripts.

## Install and use

1. [Known issues and safety](KNOWN-ISSUES.md) — hardware coverage, kernel limits and recovery rules.
2. [Installation guide](CLEAN-INSTALL.md) — ordered clean-install procedure.
3. [Rebuild kit](../rebuild-kit/README.md) — what the installer and packages contain.
4. [Sleep guide](SLEEP.md) — everyday behavior, attended testing and caveats.
5. [Current status](../PROGRESS.md) — installed versions and the next checks.
6. [LG UltraFine brightness](LG-BRIGHTNESS.md) — optional CLI/slider, narrow device access and tested display scope.

## Optional power experiment

**Not part of installation. Original PCI settings are currently restored.**

- [ASPM results](ASPM-RESULTS.md) — what the short trial measured and what it did not establish.
- [ASPM procedure](ASPM-EXPERIMENT.md) — prerequisites, opt-in trial, restoration and risks.

## Maintain or understand the implementation

- [Driver packaging](../packaging/README.md) — rebuild/versioning procedure and the audio kernel gate.
- [Touch Bar idle fix](T1-IDLE-AND-ASPM.md) — patch provenance and hardware acceptance.
- [File map](FILE-MAP.md) — sources, tools, evidence locations and upstream commits.
- [Timeline](TIMELINE.md) — milestones rather than a live troubleshooting log.

## Historical research and evidence

These explain how the current setup was reached. Proposals, failed tests and old
commands are preserved as evidence, **not instructions to apply today**.

- [Original sleep research](SLEEP-RESUME-RESEARCH.md) — hypotheses and phased plan before the fix.
- [Older upstream model notes](model-notes.md) — Fedora 27 / kernel 4.14-era reference, not current instructions.
- [Sleep investigation directory](../sleep/README.md) — phase installers and test records.
- [Archived progress snapshot](archive/PROGRESS-snapshot-2026-11-10.md) — detailed deployment/sleep chronology.
- [Original sleep test table](archive/SLEEP-test-record-2026-11-01.md).
- [Earlier packaging notes](archive/PACKAGING-notes-2026-11-10.md).
- [Full initial log](archive/PROGRESS-full-log-2026-11-01.md) and
  [sleep-work log](archive/PROGRESS-log-2026-11-01-sleep-work.md).

The public export excludes full journals, recordings, ACPI dumps, raw downloads
and some build/test artifacts. A quoted filesystem path can refer to local-only
evidence; it is not necessarily a missing installation dependency. Published
sources, current RPMs, configuration and checksum manifests remain available.
