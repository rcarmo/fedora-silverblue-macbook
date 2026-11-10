# Driver packaging

[Documentation index](../docs/README.md) · [Install guide](../docs/CLEAN-INSTALL.md)

This page is for rebuilding the local drivers. Installing the working package
set is covered by the installation guide, not by running build scripts on the host.

## Current package set

| Package family | Version | Source directory |
|---|---|---|
| `macbook-t1-touchbar` | **0.1.20261110-1** | `sources/macbook-t1-touchbar-0.1.20261110/` |
| `macbook-cs8409` | **0.1.20261101-1** | `sources/macbook-cs8409-0.1.20261101/` |

Each driver is installed as an **akmod + common** pair; update that pair together.
The current RPMs are published in [the rebuild kit](../rebuild-kit/README.md).
The reference boot passed the consistency audit and attended deep S3. Touch Bar
idle blanking and Fn/input behavior also passed. [Patch details](../docs/T1-IDLE-AND-ASPM.md).

**Kernel limit:** audio carries prepared Linux 7.2.13 HDA source and rejects
builds outside **7.2.x**. Port/test it or remove it before a 7.3+ deployment.
Touch Bar builds against target headers, but only 7.2.13 has been validated here.
A compiler success is not a hardware/suspend safety guarantee.

## Sources and layout

| Path | Purpose |
|---|---|
| `macbook-t1-touchbar-kmod.spec`, `macbook-cs8409-kmod.spec` | Canonical current specs |
| `sources/<package>-<version>/` | Prepared source trees; `PROVENANCE.md` records changes |
| `tarballs/` | Exact Source0 archives used by the SRPMs |
| `patches/0001-*` | Touch Bar reset-resume cache invalidation |
| `patches/0002-*` | CS8409 `.probe` and resume reinitialisation |
| `patches/0003-*` | T1 idle blanking via MODE_OFF |
| `tests/test-touchbar-idle.py` | Mocked worker/input regression test |
| `logs/` | Build and deployment audit records |

Touch Bar is pinned to AJ-dev-i60/t1-touchbar `20d65c7`; audio to
davidjo/snd_hda_macbookpro `89b22ff`, with prepared 7.2 HDA source and local fixes.
No RPM build/scriptlet fetches driver or kernel source from the network.

The local workspace also retains `rpms/<version>/`, `akmods-tests/` and a rootless
Podman container named `macbook-driver-build`. Those artifacts/container are not
shipped as a reproducible running environment in the public export. A new
builder must provision matching Fedora build dependencies and kernel-devel.
See [original build notes](../build/driver-build-results.md) for the recorded setup.

## Rebuild and validate a changed driver

1. Copy the current prepared source directory to a new version. Make the change,
   save a reproducible patch under `patches/`, and update `PROVENANCE.md`.
2. Create Source0 from `sources/`, substituting the package/version/date:

   ```text
   tar --sort=name --owner=0 --group=0 --mtime='2026-11-10 00:00Z' \
     -czf tarballs/<package>-<version>.tar.gz -C sources <package>-<version>
   ```

3. Bump Version/Release and changelog in the **canonical** `<package>-kmod.spec`.
   kmodtool's `%akmod_install` rebuilds the embedded SRPM using that filename;
   using a differently named spec previously shipped old source silently.
4. In the Fedora builder, put Source0 in `/root/rpmbuild/SOURCES/` and the spec
   in `/root/rpmbuild/SPECS/` under its canonical name. Run `rpmbuild -ba` there.
   Dependencies include kmodtool, gcc, make, redhat-rpm-config and matching
   kernel-devel; the recorded environment used akmods 0.6.2 and kmodtool 1.2.1.
5. Inspect the akmod with `rpm -qlp`: confirm it embeds the **new** `.src.rpm`.
   Extract that SRPM and run `akmodsbuild` as an **unprivileged** build user
   against the exact target kernel. Check the embedded spec/tarball too.
6. Layer only the changed driver's new akmod/common pair using rpm-ostree.
   Let composition and initramfs generation finish; inspect the staged result.
   Never make the booted `/usr` writable or hand-copy modules into it.
7. Refresh the kit RPMs, checksum manifests and expected versions in
   `tools/audit.sh`. Audit the staged deployment, reboot when ready, then audit
   the booted modules and run attended hardware/S3 acceptance.

On the existing workspace, `podman start macbook-driver-build` reuses the saved
builder. Do not assume that container exists on another machine.

## Boot safety and recovery

The common packages configure early Touch Bar/audio loading. Keep
**`apple_ibridge skip_acpi_power=1`**. SOCW is provided by the separate
`macbook_t1_socw` module and only invoked by the sleep hook.
The audio depmod override must select the literal module filename
`snd-hda-codec-cs8409` under `extra/macbook-cs8409`.

Retain a known-good deployment before upgrading. For a Touch Bar boot hang,
use both `rd.driver.blacklist=apple_ibridge,apple_touchbar` and
`modprobe.blacklist=apple_ibridge,apple_touchbar` temporarily. Do not use a live
T1 reset or post-sleep HDA reload as recovery. [Full safety rules](../docs/KNOWN-ISSUES.md).

Historical release/deployment specifics are kept in the
[archived packaging notes](../docs/archive/PACKAGING-notes-2026-11-10.md).
