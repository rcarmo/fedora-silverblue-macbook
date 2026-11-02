# Bug 193121 re-review — missing WCC helper explains failed trial setup

2026-11-01. User requested reviewing additional hardware-matched Wi-Fi fixes. Research only: no Wi-Fi host changes, module reloads, firmware replacement, initramfs composition or reboot.

## Important correction to the previous failure interpretation

The previous early-boot trial **really did remove all usable Wi-Fi** and remains a failed deployment. However, its logs and retained initramfs now demonstrate an **integration defect**, not a clean rejection of the candidate NVRAM:

Failed boot `86ecac04548f426698f5def70e835cb9`, Oct 31 23:53:40 onward:
1. dracut requests `rd.driver.pre=brcmfmac`.
2. brcmfmac loads the BCM43602 binary and its firmware console reports **7.35.177.61**.
3. `brcmf_fwvid_request_module: mod=wcc: failed 256`.
4. `brcmf_attach: brcmf_fwvid_attach failed`, then `Dongle setup failed`.
5. A later “Firmware has halted or crashed” message and cleanup/workqueue WARNING occur **after** that setup failure. Do not use them alone to conclude NVRAM RF/calibration incompatibility.
6. NetworkManager never gets a usable Wi-Fi device; this is **probe/attach failure**, not a password/band-selection problem.

Read-only, graphically authorized `lsinitrd` inspected **the retained b0a3115 trial image itself**, not the current recovery image:
`/sysroot/ostree/deploy/fedora/deploy/b0a3115661b67f83769723b4fdea41d9cc6fc267cea0b363cf4b0298fb999505.0/usr/lib/modules/7.2.13-200.fc44.x86_64/initramfs.img`.

Inspection succeeded (exit 0; 5,178-line full listing): **brcmfmac.ko.xz present, candidate NVRAM present, stock binary present, but NO brcmfmac-wcc.ko.xz**. zstd format-probe warnings match earlier successful lsinitrd runs; listing itself completed. Full evidence is under `review/`.

Upstream 7.2.13 `brcmfmac/fwvid.c` calls **request_module("brcmfmac-wcc")** dynamically and returns immediately if the loader fails. The ordinary brcmfmac hard dependency list (`brcmutil,cfg80211,mmc_core`) does not include this reverse-dependent vendor helper, so forcing the main module into dracut does not guarantee the helper is copied. Current root filesystem has the matching stock helper, and **brcmfmac_wcc is loaded on the working recovery boot**.

**Our earlier initramfs verification omitted this dynamically loaded helper.** It correctly checked the candidate/hash, binary and main module, but was incomplete as a functional early-boot dependency check. This should have been audited before calling the candidate itself a regression. The absence and matching loader failure strongly explain why the interface vanished; they do **not prove the NVRAM will work once the integration is corrected**.

Do not boot b0a3115 again. Do not rerun the current trial installer unchanged. A later approved trial must include and independently verify the WCC helper/loading path, keeping RF input otherwise constant first rather than jumping between board recipes. Preserve recovery and alternate networking.

## Fresh review of the kernel bug

Downloaded current HTML, all available REST comments through **comment 101**, attachment metadata and five NVRAM attachments. Current HTML is unchanged from the earlier saved page. Excluded unrelated out-of-office HTML attachments and did not download/run Windows/Dell firmware executables.

| Candidate / report | Hardware relevance | Results and limits |
| --- | --- | --- |
| **285753, c51–54** | c52 says **13,3**, originally adapted from **BCM94350ZAE/Dell DW1820A** text with IDs changed. c54 reports **13,2**. | 13,2 sees working 5 GHz but **cannot connect on 2.4 GHz**. Not a genuine 13,2 calibration dump. Two-chain config, boardtype 0x073e/boardrev 0x1101. Later generic-chip success reports do not prove exact model/subsystem. |
| **287497, c64** | Genuine Windows Boot Camp/VFIO capture on **14,3**, not this 13,2. | Author explicitly reports firmware initialization error with Linux. boardtype 0x157/boardrev 0x1108, sromrev12, three-chain configuration. Do not install the paired captured binary. |
| **290545/290553, c71–73** | Modified descendants of that 14,3 capture. | Mainly 5 GHz improvement; author still seeks working 2.4-GHz FEM maps. Not independent exact-model fixes. |
| **290569, c74/77/81** | Community remodification; 2016/2017 reports often omit exact model. | Boardflags variations select a usable band for some reporters. c81 changes 0xC0000303 to 0x00000303 or 0x00000003; no explicit simultaneous dual-band proof. boardtype 0x61b/boardrev 0x1421, sromrev11, three-chain configuration. |
| **c95/96** | Explicit **13,2 / BCM43602 rev2 / Iris 550**. | Initial 5 GHz disconnects quickly; final reported workaround is **2.4 GHz only**, boardflags3=0x00000003 plus a 10-dBm cap. Does not solve our absent 5 GHz. |
| **c97 on 290569** | Exact **13,2 / subsystem 106b:0157 / firmware 7.35.177.61**, kernel7.1.3. | Corrected `swctrlmap_2g`, boardflags3=0xC0000303, claims both bands/cold boot/s2idle. One machine/day at posting, calibration/wiring mechanism not vendor-certified. **This is the RF candidate already used in our failed loader-defective trial**, not a newly untried candidate. |
| **c100** | Exact **13,2 / BCM43602**, Mint22.3; subsystem/config unspecified. | NVRAM improves range/stability especially 5 GHz; a community DKMS/script made adapter disappear. No exact file/hash/map recipe. Same report copied to Mint issue923, not two independent confirmations. |

Full non-MAC key comparison is `review/candidate-key-comparison.txt`; raw downloads remain research only. Same chip ID does not mean identical antenna count/FEM wiring/calibration. No candidate is a verified board dump from this unit.

## Preferred next Wi-Fi decision (after the suspend trial, separately approved)

1. Keep current connected 2.4-GHz recovery, PT regulatory policy and unchanged station binary. Do not combine a firmware boot trial with the current NVMe suspend trial.
2. Review/fix **early-boot integration and verification** before changing candidate RF values. Include `brcmfmac-wcc` explicitly alongside the main module; verify dynamic load path and module metadata/availability in the actual staged initramfs. A no-NVRAM early-load control could distinguish integration from calibration, but that itself needs an approved deployment/reboot and is not performed here.
3. Prefer the already reviewed exact-subsystem **c97** candidate as the first RF comparison once the loader is demonstrably complete, rather than the less-matched two-chain 285753 example, raw 14,3 capture, or boardflag brute force. This is a **new corrected-integration trial**, not reusing the retained failed image; get approval/alternate-network/recovery readiness first.
4. Real board NVRAM/MAC from this machine's macOS/Boot Camp/backup remains preferable where obtainable. Do not copy another unit's MAC; locally administered identity is not recovered Apple identity. RF calibration/regulatory validity remains a caveat even if networking works.
5. Review initramfs-only limitations: future live reload/reset/resume may request firmware from the normal root and lose the NVRAM. Long-term integration must make the same input available consistently; otherwise a successful first boot is not persistence or suspend reliability. Do not broadly redirect all firmware or overwrite host /usr on Silverblue.
6. Only after successful attach verify **both advertised bands**, association and reachability, signal/stability, then separate reset/resume behavior. An `ASSOC-REJECT ... status_code=16` alone does not establish a bad password; a helper/probe failure is an earlier and different fault.

Rejected immediate changes: Broadcom-wl/b43 swaps, unrelated `.hcd`/CLM blobs, binary hex edits, country-domain bypasses, raising transmit power, blanket profile changes, and live brcmfmac unloads.

## Evidence

- `review/bug193121-{current.html,comments.json,attachments.json}`, `all-comments.txt`, selected/earlier comments.
- `review/attachment-{285753,287497,290545,290553,290569}.txt`, fetch manifests and key comparison.
- `review/retained-trial-initramfs-listing.txt` / `.stderr` and `failed-trial-module-loader.log`.
- Earlier complete kernel/NetworkManager failed-boot logs in this directory; earlier candidate and verification receipt in `../wifi-trial/`.
- `review/SHA256SUMS` records local downloaded/listing evidence integrity.

No Wi-Fi system changes applied. Only the separately requested transient **NVMe D3cold=0** setting was written to the host in this session; root lsinitrd was read-only. No suspend/reboot performed.
