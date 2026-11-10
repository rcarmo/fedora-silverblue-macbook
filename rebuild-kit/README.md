# Rebuild kit

[Installation guide](../docs/CLEAN-INSTALL.md) · [Safety rules](../docs/KNOWN-ISSUES.md)

The installable package/configuration set for the reference **MacBookPro13,2**.
Use the installation guide for ordering, compatibility checks, reboot and
verification; this page is an inventory, not a second install procedure.

## Package set

| Driver | Version | Verification |
|---|---|---|
| Touch Bar akmod + common | **0.1.20261110-1** | Idle blank/wake, keys, Fn and attended deep S3 passed |
| Audio akmod + common | **0.1.20261101-1** | Speakers and resume checked; builds only for kernel 7.2.x |

Reference kernel: **7.2.13-200.fc44**. Post-boot consistency audit: **0 failures**.
Other deployments need their own compatibility and hardware checks.

## Contents

`files/etc/...` maps to `/etc/...`; `files/usr/local/...` maps to `/usr/local/...`.
`SHA256SUMS` covers the kit contents, including this README and installer.

| Item | Purpose |
|---|---|
| `rpms/` | Both driver akmod/common pairs; embedded SRPMs provide rebuild inputs |
| `files/etc/firmware/macbook-wifi/` | BCM43602 board NVRAM for dual-band Wi-Fi |
| Wi-Fi modprobe/dracut configuration | Include NVRAM and `brcmfmac-wcc` at boot |
| USB-C udev rule + runtime service | Keep Alpine Ridge USB-C hotplug detection working |
| NVMe udev rule | Prevent Apple S3X D3cold no-wake failure |
| Sleep configuration + suspend drop-in | Select deep S3 and run the installed helper |
| `files/usr/local/sbin/macbook-sleep-hook` | Wi-Fi, Thunderbolt, wake masks and T1 sleep/wake coordination |
| `files/usr/local/sbin/macbook-thunderbolt-remove-rescan` | Remove TB upstream ports before S3; rescan after resume |
| UPower configuration | Critical battery action: power off, not suspend |
| `install-files.sh` | Install/label configuration, keep backups and enable USB-C service |

Verify before installing:

```bash
# From this directory
sha256sum -c SHA256SUMS
```

The installer checks hashes too. It does **not** layer packages, set kernel
arguments or reboot: continue through the [installation guide](../docs/CLEAN-INSTALL.md).
Backups/receipt are written to `/var/lib/macbook-rebuild-kit-*`.

**Not included:** ASPM register changes, TLP tuning, a Wi-Fi watchdog or personal
GNOME preferences. The [ASPM experiment](../docs/ASPM-EXPERIMENT.md) remains opt-in
and nonpersistent. Historical sleep phase installers are not required.
