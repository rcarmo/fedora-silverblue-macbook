# fedora-silverblue-macbook — MacBook Pro 13" 2016 Touch Bar (MacBookPro13,2, T1) on Fedora Silverblue 44

Working configuration, local driver packages and the full investigation log for a 2016 13" MacBook Pro
with Touch Bar (Apple T1, **not** T2) on **Fedora Silverblue 44, kernel 7.2.13**.

| Area | Status |
|---|---|
| Keyboard / trackpad | stock `applespi` |
| Touch Bar | local akmod (AJ-dev-i60/t1-touchbar fork) + reset-resume fix |
| Speakers / mic | local akmod (davidjo/snd_hda_macbookpro, ported to 7.2) + re-probe/resume fixes |
| Wi-Fi 2.4 + **5 GHz** | BCM43602 board NVRAM from kernel bug 193121 (no WPA3) |
| USB-C / Thunderbolt hot-plug | xHCI runtime-PM pin (udev + service) |
| **Suspend (S3, deep)** | works: NVMe, Wi-Fi, USB-C, Touch Bar, audio restored. See `docs/SLEEP.md` |

**Start with:** `docs/CLEAN-INSTALL.md` (and `rebuild-kit/README.md`), `docs/KNOWN-ISSUES.md` (safety rules),
`docs/SLEEP.md` (how sleep works, root causes), `docs/FILE-MAP.md` (layout). `PROGRESS.md` and
`docs/TIMELINE.md` are the original working log.

Highlights of what was found:
- T1 Touch Bar stays dark after S3 unless the host sends ACPI `ASOC.SOCW(0)` before / `SOCW(1)` after sleep
  (`touchbar/t1-socw/`, packaged in the Touch Bar akmod); calling it at driver probe can freeze T1 Macs.
- Apple CS8409 audio: the resume path never re-ran the codec/amp boot setup; S3 also resets the codec
  subsystem ID, so controller re-probes after sleep fail.
- "Instant wake" after 3 s when suspending with the lid open: LID0 arms the shared GPE 0x6F line.
- Thunderbolt: remove the Alpine Ridge trees before S3 and rescan after (omarchy PR #11570 logic).

**Disclaimer:** experimental, model-specific (MacBookPro13,2; partly 13,3), tested on one machine.
Never set `apple_ibridge skip_acpi_power=0`. Read `docs/KNOWN-ISSUES.md` before installing anything.
Scripts under `tools/` and `sleep/` expect to run from a checkout of this repository via `pkexec`.
Logs were sanitized for publication (MAC/IP addresses, network and device names redacted; full system
journals, raw web dumps, ACPI table dumps and superseded binaries removed — see `.excluded-files.txt`).

Licensing: see `LICENSE` (MIT for original material; GPL-2.0 for driver sources/binaries).
