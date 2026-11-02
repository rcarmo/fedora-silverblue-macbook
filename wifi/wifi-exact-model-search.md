# Exact-model Wi-Fi search — 2026-10-31

**Historical research; updated review:** see `wifi/research-20261101/BUG193121-REVIEW.md` (2026-11-01). The c97 candidate below was already trialed and produced no Wi-Fi, but retained logs/image now show a missing `brcmfmac-wcc` early-boot helper with matching module-request/attach failure. That is an integration defect, not a clean RF-candidate test. Do not retry the retained image or installer unchanged; corrected integration still requires separate approval/recovery and does not guarantee dual-band success.

## User clarification
5 GHz worked previously in macOS, before installing Fedora. No user-confirmed Fedora 5 GHz regression from the upgrade or audio/Touch Bar installation.

## Strongest new lead
Kernel bug 193121, comment 97 (2026-07-18):
https://bugzilla.kernel.org/show_bug.cgi?id=193121#c97

Author reports exact match: MacBookPro13,2, BCM43602, Apple subsystem 106b:0157, stock brcmfmac, firmware 7.35.177.61. Tested kernel 7.1.3, one machine/one day at posting. Claims both bands working simultaneously, ~330 Mbit/s 5 GHz TCP, cold boot and s2idle resume.

Recipe is attachment 290569 with boardflags3=0xC0000303 and unchanged 5 GHz map, replacing ONLY the 2 GHz map with:

```
swctrlmap_2g=0x02020202,0x01010101,0x02020202,0x00000000,0x000000ff
```

Reported mechanism: existing attachment duplicates the 5 GHz FEM map into the 2 GHz map, steering incorrect band-selection/control lines during 2 GHz transmission when firmware uses NVRAM FEM tables. Earlier boardflags toggles appear to select one usable band rather than fixing both. This explanation cites a public Broadcom wl source comment; that low-level source explanation has NOT been independently verified here. The author credits AI-assisted analysis; hardware test report is still a community claim, not vendor certification.

## Provenance and limits
- Original bug describes absent 5 GHz, weak reception and placeholder MAC on 2016 Macs; comment 4 explicitly confirms 13,2 affected.
- Comment 64 traces captured Windows Boot Camp NVRAM to a MacBookPro14,3 via VFIO. Attachment 290569 is a community-modified descendant, NOT a direct calibration dump from our machine.
- Attachment 290569 downloaded and fully inspected: `wifi/raw/wifi-kernel-attachment290569.txt`. Includes RF/power tables, boardtype=0x61b, boardrev=0x1421 and fallback macaddr. It is NOT installed or locally corrected yet.
- The exact-model test improves relevance considerably but does not certify RF power/calibration suitability for every unit or legal compliance. Keep PT regulatory setting; do not increase power or copy an unrelated MAC.
- Comment 100 (2026-10-12) provides another 13,2 NVRAM workaround report, but does not explicitly confirm comment 97's exact map or simultaneous dual-band operation. It appears to be the same reporter as linuxmint/linuxmint issue 923, so do not count these as independent reports.
- Comment 95/96 reports unstable 5 GHz on another 13,2 before falling back to 2.4 GHz. Thus earlier attachment recipes are not uniformly successful.
- MikeRatcliffe gist is a DIFFERENT variant (boardflags3=0x00000300; different 2G map), with broad Apple reports but no exact subsystem calibration certification. Author's linked article identifies only a 2016 Retina Mac, not exact 13,2. Do not equate all variants.
- 360900/mbp132-setup current README explicitly says Wi-Fi not solved. Its script is not a Wi-Fi fix and should NOT be run.

## Sources saved
- `wifi/raw/wifi-kernel-bug193121.html`, derived readable `wifi/raw/wifi-kernel-bug193121-text.txt`
- `wifi/raw/wifi-kernel-attachment290569.txt`
- `wifi/raw/wifi-gist-research.json`, `wifi/raw/wifi-gist-comments.json`, `wifi/raw/wifi-flailingmonkey.html`
- `wifi/raw/wifi-search-exact.json`, `wifi/raw/wifi-search-nvram.json`, `wifi/raw/wifi-mint-comments.json`
- `wifi/raw/wifi-mbp132-readme.md`, `wifi/raw/wifi-mbp132-setup.reference` (read-only reference; never executed)
- Initial `wifi/raw/wifi-search-13-2.json` numeric 43602 search returned unrelated issue-number matches; disregard as evidence.

## Next decision
There is now a model/subsystem/firmware-matched experimental candidate, not merely an unrelated-board example. Before any trial: explain remaining calibration/MAC risks, obtain explicit approval, establish a trusted actual MAC if possible, review Silverblue firmware staging/initramfs integration, and prepare LOCAL recovery that removes the /etc override and regenerates initramfs. Deployment rollback alone does not undo shared /etc or an override injected into other boot images. Ensure an alternate network route and user present with saved work. Do not live-unload brcmfmac or reboot without approval.

No Wi-Fi configuration, firmware, MAC, power or country changes made during search.
