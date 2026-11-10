# T1 idle blanking and ASPM follow-up (2026-11-10)

Reviewed mikeypdev/macbook-t1-suspend at
`ef2148bcd94e1a5b82c86a1a7905f03b195b801b`:
https://github.com/mikeypdev/macbook-t1-suspend/tree/ef2148bcd94e1a5b82c86a1a7905f03b195b801b

Their Arch MacBookPro13,2 setup is based on our public Fedora export. Their
Thunderbolt helper and CS8409 resume-fix header match ours byte-for-byte.

## Adopted: T1 idle blanking (Touch Bar 0.1.20261110-1)

Our T1 display-control function deliberately returns success without sending a
command, because T1 lacks that HID interface. Consequently the existing idle
worker never actually blanked the strip. Patch
`packaging/patches/0003-appletb-t1-idle-mode-off.patch` ports their MODE_OFF fix:

- Only T1, and only on expiry of the off timeout, sends the mode-off command.
- Cache the off mode only after a successful command. Normal input then
  schedules the configured Fn mode through the existing input/worker path.
- Non-T1 display commands, dim behavior, held-key checks and disabled-idle
  settings retain their existing handling.
- Keep the existing **300-second default** (live sysfs showed 300), rather than
  importing their 30-second preference. No new modprobe setting is required.
- ACPI guard, SOCW module and all suspend hooks remain unchanged.

Validation:
- `python3 packaging/tests/test-touchbar-idle.py`: compiles and executes the
  actual worker/update functions with mocked hardware/time. Checks blank and
  input restore, non-T1 behavior, pre-timeout scheduling, held keys, failed
  mode commands, disabled idle settings and dim-before-off.
- rpmbuild and unprivileged akmodsbuild against kernel 7.2.13 passed.
- The akmod embeds the correctly versioned SRPM. Full root audit of staged
  deployment **1257270345a8** passed with **0 failures**, including source/spec
  consistency, patch reproduction, module fingerprints, initramfs guard/NVRAM
  and unchanged host sleep files. Log: `packaging/logs/audit-touchbar-0.1.20261110.log`.
- Composition also refreshed ghostty, erlang-srpm-macros, redhat-rpm-config and
  kernel-headers. The actual kernel/kernel-devel stay 7.2.13 and audio stays
  0.1.20261101-1. See `packaging/logs/touchbar-0.1.20261110-package-diff.log`.

Hardware acceptance is still required **after reboot**. No live module reload,
USB rebind, SOCW experiment, unattended suspend, or reboot was performed.

### After reboot

1. Check `rpm -q akmod-macbook-t1-touchbar` reports 0.1.20261110-1; run
   `pkexec /usr/bin/bash tools/audit.sh`.
2. Leave keyboard, mouse, trackpad and Touch Bar untouched for five minutes.
   The strip should blank. Any normal input should restore it. Check Fn and
   Touch Bar keys still work; the first touch on an off strip is intentionally
   consumed by the existing wake path.
3. For a shorter attended test, temporarily set the Touch Bar HID device's
   `idle_timeout` to 30 as root, then restore its saved value (normally 300).
   This is the HID sysfs attribute, not the read-only module default parameter.
4. Check an attended lid-close S3 cycle using the existing test protocol in
   `docs/SLEEP.md`, then verify blanking and Fn behavior again. No sleep-hook
   changes are needed.
5. If the driver regresses, select the previous deployment in the bootloader.
   Do not blindly run `rpm-ostree rollback` with pinned deployments present.

## Investigated only: PCIe ASPM L1

Read-only root inspection is recorded in
`packaging/logs/aspm-readonly-20261110.log`.

| Link | L1 capability | Current L1 setting, both ends |
|---|---|---|
| NVMe root 00:1c.0 / endpoint 01:00.0 | yes | enabled |
| Left TB root 00:1c.4 / upstream 03:00.0 | yes | disabled |
| Right TB root 00:1d.0 / upstream 79:00.0 | yes | disabled |
| Wi-Fi root 00:1d.3 / endpoint 02:00.0 | yes | enabled |

The native ASPM policy reads `[default] performance powersave powersupersave`.
This audit did not attempt a policy write or prove whether firmware grants ASPM
control. Their claim of a ~2.2 W reduction is a measurement on their machine,
not ours; Wi-Fi already has L1 here, so their full saving cannot be assumed.

**No setpci writes, boot service, or resume reapplication installed.** For a
future experiment: save work, disconnect USB-C data devices, inventory both
ends of all affected links, save original link-control bits, measure a quiet
battery baseline, apply only the L1 bit with masked writes and a rollback plan,
then measure at identical brightness/load. Check PCIe AER, Wi-Fi, NVMe, USB-C
hotplug and attended S3 before making anything persistent. Direct PCI config
writes bypass Linux/firmware ownership and are not a routine power setting.

## Not imported

- Full Wi-Fi PCI remove/rescan and recovery watchdog: our unbind/rebind works;
  their watchdog has itself raced recovery and wedged a healthy chip.
- ARPT/SPIT wake masking: SPIT masking did not solve our measured instant wake
  and would remove working keyboard wake.
- Codec profile switching or automatic re-suspend: no demonstrated need here.
- TLP profile or idle-timeout preference changes: separate power/UX decisions.
- Their NetworkManager configuration: it incorrectly labels power-save enum
  values. NetworkManager defines 0=default, 1=ignore, **2=disable**, 3=enable;
  their `wifi.powersave=1` does not enforce disable. Verified against
  https://github.com/NetworkManager/NetworkManager/blob/main/src/libnm-core-public/nm-setting-wireless.h
