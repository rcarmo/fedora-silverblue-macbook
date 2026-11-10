# Attended Thunderbolt ASPM L1 experiment

**Status (2026-11-10): tooling and read-only inspection only. No PCI configuration
writes performed, no boot service or resume automation installed.** Touch Bar
0.1.20261110 is still staged, not booted. Reboot and complete its hardware checks
in `T1-IDLE-AND-ASPM.md` before applying anything here.

## What the new inspection found

`tools/aspm-experiment.py inspect` follows the two integrated Thunderbolt root
ports through sysfs, identifies physical root/downstream-to-partner links and
checks PCIe type and L1 capability at **both** ends. It does not mistake an
upstream-to-downstream internal switch edge for another physical link, nor
program empty hotplug ports.

On this boot there are **six physical internal links / twelve target functions**:

| Parent | Partner | Device |
|---|---|---|
| 00:1c.4 | 03:00.0 | Left TB upstream |
| 04:00.0 | 05:00.0 | Left NHI |
| 04:02.0 | 2c:00.0 | Left xHCI |
| 00:1d.0 | 79:00.0 | Right TB upstream |
| 7a:00.0 | 7b:00.0 | Right NHI |
| 7a:02.0 | a2:00.0 | Right xHCI |

Every end advertises L1, and every end currently has L1 disabled. Bus addresses
are examples, **not** a hardcoded write list: Thunderbolt rescans renumber them.
The four empty hotplug ports are excluded. NVMe and Wi-Fi are outside the
selected subtrees and are never targeted (both already have L1 enabled here).

Kernel evidence from the same read-only inspection:

```text
ACPI FADT declares the system doesn't support PCIe ASPM, so disable it
_OSC: OS assumes control of [PCIeHotplug SHPCHotplug AER PCIeCapability LTR DPC]
```

Thus Linux reports disabling native ASPM because of firmware. Merely seeing a
`powersave` option in `/sys/module/pcie_aspm/parameters/policy` is not evidence
that changing it would work. No policy write was attempted. If a future firmware
or kernel enables native control, prefer that and do not bypass it with this
tool. Do not use blanket `pcie_aspm=force` as the first experiment.

Raw local inspection: `tools/logs/aspm-inspect-20261110.log` (excluded from the
public export; the relevant findings are reproduced above).

## Preconditions

- Save work; this is a PCI hardware experiment and **can still freeze a machine**.
  L1 support bits do not prove the absence of firmware/kernel quirks.
- Reboot into Touch Bar **0.1.20261110**, then verify blanking, input/Fn restore,
  and the existing attended S3 behavior. Do not combine an untested driver boot
  with ASPM changes. The trial requires the booted package version and explicit
  confirmation that these hardware checks passed.
- Charge well above 20% (preferably 50%+) before starting, then unplug AC.
  The sampler refuses AC/charging and aborts below 20% of `charge_full`.
- Unplug all USB-C data devices, displays and docks. The inventory also rejects
  unknown PCI functions in either TB subtree. Do not hotplug during the trial.
- Close heavy applications; fix display/keyboard brightness, disable automatic
  brightness and idle dim/blank for the trial in GNOME, and remember to restore
  those preferences afterward. Do not disable critical battery protection.
- Keep the same screen state and workload throughout. No typing/mouse/trackpad
  activity once warmup begins. Avoid downloads, updates and background builds.

The trial automatically waits for the current Touch Bar idle timeout plus five
seconds **before** its baseline; otherwise the first phase could include a lit
bar and later phases an unlit one. With our 300-second timeout, this adds about
five minutes. It also checks backlight sysfs values during sampling and aborts
if they change. That check cannot detect every display/workload change; the
operator still needs to control them.

## Commands (from the repository root)

Read-only diagnostics, safe before the driver reboot:

```bash
pkexec /usr/bin/python3 "$PWD/tools/aspm-experiment.py" inspect
```

Optional read-only battery CSV, no root required (discharging, charge >=20%):

```bash
python3 tools/aspm-experiment.py sample --seconds 300 > baseline.csv
```

**After all preconditions**, run one automatic baseline -> L1 -> restored trial:

```bash
pkexec /usr/bin/python3 "$PWD/tools/aspm-experiment.py" trial \
  --touchbar-tested --unplugged --saved-work --native-control-unavailable
```

The confirmations are assertions by the operator, not permission to skip the
checks. `--native-control-unavailable` means the current inspection still shows
native ASPM disabled by firmware and you have chosen this direct-write
experiment instead. Do not pass it on a machine with working native control.

Defaults: 300 seconds per phase, 30 seconds settling before each phase, plus
initial Touch Bar warmup: about **22 minutes** total here. For a shorter first
smoke test, use `--seconds 60`; do not infer a reliable power saving from a
single short/noisy run. `--interval` controls sampling cadence (default 5 s).

The tool:

1. Checks model, current driver version, confirmations, battery and PCI topology.
2. Acquires a sleep inhibitor for the complete trial and an exclusive state lock.
3. Measures baseline, saves and fsyncs the original settings **before** writes,
   then enables only LnkCtl bit 1 with masked `setpci` writes and readback.
4. Measures L1, restores the original L1 bits without overwriting unrelated
   control bits, and measures the restored baseline.
5. Restores on Python errors, Ctrl-C or SIGTERM, and releases the sleep inhibitor.

Receipts, topology/lighting metadata, raw phase CSVs and a successful-run summary
are stored root-only in `/var/lib/macbook-aspm-experiment/`. Compare both baseline
means/medians against the L1 phase and inspect variability. Repeat if necessary;
large baseline drift means the result is inconclusive, not a power saving.

Check kernel errors from the receipt's `started_at` time onward:

```bash
journalctl -b -k --since '<trial-start-time>' --grep='AER:|PCIe Bus Error|nvme|thunderbolt|xhci'
```

The trial deliberately blocks sleep and does **not** claim to validate enabled-L1
USB-C hotplug or S3. Those need a separate attended validation phase after an
actual measurable win; no persistent helper should be installed before then.

## Recovery / limits

Normal completion restores the original L1 bits automatically. Ctrl-C is the
preferred way to abort. If the process was killed without cleanup, recover on
**the same boot, before a rescan/suspend**, using:

```bash
pkexec /usr/bin/python3 "$PWD/tools/aspm-experiment.py" restore
```

Recovery requires the saved boot ID, device IDs, paths and sysfs inodes to match.
If a device was re-enumerated or a reboot occurred, it **refuses stale writes**.
Do not edit the receipt to bypass that check. Inspect current state instead.
A retained `active.json` blocks further trials until recovery is resolved; after
a reboot, archive that stale receipt manually only after reviewing the state.

SIGKILL, power loss, a hardware lockup, a forced suspend, or PCI hotplug cannot be
made safe by Python `finally`. Durable receipts enable recovery when the same
hardware instance is still present; they are not a guarantee of it. Settings
are not deliberately reapplied at boot/resume. Do not rely solely on a reboot
as a substitute for verified restoration.

## Tool tests

```bash
python3 -m unittest discover -s tools/tests -v
```

All **15 tests passed**. The real systemd sleep inhibitor was also acquired and
released successfully in isolation, without PCI access. Read-only inspection
was rerun afterward; all six links remain L1-disabled.

Tests use fake sysfs and mocked PCI access; no root or hardware writes. Coverage
includes link pairing/empty ports, unknown devices, both-end capability checks,
masked writes, preservation of unrelated/original bits, readback failure,
identity/boot mismatches, partial restoration, durable receipts before a partial
apply failure, rollback after measurement failure, driver/confirmation gates,
battery safety, lighting changes, and CSV sampling.
