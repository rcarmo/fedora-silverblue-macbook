# NVMe trial outcome — 2026-11-01 09:30 WET read-only audit

User reports eventual host resume after approximately one minute, Wi-Fi unavailable until a NORMAL restart. Partial functional resume, not reliable suspend or a proven NVMe fix.

## Critical mode correction

Prepared temporary deep override was visible to `systemd-analyze cat-config`, but systemd-sleep was denied access by SELinux:

`09:22:04.380 AVC denied { read } comm=systemd-sleep name=sleep.conf.d dev=tmpfs ... tcontext=unconfined_u:object_r:init_var_run_t:s0`

Actual kernel entry at 09:22:04.412334 is **PM: suspend entry (s2idle)**. Thus this was s2idle with previously verified NVMe d3cold_allowed=0, NOT deep. Earlier merged-config verification was insufficient. Do not disable SELinux; any future override needs appropriate labeling/access verification and actual kernel-mode verification. No corrected override applied here.

## Recorded outcome

- Lid close logged 09:22:02; `PM: suspend exit` 09:25:53.337462; systemd returned from sleep successfully.
- Several Alpine Ridge PCI bridges inaccessible across D3cold/D0 transitions. Thunderbolt `tb_resume_noirq` configuration read/write WARNs.
- xHCI 0000:06:00.0 and 0000:7c:00.0 report escalating waits, ultimately `not ready 65535ms after resume; giving up`. Concrete device failure/long-wait lead, not proof every second of user delay has been accounted for. Journal timestamps cluster due to suspend/buffering; lid-open journal time is not reliable physical wake-onset timing.
- NVMe reestablishes queues; disk-backed journal and normal user restart work. Does not establish causality of D3cold policy; previous failures only waited about 30 seconds.
- Broadcom interface persists as phy0/wlp2s0, but driver firmware-command responses repeatedly time out (`brcmf_msgbuf_query_dcmd`, errors -5); supplicant initialization fails. Not merely absent 5 GHz/association trouble; underlying firmware/PCI recovery cause unresolved. WCC is loaded in this working image; unrelated failed NVRAM trial remains separate.
- Normal restart requested at 09:28:27; shutdown records retained.

## Current state after restart

Boot c26ba3cd78a140ba9e36952baea10ec1, recovery c4ebdd8.0, kernel 7.2.13. rpm-ostree idle/no staged deployment; failed Wi-Fi image remains second. Wi-Fi connected. Custom codec selected; skip_acpi_power=1.

Transient NVMe flag reset to **1**, temporary /run deep override absent. Persistent /etc s2idle override remains. GNOME automatic suspend remains enabled at 900 seconds for AC and battery. No containment applied. Keep active/lid open; never bag an awake or unverified-sleeping laptop.

Only user-owned evidence/documentation written; no privileged operations, policy reapplication, driver resets, suspend/reboot or system changes. Do not immediately repeat tests or persist NVMe policy on this evidence. Next: investigate recorded Thunderbolt/xHCI and brcmfmac recovery failures read-only; separate approval/readiness required for any mitigation trial.

Evidence: deep-nvme-trial-kernel.log, deep-nvme-trial-kernel-monotonic.log, deep-nvme-trial-ending.log, after-deep-nvme-restart-state.txt, after-deep-nvme-restart-deployments.json.
