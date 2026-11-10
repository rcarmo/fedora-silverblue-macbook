# Installation guide

[Documentation index](README.md) · [Safety and known issues](KNOWN-ISSUES.md)

Reproduce the working **MacBookPro13,2** setup on Fedora Silverblue 44.
The included packages were tested with **kernel 7.2.13**. Read the whole guide
before starting; the audio driver cannot be installed on arbitrary newer kernels.

## 1. Check compatibility and prepare recovery

```bash
cat /sys/class/dmi/id/product_name
uname -r
rpm-ostree status
```

- **Model:** this recipe is validated on `MacBookPro13,2`, the four-port 2016
  13-inch Touch Bar model. Do not treat T2 Macs or other models as equivalent.
- **Kernel gate:** the audio source accepts **7.2.x only**. If the deployment you
  will install into uses 7.3+, stop: port/test audio first or prepare a reduced
  setup without that driver. See [packaging](../packaging/README.md).
- Do not blindly run an OS upgrade before checking the target kernel. A fresh
  Silverblue 44 install today may differ from the tested image. RPM composition
  rebuilds the modules; prebuilt package names do not bypass the kernel gate.
- Back up data and this repository before wiping an existing install. Keep a
  known-good deployment available; inspect deployment order before pinning one.
- Connect the charger. Disconnect external drives and USB-C data devices.
  Have alternate networking available; stock Wi-Fi may be limited to 2.4 GHz.

Install Silverblue itself using Fedora's normal procedure. The remaining steps
assume a compatible installed deployment and a checkout of this repository.

## 2. Get the repository and verify the kit

```bash
git clone https://github.com/rcarmo/fedora-silverblue-macbook.git
cd fedora-silverblue-macbook
REPO="$PWD"
(cd "$REPO/rebuild-kit" && sha256sum -c SHA256SUMS)
```

Run the following commands from this shell. If you already have the checkout,
set `REPO` to its absolute path instead. Contents: [rebuild-kit README](../rebuild-kit/README.md).

## 3. Install configuration first

```bash
pkexec /usr/bin/bash "$REPO/rebuild-kit/install-files.sh"
```

This installs Wi-Fi NVRAM/firmware lookup configuration, the USB-C hotplug
workaround, NVMe D3cold guard, deep-sleep configuration, suspend hooks and
critical-battery power-off policy. It labels files for SELinux and enables the
USB-C runtime service. Backups and a receipt go under
`/var/lib/macbook-rebuild-kit-*`.

**Order matters:** the Wi-Fi dracut configuration must exist before driver
installation generates an initramfs. In particular it must include `brcmfmac-wcc`.

## 4. Layer the drivers and configure boot

```bash
rpm-ostree install akmods kernel-devel-matched "$REPO"/rebuild-kit/rpms/*.rpm
rpm-ostree kargs --append=firmware_class.path=/etc/firmware/macbook-wifi
rpm-ostree initramfs --enable --arg=--force
rpm-ostree status
```

These are separate transactions; let each finish. An operation that outlives a
terminal/tool timeout may still be running—check status before retrying.
The packages install the mandatory `apple_ibridge skip_acpi_power=1` guard and
the early-load/module-selection configuration. **Never change that guard to 0.**

Review the staged deployment, save work, then:

```bash
systemctl reboot
```

## 5. Verify the boot before testing sleep

From the repository root after reboot:

```bash
pkexec /usr/bin/bash "$PWD/tools/audit.sh"
iw phy | grep -E 'Band [12]'
```

On the exact reference setup, the audit should report **0 failures**. It compares
sources, package contents, modules, initramfs and configuration. It is also
pinned to the reference kernel/package set: on a different deployment, investigate
mismatches rather than treating every difference as a hardware failure.

Check keyboard/trackpad, Touch Bar, both Wi-Fi bands and audio. Start audio muted
or at low **PipeWire** volume; never use `hw:0,0` or `plughw:0,0`. After five
minutes with no input, the Touch Bar should blank; input should restore it.
Check its keys and Fn switching.

## 6. Run one attended S3 test

Save work, keep the charger connected and disconnect USB-C data devices.
Stay at the machine; this is a real suspend, not a simulation.

```bash
pkexec /usr/bin/bash "$PWD/tools/run-s3-test.sh" 120
```

Follow the [sleep guide](SLEEP.md) to check duration, wake behavior and restored
devices. If it hangs or immediately wakes, review the logs before repeating.

## Optional preferences and later experiments

Caps→Escape and disabling tap-to-click were personal settings, not driver
requirements. Automatic idle suspend is enabled on the reference installation
(15 minutes on AC and battery).

**Do not install ASPM changes as part of this procedure.** The short trial is
promising but not yet validated for hotplug or S3. Read the
[results](ASPM-RESULTS.md) and [opt-in procedure](ASPM-EXPERIMENT.md) separately.

## Recovery and Wi-Fi notes

- Select a known-good previous deployment in the bootloader if the new one
  fails. Do not blindly use `rpm-ostree rollback` with pinned deployments around.
- For a Touch Bar boot hang, append **both** kernel arguments temporarily:
  `rd.driver.blacklist=apple_ibridge,apple_touchbar` and
  `modprobe.blacklist=apple_ibridge,apple_touchbar`.
- Wi-Fi NVRAM is based on kernel bug 193121 attachment 290569 plus the comment 97
  `swctrlmap_2g` fix. The public installer replaces its placeholder MAC with a
  locally administered address; another machine should not copy the reference
  machine's address or expect its NVRAM checksum to match after that change.
- The firmware-path kernel argument is needed for NVRAM reload **after resume**,
  not just early boot. WPA3-Personal is unsupported; use WPA2-AES or a compatible
  transition network.
- Historical `wifi/recover-wifi.sh` tooling is host-specific, not a general
  recovery installer. Do not copy random firmware or use broadcom-wl.
