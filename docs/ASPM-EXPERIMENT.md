# Optional ASPM experiment

[Documentation index](README.md) · [Results and limitations](ASPM-RESULTS.md)

**Not an installation step.** The short trial showed a preliminary awake-power
saving, but original settings are restored. Direct PCI configuration writes
bypass firmware/kernel decisions and can freeze the machine even when L1 is
advertised. There is no persistent ASPM helper in the working setup.

## What the tool does

`tools/aspm-experiment.py` provides four commands:

| Command | Purpose | PCI writes? |
|---|---|---|
| `inspect` | Discover paired internal TB links and show kernel ASPM diagnostics | No |
| `sample` | Record battery draw as CSV | No |
| `trial` | Baseline → L1 → restored-baseline comparison | Yes, temporary masked L1 writes |
| `restore` | Recover a saved receipt after an interrupted same-boot trial | Yes, only saved L1 bits |

It validates both ends of each physical link, skips empty/unpaired ports and
rejects unknown PCI functions in either TB subtree. NVMe and Wi-Fi are outside
its write scope. Addresses are discovered through sysfs; no renumbered TB bus
address is assumed to remain stable.

## 1. Prepare before any trial

- Save work; keep recovery available. This is an **attended hardware experiment**.
- Boot/test Touch Bar 0.1.20261110, including blanking, input, keys and Fn, then
  check normal S3. Those checks passed on the reference machine; they are still
  prerequisites on another install.
- Charge with generous headroom (50%+ recommended), then unplug AC. The sampler
  requires discharging and stops below **20% of charge_full**. The kernel's
  percentage display is not used; allow margin for gauge fluctuations.
- Disconnect USB-C data devices, displays and docks. Do not hotplug, suspend or
  reboot during the trial.
- Fix screen/keyboard brightness and the workload. Disable auto-brightness and
  idle dim/blank temporarily, remembering the previous preferences. Do not
  disable critical-battery protection. Avoid downloads, updates and builds.

Do not infer native ASPM control from the presence of a `powersave` option. On
this machine the kernel says firmware's FADT disables ASPM. Prefer native control
if a future kernel/firmware makes it available; do not start with `pcie_aspm=force`.

## 2. Inspect without changing hardware

Run from the repository root:

```bash
pkexec /usr/bin/python3 "$PWD/tools/aspm-experiment.py" inspect
```

Review the paired links, capability/enable bits and kernel ownership messages.
The [result page](ASPM-RESULTS.md) records the reference machine's findings.

Optional battery baseline, no root required:

```bash
python3 tools/aspm-experiment.py sample --seconds 300 > baseline.csv
```

## 3. Run a reversible comparison

Only after the prerequisites and inspection:

```bash
pkexec /usr/bin/python3 "$PWD/tools/aspm-experiment.py" trial \
  --touchbar-tested --unplugged --saved-work --native-control-unavailable
```

These flags are **operator confirmations**, not ways to skip checks.
`--native-control-unavailable` means you reviewed the current diagnostics and
chose the direct-write experiment because native ASPM is disabled by firmware.

Default timing is 300 seconds per phase, 30 seconds settling before each phase,
plus an initial Touch Bar idle warmup: about **22 minutes** with the 300-second
Touch Bar timeout. `--seconds 60` shortens each measurement phase, but does not
skip warmup. A short run is a smoke test, not a reliable power benchmark.

Once warmup starts, leave keyboard/mouse/trackpad untouched. The initial wait
avoids comparing a lit Touch Bar baseline with an unlit later phase. Sampling
also aborts on detected backlight changes; this cannot detect every workload or
display-state change, so the operator still needs to control them.

The tool locks its state, inhibits sleep, durably saves original settings before
writing, modifies only **LnkCtl bit 1**, and checks readback. It restores the
original bit values on normal exit, Python errors, Ctrl-C or SIGTERM, preserving
unrelated control bits. Hardware failure or forced termination can still defeat
cleanup; see recovery below.

## 4. Review the result

Root-only receipts, topology/lighting metadata, phase CSVs and a successful-run
summary live under `/var/lib/macbook-aspm-experiment/`.

- Compare both baseline means/medians to the L1 phase and examine variability.
  Large baseline drift makes the result inconclusive.
- Check kernel errors from the receipt's `started_at` time onward:

  ```bash
  journalctl -b -k --since '<trial-start-time>' --grep='AER:|PCIe Bus Error|nvme|thunderbolt|xhci'
  ```

- Run `inspect` again to verify restoration. Do not assume a successful power
  comparison establishes USB-C or suspend stability.

The tool intentionally blocks sleep and restores settings before finishing.
**Hotplug and S3 with L1 enabled need a separate validation phase** before
persistent boot/resume integration is considered.

## Recovery

Ctrl-C is the preferred abort. If the process died without cleanup, recover on
**the same boot, before a rescan or suspend**:

```bash
pkexec /usr/bin/python3 "$PWD/tools/aspm-experiment.py" restore
```

The boot ID, device IDs, paths and sysfs inodes must match the receipt. After a
reboot or re-enumeration, the tool refuses stale writes. Do not edit the receipt
to bypass that check. Inspect current state instead; retain `active.json` until
recovery is resolved. It deliberately blocks further trials. Archive a stale
receipt manually only after reviewing the state.

SIGKILL, power loss, lockups, forced sleep and hotplug cannot be made safe by
Python `finally`. Durable receipts enable recovery when the same hardware
instances still exist; they do not guarantee it. Do not rely solely on a reboot
as a substitute for verified restoration.

## Tests

```bash
python3 -m unittest discover -s tools/tests -v
```

The 15 ASPM tests use fake sysfs and mocked PCI access; no root or hardware writes.
They cover pairing, scope, capability checks, masked writes/readback, durable
receipts, stale identity/boot refusal, partial failures, restoration, battery and
lighting checks, and sampling. The real sleep inhibitor was tested separately.
