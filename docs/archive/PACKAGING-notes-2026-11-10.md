# Archived packaging notes — 2026-11-10

> Historical packaging/deployment details captured before the documentation tidy.
> Relative path strings below retain their original context. Use the
> [current packaging guide](../../packaging/README.md) for maintenance.

**Current package set:** Touch Bar **0.1.20261110-1** (`rpms/0.1.20261110/`),
audio **0.1.20261101-1** (`rpms/0.1.20261101/`). Touch Bar idle blanking,
input/Fn behavior and attended post-update deep-S3 passed after reboot;
post-boot audit: 0 failures. See `../docs/T1-IDLE-AND-ASPM.md`.
Previous Touch Bar: 0.1.20261101-1 (working reference); older sets remain archived.

## Layout
| Path | |
|---|---|
| `macbook-t1-touchbar-kmod.spec`, `macbook-cs8409-kmod.spec` | CURRENT specs. Keep these canonical names: kmodtool's `%akmod_install` rebuilds the embedded SRPM from `%{_specdir}/%{name}.spec` (with another file name the akmod silently ships the OLD source). |
| `sources/<pkg>-<ver>/` | Unpacked source trees; `tarballs/` holds the exact Source0 archives (`tar --sort=name --owner=0 --group=0 --mtime='2026-11-01 00:00Z'`). |
| `patches/0001-appletb-reset-resume-invalidate-cached-mode.patch` | Touch Bar: reset-resume re-sends mode (0.1.20261031 → 0.1.20261101) |
| `patches/0002-cs8409-apple-probe-op-and-resume-reinit.patch` | Audio: `.probe` op + boot-setup re-run after system sleep (`resume_reinit` param) |
| `patches/0003-appletb-t1-idle-mode-off.patch` | T1 idle timeout blanks via MODE_OFF; normal input restores Fn mode (0.1.20261110) |
| `sources/macbook-t1-touchbar-0.1.20261110/macbook_t1_socw.c` | Module (dev copy `../touchbar/t1-socw/`): ASOC.SOCW on demand via `socw` param |
| `tests/test-touchbar-idle.py` | Compiles actual worker/update functions with mock hardware/time; `python3 tests/test-touchbar-idle.py` |
| `akmods-tests/<ver>/` | `akmodsbuild` outputs as container user `akmods` (PASS) |
| `logs/` | rpmbuild/akmods/rpm-ostree logs |

## Rebuild a new version
1. Copy `sources/<pkg>-<cur>` to `<pkg>-<new>`, edit, write a patch into `patches/`, update `PROVENANCE.md`.
2. Tarball into `tarballs/` (command above); bump Version/Release + changelog in the canonical spec.
3. `podman start macbook-driver-build`; `podman cp` tarball → `/root/rpmbuild/SOURCES/`, spec → `/root/rpmbuild/SPECS/<name>.spec`; `rpmbuild -ba`.
4. Check `rpm -qlp akmod-*.rpm` shows the NEW `.src.rpm`; run `akmodsbuild` as user `akmods`.
5. Copy RPMs to `rpms/<ver>/` + `SHA256SUMS`; swap with `rpm-ostree uninstall <old package names> --install <new rpm> ...`. Upgrade the changed driver's akmod + common together; leave the other driver alone.
6. Update `rebuild-kit/rpms/` + its `SHA256SUMS`; run `tools/audit.sh` (update its version strings).

---
## Original notes (0.1.20261031)

These packages were built for Fedora Silverblue 44 / kernel 7.2.13-200.fc44.x86_64. They are local audit packages, not maintained Fedora packages. Compilation is not a guarantee of hardware, headphone, or suspend safety.

## Inputs
- Touch Bar: AJ-dev-i60/t1-touchbar `20d65c7b0fe6d05ea9734f869b27384a62de5109`, plus normalization of USB success return and optional-display T1 reset-resume predicate.
- Audio: davidjo/snd_hda_macbookpro `89b22ff90b86468b186706861dd18663562defa7`, prepared using upstream Linux 7.2.13 HDA source and local header port. Details in `../driver-build-results.md` and each source `PROVENANCE.md`.
- Fedora akmods 0.6.2-14.fc44 / kmodtool 1.2.1-1.fc44.
- Source archives are local; no RPM build or scriptlet downloads driver/kernel source.

## Build
Preserved rootless Podman container `macbook-driver-build`; restart with `podman start macbook-driver-build`.
Sources/specs are in `/root/rpmbuild/SOURCES` and `/root/rpmbuild/SPECS` inside the container. Build akmod/SRPMs via `rpmbuild -ba SPEC`. For a direct kmod build, add `--define 'kernels 7.2.13-200.fc44.x86_64'`.

Real akmods rebuild tests were run as container user `akmods` against the embedded SRPMs with exact matching kernel-devel; both passed. Root execution outside OSTree's read-only sandbox is refused by akmodsbuild. Container test logs are in `test-touchbar/` and `test-audio/`.

## Installed requests / desired final versions
- akmod-macbook-t1-touchbar 0.1.20261031-1.fc44
- macbook-t1-touchbar-kmod-common 0.1.20261031-1.fc44
- akmod-macbook-cs8409 0.1.20261031-2.fc44
- macbook-cs8409-kmod-common 0.1.20261031-2.fc44
- Fedora akmods and kernel-devel-matched (with their compiler/build dependencies).

Use rpm-ostree, not dnf/rpm or hand copies on the host. The standard akmods OSTree %post integration builds modules during deployment composition and extracts them into the composed image; the existing booted /usr is never made writable.

Audio release 1 used an underscore in the depmod override and did not override the stock module. Release 2 uses the literal filename `snd-hda-codec-cs8409`; a read-only depmod test against the full staged stock+custom tree confirmed this selects extra/macbook-cs8409. BOTH audio akmod and common package must be upgraded together: akmods-ostree-post also extracts the common RPM generated from its embedded SRPM.

## Boot integration
`rpm-ostree initramfs --enable` enables local regeneration for the requested deployment. Package dracut configuration:
- force_drivers: apple_touchbar, apple_ibridge, with explicit skip_acpi_power=1 via modprobe config.
- add_drivers: snd_hda_codec_cs8409, selected from extra/macbook-cs8409 via depmod override.

Early Touch Bar loading is experimental. No live unbind/rebind or USB configuration rewrite is installed. Native applespi remains stock. Verify modules and ACPI guard in the initramfs before reboot. Never force skip_acpi_power=0.

## Update limitations
Touch Bar recompiles with target kernel headers. Audio carries prepared 7.2.13 HDA source and deliberately rejects kernel versions outside 7.2.*. Before a future 7.3+ upgrade, refresh/port/test the audio source package or remove it; an akmods failure should abort composition instead of silently installing unreviewed source. Local akmod SRPMs are not automatically updated from GitHub.

## Safe first boot
Save all work; connect power; leave headphones unplugged. Built-in audio should be muted and at low software volume until explicitly tested after boot. Do not use direct hw/plughw playback. No suspend test until basic hardware is checked.

Recovery: choose stock Fedora 44.20261031.0 deployment (f1365bc) or pinned original 44.1.7 in the bootloader. For a driver boot hang, append BOTH:
```
rd.driver.blacklist=apple_ibridge,apple_touchbar
modprobe.blacklist=apple_ibridge,apple_touchbar
```
Disabling the audio codec requires separate consideration; selecting a stock deployment is the clean recovery.

To remove both drivers while preserving btop/htop/tmux/vim:
```
rpm-ostree uninstall akmod-macbook-cs8409 macbook-cs8409-kmod-common akmod-macbook-t1-touchbar macbook-t1-touchbar-kmod-common
```
Use graphical/admin authentication as appropriate. Recheck status, wait for composition, then reboot only when ready. akmods/kernel-devel-matched may be removed separately if no other driver needs them. Local initramfs regeneration can be disabled afterward if no custom boot configuration remains. Never remove Fedora's stock codec by hand.
