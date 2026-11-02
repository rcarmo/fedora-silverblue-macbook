# Return to sleep/resume — 2026-11-01 10:06 WET

**SUPERSEDED: this rehearsal was executed and FAILED Wi-Fi recovery. Do not rerun or advance to platform/real sleep.** See `DEVICES-REHEARSAL-OUTCOME.md` and latest `PROGRESS.md`. Display blanked but Touch Bar stayed lit; test returned, Wi-Fi remained broken until subsequent reboot. Instructions below are historical preparation, not current authorization.

User accepts doing without WPA3 and requests resuming sleep investigation. User agrees to one diagnostic/readiness and confirms adequate battery without charger; fresh UPower29.35%/no warning. Guarded user-triggered launcher prepared: `run-devices-rehearsal.sh`. Shell/embedded Python syntax checked; host execution still PENDING. No diagnostic flags armed or suspend triggered.

Run ONCE from project directory, with lid open/work saved:

```bash
bash sleep/suspend-audit/run-devices-rehearsal.sh 2>&1 | tee sleep/suspend-audit/devices-rehearsal-run.log
```

Graphical pkexec launches a transient system-slice service (supervisor must not be in the frozen user.slice). Literal isolated Python guards exact boot/kernel/deployment/model, >=25% UPower/no warning, no staging/transaction, Touch Bar guard, effective s2idle config and baseline flags. It temporarily sets pm_print_times=1/pm_test=devices, runs blocking `systemctl start suspend.target` (waits for the oneshot sleep dependency to finish), then restores both flags in finally. No mode/power-policy/firmware/driver changes or persistent hook. Interrupt signals ignored during transition so flags cannot be reset prematurely; a hard hang may still require reboot. Graphical authorization/test are user-triggered, not performed by assistant. Wait up to3min if stalled, no repeated run; report elapsed/functionality or forced restart and re-audit exact boot.

## Current state

Corrected Wi-Fi deployment 39e497f.0 remains booted, kernel7.2.13, rpm-ostree idle/no staged. Persistent /etc sleep override selects s2idle on next systemd suspend; sysfs currently s2idle [deep] before systemd writes mode. pm_test=none, pm_print_times=0, test delay5 seconds. No suspend entry in this boot. NVMe and Wi-Fi d3cold_allowed=1, runtime control=on. GNOME auto-suspend timeouts remain900 seconds. UPower29.8% discharging, ~46 minutes estimated; request charger before further attended diagnostics.

## Localized prior failures

Last actual s2idle/NVMe trial showed both Thunderbolt branches inaccessible: upstream03:00.0/79:00.0 and downstream04:*/7a:* bridges, NHI05:00.0/7b:00.0 and xHCI06:00.0/7c:00.0. xHCI readiness waits ended at65535ms; Thunderbolt tb_resume_noirq WARNs. NVMe resumed sufficiently for journal/restart; this does not prove the NVMe policy caused recovery. Wi-Fi firmware commands timed out, a separate fault; corrected NVRAM now differs and sleep has NOT been retested on it.

Current USB topology has no devices under either external Alpine Ridge xHCI (buses3–6). Internal T1 camera/HID is under00:14.0 (bus1), outside those branches; Wi-Fi02:00.0 and NVMe01:00.0 are separate root-port branches. This helps scope future isolation but does not authorize removals. No external branch device teardown/rescan, blanket D3cold changes, firmware reloads or Touch Bar guard changes.

## Proposed next diagnostic, consent/readiness pending

A single callback-timed `devices` PM rehearsal with existing s2idle selection and no power-policy changes. It suspends/resumes ordinary device callbacks and automatically returns after the kernel's5-second test delay, WITHOUT entering actual sleep or running late/noirq callbacks. Even this can hang or leave Wi-Fi unavailable and require a restart; saved work, charger, user attendance/recovery required. Temporarily enable pm_print_times and pm_test=devices using scoped guarded admin operation, restore original values after return and independently verify. Do not trigger automatically or automate a level sweep.

If it passes, separately consider one `platform` rehearsal: upstream v7.2.13 suspend_enter runs dpm_suspend_late/noirq before TEST_PLATFORM, then reverses, bypassing s2idle_loop and actual deep firmware entry. It therefore exercises the implicated noirq paths WITHOUT real sleep. It too may hang; any higher test requires renewed readiness. Passing either rehearsal is not proof of working actual suspend.

Why not immediately retry sleep or apply a hook: current evidence already implicates device recovery, and repeated blind mode/power bundles do not localize it. Permanent NVMe policy remains unjustified. Devices-first distinguishes ordinary callback failure (including Wi-Fi) from the deeper path before contemplating controlled Thunderbolt isolation. Exact Fedora patch parity not fully reviewed; local supported knobs checked, upstream source used as reference.

Keep lid open/active. Automatic sleep remains enabled, unchanged; optional temporary containment only with consent, and never bag an awake/unverified-sleeping machine. Early-initramfs-only NVRAM is not guaranteed available on root for resets: do not use live module reload as a Wi-Fi recovery method.
