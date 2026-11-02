# Corrected WCC-inclusion Wi-Fi trial — STAGED and VERIFIED

2026-11-01 09:56 WET. User approved trying saved c97 files with alternate networking/recovery readiness. No reboot performed; functional outcome pending.

## Exact staged image

- Commit **39e497fbe6383c8b5c9dda53c1bdaab1e3e77291c81cef20ceace9017ab5c936.0**.
- Same base, kernel **7.2.13-200.fc44.x86_64**, requested packages and custom driver packages as current working recovery c4ebdd8.0.
- Initramfs generation remains enabled, args **--force** only; prior recovery exclusions removed from this new image, not from any fallback.
- Candidate SHA256 **90f3f15991fcd8dc3b29a3cfda7859fd4faf9fe275cbef7b522658ff9971fa74**: saved attachment290569 plus c97 swctrlmap_2g correction and previous locally administered unicast MAC. Same RF inputs as old trial; new unpersonalized source differs only in macaddr. Not a recovered Apple identity or certified calibration.
- Only three documented trial /etc files installed, root-owned with restorecon. No generic host /usr firmware, station binary, NetworkManager profile, regulatory PT, txpower, kernel args, driver packages or sleep/NVMe policies changed.
- Main brcmfmac early-loaded, **brcmfmac-wcc explicitly included with add_drivers**. Corrects the missing dynamic helper in failed b0a3115 image.

## Independent verification passed

`boot-verification.log`: exact staged NVRAM/hash; unchanged station binary; matching helper/main/custom audio/Touch Bar/applespi module hashes; WCC vermagic, dependencies, real staged modules.dep.bin resolution OFFLINE with --show-depends (printed insmod lines are not executed); early-load instructions; skip_acpi_power=1.

All FOUR actual BLS fallback images lack NVRAM file entries and retain original hashes. Recovery and driver baseline retain custom modules/guard. zstd format-probe warnings occur in lsinitrd but extraction/checks passed. Parser distinguishes listing Arguments headers mentioning --remove paths from actual files.

Staged image verified under its deployment root; OSTree writes its BLS menu entry during normal shutdown finalization. Do not claim the current pre-finalization BLS title mapping is already shifted.

## Reboot/test instructions

Save work, keep lid open, headphones unplugged, alternate networking available. User should perform a NORMAL GNOME restart when ready, not forced power-off (shutdown finalizes the staged deployment). No assistant-triggered restart.

Next boot menu requested visible for **60 seconds**, verified supported by installed GRUB. Only menu_show_once_timeout changed; no saved_entry/default/deployment-order selection change.

Expected after successful finalization with no intervening deployment operations:
- **(ostree:0)** — new candidate 39e497f, normal/default trial.
- **(ostree:1)** — pinned working recovery c4ebdd8, return here if Wi-Fi disappears.
- **(ostree:2)** — OLD FAILED b0a3115, DO NOT select.
- **(ostree:3)** — pinned driver baseline43e45ec.
- **(ostree:4)** — pinned stock updated f1365bc.
- **(ostree:5)** — pinned original b8e75b7/kernel6.19.10.

If mapping does not match, stop and review rather than choosing blindly. On trial login keep lid OPEN; do not suspend. Resume assistant audit: verify exact booted deployment, WCC load/firmware logs, both advertised bands, connection/reachability, user-visible 5-GHz network, audio/Touch Bar guard. Seeing channels alone is not usable 5-GHz networking.

If no Wi-Fi, use alternate network or boot recovery:1 and report. No live brcmfmac reload. Do not blindly rpm-ostree rollback or rerun staging. make restore supports these three scoped paths but refuses booted-not-first or staged/busy status; audit exact status/default before invoking from a manual fallback. Recovery exclusions preserve working baseline until guided cleanup/composition.

## Power and limits

User correctly reported GNOME47% while raw kernel capacity read34%. UPower/charge_now divided by charge_full agreed ~46%; used >=40% usable-charge guard to stage on battery with user request to proceed. Charger remained offline. At final verification UPower **36.5% DISCHARGING**, no warning, estimated59 minutes; sufficient for one short attended boot audit, connect charger if available. Do not infer battery health from conflicting capacity counters alone.

GNOME automatic suspend still enabled at900 seconds, persistent s2idle override retained, NVMe D3cold reset to1. No new suspend test or containment authorized/applied. Keep active/lid open and never bag an awake/unverified-sleeping laptop.

Early-initramfs-only NVRAM is NOT available in normal host firmware lookup after a live reload/reset/resume. Boot success does not establish reliable reset/suspend or long-term integration. Proper consistent firmware packaging remains separate after functional result.

## Receipts

- `staging.log`: staging tool timed out300s; root script/transaction continued and completed. Do not repeat it.
- Root recovery receipt **/var/lib/macbook-wifi-recovery/trial-v2-GpvAhXy5**; original arming/baseline/backups preserved intact; current recovery pinned.
- `boot-verification.log`, `before-boot-verification.log`, recovery listing, root preflight/BLS audit.
- `pre-reboot-deployments.json`, `menu-arming.log`, `pre-reboot-menu-audit.txt`.
- Scoped guarded `stage-wifi-trial.sh` and read-only `verify-boot-images.py`. Verifier timed out180s but continued to successful completion; no module was loaded.
