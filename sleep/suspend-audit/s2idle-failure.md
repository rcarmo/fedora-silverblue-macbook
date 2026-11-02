# s2idle trial failure — 2026-11-01

## User observation
After opening the lid, the Touch Bar was lit but nothing else responded. A forced power cycle was required. This is a failed functional wake test, not a confirmed successful kernel resume.

## Read-only evidence
- Failed boot: `578cc58e23ff43ed9615777372ed7bfa`.
- 08:31:50.458306 WET: logind reports `Lid closed.` and initiates suspend.
- 08:31:52.374138: systemd-sleep successfully freezes `user.slice`.
- 08:31:52.379482: final journal record is `PM: suspend entry (s2idle)`.
- No recorded `PM: suspend exit`, Touch Bar resume or logind wake. The journal cannot distinguish entry hang, failed wake, or an unlogged resume hang. No driver is proven responsible. The illuminated Touch Bar alone does not identify the failing subsystem.
- Current boot: `c01ede9e55464651886c6954365824f6`, starts 08:32:55 WET.
- Booted recovery deployment `c4ebdd857316f64e6b97b3c29f64993fef8ebe82824484091bc4d848b2ae39bc`, kernel `7.2.13-200.fc44.x86_64`; rpm-ostree idle, no staged deployment.
- `/etc/systemd/sleep.conf.d/90-macbook-s2idle.conf` remains installed/effective. Current sysfs reads `s2idle [deep]` after restart, as expected before systemd selects s2idle on a future suspend. This file is now a FAILED trial, not a fix.
- Custom audio codec still selected from `extra/macbook-cs8409`; `apple_ibridge` and `apple_touchbar` loaded. `skip_acpi_power=1` remains set. Do not change it to 0.
- NetworkManager reports `wlp2s0` connected after restart; physical audio/Touch Bar and internet access were not retested.
- GNOME still automatically suspends on BOTH AC and battery after 900 seconds. No containment has been applied.
- `pm_test` supports `freezer`, `devices`, `platform`, `processors`, `core`; current selection `none`. `pm_debug_messages` and `pm_print_times` are 0. No diagnostic write/test performed.
- `/sys/fs/pstore` listing requires privilege; not inspected, so presence/absence of persistent crash evidence is unknown.

## Preserved evidence
- `failed-s2idle-ending.log`: last 200 journal records of the exact failed boot.
- `failed-s2idle-kernel.log`: kernel journal of the exact failed boot.
- `after-s2idle-deployments.json`: deployment identities after recovery restart.
- `after-s2idle-sleep-config.txt`: current merged sleep configuration.

## Next diagnostic, requiring readiness and reboot approval
Stop repeating uncontrolled lid tests. A pinned stock same-kernel comparison can distinguish failures associated with the custom driver deployment from problems that also affect stock Fedora. It does not by itself identify an individual driver, and successful boot is not a successful suspend test.

1. Offer temporary prevention of automatic/lid suspend while investigating. Explain that the machine stays awake and must not be put in a bag. Do not apply without approval; user previously preferred fixing suspend, not merely disabling it.
2. Save work, connect power, unplug headphones and arrange recovery. Review exact boot entry identities immediately before selecting a deployment.
3. Prefer a one-time boot of pinned stock updated `f1365bcef08f98f305177529b4132dbef7c2a4d4ad1fc38de9b24fc85c306517` (currently index 3), kernel 7.2.13. Custom audio/Touch Bar functionality will likely be absent during that comparison; do not remove installed drivers or alter the default deployment merely to test.
4. After stock boot, re-audit actual codec/Touch Bar driver selection, Wi-Fi, sleep configuration and mode. `/etc` configuration is not reliably undone by deployment selection; explicitly verify the s2idle drop-in and do not assume stock means deep mode. Only perform a controlled suspend with explicit user readiness. Consider PM callback diagnostics before another full sleep; even `pm_test=devices` can hang in a driver callback and is not risk-free.
5. If stock same-kernel suspend works, plan boot-time one-driver-at-a-time isolation in the recovery deployment, avoiding live unbinding/unloading. If stock also fails, investigate stock drivers/platform/kernel and consider original pinned kernel 6.19.10 as a separate comparison. No culprit/fix promised yet.

Current deployment order: recovery `c4ebdd8`, FAILED Wi-Fi trial `b0a3115`, pinned custom-driver baseline `43e45ec`, pinned updated stock `f1365bc`, pinned original `b8e75b7`. **Never blindly run rpm-ostree rollback.**

Only audit files/documentation written this session. No privileged commands, system configuration changes, driver reload/unbind, playback, suspend or reboot initiated.
