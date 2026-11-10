# Touch Bar idle-blanking update

[Documentation index](README.md) · [Current package set](../packaging/README.md)

Touch Bar **0.1.20261110-1** fixes idle blanking on the T1. It does not change the
working suspend hook or enable ASPM. For the separate power experiment, see
[ASPM results](ASPM-RESULTS.md) and [procedure](ASPM-EXPERIMENT.md).

## Problem and fix

T1 has no separate display-control interface. Our driver's display-control
function deliberately returned success without sending a command, so the idle
worker believed it had blanked the strip when it had not.

[Patch 0003](../packaging/patches/0003-appletb-t1-idle-mode-off.patch) sends
**MODE_OFF** on the T1 off-timeout instead. After a successful command it updates
the cached mode, allowing normal input to schedule the configured Fn mode again.
Non-T1 display handling, held-key checks and disabled-idle settings retain their
existing behavior. The default timeout remains **300 seconds**.

## Validation

- Regression tests compile the actual worker/update functions with mocked
  hardware and time: `python3 packaging/tests/test-touchbar-idle.py`.
- rpmbuild and unprivileged akmodsbuild passed against kernel 7.2.13.
- Staged and post-boot audits reported **0 failures**, including embedded source,
  spec, module fingerprints, initramfs guard/NVRAM and unchanged sleep files.
- The user confirmed idle blanking, input restore, keys and Fn switching.
- Attended deep S3 passed at 18:40:53–18:42:34 on 2026-11-10; all devices worked
  afterward, with TB restored on rescan attempt 1 and Wi-Fi/T1 recovery successful.

No live T1 module reload, USB rebind or SOCW experiment was used for acceptance.
Published build audit: [staged audit](../packaging/logs/audit-touchbar-0.1.20261110.log).
Post-boot/S3 raw logs are local-only under `tools/logs/`.

## Provenance

Ported from [mikeypdev/macbook-t1-suspend](https://github.com/mikeypdev/macbook-t1-suspend/blob/ef2148bcd94e1a5b82c86a1a7905f03b195b801b/apple-ib-t1-idle-off.patch),
reviewed at `ef2148b` (idle fix originally `4414905`). That Arch setup ports this
project's earlier Fedora recipe to the same MacBook model. Its Thunderbolt
helper and CS8409 resume-fix header matched ours; those were not new fixes.

We did not import its Wi-Fi watchdog, extra wake masks, codec profile switching
or TLP preferences. Its NetworkManager enum advice was also incorrect:
`wifi.powersave` is **0=default, 1=ignore, 2=disable, 3=enable**. This follow-up
keeps the existing working Wi-Fi and wake policy.
