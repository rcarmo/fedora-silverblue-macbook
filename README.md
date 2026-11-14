# Fedora Silverblue on a 2016 MacBook Pro with Touch Bar

Drivers, configuration and reproducible notes for **MacBookPro13,2**: the
13-inch, four-port 2016 MacBook Pro with an **Apple T1**, not a T2.

The reference machine runs Fedora Silverblue 44 with kernel **7.2.13**. Touch Bar,
speakers, dual-band Wi-Fi and deep suspend work with the included setup.

> **Experimental; tested on one machine.** Read the [safety rules](docs/KNOWN-ISSUES.md)
> and [kernel compatibility check](docs/CLEAN-INSTALL.md) before installing.
> The audio package is restricted to **7.2.x**; this is not a recipe for arbitrary
> current Fedora kernels. Other MacBook models are not validated by this project.

## Start here

| I want to… | Read |
|---|---|
| Install the working setup | [Installation guide](docs/CLEAN-INSTALL.md) |
| Check support and limitations | [Known issues and safety](docs/KNOWN-ISSUES.md) |
| Understand suspend/resume | [Sleep guide](docs/SLEEP.md) |
| Control LG UltraFine brightness in GNOME | [Quick Settings extension + CLI](docs/LG-BRIGHTNESS.md) |
| See the latest verified state | [Current status](PROGRESS.md) |
| Investigate awake battery draw | [ASPM results](docs/ASPM-RESULTS.md), then the [experimental procedure](docs/ASPM-EXPERIMENT.md) |
| Rebuild the drivers | [Packaging guide](packaging/README.md) |
| Browse the evidence and history | [Documentation index](docs/README.md) |

## Hardware status

Last verified **2026-11-10** on the reference machine:

| Area | Status | Notes |
|---|---|---|
| Keyboard / trackpad | Working | Stock `applespi`; intermittent phantom-click reports remain unresolved |
| Touch Bar | Working | Local driver; idle blanking, input restore, keys, Fn and S3 checked |
| Speakers / microphone | Working | Local CS8409 driver; microphone is quiet; headphone jack untested |
| Wi-Fi | Working, 2.4 + 5 GHz | Board NVRAM required; no WPA3-Personal |
| Deep suspend (S3) | Working | Devices restored after resume; occasional early wake remains possible |
| USB-C / Thunderbolt | Partially validated | Right/front USB-C tested; LG UltraFine image + USB brightness checked Nov 14; P20 unresolved, docks/general display support not established |
| Camera | Working in Firefox | GNOME Camera crashes on this install |
| Bluetooth | Pairing untested | Controller detected |
| Touch ID | Unsupported | |

The [rebuild kit](rebuild-kit/README.md) contains the driver RPMs and the working
configuration. Follow the [installation guide](docs/CLEAN-INSTALL.md) in order;
its kernel check and recovery preparation are part of the procedure.

## Power: working sleep, experimental awake savings

- **S3 standby:** an overnight estimate was about **0.45 W** on this machine,
  conditional on the charger being unplugged at lid close. It is not a guaranteed
  standby figure. See the [sleep guide](docs/SLEEP.md).
- **Awake ASPM:** a short reversible Thunderbolt L1 trial showed approximately
  **1.6 W less draw**. Original settings were restored. Longer testing, hotplug
  and S3 with L1 enabled are still pending. **ASPM is not enabled by the installer.**

Do not confuse the awake-power experiment with the validated suspend recipe.

## Repository contents

- [`rebuild-kit/`](rebuild-kit/README.md) — installable configuration, local RPMs and checksums.
- [`packaging/`](packaging/README.md) — driver sources, patches, specs and build instructions.
- [`tools/`](docs/FILE-MAP.md) — consistency audit, attended S3 test and opt-in ASPM diagnostics.
- [`extensions/`](extensions/) — optional GNOME Shell 50 LG brightness slider; [installation](docs/LG-BRIGHTNESS.md).
- [`docs/`](docs/README.md) — current guides, experiment results and historical references.
- `sleep/`, `wifi/`, `audio/`, `touchbar/` — detailed investigations, not alternative install guides.

The public export omits recordings, full journals, raw downloads and other
machine-specific evidence. Some notes name local evidence that is not published;
those paths are explicitly identified as local where relevant.

## Credits and licensing

Built on [AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar),
[davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro),
[BCM43602 NVRAM research](https://bugzilla.kernel.org/show_bug.cgi?id=193121),
[omarchy's Thunderbolt suspend work](https://github.com/omacom/omarchy/pull/11570),
[simbilim's T1 work](https://github.com/simbilim/omarchy-macbookpro13-3-t1), and
[mikeypdev's T1 idle/power follow-up](https://github.com/mikeypdev/macbook-t1-suspend).

Original scripts and documentation: MIT. Driver sources and RPMs: GPL-2.0;
upstream notices are retained. See [LICENSE](LICENSE) for the licensing overview
and the individual driver source trees for their licences.
