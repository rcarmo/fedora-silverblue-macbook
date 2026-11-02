# Apple NVMe D3cold trial — APPLIED, suspend outcome PENDING

2026-11-01, approximately 09:08 WET. User requested trying the researched NVMe fix. This supersedes the earlier research-only prohibition on applying this one setting; it does not authorize Wi-Fi staging or an assistant-triggered sleep/reboot.

## Latest arming checkpoint — 09:20 WET; user test PENDING
User selected **deep** and confirmed saved work. Installed only **`/run/systemd/sleep.conf.d/91-macbook-deep-test.conf`**, root:root0644, via scoped graphical pkexec/install. Merged configuration verifies **SuspendState=mem, MemorySleepMode=deep**, taking precedence over the retained /etc90-s2idle file. The runtime override disappears on reboot; no /etc file removed or altered. Source copy is `91-macbook-deep-test.conf`.

Same recovery boot/checksum, rpm-ostree idle/no staged deployment, **NVMe D3cold=0**, PM test none/trace0, no current suspend entry verified. Battery **57.6% discharging**, adapter0, no low warning; user has no charger. Wi-Fi connected/unchanged, skip_acpi_power=1 retained. Receipt: `deep-nvme-arming-receipt.json`; merged config: `deep-nvme-effective-sleep-config.txt`; audit: `pre-deep-nvme-test-{state.txt,deployments.json}`.

Giving instructions for **one user-performed attended lid close for60 seconds, then lid open**. If black, wait up to3 minutes after opening (related machines can resume very slowly); if still unresponsive recover once as before into :0 and report. No repeat trials. Unplug headphones, no external devices/storage, saved work confirmed. No assistant-triggered sleep/reboot. Require actual deep entry/exit and display/input/device checks before success; this is a comparison against earlier custom deep failure, not the immediately previous s2idle configuration.

If cancelling without reboot, narrowly remove only the runtime file after verifying its identity/contents; that restores known-failed s2idle from /etc90. A reboot also loses both this override and the transient NVMe policy. Neither reset is a suspend fix. GNOME auto-suspend remains enabled; never bag an awake/unverified sleeping machine.

## Original NVMe policy scope and verification
- Recovery `(ostree:0)` c4ebdd8.0 remains booted, kernel `7.2.13-200.fc44.x86_64`, boot ID `<uuid>`.
- rpm-ostree idle/no staged deployment; order unchanged. FAILED Wi-Fi trial b0a3115 remains second. Never blindly rollback.
- Graphically authorized **pkexec /usr/bin/python3 -I -c** command checks root identity, exact model/kernel/boot ID, target vendor/device and nvme driver binding before writing.
- Only written sysfs attribute: `/sys/bus/pci/devices/0000:01:00.0/d3cold_allowed`, Apple **106b:2003**, nvme bound.
- **Before 1, after 0; readback verified.** Kernel PCI code updates upstream bridge D3 capabilities as a consequence; no separate root-port setting was written.
- Receipt: `nvme-d3cold-apply.log`. Pre-change deployment snapshot: `pre-nvme-policy-deployments.json`.

## Not a confirmed suspend fix
No suspend/reboot, PM test, driver reload, Wi-Fi/firmware change, APST/C-state/ACPI argument, persistent service or udev rule was performed/installed. Both custom audio and Touch Bar remain present with skip_acpi_power=1. NetworkManager still reports Wi-Fi connected.

The setting is **transient for this boot**; a reboot normally restores default 1 because no persistence was installed. Re-audit before reapplying. To undo within this same boot, after verifying the same Apple/nvme target and boot, write the recorded previous value 1 back to this attribute with narrowly scoped graphical authorization. Do not change unrelated PCI devices.

## Historical pre-arming mode/readiness state (superseded above)
**Pre-arming user decision:** DEEP selected, with comment97 files requested first. Files downloaded into `../wifi-comment97/`; no Wi-Fi installation. **Deep is not yet armed** and saved-work/readiness has not been confirmed. Do not give lid-close instructions until the actual mode is configured and verified.

Recovery still has the **known-failed** `/etc/systemd/sleep.conf.d/90-macbook-s2idle.conf` selecting s2idle for the next systemd suspend. `/sys/power/mem_sleep` may still show `s2idle [deep]` before systemd writes its selection. We did **not** change mode:
- Testing the current recovery s2idle configuration would compare against the previous custom s2idle failure with the NVMe policy as the only intended change.
- The direct historical 13,2 NVMe report concerns deep sleep; testing deep requires an explicit separately recorded mode decision. Do not silently remove the s2idle override or call a two-setting change a one-variable comparison.

No test instructions issued before explicit saved-work/readiness confirmation. Initial battery was about 64.4% (UPower), discharging, no charger/low warning. Connect charger when available and arrange no external storage/dock/display dependencies, unplug headphones, save work/backups, keep user present, prearrange exact recovery. No repeated automatic trials. Related hardware has long resume stalls; agree a bounded wait/capture plan before interpreting black screen as a hard hang.

Require recorded actual mode and entry/exit, responsive display/input and device checks before declaring success. A successful short wake would not prove repeated-cycle reliability or standby consumption.

**GNOME still auto-suspends after 900 seconds on battery and AC.** No containment applied. Keep lid open and remain active pending an attended test; never bag an awake laptop.
