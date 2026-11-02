# Phase 1b — disable XHC1 S3 wake (PREPARED 2026-11-01, not installed)

Why: Phase 1 S3 test (`../sleep-phase1/test-20261101-124139/`) entered real S3 but woke after ~4 s
(not the 120 s RTC), pm_wakeup_irq=0. S3-enabled wake sources were XHC1 (00:14.0, hosts the T1
iBridge on usb 1-3), SPIT (keyboard), LID0. Prime suspect: XHC1. Touch Bar went dark and the
Thunderbolt tree did not return; may be related to the instant wake, so retest first.

Change: only `/usr/local/sbin/macbook-sleep-hook` (Phase 1 sha db5b21ec… → 1b sha 6dd370ed…).
pre: record + set `0000:00:14.0/power/wakeup=disabled`, log enabled ACPI wake list.
post: restore it, log pm_wakeup_irq. Keyboard (SPIT) and lid (LID0) wake untouched.

## Steps (after the reboot that restores Touch Bar + USB-C)
1. `pkexec /usr/bin/bash /var/home/me/macbook-fedora-audit/sleep/phase1b/install-phase1b.sh`
   (refuses unless the installed hook is the reviewed Phase 1 version; prints receipt dir).
2. `pkexec /usr/bin/bash /var/home/me/macbook-fedora-audit/sleep/phase1b/run-s3-test.sh 120`
   Same conditions: charger in, nothing in USB-C, lid open, hands off. Refuses if the iBridge or
   USB-C controllers are missing. Adds pm_debug_messages, /proc/acpi/wakeup, GPE counters, iBridge state.
   Expected: sleep ~120 s. If it never wakes by RTC, open/press a key; if dead after 3 min, hold power.
Undo: `undo-phase1b.sh <receipt>`.
