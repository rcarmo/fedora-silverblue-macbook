# Phase 1 S3 recipe — INSTALLED 2026-11-01 12:20, reboot + test pending

Research basis: `../docs/SLEEP-RESUME-RESEARCH.md`. Receipt (backups): `/var/lib/macbook-sleep-phase1-csZYkCwn`.

| Installed | Purpose |
|---|---|
| `/etc/systemd/sleep.conf.d/90-macbook-deep.conf` (replaces `90-macbook-s2idle.conf`) | real S3 |
| `/etc/systemd/system/systemd-suspend.service.d/50-macbook-s3.conf` | runs hook pre/post every suspend |
| `/usr/local/sbin/macbook-sleep-hook` | deep; NVMe d3cold=0 (aborts suspend if impossible); Wi-Fi unbind/rebind; calls TB hook |
| `/usr/local/sbin/macbook-thunderbolt-remove-rescan` | omarchy PR #11570 @3aab5a0, byte-identical (MIT) |
| `/etc/udev/rules.d/61-macbook-nvme-d3cold.rules` | NVMe 106b:2003 d3cold_allowed=0 (verified 0 live) |
| `/etc/udev/rules.d/99-macbook-usbc-runtime.rules` + `macbook-usbc-runtime.service` | USB-C root hubs awake on BOTH sides, matched by 8086:15d4 (replaces right-only `99-macbook-right-usb3-runtime.*`, disabled/removed) |
| karg `firmware_class.path=/etc/firmware/macbook-wifi` | NVRAM found on Wi-Fi rebind (staged deployment ea9c0ec, needs reboot) |

Hashes: `files/SHA256SUMS`, `install.log`. Undo: `undo-phase1.sh <receipt>` + karg delete (see script header).

## After reboot (assistant audit first)
1. Verify `/proc/cmdline` has the karg, booted deployment, hooks, NVMe 0, both USB-C root hubs `on`, 5 GHz.
2. Awake Wi-Fi unbind/rebind check (~10 s Wi-Fi drop): NVRAM must load from /etc, Band 2 present.
3. ONE attended test: `pkexec /usr/bin/bash .../sleep-phase1/run-s3-test.sh 120` — charger in, nothing else in USB-C, lid open, hands off 10 s. If it hangs: wait 3 min, then hold power and report.

Until the test passes: lid close now uses this untested path — keep the lid open; GNOME idle suspend stays off.
