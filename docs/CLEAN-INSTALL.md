# Clean-install rebuild guide — MacBookPro13,2 on Fedora Silverblue 44

Everything to install lives in **`rebuild-kit/`** (exact copies of the current install, `SHA256SUMS`,
`install-files.sh`). Check `rebuild-kit/SHA256SUMS` first. Verification afterwards: `tools/audit.sh`.

## 0. Before wiping the disk
1. Copy this whole directory (`/var/home/me/macbook-fedora-audit`, a git repo) to external storage.
   Minimum: `rebuild-kit/`, `docs/`, `packaging/` (sources/specs/patches to rebuild drivers for a newer kernel), `tools/`.
   Upstream clones are git-ignored; re-clone from the URLs in `docs/FILE-MAP.md` if needed.
2. Alternate networking (USB tethering/Ethernet) — stock Wi-Fi is 2.4 GHz only until the NVRAM step.
3. Charger connected. No external drives connected.

## 1. Install and update
- Install Fedora Silverblue 44. Keyboard/trackpad (applespi), display, camera and 2.4 GHz Wi-Fi work out of the box; Touch Bar and speakers do not.
- `sudo rpm-ostree upgrade`, reboot. Note `uname -r`.
- **Kernel gate:** the audio akmod only builds for **7.2.\***. On 7.3+ port the audio source first (`packaging/README.md`, `build/driver-build-results.md`), otherwise the composition fails (by design). Touch Bar + `macbook_t1_socw` rebuild against any headers (tested on 7.2.13).
- Optional: `ostree admin pin 0` on a known-good deployment before layering anything.

## 2. Files (before rpm-ostree — the Wi-Fi dracut config must exist when the initramfs is built)
```sh
pkexec /usr/bin/bash /path/to/macbook-fedora-audit/rebuild-kit/install-files.sh
```
Installs Wi-Fi NVRAM + configs, USB-C runtime-PM pin (udev + service, enabled), S3 config, suspend hook
drop-in + hooks, NVMe d3cold rule, UPower critical → PowerOff, and the SELinux fcontext rule. Receipt
and backups in `/var/lib/macbook-rebuild-kit-*`. Table of what each file does: `rebuild-kit/README.md`.

## 3. Drivers, karg, initramfs (one composition), reboot
```sh
cd /path/to/macbook-fedora-audit/rebuild-kit
rpm-ostree install akmods kernel-devel-matched btop htop tmux vim ./rpms/*.rpm
rpm-ostree kargs --append=firmware_class.path=/etc/firmware/macbook-wifi
rpm-ostree initramfs --enable --arg=--force
systemctl reboot
```
(btop/htop/tmux/vim are conveniences.) The packages ship `options apple_ibridge skip_acpi_power=1`
(**never set 0**), dracut configs (early Touch Bar modules, the codec), and a depmod override selecting
`extra/macbook-cs8409` over Fedora's stock codec.

## 4. Desktop preferences (user, no admin)
```sh
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:escape']"
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click false     # phantom-click isolation
# idle auto-suspend: Fedora default (suspend after 15 min) works with S3 — leave it on
```

## 5. Verify
```sh
pkexec /usr/bin/bash /path/to/macbook-fedora-audit/tools/audit.sh     # expect 0 failures (kit vs system vs packages)
iw phy | grep -E 'Band [12]'                                           # both bands
pkexec /usr/bin/bash /path/to/macbook-fedora-audit/tools/run-s3-test.sh 120   # attended; charger in, USB-C empty, lid open
```
Audio safety: start muted/low volume via PipeWire; **never** play to `hw:0,0`/`plughw:0,0`. GNOME Camera
(Snapshot) segfaults — use the browser.

## Wi-Fi notes (BCM43602, 106b:0157)
- NVRAM = kernel bug 193121 attachment 290569 + comment 97 `swctrlmap_2g` fix, macaddr `XX:XX:XX:XX:XX:XX` (locally administered). SHA256 `90f3f159…`.
- The dracut file MUST include `add_drivers+=" brcmfmac-wcc "`; without it Wi-Fi disappears completely.
- WPA3-Personal does NOT work (firmware lacks SAE). Use WPA2-AES or WPA2/WPA3 transition networks.
- Recovery if no Wi-Fi: pick the previous deployment in GRUB (read `rpm-ostree status` first). Emergency args: `rd.driver.blacklist=brcmfmac modprobe.blacklist=brcmfmac`. `wifi/Makefile` + `wifi/recover-wifi.sh` are host-specific reference tooling.

## Deliberately NOT reapplied
- s2idle (`90-macbook-s2idle.conf`): hangs/draws 7–13 W on this model family; S3 is used.
- Any Touch Bar `skip_acpi_power=0`, broadcom-wl, random firmware.
- The per-kernel `/usr/local/lib/macbook-t1-socw/` fallback module (the akmod provides `macbook_t1_socw`).
