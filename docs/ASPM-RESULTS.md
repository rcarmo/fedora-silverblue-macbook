# Thunderbolt ASPM: results so far

[Documentation index](README.md) · [Experimental procedure](ASPM-EXPERIMENT.md)

**Promising awake-power result, not a finished suspend fix.** One short attended
trial on 2026-11-10 reduced draw by about **1.6 W**. All original L1 settings were
restored and verified afterward. No ASPM boot service or resume hook is installed.

## What was measured

Reference system: MacBookPro13,2, Fedora Silverblue 44, kernel 7.2.13,
Touch Bar 0.1.20261110. Its functional checks and a normal deep-S3 check had
passed before the experiment. No suspend was attempted while L1 was enabled.

Session `20261110-184758` enabled only the L1 bit on **six paired internal
Thunderbolt links / twelve PCI functions**. NVMe and Wi-Fi were not changed.

| Phase | Duration | Samples | Mean W | Median W | Standard deviation W |
|---|---:|---:|---:|---:|---:|
| Original settings | 60 s | 13 | 12.176 | 12.133 | 0.211 |
| L1 enabled | 60 s | 13 | 10.481 | 10.357 | 0.543 |
| Original settings restored | 60 s | 13 | 11.897 | 12.031 | 0.444 |

Relative to the average of both baselines (**12.036 W**), the L1 phase used
**1.555 W less (~12.9%)**. The baseline means differed by 0.278 W.
This is an apparent saving in that workload, not a prediction of runtime or
standby drain on other machines.

## Method and limitations

- Battery draw was calculated from `current_now × voltage_now`, sampled every
  five seconds. The usual 20% charge cutoff remained in place.
- To keep the run short, the Touch Bar timeout was temporarily changed from
  300 to 30 seconds; sampling started after a 35-second warmup. The original
  300-second timeout was restored in `finally`.
- GNOME idle and system sleep were inhibited for the trial without changing
  persistent preferences. Lighting stayed fixed according to the tool's checks.
- There was **no settling interval** between phases. The first sample after
  each transition visibly lagged the register change; battery telemetry is not
  an instantaneous precision power meter.
- The final sample was 20.26% of charge_full. A later reading was ~19.6%, and
  the user was asked to reconnect AC. Gauge jumps make a low-charge repeat undesirable.
- All six links were confirmed L1-disabled again. There were no new matching
  AER/PCIe/NVMe/Thunderbolt/xHCI kernel entries since the trial start.

A one-minute L1 phase with no errors establishes only a short smoke/power result.
**Long-term stability, USB-C hotplug and S3 with L1 enabled remain unvalidated.**

## Why investigate Thunderbolt specifically?

The native policy reads `[default] performance powersave powersupersave`, but
Linux logs:

```text
ACPI FADT declares the system doesn't support PCIe ASPM, so disable it
_OSC: OS assumes control of [PCIeHotplug SHPCHotplug AER PCIeCapability LTR DPC]
```

All six paired TB links advertise L1 yet had it disabled at both ends. In contrast,
NVMe and Wi-Fi already had L1 enabled, so importing a blanket vendor-ID script
would change more than necessary. Capability bits alone do not prove safety;
direct configuration writes bypass firmware/kernel ownership decisions.

The idea came from [mikeypdev/macbook-t1-suspend](https://github.com/mikeypdev/macbook-t1-suspend),
an Arch port based on this project's earlier Fedora setup. Its reported saving
is a separate measurement, not evidence for our result.

## Next validation

1. Repeat with ample charge, longer phases and settling; reject runs with large
   baseline drift or lighting/workload changes.
2. If the saving repeats, plan separate attended hotplug and S3 validation
   **with L1 enabled**, with a restoration strategy that accounts for rescan.
3. Consider narrowly scoped boot/resume integration only after those checks.

Do not install a persistent service based on this short trial alone. The
[procedure](ASPM-EXPERIMENT.md) is deliberately opt-in and restores state.

## Evidence locations

Local raw evidence (excluded from the public export):

- `tools/logs/aspm-short-trial-20261110/`: phase CSVs, topology/lighting plan,
  undo receipt, summary and exact temporary-timeout wrapper.
- `tools/logs/aspm-short-trial-20261110.log`: console output.
- `tools/logs/aspm-after-short-trial-20261110.log`: restored-state inspection.

The measured values and relevant kernel messages are reproduced above so the
published result remains understandable without those local files.
