# Known issues, lessons and safety rules

Status as of 2026-11-01. Evidence paths are relative to the project root.

## Working
| Area | Status | Notes |
|---|---|---|
| Keyboard/trackpad | Works (stock applespi) | Phantom clicks + libinput "Touch jump" errors — see below |
| Touch Bar | Works (local akmod), also after S3 | `skip_acpi_power=1` mandatory; SOCW only via sleep hook |
| Speakers | Works (local cs8409 akmod), also after S3 | Headphone jack untested |
| Sleep (S3) | Works — see `docs/SLEEP.md` | Lid-open suspend: wake with key/power button |
| Internal mic | Works, very quiet | Upstream driver limitation |
| Screen/keyboard backlight | Works | |
| Camera | Works in browser | GNOME Camera segfaults — ignored |
| Wi-Fi 2.4+5 GHz | Works with NVRAM | No WPA3 (firmware lacks SAE) |
| USB-C right/front | Works with udev workaround | Left side not validated |
| Caps→Escape | GNOME setting | |

## Broken / unresolved
### Suspend/resume — WORKS (2026-11-01), see `docs/SLEEP.md`
- Suspending with the lid OPEN disables lid wake for that sleep (else it woke after 3 s): wake it with a key/trackpad or the power button.
- Kernel updates: audio akmod builds only for 7.2.*; `macbook_t1_socw` comes from the Touch Bar akmod (rebuilt automatically). If it can't load, the hook logs a warning and the Touch Bar stays dark after resume.
- S3 drain estimate ~4–5 %/h (35 min sample, coarse gauge) — measure overnight. GNOME idle-suspend restored (15 min, AC and battery).
Pre-fix failure history (s2idle hangs, Thunderbolt xHCI "not ready 65535ms", brcmfmac timeouts): `sleep/suspend-audit/`, `docs/SLEEP-RESUME-RESEARCH.md`.

### Trackpad phantom clicks
libinput logged "kernel bug: Touch jump detected and discarded" 5× (10:16–10:31 on 2026-11-01). Tap-to-click disabled as an isolation test; outcome pending. Evidence `sleep/idle-trackpad-audit/`.

### Others
- WPA3: not possible with current Broadcom firmware; `wifi/wpa3-audit/README.md`.
- Bluetooth: controller up, pairing untested; missing BCM.hcd is expected — don't copy random firmware.
- Thunderbolt docks/external display/left USB ports: mostly untested (one LG UltraFine 1080p mode test restored fine: `misc/lg-display/lg-video-test.log`).
- Battery: 673 cycles, ~74% of design. Kernel `capacity` disagrees with UPower; trust charge_now/charge_full.
- `systemd-remount-fs` failure is normal on Silverblue composefs — don't "fix".
- Touch ID: unsupported.

## Hard rules learned the hard way
1. **Never** set `apple_ibridge skip_acpi_power=0` (T1 ACPI call can freeze the machine).
2. **Never** play audio to `hw:0,0`/`plughw:0,0`; use PipeWire, low volume.
3. Wi-Fi NVRAM via initramfs must include `brcmfmac-wcc`, or Wi-Fi disappears completely.
4. Wi-Fi rebind is safe only with the `firmware_class.path=/etc/firmware/macbook-wifi` karg (otherwise the NVRAM exists only in the initramfs and a reload falls back to 2.4 GHz).
5. Don't blindly `rpm-ostree rollback`; read `rpm-ostree status`, deployment order changes.
6. `/run` sleep.conf.d drop-ins are blocked by SELinux for systemd-sleep — a "deep" test silently ran as s2idle. Verify the actual `PM: suspend entry (...)` mode in the kernel log.
7. A lit/responsive Touch Bar does NOT mean the host is awake; the T1 is a separate computer.
8. Before bagging: S3 works, but a chain of instant wakes is possible on the charger — check it actually stays asleep (or shut down).
9. Don't use broadcom-wl, don't force Wi-Fi capability bits, don't disable PMF for SAE.
10. Don't paste community PCI remove/rescan or blanket D3cold hooks without targeted validation (the ones in use were validated: `docs/SLEEP.md`).
11. Long rpm-ostree operations often outlive tool timeouts but complete — check status before retrying.
12. `ASOC.SOCW` only after an S3 resume / before S3 (via `macbook_t1_socw`), never at driver probe.
13. Never unbind/rebind the HDA controller (00:1f.3) or reload `snd_hda_codec_cs8409` after a sleep: S3 resets the codec subsystem ID, the Apple path isn't found and built-in audio is lost until reboot. `modprobe -r snd_hda_codec_cs8409` also unloads `snd_hda_codec_generic`/`snd_hda_scodec_component`.
14. Don't live-unbind/rebind the iBridge/T1 (can wedge it); re-send the mode via the `idle_timeout` sysfs attribute instead.
15. Module files in `/usr/local` need SELinux type `modules_object_t` (semanage rule), or insmod from systemd units is denied.
16. Packaging: kmodtool's `%akmod_install` embeds the SRPM built from `%{name}.spec` — keep the current spec under the canonical name or the akmod ships the OLD source.
17. Deployment order: never `rpm-ostree rollback` blindly with pinned deployments present — it can make an old pinned image default. Read `rpm-ostree status`, then `ostree admin set-default <index>`.
