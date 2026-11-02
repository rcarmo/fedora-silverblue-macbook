# Driver build results — 2026-10-31

## Physical results and diagnosis
User confirmed Touch Bar remains dark and heard nothing during targeted low-volume PipeWire speaker tests. Built-in sink was unmuted, active port Speakers. Read-only amixer inspection found PCM playback volume, no separate speaker mute switch. Codec 0x10138409 / subsystem 0x106b3600 uses generic stock initialization; uninitialized Apple external amplifiers are a likely explanation, not independently proven.

Audio observations saved in `audio/logs/audio-mixer.txt`, `audio/logs/audio-cards.txt`, `audio/logs/audio-kernel.log`. Subsequent sink volume read 0.52 (not changed by assistant); no additional playback or volume increase performed.

iBridge USB configuration is already 1 with four interfaces and functional device detection; do not provision T1 firmware.

## Isolated environment
Rootless Podman container `macbook-driver-build`, now stopped and preserved. Restart with `podman start macbook-driver-build`.
Base image registry.fedoraproject.org/fedora:44 digest sha256:b414c09be79dd1f32529b55b096b6bb30435d82ee16fbdbbabf8985eb5f86db0.
Inside container only: gcc 16.2.1-2.fc44, make 4.4.1-12.fc44, exact kernel-devel 7.2.13-200.fc44.x86_64, patch, elfutils-libelf-devel, openssl-devel, rpm-build, kmod and dependencies. Host packages not installed by assistant.
Dependency installation outlived the tool timeout; subsequent RPM queries confirmed completion. Download log capture incomplete (`build/logs/build-dependencies.log`); do not interpret its last download line as current state.

## Touch Bar: compilation PASS
Pinned AJ-dev-i60/t1-touchbar revision 20d65c7b0fe6d05ea9734f869b27384a62de5109. Sources at /root/touchbar in container.

Build command:
```
podman exec macbook-driver-build make -C /root/touchbar KERNELRELEASE=7.2.13-200.fc44.x86_64 KDIR=/usr/src/kernels/7.2.13-200.fc44.x86_64 -j2
```
KDIR must be explicit in this container: kernel-devel installs /usr/src/kernels, but no /lib/modules/.../build symlink exists. Initial default-KDIR attempt failed for that reason only.

Modules apple-ibridge.ko and apple-touchbar.ko saved in `build/artifacts/`; log `touchbar/logs/touchbar-build.log`. Vermagic matches running kernel. Missing vmlinux/pahole caused BTF skip warnings, not compilation failure. No applespi module built or replaced.

## Audio: adapted compilation PASS
Pinned davidjo/snd_hda_macbookpro revision 89b22ff90b86468b186706861dd18663562defa7 (clone `audio/upstream/audio-src/`). Model-specific report for the same codec and model is saved in `audio/raw/model-audio-readme.md`; that report tested Arch kernel 7.1.9, not Fedora.

Exact upstream Linux 7.2.13 archive from kernel.org HTTPS at `build/inputs/linux-7.2.13.tar.xz`:
SHA256 08e7b0c4f2dd1971f972da274b5e589a98989390ac56acd7a1a5af922363ea6c.
Archive xz integrity checked; independent kernel-maintainer signature not verified. It is upstream source, not the complete Fedora-patched source RPM; assess source differences before production packaging.

Original upstream cs8409.c patch applies with line offsets and zero fuzz. Original cs8409.h patch rejects two hunks on kernel 7.2.13. Do not run upstream installer and expect it to work unchanged.

Local compile-only port (`audio/port-audio-header-7.2.py`):
- Omit first header hunk: only comments on enums, incompatible with stock RECEIVER identifier renames.
- Add upstream unsol_item and hda_cvt_setup_apple definitions and sub_codec linein_jack_in field.
- Add upstream Apple-specific cs8409_spec fields before exec_verb, preserving Linux 7.2's speaker_muted and component-binding fields.
- `build/inputs/audio-header-7.2.diff` records resulting header changes.

Reproducible preparation/build script `audio/compile-audio-in-container.sh` runs only in existing container, expects /root/audio to be fresh (no build/hda), source archive at /root/linux-7.2.13.tar.xz, and copies host-generated adapted header. It never installs/loads modules. Preparation plus compile can exceed 60 seconds; use >=120 seconds or detached execution with status logging. Last clean preparation completed; a timed-out compilation was successfully finished by repeating make.

Final module `build/artifacts/snd-hda-codec-cs8409.ko`; logs `audio/logs/audio-build.log` and `audio/logs/audio-build-adapted.log`. Build success does not establish hardware safety or functionality.

Older egorenar akmod recipe (clone `audio/upstream/audio-akmod-src/`, revision 47cdd3011892baefd0a1cd544901264d36746a22) is an RPM packaging reference only: floating master source, different driver tree, mainly iMac-oriented; not suitable to install unchanged.

## Installation gates
Neither module is installed or loaded. No host /etc, initramfs, firmware or authentication changes made.
- Fully inspect runtime source paths; keep Touch Bar skip_acpi_power=1, never 0. No blind live iBridge rebind.
- Package pinned source + local port as reproducible RPM akmods/custom image for Silverblue, offline rebuild inputs, matching kernel-devel, module precedence, and update verification. Never manually write read-only /usr/lib/modules.
- Decide isolated single-driver test and explicit recovery plan; warn user before possible freeze/reboot, save work and connect charger.
- Audio source README warns headphone noise and unknown sleep/power behavior; never direct hw/plughw playback, start muted then low PipeWire volume after any module swap.
- Battery fell to 22%, discharging, during downloads/builds. Container stopped to avoid further work consumption; connect charger before proceeding.

## Concurrent deployment change
Final rpm-ostree status shows a NEW unbooted deployment with layered btop, htop, tmux, vim (11 added), above the booted base update. Assistant did not request this transaction. Original 44.1.7 remains pinned, now third in list. Recheck status before changes; do not overwrite/rollback the user's staged deployment or assume old indexes.
