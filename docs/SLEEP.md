# Sleep (S3) — current design and status (2026-11-01)

**Status: works.** Real S3 (`deep`), lid close or `systemctl suspend`, with NVMe, Wi-Fi (incl. 5 GHz),
Thunderbolt/USB-C, Touch Bar and speakers restored after resume. The "instant wake" (3–4 s) was the
lid wake line when suspending with the lid OPEN — fixed 2026-11-01 19:45 (Phase 1e, below).

## How it works
`systemd-suspend.service` drop-in (`50-macbook-s3.conf`) runs `/usr/local/sbin/macbook-sleep-hook`:

| pre (in order) | post (in order) |
|---|---|
| force `mem_sleep=deep` | **T1 `SOCW(1)`** ("host awake") |
| Apple NVMe `d3cold_allowed=0` — aborts the suspend if this fails | Thunderbolt rescan (retries in a transient unit) |
| unbind BCM43602 from brcmfmac | rebind Wi-Fi (NVRAM via `firmware_class.path` karg) |
| Thunderbolt upstream-port removal (`macbook-thunderbolt-remove-rescan`) | restore XHC1 S3 wake |
| disable XHC1 (00:14.0, hosts the T1) S3 wake — fixed the first instant-wake cause | restore LID0 wake (if pre disabled it) |
| **lid open only:** disable LID0 S3 wake (GPE 0x6F) — wake with keyboard/power button | re-send Touch Bar mode (`idle_timeout` -2 → saved) |
| **T1 `SOCW(0)`** ("host sleeps"), last | |

Kernel side (akmods 0.1.20261101, `packaging/`):
- `macbook_t1_socw` evaluates `\_SB.PCI0.XHC1.RHUB.ASOC.SOCW(0|1)` only when the hook writes its `socw`
  parameter. Without `SOCW(1)` after S3 the T1 keeps the Touch Bar dark; without `SOCW(0)` before S3 it
  can wake the host. `apple_ibridge` still never calls SOCW at probe (`skip_acpi_power=1`).
- `apple-touchbar`: reset-resume invalidates its cached mode (it believed the bar was on and sent nothing).
- `snd-hda-codec-cs8409` (Apple): re-runs the Apple boot setup (codec reset + CS42L83/amp setup) once on
  the first codec resume after a system sleep; also gained the missing `.probe` op (re-probe used to
  WARN and fail). S3 resets the codec subsystem ID to `0x10138409` (firmware sets `0x106b3600` only at
  power-on), so **never rebind/reload the HDA controller after a sleep** — it can't find the Apple path.

Other pieces: `61-macbook-nvme-d3cold.rules`, `90-macbook-deep.conf`, UPower critical action PowerOff,
USB-C xHCI runtime-PM pin. All in `rebuild-kit/`.

## Test record
| When | Test | Result |
|---|---|---|
| 12:41 | Phase 1, RTC 120 s | woke in 4 s (XHC1 wake), TB tree dead, Touch Bar dark |
| 12:48 | 1b (XHC1 wake off) | **117 s ok**; Touch Bar dark |
| 12:58 | 1c, SELinux blocked socw load | 3.7 s instant wake, Touch Bar dark |
| 13:12 | 1c (SOCW 0/1 working) | **112 s ok**, Touch Bar on |
| 13:20 | lid close on AC | ok (audio silent → fixed later) |
| 13:21 | lid close 24 min on battery | **ok**, drain ≈ 0 (gauge too coarse) |
| 14:02 | patched cs8409, chime playing | audio OK after resume; 3.3 s instant wake |
| 14:05 | lid close on AC | 2 instant wakes, logind re-suspended, 3rd held 3.5 min; TB back |
| 16:28–19:36 | lid-open RTC tests (battery/AC, chime, nohda, cold boot, nolid, nowake=SPIT) | all instant; 0x6F +1 whenever LID0 armed |
| 16:47, 19:37 | lid close (35 min, 3 min) | held; TB back |
| 19:42 | lid open, `nolid` | **118 s**, 0x6F silent |
| 19:45 | lid open, Phase 1e hook, no options | **118 s**, 0x6F silent, LID0 wake restored |

Tests: `sleep/phase*/test-*/`, new ones in `sleep/tests/` via `tools/run-s3-test.sh`.

## Instant wakes — cause and fix (resolved 19:45)
- Symptom: suspend with the lid OPEN (menu / `systemctl suspend` / RTC test) woke after ~3 s; afterwards the
  Alpine Ridge controllers stayed unpowered (USB-C dead) and further short sleeps also woke, until one
  sleep held for minutes. Lid-closed sleeps held. On AC and battery alike.
- Evidence: every such wake incremented GPE 0x6F; clean runs didn't. ACPI tables (`sleep/acpi-tables/`):
  0x6F (GPIO GPD2) is the `_PRW` wake GPE of LID0, EC, ADP1 and BLTH; only LID0 is wake-enabled, so it
  arms the line. With the lid already open the line asserts right after S3 entry.
- Ruled out on the way: audio activity, the audio controller (`nohda`), keyboard/trackpad (`nowake=SPIT`),
  charger, cold boot, the new packages (the 14:02 failure ran the old ones).
- Confirmation: lid open + LID0 wake off → 118 s twice (19:42 option `nolid`, 19:45 hook fix), 0x6F silent.
- Fix (Phase 1e hook): if the lid is open at suspend, disable LID0 wake; restore on resume. A lid-open
  suspend is then woken by keyboard/trackpad or power button, not by lid movement.

## Measurements / remaining minor issue
- Overnight 2026-11-01→02: 17 h 49 min in S3, ≈0.45 W (≈1.2 %/h, ≈3.5 days standby from full) assuming
  the charger was unplugged at lid close (worst case).
- A lid-CLOSED suspend woke once after ~5 s (22:20); logind re-suspended after 30 s and that sleep held
  15 h. Suspected: the lid-close event reaching GPE 0x6F shortly after S3 entry. Self-healing; not fixed.

## History
Phase directories `sleep/phase1`, `phase1b`, `phase1c`, `phase1d`, `phase1e` (each with README, installer, undo,
receipts under `/var/lib/macbook-sleep-phase1*`). Earlier failures and research: `sleep/suspend-audit/`,
`docs/SLEEP-RESUME-RESEARCH.md`.
