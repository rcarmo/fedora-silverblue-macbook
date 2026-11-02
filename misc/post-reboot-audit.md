# Post-reboot audit — 2026-10-31

## Confirmed
- Running Fedora Silverblue 44.20261031.0, kernel 7.2.13-200.fc44.x86_64, expected commit f1365bc…; rpm-ostree idle. Original 44.1.7 deployment remains pinned.
- Native applespi keyboard and trackpad present. Caps-to-Escape GNOME mapping survived reboot.
- Intel i915 DMC loaded. No WARN stack traces found in this boot's saved kernel journal (`misc/kernel-current.log`); previous Plymouth cleanup traces absent.
- brcmfmac Wi-Fi connected. Generic firmware remains 7.35.177.61; optional clm/txcap absent and ARP table -52 warning persists.
- Bluetooth powered, not discovering; baud-rate -16 and missing generic BCM.hcd warnings persist. Pairing not tested.
- FaceTime camera detected by UVC and PipeWire/libcamera, /dev/video0 and /dev/video1. No capture performed.
- CS8409 still uses generic autoconfiguration. Built-in analog stereo sink at volume 0.40 and microphone source present. No physical playback/recording performed.
- Screen brightness 59/90; keyboard backlight 31/255. Only read, not adjusted.
- Both Thunderbolt controllers bound; tunneled native-port link warnings persist. External hardware not tested.
- Battery snapshot: discharging, 33%, 673 cycles, full charge 3200 mAh vs design 4315 mAh (~74% reported remaining capacity), temperature 37.2 C. Endurance/charging not tested; connect power before long build or suspend experiments.
- Suspend choice remains s2idle [deep]; no suspend performed.

## Remount service
systemd-remount-fs.service still fails because composefs overlay rejects reconfigure. `/` is a read-only composefs overlay; `/sysroot` is read-only Btrfs. `/etc/fstab` has a root Btrfs entry with subvol=root,compress=zstd:1,ro, marked updated by bootc-fstab-edit.service. No evidence here of an SSD failure; do not mask the service or alter root mounts merely to hide the error. No configuration changed.

## Touch Bar research
Newer T1 forks exist, so the 2020 source is not the best starting point.

- https://github.com/AJ-dev-i60/t1-touchbar — locally cloned in `touchbar/upstream/t1-touchbar-src/`, commit `20d65c7b0fe6d05ea9734f869b27384a62de5109`.
  - Based on t2linux/apple-ib-drv; builds only apple-ibridge and apple-touchbar, not applespi.
  - Author reports Ubuntu 26.04 kernel 7.0 on MacBookPro14,3. Separate model-specific repo reports this exact revision working on MacBookPro13,2 / Arch 7.1.9.
  - Source inspected in part: tri-state skip_acpi_power defaults to skipping SOCW on MacBookPro13/14; probe/suspend/resume call sites guarded. Explicit option skip_acpi_power=1 must be retained. Never force 0: reported hard freezes.
  - No build or load tested here on Fedora kernel 7.2.13. Installer targets apt/DKMS, writes /usr/src and installs modules; do NOT execute it on Silverblue.
  - Supplied udev rule also disables iBridge autosuspend; assess whether necessary rather than adopting speculative power changes.
- https://github.com/cevatkerim/macbookpro13-2-touchbar — `touchbar/raw/macbookpro13-2-touchbar-readme.md` and `touchbar/model-touchbar-packaging.md` saved. Arch packaging pins the above source. Firmware provisioning is explicitly unnecessary when production firmware already works; this machine has camera and physical HIDs, so no reason to run firmware recovery.
  - Also reports experimental T1Bridge Touch ID support on this model. This updates the older blanket unsupported assumption, but is not independently verified, not established for Fedora, and includes sensitive firmware/authentication integration. Do not promise support or change PAM/provision firmware from these claims.
- https://github.com/Phennova/apple-touchbar-driver — README saved. Tested Arch 6.18/6.19 on 13,3. Uses aggressive rebind services; docs contain conflicting/generalized advice. Not preferred over freeze-guarded pinned source without further review.
- t2linux/apple-ib-drv API says last push 2025-01-04, default branch mbp15; not archived. Name alone does not mean its fork cannot support T1.

## Next implementation gate
Find or design reproducible RPM akmod/custom-image packaging for the pinned two-module source, with matching Fedora kernel-devel and build tooling. None of gcc/make/kernel-devel/akmods/dkms installed on host. Compile-test in an isolated build environment first, inspect source fully and verify update/rollback behavior before loading. No external installers or downloaded scripts have been executed.

## User-assisted tests still needed
Low-volume built-in speaker playback and user feedback; headphone jack; microphone and camera (explicit consent before recording/capture); display/keyboard backlights; Bluetooth accessory pairing; USB-C/Thunderbolt/external display; saved-work controlled suspend/resume.
