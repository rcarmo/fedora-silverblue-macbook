# USB6 runtime diagnostic — detection restored, not a persistent fix

2026-11-01, user explicitly approved proposed scoped diagnostic with 'go'. Adapter left directly connected on right/front (nearest user), no Ethernet cable. No physical replug requested during the diagnostic.

## Operation

Fresh baseline bootf23f5beb/kernel7.2.13/deployment39e497f.0 first/booted; rpm-ostree idle/no staged; battery46.6375% charging/no warning. USB inventory contains only root hubs/internal iBridge, no external mounted storage. Target exact USB3 root `usb6` behind PCI7c:00.0/8086:15d4/xhci_hcd; baseline auto/runtime-suspended. Touch Bar guard1; pm_testnone/pm_print_times0; sleep service inactive.

Prepared syntax-checked `run-usb6-runtime-diagnostic.sh`; graphical pkexec launches transient systemd-inhibited service with literal isolated Python, exact identity/topology/state guards. Only policy write: **usb6/power/control auto -> on for~15.7seconds -> auto**; restoration in finally and independent readback. Temporary sleep-block inhibitor only during diagnostic, now gone. No persistent hook or kernel args, no sleep/system reboot, no manual driver reload/controller reset/PCI write/removal/D3cold setting change. Kernel r8152 performs its normal automatic device reset during successful probe; not a separate assistant-initiated reset experiment.

## Result

Before10:35:37: adapter absent. At10:35:37.223621 wrote root-hub controlon. Hub became active and automatically runtime-resumed parent PCI7c:00.0 while PCI policy remainedauto. Kernel enumerated **Realtek RTL8153 USB6-2/0bda:8153** at10:35:37–38 and stock r8152 created **enp124s0u2**. Adapter visible by5-second snapshot and throughout15-second check. Setting restoredauto at10:35:52.924730; adapter still visible afterward/independent10:36check.

This is strong local intervention evidence for a **runtime hub/controller wake/detection failure**, matching Dunedan issues120/178, rather than missing adapter driver or Ethernet cable. It does not isolate root hub versus parent controller/port firmware mechanism: root-hub wake necessarily resumes parent hardware. It also does not prove every prior failed insertion or suspend failure shares this cause. No repeatability/left-side test across controlled runtime re-suspend performed.

NM marks Ethernetunavailable because link has **NO-CARRIER/carrier0**, expected with no Ethernet cable. Device exists/bound; actual Ethernet link/DHCP/reachability remains untested. Wi-Fi stays NMconnected. USB6/parent remain runtimeactive at independent check while adapter is attached; other external roots3–5/controller06:00.0 still auto/suspended. Original policy restored, not expected immediate return to suspended state with new active device present.

## Next

Do not call this a permanent fix or system-sleep fix. No additional policy changes/PM tests authorized by this one diagnostic. With separate approval/readiness, options are a scoped repeatability check or planned root-hub-specific persistent runtime workaround with battery/power tradeoff after validating both branches. Actual Ethernet cable test can independently verify network operation. No need to unload xhci/r8152 or modify Thunderbolt authorization. Broadcom reset/resume NVRAM and actual sleep noirq failures remain separate unresolved work.

Evidence: `usb-root-hub-preflight.txt`, preflight deployments JSON, `usb6-runtime-diagnostic-{run.log,kernel.log,after.txt}`. Upstream hub.c v7.2 fetch did succeed (earlier report grouped source coverage too broadly); USB PM documentation fetch failed429. Upstream source version is reference, not full Fedora patch audit.
