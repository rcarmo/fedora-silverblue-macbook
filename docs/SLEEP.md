# Sleep and resume

[Documentation index](README.md) · [Safety rules](KNOWN-ISSUES.md)

**Deep S3 works on the reference MacBookPro13,2.** Lid-close and menu/command
suspend restore Wi-Fi, NVMe, Thunderbolt/USB-C, Touch Bar and speakers with the
included hooks and drivers. Last attended check: **2026-11-10**, after the Touch
Bar update; everything was reported working afterward.

This describes the normal installed setup. **S3 with experimental ASPM L1 enabled
has not been tested**; the short power trial restored the original PCI settings.

## Everyday behavior

- Use lid close or GNOME's normal suspend action.
- If the lid is **open at entry**, the hook temporarily disables lid wake to
  prevent an immediate wake. Use keyboard/trackpad or the power button to resume.
- Leave USB-C data devices disconnected for the validated test configuration;
  chargers are fine. Docks and general external-device suspend behavior remain
  unvalidated.
- An occasional closed-lid early wake can still happen. One overnight case
  recovered through logind re-suspending. Check it stays asleep before bagging.
- A lit Touch Bar alone is not evidence that the host is awake.

## Run an attended check

Save work, connect the charger and unplug USB-C data devices. From the repository
root, stay at the machine and run:

```bash
pkexec /usr/bin/bash "$PWD/tools/run-s3-test.sh" 120
```

The helper records a test under `sleep/tests/`. Allow the RTC wake to occur;
do not deliberately interrupt the first few seconds. Afterward:

1. Confirm the kernel logged `PM: suspend entry (deep)` and `PM: suspend exit`.
2. Check the duration: a 3–5-second return is an early wake, not a held 120-second sleep.
3. Check keyboard/trackpad, Touch Bar keys/Fn, Wi-Fi (including 5 GHz), audio and
   the previously working USB-C port.
4. If it hangs or immediately wakes, review the logs before repeating. Avoid
   live T1 or HDA rebind/reload recovery; see the [safety rules](KNOWN-ISSUES.md).

Useful logs:

```bash
journalctl -b -k --grep='PM: suspend entry|PM: suspend exit|Timekeeping suspended'
journalctl -b -t macbook-sleep -t thunderbolt-remove-rescan
```

## How the installed fix works

The `systemd-suspend.service` drop-in calls `/usr/local/sbin/macbook-sleep-hook`.

| Before sleep | After resume |
|---|---|
| Select `deep`; enforce Apple NVMe `d3cold_allowed=0` (abort if it fails) | Send T1 `SOCW(1)` first |
| Unbind BCM43602 Wi-Fi | Rescan the removed Thunderbolt ports, retrying if necessary |
| Remove the two Thunderbolt upstream ports | Rebind Wi-Fi; reload NVRAM through the firmware-path argument |
| Disable XHC1 wake; disable LID0 wake only if the lid is open | Restore saved wake settings |
| Send T1 `SOCW(0)` last | Re-send the Touch Bar mode using its saved idle timeout |

The Touch Bar driver invalidates stale mode state on reset-resume. Its newer
idle-blanking fix does not change this suspend policy. The CS8409 driver re-runs
Apple codec/amplifier setup on the first codec resume after system sleep.
The iBridge guard remains **`skip_acpi_power=1`**: no SOCW call at driver probe.

The kit also includes the NVMe rule, USB-C runtime hotplug workaround and
critical-battery power-off policy. See [kit contents](../rebuild-kit/README.md).

## Evidence and remaining limits

- **2026-11-10:** deep-S3 entry 18:40:53, exit 18:42:34 (~101 seconds between
  logged entry/exit). Thunderbolt returned on attempt 1; Wi-Fi rebound; both
  SOCW calls succeeded; user confirmed all devices working. Local raw record:
  `tools/logs/s3-post-update-20261110.log` (not published).
- **2026-11-01→02:** about 17 h 49 min in S3, with estimated draw **~0.45 W**
  (~1.2%/h on that worn battery), **assuming** unplugging at lid close. The estimate
  is conditional; an earlier short sample was too coarse to use as a standby figure.
- Lid-open instant wakes were traced to the shared lid/EC GPE 0x6F and fixed by
  masking LID0 only for lid-open entry. Closed-lid early wakes are not fully resolved.

For the detailed test sequence, see the [original test record](archive/SLEEP-test-record-2026-11-01.md),
[historical research](SLEEP-RESUME-RESEARCH.md) and [phase-directory guide](../sleep/README.md).
Use the rebuild kit for installation, not the historical phase installers.
