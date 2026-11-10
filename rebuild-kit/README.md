# rebuild-kit — current package set and installed configuration (2026-11-10)

`files/` = absolute paths (`files/etc/...` → `/etc/...`), unchanged working S3 configuration.
`rpms/` = Touch Bar **0.1.20261110-1**, audio **0.1.20261101-1**.
The Touch Bar update adds idle blanking; reboot/hardware acceptance remains
required. Validation and test steps: `../docs/T1-IDLE-AND-ASPM.md`.
`SHA256SUMS` covers everything. Full narrative: `../docs/CLEAN-INSTALL.md`.

## On a clean Fedora Silverblue 44 (kernel 7.2.x)
1. Files FIRST (the Wi-Fi dracut config must exist before the initramfs is generated):
   `pkexec /usr/bin/bash $PWD/install-files.sh`
2. Layer drivers + build deps in one transaction (akmods builds during composition):
   `rpm-ostree install akmods kernel-devel-matched ./rpms/*.rpm`
3. Kernel argument (5 GHz NVRAM survives the Wi-Fi rebind across S3):
   `rpm-ostree kargs --append=firmware_class.path=/etc/firmware/macbook-wifi`
4. Local initramfs regeneration (early Touch Bar/audio modules + NVRAM): `rpm-ostree initramfs --enable`
5. Reboot, then `pkexec /usr/bin/bash ../tools/audit.sh` and an attended `pkexec /usr/bin/bash ../tools/run-s3-test.sh 120`.
6. Optional GNOME prefs used here: Caps→Escape; tap-to-click off (phantom-click test);
   idle auto-suspend: leave the default (suspend after 15 min); S3 works.

## What each piece does
| Path | Purpose |
|---|---|
| rpms/akmod-macbook-t1-touchbar + common | apple-ibridge/apple-touchbar (T1 Touch Bar; `skip_acpi_power=1` guard), reset-resume fix, T1 idle blanking, `macbook_t1_socw` (ASOC.SOCW on demand) |
| rpms/akmod-macbook-cs8409 + common | Apple CS8409/CS42L83 audio (amps), re-probe fix, boot-setup re-run after system sleep |
| etc/firmware/macbook-wifi, etc/modprobe.d + etc/dracut.conf.d/99-macbook-wifi-nvram.conf | BCM43602 NVRAM for 5 GHz |
| etc/udev/rules.d/99-macbook-usbc-runtime.rules + etc/systemd/system/macbook-usbc-runtime.service | keep Alpine Ridge USB-C xHCIs awake (hot-plug), both sides, by PCI ID |
| etc/systemd/sleep.conf.d/90-macbook-deep.conf | suspend = S3 (deep) |
| etc/systemd/system/systemd-suspend.service.d/50-macbook-s3.conf | runs the hook pre/post suspend |
| usr/local/sbin/macbook-sleep-hook | NVMe D3cold off (guard), Wi-Fi unbind/rebind, Thunderbolt remove/rescan, XHC1 wake off, LID0 wake off if lid open, T1 SOCW(0)/(1), Touch Bar mode re-send |
| usr/local/sbin/macbook-thunderbolt-remove-rescan | Thunderbolt tree removal before S3 / rescan after (omarchy PR #11570 logic) |
| etc/udev/rules.d/61-macbook-nvme-d3cold.rules | NVMe d3cold_allowed=0 at boot |
| etc/UPower/UPower.conf.d/90-macbook-critical-poweroff.conf | critical battery → power off (not S3) |

Known limits: a lid-open suspend is woken by keyboard/power button (lid wake disabled for it);
audio akmod refuses kernels other than 7.2.* (port before 7.3). See `../docs/KNOWN-ISSUES.md`.
