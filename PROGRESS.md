# Current status

Last verified **2026-11-10**. This describes the reference machine, not a support
guarantee for other MacBooks. Start with the [project overview](README.md) or
[installation guide](docs/CLEAN-INSTALL.md).

## Installed and verified

| Component | Reference state |
|---|---|
| OS / kernel | Fedora Silverblue 44.20261031.0 / 7.2.13-200.fc44 |
| Booted deployment | `1257270345a8` |
| Touch Bar packages | **0.1.20261110-1** |
| Audio packages | **0.1.20261101-1**; build restricted to 7.2.x |
| Configuration | [Rebuild kit](rebuild-kit/README.md); current working S3 hooks unchanged |
| Wi-Fi firmware lookup | `firmware_class.path=/etc/firmware/macbook-wifi` |
| ASPM experiment | **Original settings restored**; no boot/resume automation |

- Post-boot consistency audit: **0 failures**, including loaded-module fingerprints.
- User-confirmed Touch Bar idle blanking, input restore, keys and Fn switching.
- Attended deep S3 passed at 18:40:53–18:42:34; all devices reported working
  afterward. Thunderbolt returned on its first rescan; Wi-Fi and T1 recovery succeeded.
- A short awake-power trial measured **12.18 → 10.48 → 11.90 W**
  (baseline → L1 → restored). Preliminary saving: **~1.6 W / 13%**.
  This did **not** test hotplug or S3 with L1 enabled. See [ASPM results](docs/ASPM-RESULTS.md).

Local evidence: `tools/logs/audit-post-reboot-20261110.log`,
`tools/logs/s3-post-update-20261110.log`, `tools/logs/aspm-short-trial-20261110/`.
These raw logs are excluded from the public export; the guides reproduce the findings.

## Next checks

1. Repeat the ASPM comparison with more battery headroom, settling and longer
   measurement phases. Validate hotplug and **S3 with L1 enabled** separately
   before considering persistence. [Procedure](docs/ASPM-EXPERIMENT.md).
2. Validate headphone output, Bluetooth pairing, left-side USB-C and docks.
3. Monitor occasional early S3 wakes and trackpad phantom clicks.
4. **Before a kernel 7.3+ update:** port/test the audio package or remove it;
   do not assume the existing source will build.

## Recent changes

- Touch Bar 0.1.20261110 adds T1 idle blanking via MODE_OFF. The default timeout
  remains **300 seconds**; sleep/wake policy and the ACPI freeze guard are unchanged.
- Composition also refreshed Ghostty, erlang-srpm-macros, redhat-rpm-config and
  kernel-headers. The running kernel and kernel-devel remain 7.2.13; audio was
  unchanged. Published delta: [package diff](packaging/logs/touchbar-0.1.20261110-package-diff.log).

History is in the [timeline](docs/TIMELINE.md) and
[archived progress snapshot](docs/archive/PROGRESS-snapshot-2026-11-10.md).
