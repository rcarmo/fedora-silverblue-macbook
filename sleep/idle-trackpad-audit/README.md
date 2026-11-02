# Idle unresponsiveness and phantom trackpad clicks — 2026-11-01

User reports returning to an idle machine with main system unresponsive and only Touch Bar lit/responding to touch; occasional phantom trackpad clicks. Recovery method and exact wait duration not yet supplied.

## Read-only findings at 11:21–11:22 WET
- Previous boot <uuid>: logind announces suspend at 11:00:23.769376; systemd freezes user.slice and kernel records `PM: suspend entry (s2idle)` at 11:00:25.164927. This is the final saved record: no saved suspend exit or orderly shutdown. Cannot distinguish entry hang, failed wake, unlogged resume hang, or inaccessible journal storage.
- No lid-close record found in selected previous-boot sleep evidence. User reports idle; GNOME auto-suspend is still `suspend`/900 seconds for both AC and battery. Consistent with idle-triggered known sleep failure, but initiating caller not independently identified.
- Current boot <uuid> starts 11:20:01. Deployment JSON saved; rpm-ostree idle, no staged deployment, corrected 39e497f image remains booted/first. No assistant-triggered reboot.
- Touch Bar guard remains skip_acpi_power=1; pm_test=none, pm_print_times=0. Touch Bar responses alone do not prove host resumed or identify Touch Bar as the cause.
- GNOME Shell/libinput explicitly logged Apple SPI Touchpad `kernel bug: Touch jump detected and discarded` at 10:16:35, 10:23:38, 10:25:11, 10:31:04 and 10:31:08, then rate-limited future messages. This establishes anomalous touch-coordinate reports, NOT proof those reports caused phantom clicks or definitive hardware/kernel attribution.
- Native applespi remains bound, Apple SPI Touchpad event6 exists. GNOME tap-to-click=true, tap-and-drag=true, click-method=fingers, disable-while-typing=true. No input-event recording performed; would require separate readiness and tightly scoped trackpad-only capture, never keyboard recording.
- Right USB3 workaround successfully executed at this actual boot 11:20:15. usb6 power/control=on, roots1–5=auto. Boot persistence now observed, NOT a system-sleep fix or validation of post-resume USB/Ethernet traffic.

## User-approved containment and click isolation applied — 11:31:40 WET
- User approved both proposed settings changes. Verified pre-change AC/battery idle-suspend types `suspend`, tap-to-click=true.
- Set ONLY org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type and sleep-inactive-battery-type to `nothing`, and org.gnome.desktop.peripherals.touchpad tap-to-click=false. Independent gsettings readback confirms all three. Timeouts remain900; no lid policy, tap-and-drag, driver, USB, firmware or system sleep configuration changes.
- Persistent per-user desktop settings, reversible. Idle-suspend containment is NOT a sleep fix; manual/lid-close sleep remains unsafe. Trackpad result pending user observation; physical press-to-click remains available.
- Undo: set the two idle-suspend types back to `suspend` (re-enables known-failing unattended sleep) and tap-to-click back to true. No reset/suspend/reboot or admin prompt performed.

## Diagnostic proposals at initial audit
1. Ask consent to set only GNOME AC/battery idle-suspend types to `nothing` as temporary containment. Preserve timeout values and lid behavior. Does not fix sleep or make lid-close safe; shutdown before transport, never bag awake laptop.
2. Ask whether phantom clicks occur while fingers hover/rest/move or completely hands-off; ask whether a mechanical click is felt or only a software action. With consent, turn only tap-to-click off as a reversible isolation test; does not repair anomalous touch-coordinate reports.
3. No more uncontrolled sleep tests, module unloads, Touch Bar guard changes, global USB settings, or firmware changes.

Evidence: previous-boot.log, previous-kernel.log, current-kernel.log, deployments.json. These contain local journal details; no upload. Only read-only host commands and user-owned project writes performed.
