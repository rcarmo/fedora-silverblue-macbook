# Stock suspend failure: evidence and research, not another trial

2026-11-01, read-only investigation after return to recovery `(ostree:0)`.

## Findings on this machine

| Trial | Deployment / kernel | Last saved suspend record | Functional outcome |
| --- | --- | --- | --- |
| Custom deep | recovery c4ebdd8 / 7.2.13 | `PM: suspend entry (deep)`, 00:05:49 | User required forced restart |
| Custom s2idle | recovery c4ebdd8 / 7.2.13 | `PM: suspend entry (s2idle)`, 08:31:52 | User required forced restart |
| **Stock deep** | pinned f1365bc.0 / 7.2.13 | **`PM: suspend entry (deep)`, 08:52:11.646218** | **User reports failed wake and return to :0** |

Stock failed boot ID: `5e39fd98c9a14bbebcbc687a0b949f41`. Lid closed at 08:52:09.910140. systemd-sleep successfully froze user.slice and began suspend. No saved suspend exit, stack trace, or callback failure follows. Pre-test stock audit verified stock CS8409 codec, no custom Touch Bar modules, and no local sleep override.

Current boot: `8d41d00e48854062908350050ed62171`, starting 08:53:37, recovery c4ebdd8, kernel `7.2.13-200.fc44.x86_64`. rpm-ostree idle, no staged deployment, ordering unchanged. Wi-Fi connected; custom CS8409 selected; apple_ibridge/apple_touchbar loaded; **skip_acpi_power=1 preserved**. Actual audio/Touch Bar operation not physically retested.

**The custom drivers are not necessary for the deep failure.** This does not establish that their PM paths are safe, or explain the custom s2idle failure. Stock s2idle was not tested. Do not uninstall working drivers merely because they were initially suspects, or repeat mode-only trials.

### What the journal does not establish

In upstream **v7.2.13** `kernel/power/suspend.c`, `pm_suspend()` prints `suspend entry` **before** `enter_state()`, filesystem sync, process freezing, device callbacks, and firmware entry. Thus the line does not prove the machine actually reached S3/s2idle. Later kernel messages can stay in RAM after journald is frozen or storage becomes unavailable; a forced reset loses them. Entry hang, actual sleep/wake failure, and an unlogged/very slow resume are still distinguishable hypotheses, not established outcomes.

The user now confirms **waiting approximately 30 seconds after opening the lid, with nothing connected to USB-C**, before forcing recovery from the failed stock test. This was therefore an empty-port battery trial, not an attached dock/storage/display case. Thirty seconds establishes no functional wake within that interval; it does **not rule out** the 77–120-second resume stalls reported on related machines. The next boot begins approximately 86 seconds after stock's entry record, including user actions and reboot/bootloader time; that interval is not the wake wait time. Do not relabel this as a successful or definitely permanent hang, and do not repeat suspend simply to wait longer. Internal NVMe and both internal Thunderbolt branches still participate in PM with all external ports empty.

Current suspend_stats all zero are **new-boot counters**, not a retrospective success/failure result. PM trace is 0; incidental `Magic number` / `pm_trace_dev_match` values are not valid evidence of a traced culprit. `/sys/fs/pstore` and ACPI DSDT are root-only and were not read. Accessible `/var/lib/systemd/pstore` has no files; that does not prove there was no crash or persistent record elsewhere.

## Ranked hypotheses

### 1. Apple S3X NVMe / PCI power transition — strongest exact-model lead

- This machine: **Apple `106b:2003`, revision 12, bound to nvme at `0000:01:00.0`**, behind root port `0000:00:1c.0` (RP01). PCI class is **`0x018002`**, not the usual `0x010802`: a generic NVMe class-only script could miss it.
- Current recovery boot: **`d3cold_allowed=1`**, `power/control=on`, state D0, exported NVMe quirks **`none`**. Firmware revision 14.17.01. Stock's flag was not sampled immediately before failure, so do not claim a measured stock value.
- The [mbp-2016-linux suspend section](https://github.com/Dunedan/mbp-2016-linux#suspend--hibernation) identifies this exact model family/controller as requiring D3cold disabled for resume.
- **Direct MacBookPro13,2 confirmation**, not just a neighboring model: [Dunedan, 2019-11-02](https://github.com/Dunedan/mbp-2016-linux/issues/37#issuecomment-549038942) reports resume restored by that change, but still taking 10–20 seconds. Neighboring-model reports are mixed; a Fedora 14,1 report describes two-minute CPU/Thunderbolt stalls even after it.
- **Mechanism checked in upstream v7.2.13:** `drivers/pci/pci-acpi.c:acpi_pci_choose_state()` limits the requested state to D3hot when `d3cold_allowed` is false; `pci-sysfs.c:d3cold_allowed_store()` updates upstream bridge D3 capabilities and requests runtime resume. It is a device-power policy change, not a disk format/firmware/partition operation.
- `power/control=on` disables ordinary runtime autosuspend, **not** system-suspend transitions. Its present value does not make the D3cold candidate redundant.
- Upstream v7.2.13's Apple `0x2003` NVMe ID entry has no dedicated quirk flags. The observed `quirks=none` is consistent with that. This is not evidence that the hardware has no power-management bug.
- NVMe APST (`nvme_core.default_ps_max_latency_us`) and PCI D3cold are different mechanisms. Under firmware-driven deep suspend, upstream NVMe code uses shutdown/reset rather than the context-retaining path. Do not substitute the popular APST=0 suggestion for the exact-model PCI issue.

**Assessment:** best-supported single-variable candidate for a future separately approved trial, **not proven on Fedora 7.2.13 here**. A transient setting would disappear on reboot; no persistent service or udev rule is justified before functional verification. Do not apply now. Its safety/recovery preparation still matters because a failed sleep can require forced power-off. Firmware could remove power independently, and multiple faults can coexist.

### 2. Alpine Ridge Thunderbolt / PCI late-noirq transition — strong related-hardware lead

This machine has **two** Alpine Ridge branches: upstream `8086:1578` at `03:00.0` and `79:00.0`, NHIs `8086:15d2` at `05:00.0` / `7b:00.0`, xHCIs `8086:15d4` at `06:00.0` / `7c:00.0`. Root ports are `00:1c.4` / `00:1d.0`. Current flags permit D3cold; runtime D3hot on idle ports is not itself a demonstrated fault.

[Omarchy PR 11570](https://github.com/omacom/omarchy/pull/11570), particularly [the 14,1 timed callback report](https://github.com/omacom/omarchy/pull/11570#issuecomment-5753051227), has a closely matching symptom: last persistent entry is suspend entry, followed by apparently dead wake. Instrumented PM rehearsals instead expose **77 seconds of noirq resume**, including xHCI/bridge timeout waits. The author reports repeated improvements on 14,2 and other users on 14,1/14,3 with pre-sleep Thunderbolt removal and post-resume rescan.

**Limits:** not a verified 13,2/Fedora fix. Reports contradict a universal D3cold explanation: 14,2 tests with D3cold blocked throughout the tree still fail from D3hot. [Issue 15630](https://github.com/omacom/omarchy/issues/15630) even contradicts itself about deep versus s2idle success. Occupied USB-C ports, mounted external storage, displays, early wakes and rescans have substantial caveats. Some reports call a failed platform PM test an entry hang, but **that test also runs noirq resume**, so direction is unproven without callbacks/timing.

**Do not paste a remove/rescan hook or write D3cold=0 across all PCI devices.** Addresses differ from this machine, and teardown can remove storage/network/display dependencies. This needs local localization and a guarded topology-aware design if eventually pursued.

### 3. Shared stock driver / firmware / kernel issue

Stock i915, applespi/SPI/LPSS, brcmfmac, HDA controller, USB/T1 generic HID/UVC, CPU/ACPI, and platform firmware are still shared candidates. No callback timing identifies one here. Intel-only 13,2 has no AMD dGPU, so Radeon/gmux/iGPU-switch fixes for 15-inch models are inapplicable.

The broadcom ARP warning before sleep also occurs during normal network setup/teardown; NetworkManager deliberately disconnects for suspend. Neither proves brcmfmac blocks PM. [Omarchy PR 7589](https://github.com/omacom/omarchy/pull/7589) describes a BCM43602 firmware/repeated-suspend failure **after a first resume**, not our demonstrated first-trial pattern. Its claimed 13,2 Wi-Fi address `03:00.0` is Thunderbolt on this machine; **never reuse it**.

Boot-time CPU ACPI `AE_ALREADY_EXISTS`/`AE_NOT_FOUND` and DMAR handle errors also existed on the original 6.19.10 boot. They merit context but are not proof of a new 7.2 regression or the suspend culprit. Original 6.19.10 has no tested sleep baseline; booting it would change userspace as well as the kernel, so any result would be a deployment comparison, not a clean kernel bisection.

## User-supplied audio repository — useful, but a separate resume issue

Reviewed [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro), both source and its open sleep-related issues/PRs. The fetched current master is **89b22ff90b86468b186706861dd18663562defa7**, exactly the revision already bundled in our local audio package. Reinstalling master would not add a newer suspend fix. Current README still says **“Power down/sleep completely unknown and untested.”**

The prepared package's `hda/codecs/cirrus/cirrus_apple.h` confirms:
- `cs_8409_apple_suspend()` is a dummy returning 0.
- `cs_8409_apple_resume()` calls `snd_hda_codec_init()` and `snd_hda_regmap_sync()`.
- The Apple `.init` routine's substantive hardware setup is commented out; full vendor/I2C/amp boot setup is called at probe, not by that resume routine.

This supports a **separate risk of silent audio after an otherwise successful wake**, because ordinary HDA regmap replay does not necessarily reconstruct Apple vendor/I2C programming after power loss. It does **not** explain the stock driver's host wake failure or establish that our custom driver's complete PM chain cannot hang.

Relevant unmerged proposals, archived with exact patches/head SHAs:
- [PR 198](https://github.com/davidjo/snd_hda_macbookpro/pull/198), head `d12f4d3ead40fe5263d17bf3ee5afcd60c98a046`: replays full boot setup on codec resume. Reports a **Fedora 43 / 6.19 / MacBookPro14,1** speaker-resume test, not 13,2 / 7.2.13. No system/runtime distinction in its added call, despite the body claiming s2idle unaffected.
- [PR 228](https://github.com/davidjo/snd_hda_macbookpro/pull/228), head `16e74390a3d176ffa0a58a344c334b573aad2a23`: reports #198 caused silent cold-boot playback with runtime power saving; adds a system-sleep notifier gate instead. Tested nine deep cycles on **14,1 / Ubuntu 7.0**, not our model. Notifier also fires for s2idle/hibernate and aborted preparations; not proof of codec power loss. File-scope state, lifecycle/concurrency/error handling and hardware behavior need review before porting.
- [PR 220](https://github.com/davidjo/snd_hda_macbookpro/pull/220), head `b8bc4d935335a9a5476c478d491adf9b18012f58`: gates replay on a measured zero codec GPIO mask (lost setup), with driver-state reset. Reports **14,3 / linux-lts 6.18.49**, many completed deep cycles, but also carries other local audio changes. Headphones, active streams, hibernation and s2idle not verified. Hardware test and the gate must be validated on subsystem **0x106b3600** here, not inferred from 14,3 **0x106b3900**.

Our current HDA runtime settings are **power_save=10, power_save_controller=Y** (read only). This makes the runtime-resume regression concern relevant; blindly applying #198 could break already-working playback before any sleep. No setting changed, codec GPIO read/verb ioctl sent, audio played, module reloaded or patch applied. Keep these proposals for **after host wake is localized/restored**, then test audio recovery with separate approval and low-volume PipeWire safeguards. Never use upstream's direct installer or live HDA reconfig on Silverblue; reports also describe reconfig lockups.

Artifacts: `research/audio-pm-selected-reports.txt`, API PR metadata/files, current README/source, and fetch manifests. The second user-supplied repository, **Dunedan/mbp-2016-linux**, is already the primary exact-model NVMe source in hypothesis 1 above.

## Research rejected as an immediate remedy

- Broad bundles of `s2idle + APST=0 + intel_idle.max_cstate=1`: [PR 14409](https://github.com/omacom/omarchy/pull/14409) tested those together on **14,1 only** and later restricted its gate accordingly. C1-only affects awake power/heat continuously. No isolated evidence for 13,2.
- `acpi_osi=Darwin`, patched DSDT, direct vendor NVMe commands, T1 firmware/authentication changes, `skip_acpi_power=0`, and blanket module/PCI removal: no sufficiently scoped evidence; some directly risk a hard freeze or loss of devices.
- PM_TRACE as a supposedly read-only diagnostic: it **writes the RTC and disables async PM**, can corrupt system date/time, and hash matches can collide. Not armed. Fedora configuration supports it, but it is a later explicit-consent diagnostic, not a default step.
- `no_console_suspend` / verbose kernel logging alone: can aid a live console capture but do not make a frozen userspace journal or inaccessible SSD reliably persistent. An in-memory trace also disappears on forced reset.

## Decision path — proposal only, no operation authorized/performed

1. Stay on the verified recovery deployment; no further lid-close or idle-suspend trials. User has answered: **30-second wake wait, no external USB-C devices** for the failed stock trial. Preserve that observation; any later diagnostic must distinguish slow resume from a hard hang without relying on journal silence alone.
2. Offer temporary automatic/lid-suspend containment **with consent**, not as a fix. GNOME still requests suspend after 900 seconds on AC and battery; the known-failed s2idle drop-in is active again on recovery. Keep lid open and remain active. Never put an awake laptop in a bag.
3. If additional read-only evidence is wanted, use narrowly scoped graphical authorization to inspect ACPI tables/power resources and pstore, and verify relevant Fedora kernel patch differences. Downloaded upstream **v7.2.13** source is a mechanism reference, **not** a verified complete Fedora source/patch audit. No admin prompt occurred today.
4. Before any future trial: saved work/backups, charger when available, no peripheral/storage dependencies, explicit readiness, exact deployment/mode record and prearranged recovery. Arrange meaningful logging/capture first. The first prospective mitigation to evaluate is **only the identity-checked Apple NVMe D3cold policy**, not a multi-setting bundle. Decide the mode explicitly; recovery currently selects s2idle whereas the exact-model historical evidence concerns deep. Changing both mode and device policy versus the last boot is not an isolated comparison.
5. If localization rather than mitigation is chosen, plan staged PM tests (`freezer`, `devices`, then `platform` only as warranted) with callback timings and a capture strategy. **Even rehearsals can hang**; higher tests run both suspend and resume. Do not automate a sweep. Passing rehearsal does not prove real firmware sleep/resume.
6. Only after a reproducible entry/exit, responsive display/input and device checks consider persistence, repeated cycles, peripheral tests and standby-power measurements. A one-off wake is not full hardware reliability.

## Artifacts and integrity

Failed stock journal: `failed-stock-kernel.log`, `failed-stock-ending.log`; deployment/state: `after-stock-failure-deployments.json`, `after-stock-failure-state.txt`, `boots-after-stock-failure.txt`. Raw research, source references, fetch manifests, selected reports and local PCI/PM evidence are under `research/`; hashes in `research/SHA256SUMS`. Local evidence contains machine/network details and should be reviewed/redacted before any public bug report. No user recordings, firmware or personalized identity data were uploaded.

**Session scope:** read-only host inspection and HTTPS research downloads; only project evidence/documentation written. No privileged commands, settings changes, module loads/unloads, PCI writes/removals, PM diagnostics, sleep or reboot.
