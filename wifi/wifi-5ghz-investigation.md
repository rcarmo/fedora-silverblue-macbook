# Missing 5 GHz band — 2026-10-31

User reports 5 GHz networks absent and confirms location Portugal.

## Confirmed read-only findings
- BCM43602 14e4:43ba / Apple subsystem 106b:0157 supports 5 GHz hardware; absence is not an inherent 2.4-only chipset limitation.
- `iw phy phy0 info` exposes ONLY Band 1 (2.4 GHz channels 1–13; channel 14 disabled). No Band 2 exists, rather than 5 GHz channels merely being disabled.
- Global regulatory domain is already PT, DFS-ETSI. Device has firmware-managed country 99 with both 2.4 and 5 GHz regulatory ranges. Do not change to US or raise transmit power.
- `ethtool -P wlp2s0` reports a Broadcom fallback 00:90:4c prefix, not the board's expected Apple permanent identity. NetworkManager's current address is randomized. No MAC address changed.
- brcmfmac uses generic 43602 firmware, v7.35.177.61; model-specific NVRAM .txt was absent in original and updated baseline. Optional CLM/TXCAP warnings alone do not establish the cause.

Combined missing band plus fallback permanent address strongly suggests absent board NVRAM configuration. This is a lead, not proof that a third-party NVRAM file is safe for this board.

Files: `wifi/raw/wifi-phy-info.txt`, `wifi/raw/wifi-cached-scan.txt` (private nearby SSIDs), `wifi/raw/wifi-kernel-current.log`; upstream 7.2.13 brcmfmac code extracted in `build/inputs/wifi-source/brcmfmac/`.

## Research (not installed)
`wifi/wifi-model-research.md` and `wifi/wifi-nvram-research.md`: nohzafk/omarchy-macbookpro-t1 reports the identical symptom pair on MacBookPro14,2 / BCM43602, resolved by adding board NVRAM. That is a different board/model. It traces its configuration to MikeRatcliffe's gist. `wifi/raw/wifi-nvram-example.txt` saved as research only; never install without provenance and board/calibration review. It includes a placeholder/example MAC and RF tables; do not use somebody else's MAC, invent calibration data, or assume all BCM43602 boards are identical.

The repository contains broad and sometimes conflicting assertions about T1 firmware, Touch ID and driver availability. Treat measured observations as leads, not authoritative universal instructions. Do not adopt its generic power/suspend tweaks.

## Recheck after driver reboot
- Driver deployment is now booted, kernel 7.2.13-200.fc44; audio and Touch Bar work per user.
- `iw phy` STILL exposes only 2.4 GHz Band 1. Global country remains PT; firmware-managed country 99 includes 5 GHz ranges. This is not simply a hidden SSID, GNOME scanning problem or missing PT setting: the driver exposes no 5 GHz band at all.
- `ethtool -P` still returns a Broadcom fallback permanent identity. Firmware remains 7.35.177.61, FWID 01-ea662a8c; only generic station/AP .bin.xz files are present for 43602, with no board .txt. Boot logs still report absent optional CLM/TXCAP.
- Strongest current diagnosis remains missing/wrong board NVRAM; exact causal proof and safe model-specific replacement are still pending. The saved third-party example's board/calibration provenance is insufficient for installation on this machine.
- `lsblk` shows Fedora/EFI partitions, no evident macOS filesystem. Ask about external macOS, Recovery or backups rather than mounting/changing disks speculatively.
- No firmware, regulatory domain, interface state or connection profile changed.

## Next steps
1. Clean-boot recheck complete; proceed with board-specific provenance research. Do not unload brcmfmac or interrupt current Wi-Fi to test during a session.
2. Establish board-specific NVRAM provenance for MacBookPro13,2 / subsystem 106b:0157: prefer genuine configuration extracted from this machine/macOS or authoritative model firmware packaging. Ask whether macOS or a firmware backup is available if needed.
3. Confirm real permanent MAC from a trusted source, not NetworkManager's randomized address or the firmware fallback. Do not publish device identifiers.
4. Only after review, use reversible narrowly scoped /etc firmware search path or packaged firmware integration compatible with Silverblue, ensure initramfs includes it, keep generic firmware untouched, and prepare bootloader stock recovery. No broadcom-wl substitution or invented CLM/BCM.hcd.

No Wi-Fi configuration, firmware, country, transmit power, connection profile or interface state changed in this investigation.
