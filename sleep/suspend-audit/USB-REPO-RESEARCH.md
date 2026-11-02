# USB Ethernet / USB-C repository research — 2026-11-01

User requested research in their supplied repositories rather than more port shuffling. Research only: no admin prompts, manual module loads/unloads, PCI removals/resets, power-policy writes, kernel arguments, firmware changes, suspend or reboot.

## Best match: runtime USB hotplug / autosuspend

Fresh GitHub issue searches and selected complete threads from Dunedan/mbp-2016-linux yielded:

1. **[Issue120: devices absent from lsusb after insertion](https://github.com/Dunedan/mbp-2016-linux/issues/120)**. Initial report is14,3/Debian5.2; **[comment535040180](https://github.com/Dunedan/mbp-2016-linux/issues/120#issuecomment-535040180)** specifically reports a USB-C GigE adapter intermittently requiring xhci_pci unload/reload. Other reports describe USB3/battery/autosuspend, descriptor probing waking the devices, and a Fedora30/14,1 global autosuspend workaround. This closely matches failed detection after insertion, but is NOT exact13,2/Fedora7.2.13 verification.
2. **[Issue178: USB3 regression](https://github.com/Dunedan/mbp-2016-linux/issues/178)**. Initial14,3 report: no lsusb/dmesg detection, USB2 works, USB3 works over a USB2 connection; attributes onset to root-hub power-on-good delay commit90d28fb53d4a51299ff324dede015d5cb11b88a2 (5.10 stable972b4c19...). **[comment891695046](https://github.com/Dunedan/mbp-2016-linux/issues/178#issuecomment-891695046)** explicitly says ports supply power and disks spin, but devices remain undetected; root-hub power/control=on or disabling autosuspend helped. Later reports include13,1 and14,1, and one case where devices work until unplug/replug. Claimed commit regression is not independently bisected here or proven still causal on7.2.13. Do not revert an old patch blindly.
3. **[Issue96: USB-C dock/cable](https://github.com/Dunedan/mbp-2016-linux/issues/96)**. Same Realtek ID0bda:8153/r8152 as our adapter, but14,1 with a dock. Reports SuperSpeed errors/U1/U2/LTM and cables changing observed PCI/USB path. **[roadrunner2 comment477444630](https://github.com/Dunedan/mbp-2016-linux/issues/96#issuecomment-477444630)** explains different controller paths likely reflect negotiated connection mode. Descriptor probes sometimes help and sometimes do not. This supports runtime/controller/USB3-path investigation, not a confirmed r8152 patch or cable diagnosis. Our journal lacks its -71/U1/U2/LTM sequence; our -108 occurs on disconnect. Its kernel bug204871 is a follow-up reference, not reviewed yet.
4. **[Issue36: hit-or-miss USB hotplug](https://github.com/Dunedan/mbp-2016-linux/issues/36)** includes failures with no log output and separate reports of physically faulty adapters. It reinforces that silent logs neither prove software failure nor rule it out.

## Local comparison

Our RTL8153 was successfully enumerated once at10:22:26 on USB6-2 behind7c:00.0; stock r8152 created enp124s0u2. Adapter driver is available. Disconnect10:22:48 during port-move sequence logs xHCI TR Deq Ptr warning/-108; not proven cause. Left/front both orientations and return to right/front failed subsequent enumeration. Missing Ethernet cable prevents carrier, not USB detection. LED proves some power, not successful data negotiation.

**10:26:31 read-only runtime PM snapshot:** both external PCI xHCI06:00.0 and7c:00.0 have power/control=auto, runtime_status=suspended, d3cold_allowed=1. USB roots3–6 also auto/suspended, autosuspend_delay_ms=0. usbcore autosuspend parameter2. USB6 accumulated~23.7s active, consistent with the one enumerated interval. Internal roots1/2 also suspended; their state is not by itself a fault. PCI runtime PM and USB root-hub PM are distinct layers. Normally an insertion should wake a suspended hub/controller; suspended state alone does NOT prove lost wake notification.

This is **fresh-boot runtime hotplug trouble, without another system suspend**. It should be tracked separately from previous actual-sleep Thunderbolt late/noirq65535ms failures, although both involve external Alpine Ridge hardware. A USB runtime workaround would NOT establish a system sleep fix or repair Broadcom firmware recovery.

## What not to copy

- Do NOT unload/reload xhci_pci globally: it also owns internal00:14.0/iBridge camera/Touch Bar, and would disrupt attached USB devices/storage.
- Do NOT run usbhid-dump: unrelated HID capture/interface disruption is inappropriate here.
- Do NOT use blanket USB/PCI power changes, pci=nommconf, pci=nocrs or edit/regenerate GRUB as a first fix. Global usbcore.autosuspend=-1 has broad power/battery consequences and is not an isolated diagnosis.
- Reports of root `lsusb -v` recovery are not purely observational: USB descriptor/control transfers may runtime-resume hardware. It can perturb the symptom; any such diagnostic must be deliberate, recorded and scoped.

## Thunderbolt authorization is a different case

**[Issue87](https://github.com/Dunedan/mbp-2016-linux/issues/87)** includes missing Ethernet behind Thunderbolt displays/adapters, mixed outcomes, and warnings that auto-authorizing all Thunderbolt devices creates a major security gap. Our adapter enumerated as native USB RTL8153, directly connected; no tunneled Thunderbolt peripheral is established. Empty boltctl list is therefore expected and NOT evidence it needs authorization. Do not copy its authorize-all udev rule, SMC/NVRAM reset or firmware suggestions.

Repository README's generic USB/Thunderbolt 'working' status is not a guarantee; it also acknowledges incomplete Thunderbolt power management. The issue evidence is more specific to current symptoms.

## Audio repository

Searches in davidjo/snd_hda_macbookpro find **[issue140: network gone after install](https://github.com/davidjo/snd_hda_macbookpro/issues/140)**, but its body gives no USB adapter ID, hotplug logs or causal mechanism (2017/Ubuntu report). Comments could not be fetched due to GitHub rate limiting, so no resolution claim. **[PR90](https://github.com/davidjo/snd_hda_macbookpro/pull/90)** is codec boot reinitialization on S3 resume, not a USB Ethernet/controller fix. Prior reviewed PR198/220/228 concern audio recovery after host wake. No basis to reinstall/remove working audio drivers for this symptom. Previously tested stock deep failure also does not require custom audio/Touch Bar drivers.

## Next useful step — proposal only

Stop physical port repetition. A separately approved, narrowly scoped **transient runtime-PM diagnostic** on ONE mapped external branch could distinguish root-hub autosuspend/wake failure: baseline topology/attached devices/power state, set only that branch's relevant USB root-hub control to on with exact identity guards, observe whether the already-connected adapter appears, and restore originals after capture. Root-hub versus PCI-controller layer should be separated; no global writes, internal00:14.0 change, PCI removal/reset, D3cold changes or system suspend. If root-hub-only does not help, stop and review before any PCI-runtime-policy change. Changes may raise power use and restoration may cause re-suspend; require consent/readiness and no external mounted storage/critical devices. Physical port mapping beyond our successful USB6-2 event remains inferred; re-audit before implementation.

No diagnostic has been prepared/applied by this research request. More upstream investigation of kernel USB runtime wake/root-hub sequence and bug204871 is appropriate before claiming a fix. Independent adapter/known-good USB-device comparison remains useful but is not substituted for repository research.

## Evidence / coverage limits

`usb-repo-research/` contains six fresh issue-search JSON results, issue bodies, selected comment threads and `selected-threads.txt`, plus local-runtime-pm.txt. `usb-repo-fetch.log` records downloads/errors. Selected Dunedan threads36/120/178/87/96 fetched fully (all fewer than100comments); broader threads with100entries are first-page-only. GitHub rate limits403/429 prevented remaining comment fetches; no retries to evade limits. Attempted upstream v7.2 USB PM docs fetch also failed429; independent source verification of the proposed PM mechanism is incomplete. Prior cached repository README read fully. Search/body download does not mean every unrelated thread was reviewed. Only project files were written.
