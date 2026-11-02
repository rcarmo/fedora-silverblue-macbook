# Persistent tested-branch USB3 hotplug workaround — 2026-11-01

## Installed and live verified

User requested a permanent fix after successful scoped root-hub diagnostic. Installed a **persistent workaround**, not an upstream driver fix or demonstrated system-sleep fix:

- `/etc/udev/rules.d/99-macbook-right-usb3-runtime.rules`
- `/etc/systemd/system/macbook-right-usb3-runtime.service`
- Enabled service link in `multi-user.target.wants`.

Rule matches add/change events ONLY for Linux USB3 ROOT hub(devpath0, KERNELusb*,1d6b:0003) whose same PCI ancestor is7c:00.0/8086:15d4. It writes only root hub power/control=on. Does not depend on USB bus numbering staying6. Does not change USB2 root, internal00:14.0/iBridge, other external branch06:00.0, PCI power/control, D3cold, NVMe, Wi-Fi firmware/profiles, or system sleep.

One-shot boot service with MacBookPro13,2 DMI guard replays only this root-hub event after udev/tuned. Needed because hubs may already enumerate in initramfs, which does not contain the new rule. No initramfs/deployment rebuild. Rule handles subsequent add/change; there is no polling daemon or resume hook. Oneshot remains active(exited), no running process after completion.

**Tradeoff:** hub stays runtimeactive, keeping parent controller awake and potentially increasing idle battery use. No battery cost measured. Does not prevent system-suspend callbacks and does not make them safe. Does not permanently fix the left-side branch; that needs separately scoped validation before expansion. Successful adapter detection has mapped right/front to USB6-2/PCI7c:00.0 in this session; other physical-port mapping is not fully audited.

## Tuned review

Current tuned profilepowersave; dynamic_tuning0. Reviewed shipped powersave script/functions and USB plugin: legacy USB setting writes power/autosuspend(delay), not power/control. No active profile USB plugin/control override found. No tuned changes made. Boot unit ordered after tuned when present; ordering does not start/force tuned. Future profiles/tools such as powertop auto-tune could overwrite sysfs and require review; this is not guaranteed enforcement against every external writer.

## Verification at10:39:45

- Both installed files root:root0644, restorecon gives udev_rules_t/systemd_unit_file_t; bytes exactly match reviewed SHA256.
- Udev rule syntax verified and systemd unit verificationpassed. Dry-run trigger matches ONLY usb6 on tested branch, not its adapter or other hubs.
- Unit enabled and active(exited), targeted settled change event completed successfully10:39:33.
- USB6 controlon/runtimeactive; other USB roots1–5 remainauto; both external PCI policies remainauto.
- RTL8153 still detected; enp124s0u2 exists/no Ethernet cable (NMunavailable expected); Wi-Fi NMconnected.
- PM flagsnone/0, Touch Bar guard1 unchanged. Bootf23f5beb/kernel7.2.13/deployment39e497f remains booted; no deployment composition/reboot/suspend.

**One attended unplug/replug PASSED:** user unplugged at10:43:06, hub remainedon/active while adapter/interface disappeared. Replug in same right/front port enumerated RTL8153 as USB6 device4 and recreated enp124s0u2 at10:43:24, without any additional administrative intervention. Snapshot10:43:39 confirms device/interface and Wi-Fi connected. Unplug again logged xHCI TR Deq Ptr warning/-108, but it did NOT prevent this successful reconnect; warning remains unresolved, not evidence of failed recovery by itself. Evidence `usb6-persistent-{unplug,replug}-check.txt`.

**Not yet independently tested:** repeated hotplug cycles, actual Ethernet link/DHCP/reachability, subsequent boot persistence or battery cost. Enabled boot configuration and live rule verification are not equivalent to having reboot-tested it. No reboot or sleep test should be performed merely to prove this now.

## Undo (prepared, NOT executed)

With adapter unplugged and no critical external USB use, from project directory:

```bash
bash sleep/suspend-audit/undo-right-usb3-runtime.sh
```

Graphical admin approval. Script checks exact installed hashes, disables ONLY this service, removes ONLY its two configuration files, reloads systemd/udev and restores baselineauto on matching root hub. Refuses modified/missing files rather than deleting unknown configuration. Root receipt is retained. Returningauto may bring the detection problem back. Merely stopping the oneshot does NOT undo sysfs or remove the udev rule.

Rule hash96a25429a5879959a6e70f92a21b70eb6c448de11ed4631060bb299a3d5f708a; service hash3e0806921421a637348714228ab991c9394c8bd7d336a1c89657f56816b8952e.

## Evidence

Root baseline/success receipt `/var/lib/macbook-usb-runtime-qsr7b_8g` (preserve). Project: reviewed rule/unit, `install-right-usb3-runtime.sh`, installer log, `usb6-persistent-verification.txt`, service journal, preflight/after deployment JSON, udev attribute walk and local manual snapshot. Installer checked exact boot/model/kernel/deployment/PM flags/topology/PCI ID/no unexpected USB devices and refused existing destinations. No other configuration replaced. Installer includes failure rollback; actual rollback/undo not executed on host.

Keep lid open/active; auto-suspend remains enabled, no containment change. Never bag laptop unless reliably sleeping/shut down. This USB runtime workaround does not resolve Broadcom firmware recovery, Touch Bar display-off behavior or previous actual-sleep Thunderbolt/noirq stalls.
