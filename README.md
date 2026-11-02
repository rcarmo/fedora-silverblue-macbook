# Fedora Silverblue on a 2016 MacBook Pro with Touch Bar

Everything needed to get a **MacBook Pro 13" 2016 with Touch Bar** (`MacBookPro13,2`, Apple T1 chip)
fully working on **Fedora Silverblue 44** (kernel 7.2), including **suspend/resume**.

> ⚠️ Experimental and tested on one machine. Read [Known issues and safety rules](docs/KNOWN-ISSUES.md)
> before installing anything. Some parts also apply to the 15" `MacBookPro13,3`.

## What works

| Hardware | Status | How |
|---|---|---|
| Keyboard, trackpad | ✅ | Stock Fedora (`applespi`) |
| Touch Bar | ✅ | Local driver package (T1 driver, with resume fixes) |
| Speakers, microphone | ✅ | Local driver package (Apple CS8409 audio, ported to kernel 7.2) |
| Wi-Fi 2.4 + 5 GHz | ✅ | Board calibration file (NVRAM) for the BCM43602; no WPA3 |
| USB-C / Thunderbolt | ✅ | Keeps the USB-C controllers awake so plugged-in devices are detected |
| Sleep (S3) | ✅ | Suspend hook + driver fixes; everything comes back after resume |
| Camera | ✅ | Works in Firefox (e.g. video calls); the GNOME Camera app crashes |
| Headphone jack, Bluetooth pairing, docks | ❔ | Untested |

## Install

Everything you need is in [`rebuild-kit/`](rebuild-kit/README.md); the full walkthrough is
[docs/CLEAN-INSTALL.md](docs/CLEAN-INSTALL.md). In short, on a fresh Fedora Silverblue 44:

```sh
git clone https://github.com/rcarmo/fedora-silverblue-macbook && cd fedora-silverblue-macbook/rebuild-kit
pkexec bash "$PWD/install-files.sh"                       # config files and sleep hook (do this first)
rpm-ostree install akmods kernel-devel-matched ./rpms/*.rpm
rpm-ostree kargs --append=firmware_class.path=/etc/firmware/macbook-wifi
rpm-ostree initramfs --enable --arg=--force
systemctl reboot
```

Afterwards, `pkexec bash tools/audit.sh` checks that everything is installed and consistent.

**Kernel versions:** the audio driver only builds for kernel **7.2.x** and must be ported before a 7.3
upgrade (see [packaging/README.md](packaging/README.md)).

## How sleep was fixed

Getting reliable S3 sleep took most of the work. The causes, in short:

- **Thunderbolt/USB-C** lost power in S3 and never came back → the controllers are removed before sleep
  and rescanned after.
- **Touch Bar** stayed dark after resume → the T1 chip must be told "host is going to sleep" / "host is
  awake" through an ACPI call (`SOCW`); a small kernel module does this from the suspend hook.
- **Speakers** were silent after resume → the audio driver never re-initialised the amplifiers; patched.
- **Instant wake-ups** after 3 seconds → suspending with the lid open armed the lid's wake line, which fired
  immediately; the hook now disables lid wake in that case (wake with a key or the power button).

Measured standby drain: about 0.45 W, roughly 1.2 % of the battery per hour.
Details, evidence and the test record: [docs/SLEEP.md](docs/SLEEP.md).

## Repository layout

| Path | Contents |
|---|---|
| [`rebuild-kit/`](rebuild-kit/) | Exact copy of the working setup: config files, hooks, driver RPMs, installer |
| [`docs/`](docs/) | Install guide, known issues, sleep design, timeline |
| [`packaging/`](packaging/) | Driver sources, patches and RPM specs (to rebuild for a new kernel) |
| [`tools/`](tools/) | `audit.sh` (consistency check), `run-s3-test.sh` (sleep test) |
| `sleep/`, `wifi/`, `audio/`, `touchbar/` | Investigation notes, test results and earlier attempts |
| [`PROGRESS.md`](PROGRESS.md), [`docs/TIMELINE.md`](docs/TIMELINE.md) | The original working log |

See [docs/FILE-MAP.md](docs/FILE-MAP.md) for the full map.

## Notes

- **Never** set `apple_ibridge skip_acpi_power=0`. It can hard-freeze T1 Macs.
- Scripts expect to be run from a checkout of this repository, via `pkexec`.
- Logs were sanitised before publication: addresses, network and device names were redacted, and full
  system journals, raw web downloads, ACPI table dumps and old binaries were removed
  (list in [`.excluded-files.txt`](.excluded-files.txt)).

## Credits and licence

Built on [AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar),
[davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro),
the Wi-Fi NVRAM from [kernel bug 193121](https://bugzilla.kernel.org/show_bug.cgi?id=193121),
the Thunderbolt sleep logic from omarchy PR #11570, and the MacBookPro13,3 work in
simbilim/omarchy-macbookpro13-3-t1.

Original scripts and docs: MIT. Driver sources and RPMs: GPL-2.0. See [LICENSE](LICENSE).
