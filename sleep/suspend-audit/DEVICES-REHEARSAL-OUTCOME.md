# Devices rehearsal FAILED functionally — 2026-11-01

## Observations and evidence

User reports Wi-Fi was lost during the test and never recovered in that session; display blanked but Touch Bar never shut off. These are not successful sleep/wake observations.

Exact tested boot: `<uuid>`, corrected Wi-Fi deployment `39e497f.0`, kernel `7.2.13-200.fc44.x86_64`.

`devices-rehearsal-run.log` reports one devices rehearsal, suspend target exit 0 after 6.98 seconds, and verified restoration of pm_test=none/pm_print_times=0. Exit 0 means the transition returned, NOT that hardware recovered. Kernel entry at 10:10:05.991418 is s2idle; exit is recorded. The guarded devices checkpoint bypasses actual sleep and late/noirq paths. Display blanking during ordinary callbacks does not establish actual sleep.

Kernel callback timing: device suspend 0.561 seconds, resume 0.545 seconds. brcmfmac PCI suspend/resume callbacks return 0, but firmware query timeouts appear and persist afterward, followed by commonring reservation failures and scan errors (-12). This is firmware/driver communication failure, not merely association/WPA3 or a password problem. The -12 ring errors do not by themselves diagnose system RAM exhaustion.

An additional concrete lead appears at monotonic659.929 / 10:10:06.051157: `Direct firmware load for brcm/brcmfmac43602-pcie.txt failed with error -2`. The personalized NVRAM is currently only supplied in initramfs; normal-root reset/resume integration was never established. Investigate this request and driver firmware-cache/PM paths read-only before proposing a scoped integration fix. Missing optional NVRAM alone does NOT establish why firmware stopped responding.

This rehearsal reproduces Wi-Fi failure without exercising the late/noirq/real-sleep path responsible for prior Thunderbolt/xHCI stalls. Do not attribute this failure solely to those prior stalls or advance to a platform rehearsal. No new 65535ms readiness stalls found in this test's kernel log.

## USB Ethernet recovery also failed — user correction

User additionally reports the USB Ethernet adapter could not be used after the rehearsal. This is an additional functional failure; alternate networking was NOT a working recovery route in that session. User clarifies: adapter was NOT working/verified before the test; it was plugged in AFTERWARD to recover connectivity, and is now unplugged. Adapter model and port remain unknown. This is a failed post-test recovery attempt, not evidence that a previously working Ethernet adapter regressed across suspend.

Read-only search of the captured 10:09-through-reboot journal found no external USB adapter enumeration, Ethernet interface registration or common USB Ethernet driver messages. Current lsusb shows only root hubs/internal iBridge; NM lists no Ethernet device. The user confirms it is currently unplugged, so its absence from current lsusb/NM is expected and supplies no failure evidence. The failed-boot log absence does not distinguish USB/port enumeration failure from adapter/cable/driver/network issues. Ordinary xHCI callbacks returning0 do NOT demonstrate working post-test USB hotplug. Prior Thunderbolt/xHCI problems remain relevant; absence of the earlier65535ms stalls does not rule out another USB recovery failure. Do not narrow the whole incident to Wi-Fi/NVRAM alone or rely on USB Ethernet as verified recovery.

### Fresh-boot adapter check — 10:21:26

User plugged the adapter back in, without a network cable. Read-only lsusb/lsusb -t still show only root hubs/internal iBridge; ip link/NM show no Ethernet interface, and no kernel messages appear in the preceding5minutes. A USB Ethernet adapter normally enumerates and creates an interface without an Ethernet cable; no cable prevents carrier/connectivity, not USB detection. Therefore this adapter's detection problem is also present on the fresh boot, without another suspend, and cannot be called exclusively a resume regression. User confirms direct connection to RIGHT port nearest them (front), adapter LED lit, no hub/dongle or Ethernet cable. Model/connection type (USB versus Thunderbolt) remains unconfirmed. LED shows some power reaches the adapter, not working USB data. Repeat10:22 read-only check still shows no external USB device/recent kernel events; boltctl list is empty and both external xHCI controllers are bound. Physical-port-to-PCI-branch mapping not established. Evidence also `usb-ethernet-right-front-check.txt`. Evidence `usb-ethernet-fresh-boot-detection.txt`. No driver loads/resets, policy/config changes or tests initiated.

### Port move / later enumeration — 10:23 update

IMPORTANT correction to point-in-time no-detection snapshots: at10:22:26 (immediately after previous snapshot), kernel DID enumerate Realtek RTL8153 `0bda:8153` on USB6-2 behind PCI7c:00.0, loaded stock r8152 and created `enp124s0u2` at10:22:27. Thus compatible driver is present and at least one fresh-boot insertion successfully created an Ethernet interface. Physical port association is inferred from user sequence (right/front before requested move), not independently verified.

At10:22:48 device disconnected, consistent with user moving it; xHCI logged `WARN Set TR Deq Ptr cmd failed due to incorrect slot or ep state`, and r8152 interrupt submission stopped-108. Do not diagnose the unplug warning as cause of failed re-enumeration without more evidence. After user reports left/front insertion, snapshots10:23:08 and10:23:25 show no adapter/interface and no subsequent enumeration. Current left/front detection has not succeeded; no network cable/connectivity test performed. User then flipped USB-C connector and reinserted SAME left/front port;10:24:22 snapshot still no external USB device/Ethernet interface/new kernel events. Evidence `usb-ethernet-left-front-flipped.txt`. Both orientations fail detection in this comparison, but physical port damage versus controller/negotiation/adapter issue remains unresolved. User then moved back to RIGHT/front and waited~15s;10:25:02 still no USB device/Ethernet interface/new kernel event (`usb-ethernet-right-front-repeat.txt`). Earlier successful enumeration is NOT repeatable so far; do not conclude left-only fault. Stop repeated port shuffling; next useful isolation is a known-good different USB data device on this laptop or this adapter on another computer, if available. No controller reset/removal or new sleep authorized. Evidence `usb-ethernet-left-front-{check,recheck}.txt`. No manual driver loads/resets or configuration changes; kernel automatically bound driver on detection.

## Touch Bar

Record the user's observation literally: display blanked, Touch Bar remained lit. The guard skip_acpi_power=1 intentionally skips risky T1 ACPI power calls, and must remain enabled. Separately, local apple-touchbar.c appletb_suspend attempts MODE_OFF and DISP_OFF once both interfaces are suspended for PM_EVENT_SUSPEND. No `Touchbar suspended.` message was found in this rehearsal. Why the expected display-off handling was not observed remains unresolved; callback routing/interface handling and command completion need read-only inspection. Staying lit does not prove host wake or prove the Touch Bar caused the Wi-Fi failure. Never force skip_acpi_power=0 to make it turn off.

## Recovery/current state

Journal records orderly reboot beginning 10:14:53, next boot `<uuid>` starting 10:15:12. Corrected `39e497f.0` remains booted/first, rpm-ostree idle/no staged deployment. NetworkManager now reports wlp2s0 connected to profile `7`, firmware7.35.177.61 attaches at boot. Internet reachability was not separately tested. This is recovery after reboot, NOT recovery by the rehearsal.

At 10:17:18 flags are none/0 and Touch Bar guard1; sysfs mem_sleep is s2idle [deep] before systemd's next mode selection. UPower22.959% charging/no warning. No privileged commands, system configuration changes, resets, suspend or reboot were initiated during this read-only audit.

Evidence: `devices-rehearsal-{run.log,kernel.log,ending.log}`, `after-devices-restart-{deployments.json,state.txt}`.

Stop further PM rehearsals/real-sleep trials pending analysis and separate approval. Existing auto-suspend remains enabled; keep active/lid open and never bag an awake/unverified sleeping laptop. Temporary containment requires consent. Do not live reload brcmfmac with the current early-boot-only firmware integration.
