# Phase 1c — T1 SOCW sleep/wake message + Touch Bar mode re-send (INSTALLED 2026-11-01 12:58) — TEST 2 PASS 13:12 (test-20261101-131217)

Why: after S3 the T1 keeps the Touch Bar dark (driver logs "Touchbar resumed", bar dead).
Live test 12:56: `ASOC.SOCW(1)` (no freeze) + mode re-send restored it.

Pieces:
- `../t1-socw/` — `macbook_t1_socw.ko` source (adapted simbilim module: DMI 13,2/13,3, nothing at load,
  `socw` write-only param evaluates SOCW(0|1), `auto_resume` opt-in default off, counters).
- Installed `.ko`: `/usr/local/lib/macbook-t1-socw/<kver>/macbook_t1_socw.ko`. Needs SELinux type
  `modules_object_t` (lib_t → AVC module_load denied from unconfined_service_t). Persistent rule added 13:00:
  `semanage fcontext -a -t modules_object_t "/usr/local/lib/macbook-t1-socw(/.*)?"` (not in installer yet).
- Hook (sha e0739d7c…): pre LAST `SOCW(0)` (deep only); post FIRST `SOCW(1)`, LAST Touch Bar
  re-send (idle_timeout -2 → saved). Missing/unloadable module → logged, skipped, sleep proceeds.
- Kernel update: module is per-kernel; rebuild (`make -C touchbar/t1-socw`) and copy into the new kver dir,
  otherwise SOCW is skipped (Touch Bar dark after resume until reboot). Long-term: fold into the akmod.

Test 1 (`test-20261101-125814/`): SELinux blocked insmod → no SOCW(0)/(1); S3 only 3.7 s (instant wake),
TB tree not back (dead until a sleep of a few minutes / reboot), Touch Bar dark. Hypothesis: the live
SOCW(1) told the T1 "host awake" and without SOCW(0) it woke the host. Retest after reboot.

Undo: `undo-phase1c.sh <receipt>` (+ `semanage fcontext -d "/usr/local/lib/macbook-t1-socw(/.*)?"`).
Driver fix (not built/installed): `packaging/sources/macbook-t1-touchbar-0.1.20261101/` +
`packaging/patches/0001-appletb-reset-resume-invalidate-cached-mode.patch` (compile-tested on 7.2.13).
