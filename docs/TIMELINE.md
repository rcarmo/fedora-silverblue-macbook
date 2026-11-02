# Timeline (condensed)

Full verbatim log: `docs/archive/PROGRESS-full-log-2026-11-01.md` (newest first).

## 2026-10-31
- Audited stock Fedora 44.1.7 (kernel 6.19.10). Pinned original deployment. Upgraded to 44.20261031.0 / kernel 7.2.13 (`misc/post-reboot-audit.md`).
- Caps Lock → Escape.
- Speakers silent and Touch Bar dark on stock. Built Touch Bar (AJ-dev-i60/t1-touchbar 20d65c7) and audio (davidjo/snd_hda_macbookpro 89b22ff, ported to 7.2 headers) in a rootless Podman container (`build/driver-build-results.md`).
- Packaged as local akmod RPMs (`packaging/`), layered via rpm-ostree, initramfs regeneration enabled. Audio release 2 fixed depmod override. → deployment 43e45ec. User confirmed Touch Bar, speakers, backlights work; mic works but quiet; camera works in browser.

## 2026-11-01 (night/morning)
- Wi-Fi 5 GHz investigation (`wifi/wifi-5ghz-investigation.md`, `wifi/wifi-exact-model-search.md`): missing board NVRAM. First NVRAM trial (b0a3115) → **no Wi-Fi at all**; recovered to c4ebdd8. Later found the cause: missing `brcmfmac-wcc` in initramfs (`wifi/research-20261101/BUG193121-REVIEW.md`).
- Suspend failures: deep (00:05) → s2idle override (08:31, failed) → stock image deep (08:52, failed; custom drivers not the cause) → NVMe D3cold=0 trial (09:22; intended deep but SELinux made it s2idle; resumed after ~1 min, Wi-Fi dead) (`sleep/suspend-audit/*.md`).
- Corrected Wi-Fi trial v2 39e497f (WCC included) → dual band works; WPA3 not supported (`wifi/trial-v2/`, `wifi/wpa3-audit/`).
- `pm_test=devices` rehearsal (10:10) → callbacks completed but Wi-Fi died (`sleep/suspend-audit/DEVICES-REHEARSAL-OUTCOME.md`).
- USB Ethernet (RTL8153) failed to enumerate; researched Dunedan issues; forcing USB6 root hub `power/control=on` fixed it → persistent udev workaround (`sleep/suspend-audit/USB-REPO-RESEARCH.md`, `RIGHT-USB3-PERSISTENT-WORKAROUND.md`). Persisted across reboot.
- 11:00 unattended idle suspend (s2idle) → hung, Touch Bar lit. Disabled GNOME idle suspend; tap-to-click off for phantom clicks (`sleep/idle-trackpad-audit/`).
- Notes reorganized (this `docs/` folder + `rebuild-kit/`).

## 2026-11-01 (afternoon) — sleep fixed
- Phase 1 (12:20): S3 recipe (deep, NVMe d3cold off, Thunderbolt remove/rescan, Wi-Fi unbind/rebind, `firmware_class.path` karg). First S3 entered and resumed; instant wake (XHC1), Touch Bar dark, USB-C lost.
- Phase 1b (12:48): XHC1 S3 wake off → 117 s clean S3.
- Touch Bar: T1 needs ACPI `SOCW(1)` after S3 (and `SOCW(0)` before); driver also cached a stale mode. Phase 1c (12:58) + SELinux label fix → 112 s S3 with Touch Bar (13:12). Lid close on AC and 24 min on battery OK.
- Audio silent after S3: Apple CS8409 resume never re-ran its boot setup; live rebind exposed a missing `.probe` op and the S3 reset of the codec subsystem ID. Patched driver: audio survives S3 (14:02).
- Packaged as akmods 0.1.20261101 (Touch Bar fix + `macbook_t1_socw`, audio fix); Phase 1d hook uses modprobe; staged deployment aea41722. Consistency audit 0 failures. Workspace tidied into topic dirs under git.
- Open: instant wakes on some S3 entries on the charger (`docs/SLEEP.md`).
