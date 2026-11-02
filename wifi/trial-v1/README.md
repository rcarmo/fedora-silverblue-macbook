# Scoped early-boot-only Wi-Fi NVRAM trial

**FAILED HISTORICAL TRIAL — do not rerun unchanged or boot the retained image.** 2026-11-01 inspection found the early-boot image lacks the dynamically requested stock `brcmfmac-wcc` helper; failed logs show `mod=wcc: failed 256` and attach failure. Earlier verification was incomplete. Read `../wifi-research-20261101/BUG193121-REVIEW.md`. A corrected-integration trial needs explicit helper inclusion/verification and new approval/recovery readiness; none staged. The original NVRAM's functional/calibration suitability remains unproven, not cleanly disproven by that loader failure.

User authorized making the researched exact-model candidate work. This is an experimental community configuration, not vendor-certified calibration or a guarantee of 5 GHz reliability. See `../wifi-exact-model-search.md` for provenance and mixed historical results.

## Input
`brcmfmac43602-pcie.txt` is kernel bug 193121 attachment 290569 with exactly two changes:
- `swctrlmap_2g=0x02020202,0x01010101,0x02020202,0x00000000,0x000000ff`, per comment 97 (exact MacBookPro13,2 / 106b:0157 / firmware 7.35.177.61 report).
- `macaddr` uses this interface's currently assigned locally administered unicast identity at preparation time. This is NOT a recovered real Apple permanent MAC. No unrelated person's identity is copied; NetworkManager's existing randomization/profile configuration is unchanged. Actual address kept out of prose/logs.

Everything else, including boardflags3=0xC0000303, 5 GHz map, country/revision and RF tables, remains exactly as downloaded. Global PT regulatory policy is unchanged; no txpower command or power-saving tweak is made. RF legality/calibration has not been independently certified.

Candidate SHA256: `90f3f15991fcd8dc3b29a3cfda7859fd4faf9fe275cbef7b522658ff9971fa74`.

## Integration
`stage-wifi-trial.sh` validates exact model/PCI subsystem, reviewed input hashes, unchanged booted deployment and empty trial baseline. Arms `../recover-wifi.sh` and pins both the current driver deployment and stock updated fallback. Installs ONLY the three dedicated paths in `../WIFI-RECOVERY.md`.

The modprobe file is comments-only. The dracut config forces brcmfmac early and maps the dedicated /etc file into `/usr/lib/firmware/brcm/brcmfmac43602-pcie.txt` ONLY in the generated initramfs. The host's generic /usr firmware is untouched. Stock station binary remains selected. No firmware_class parameter, alternative_fw_path, kernel argument, NetworkManager profile or live driver reload is changed.

`rpm-ostree initramfs --enable --arg=--force` composes a new deployment without changing kernel/package versions, retaining the audio/Touch Bar drivers. This takes several minutes and may outlast a tool timeout; inspect rpm-ostree status before repeating anything. The staging script is one-shot, intentionally refusing changed deployment state or existing recovery state rather than overwriting.

## Limits
The NVRAM is available in the initramfs, not the host's normal firmware lookup directory. Do NOT unload/reload brcmfmac after boot. Suspend, device reset and subsequent firmware re-request behavior remain unverified. If boot test succeeds, proper long-term firmware packaging/integration needs separate consideration. Do not claim this early-boot trial alone establishes all-hardware reliability.

## Recovery and boot verification
Run `make restore` from the project, or `make restore ADMIN=pkexec`. Recovery removes dedicated /etc files and explicitly excludes both standard /usr/lib and /lib NVRAM paths from its new initramfs. It never removes vendor /usr firmware on the host or disables local generation used by other working drivers.

Before any reboot, inspect the newly staged image for the exact candidate hash, early brcmfmac loading, generic station binary, custom audio/Touch Bar modules and skip_acpi_power=1. Check fallback images still lack this NVRAM. Save work, connect power, and arrange an alternate network route (USB tethering/Ethernet) before approving reboot. No reboot or live driver reload is part of staging.
