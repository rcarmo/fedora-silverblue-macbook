# Known issues and safety

[Documentation index](README.md) · [Current status](../PROGRESS.md)

Last reviewed **2026-11-10**. These observations come from one MacBookPro13,2.
The [front page](../README.md) summarises hardware coverage; this page explains
its limits and the rules that prevent known failures.

## Read before installing or experimenting

| Do not… | Why / safer approach |
|---|---|
| Set `apple_ibridge skip_acpi_power=0` or call `SOCW(1)` at probe | Can hard-freeze T1 Macs. Keep the guard; only the sleep hook sends SOCW messages. |
| Live-unbind/rebind the iBridge/T1 | Can wedge the Touch Bar. Use its existing `idle_timeout` mode-refresh path, not a USB reset experiment. |
| Rebind the HDA controller (`00:1f.3`) or reload `snd_hda_codec_cs8409` after sleep | S3 resets the codec subsystem ID; the Apple path can be lost until reboot. |
| Play audio directly to `hw:0,0` / `plughw:0,0` | No hardware volume protection; potentially very loud. Use PipeWire at low software volume. |
| Treat this audio package as kernel-independent | It only builds for **7.2.x**. Port/test or remove it before a 7.3+ deployment. |
| Copy blanket PCI/D3cold hooks or force ASPM globally | Device capability alone does not establish safety. Keep experiments separate from installation. |

## Working, with caveats

### Sleep and battery

Deep S3 works with the included hooks; the post-update attended test passed.
See the [sleep guide](SLEEP.md) for normal behavior and testing.

- Suspending with the **lid open** disables lid wake for that sleep. Wake with
  keyboard/trackpad or the power button, not lid movement.
- An occasional early wake with the **lid closed** remains possible. One
  overnight case recovered through logind re-suspending. **Check that the machine
  stays asleep before putting it in a bag**, or shut it down.
- A lit Touch Bar does not prove the host is awake: the T1 is a separate computer.
- Overnight standby was estimated at ~0.45 W, conditional on unplug timing.
  This supersedes an earlier coarse 35-minute drain estimate; it is not a guarantee.
- The worn reference battery's `capacity` percentage disagrees with other
  readings. Use charge/energy telemetry and UPower; allow margin for gauge jumps.

### Input, audio and camera

- Trackpad phantom clicks / libinput “Touch jump” reports remain unresolved.
  Tap-to-click was disabled for isolation, not established as a fix.
- Internal microphone works but is quiet. Headphone output is untested.
- Camera works in Firefox; GNOME Camera crashes on this installation.
- Touch Bar idle blanking, input restore, keys, Fn switching and post-S3 operation
  are verified with 0.1.20261110. [Patch details](T1-IDLE-AND-ASPM.md).

### Networking and external devices

- BCM43602 Wi-Fi works on both bands with NVRAM, but firmware lacks the SAE
  support needed for WPA3-Personal. Do not force capabilities or disable PMF
  as a supposed WPA3 fix.
- Bluetooth controller is detected; pairing is untested. A missing BCM.hcd
  message is not a reason to copy arbitrary firmware.
- Right/front USB-C has been tested. Left-side ports, docks and general
  Thunderbolt/external-display behavior are not generally validated. A Nov 14
  LG UltraFine image/USB-brightness check succeeded after writing brightness;
  the Kuycon P20 remains unresolved. See [LG brightness](LG-BRIGHTNESS.md) for
  exact scope; this is not a general display support claim.
- Touch ID is unsupported.

## Installation and maintenance traps

- Wi-Fi initramfs generation must include **`brcmfmac-wcc`**. Omitting it caused
  Wi-Fi to disappear in the first trial.
- Keep `firmware_class.path=/etc/firmware/macbook-wifi` so runtime firmware/NVRAM
  requests after Wi-Fi rebind can find the same data used at boot.
- Inspect `rpm-ostree status` and deployment order before changing defaults.
  With pinned deployments, do not blindly toggle `rpm-ostree rollback`;
  use an explicitly reviewed bootloader choice or deployment index.
- Wait for long rpm-ostree transactions; a client timeout does not prove failure.
- `/run` sleep overrides were blocked by SELinux in an earlier test, silently
  leaving s2idle selected. Use the installed `/etc` configuration and verify
  **`PM: suspend entry (deep)`** in the kernel journal.
- Optional modules under `/usr/local` need SELinux `modules_object_t` labels.
  The current SOCW module comes from the akmod instead.
- Build with the **canonical spec filename**: kmodtool can otherwise embed an
  older SRPM. See [packaging](../packaging/README.md).
- A composefs `systemd-remount-fs` failure can be expected on this Silverblue
  installation; do not make `/usr` writable to “fix” driver installation.

## ASPM is still experimental

The short trial reduced awake draw by ~1.6 W and restored the original settings.
It did **not** validate hotplug or S3 with L1 enabled. No persistent ASPM helper
is installed. Start with the [results and limitations](ASPM-RESULTS.md), not a
community boot service or `pcie_aspm=force` command.
