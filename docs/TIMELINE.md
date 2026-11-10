# Milestones

[Documentation index](README.md) · [Current status](../PROGRESS.md)

This is history, not an ordered installation procedure. Detailed hypotheses,
failed tests and deployment hashes remain in the [archive](README.md).

## 2026-10-31 — baseline drivers

Audited the stock system and moved to Silverblue 44.20261031.0 / kernel 7.2.13.
Built and packaged the T1 Touch Bar and Apple CS8409 drivers from pinned sources.
Touch Bar, speakers and backlights worked; the microphone was quiet and camera
worked in a browser. Original recovery deployments were retained.

## 2026-11-01 — Wi-Fi and suspend

- Corrected BCM43602 board NVRAM restored 5 GHz. The first attempt lost Wi-Fi
  because `brcmfmac-wcc` was missing from initramfs; the corrected build included it.
- Stock-image tests also failed suspend, ruling out the custom drivers as the
  sole cause. s2idle attempts hung or resumed with dead devices.
- NVMe D3cold prevention, Thunderbolt remove/rescan and Wi-Fi unbind/rebind
  established a working deep-S3 path.
- T1 SOCW sleep/wake messaging and Touch Bar cache invalidation restored the bar.
  CS8409 `.probe`/resume reinitialisation restored audio.
- Disabling LID0 wake only on lid-open entry fixed the reproducible ~3-second
  lid-open wake. The resulting configuration became the rebuild kit.

## 2026-11-02 — overnight observation and publication

An overnight record held roughly 17 h 49 min in S3, with estimated draw ~0.45 W
conditional on unplug timing. A closed-lid early wake recovered by re-suspending;
that minor issue remains unresolved. Idle suspend was restored to 15 minutes on
AC and battery. A sanitised public repository was published.

## 2026-11-10 — idle blanking and an ASPM trial

- Ported the T1 MODE_OFF idle fix from mikeypdev's Arch follow-up, which itself
  uses this project's earlier Fedora recipe.
- Built Touch Bar 0.1.20261110-1; staged and post-boot audits passed with 0 failures.
  User confirmed blanking/input/keys/Fn; attended normal deep S3 also passed.
- Six internal TB links supported L1 but had it disabled. Linux logged the FADT
  ASPM restriction; NVMe and Wi-Fi already had L1 enabled.
- A short reversible trial measured **12.18 → 10.48 → 11.90 W**, suggesting
  ~1.6 W less awake draw. Original settings were restored and verified.
  Hotplug, longer stability and S3 with L1 enabled remain unvalidated.

See the [Touch Bar note](T1-IDLE-AND-ASPM.md), [ASPM results](ASPM-RESULTS.md)
and [archived progress snapshot](archive/PROGRESS-snapshot-2026-11-10.md).
