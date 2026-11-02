# Sleep/resume research — MacBookPro13,2 (2026-11-01)

Goal: find **real, evidence-backed fixes** for this machine's broken suspend. Nothing in this document has been applied yet.
Raw sources for this round: `sleep/research-20261101/raw/` (PR bodies, hook scripts, module sources). Earlier research: `sleep/suspend-audit/STOCK-FAILURE-RESEARCH.md`, `sleep/suspend-audit/research/`.

## 1. What our machine actually does (our own evidence)

| Attempt | Mode | Result |
|---|---|---|
| Custom drivers, lid close | deep | Never woke (30 s wait) |
| Custom drivers, lid close | s2idle | Never woke; Touch Bar lit |
| **Stock image** (no custom drivers) | deep | Never woke → custom drivers are not the cause |
| NVMe `d3cold_allowed=0` (meant to be deep; SELinux made it s2idle) | s2idle | **Woke after ~1 min**; Thunderbolt bridges "inaccessible", xHCI "not ready 65535ms", Wi-Fi firmware timeouts until reboot |
| `pm_test=devices` rehearsal | — | Returned, but Wi-Fi firmware dead |
| Unattended idle suspend 11:00 | s2idle | Never woke; Touch Bar lit |

Three independent failure sources are visible: **NVMe** (no wake at all without D3cold off), **Alpine Ridge Thunderbolt** (minute-plus resume stall, USB-C dead), **BCM43602 Wi-Fi** (firmware hung after resume).

## 2. The key finding: our topology is identical to the MacBookPro14,2 that has working S3

| | Our 13,2 | bjhinkle's 14,2 (omarchy PR #11570) |
|---|---|---|
| T1 + Touch Bar, 13", four USB-C, Intel-only GPU | yes | yes |
| Thunderbolt upstream ports / root ports | `03:00.0`/`79:00.0` under `00:1c.4`/`00:1d.0` | same |
| TB xHCIs | `06:00.0`, `7c:00.0` (8086:15d4) | same |
| NVMe | Apple S3X `106b:2003` at `01:00.0` | Apple NVMe at `01:00.0` |
| Wi-Fi | BCM43602 subsystem **106b:0157** | BCM43602 subsystem **106b:0157** |

On the 14,2, real S3 has been used daily since 2026-09 (~100 logged resumes) with:
1. **NVMe `d3cold_allowed=0`** (Omarchy installs this for all 13,x/14,x; origin: Dunedan mbp-2016-linux, which names the **13,2** explicitly; a 13,2 owner confirmed it restored wake, issue #37).
2. **Thunderbolt remove-before-sleep / rescan-after-resume hook** (`thunderbolt-remove-rescan`, PR #11570 head `3aab5a0`). Without it, resume froze **80–104 s** while the PCI core timed out on dead bridges and USB-C died; with it, noirq resume took **12–13 ms**. The exact log signature (`Unable to change power state ... device inaccessible`, `not ready 65535ms after resume`, `tb_resume_noirq` WARNs) is what our 09:22 trial logged.
   Explanation (measured on 14,x): Apple firmware cuts power to the Alpine Ridge controllers in S3 regardless of what Linux asks; the bridges come back broken. Removing the upstream ports before sleep lets a rescan rebuild them cleanly.
   Things **measured as NOT helping** on the 14,2: `d3cold_allowed=0` across the TB tree, `pcie_port_pm=off`, `pcie_ports=compat`, forcing root ports to D0, calling firmware power methods.
3. **Wi-Fi reset around sleep** — unbind `brcmfmac` before sleep, rebind after (omarchy PR #7333). Confirmed on BCM43602 (MacBookPro11,5) in S3: firmware reloads, NetworkManager reconnects. Our earlier "Wi-Fi dead after resume" signature (`brcmf_msgbuf_query_dcmd` timeouts, commonring -12) is exactly what this fixes. The unbind used to risk a kernel oops (P2P teardown race); that is fixed in **7.2.11** (stable backport of `08a3f02fea63`), and we run 7.2.13.

Why **deep (S3), not s2idle**: on sister models s2idle never gets below package C3 and draws **7–13 W** with the lid closed (a bag-heater; one overnight test drained the battery) vs **0.1–0.3 W** in S3. Our own s2idle attempts also hung. The TB hook deliberately does nothing in s2idle.

## 3. Issues specific to OUR setup that the 14,2 recipe doesn't cover

- **Our 5 GHz NVRAM lives only in the initramfs.** After the Wi-Fi unbind/rebind (or any resume-time firmware reload — our devices rehearsal logged `Direct firmware load for brcm/brcmfmac43602-pcie.txt failed with error -2`), the driver can't find it and falls back to 2.4 GHz-only. **Fix:** kernel argument `firmware_class.path=/etc/firmware/macbook-wifi`. The kernel checks that directory first for every firmware request, then falls back to `/usr/lib/firmware`, so only our NVRAM is overridden. Low risk; needs a reboot.
- **5 GHz FEMCTRL bit (subsystem 106b:0157 — ours).** On the 14,2/14,3, S3 power-resets the chip and clears bit 4 of ChipCommon `chipcontrol`; then every 5 GHz join fails (`status_code=16`) while 2.4 GHz works. On the 14,2 this happened on the charger too. Upstream fix is a brcmfmac patch (v2, linux-wireless 2026-10-23, gated to subsystems 0157/0173 — **includes ours**), not yet in any kernel. Interim: a pre-rebind userspace write of that bit (done from a hook on the 14,2), or accept 2.4 GHz after resume until the patch lands. Test first; only act if seen.
- **Our right-side USB-C udev workaround keys on `0000:7c:00.0`.** After a TB rescan the xHCIs come back on **new bus numbers**, so the current rule would stop matching. It needs rewriting to match the Alpine Ridge xHCI by ID (`8086:15d4`), which would also cover the untested left side. (Other owners reached the same pin-awake fix independently: "a USB device plugged into a USB-C port is not detected while the Alpine Ridge xHCIs are runtime-suspended".)
- **Silverblue:** `/usr/lib/systemd/system-sleep/` is read-only, and `/run` sleep drop-ins are blocked by SELinux (we hit this). Hooks must run from an `/etc` drop-in for `systemd-suspend.service` (`ExecStartPre`/`ExecStopPost`, the approach used on a MacBookPro13,3) or a `sleep.target` oneshot like PR #7333's.
- **Touch Bar after resume:** may stay dark/ignore input after S3. Our driver package already contains the two resume fixes others needed (byte-count normalization; T1 reset-resume without a display interface). If still dark, others restore it with the T1 ACPI call `SOCW(1)` after resume (MacBookPro13,3: 59 resumes; 14,2 reports). Our `skip_acpi_power=1` guard stays; any SOCW call would be a separate, opt-in experiment.
- **Audio after resume:** CS8409 Apple driver's suspend callback is a no-op; speakers may be silent after S3 (open upstream PRs #198/#220/#228). A 13,3 setup closes all audio streams before sleep. Check after the first good resume.

## 4. Proposed plan (each step needs your go-ahead)

### Phase 0 — safe prep, no sleep involved
**Status 2026-11-01:** item 1 APPLIED (`/etc/UPower/UPower.conf.d/90-macbook-critical-poweroff.conf`, verified). Item 2 moved into Phase 1 by user decision.
1. **UPower critical action → PowerOff** (`/etc/UPower/UPower.conf`, currently `Auto`). On a 14,2, the critical-battery action triggered an S3 that froze and drained the battery. Removes that risk.
2. **`firmware_class.path=/etc/firmware/macbook-wifi`** via `rpm-ostree kargs`, reboot, confirm 5 GHz still works. Prerequisite for any Wi-Fi reload. Keep the initramfs copy too.

### Phase 1 — the S3 recipe (installed together, then ONE attended test)
3. Switch to deep: replace `90-macbook-s2idle.conf` with `SuspendState=mem` + `MemorySleepMode=deep` (in `/etc`, correctly labelled; verify the kernel logs `suspend entry (deep)`).
4. Persistent NVMe `d3cold_allowed=0` via a udev rule matching `106b:2003` (not a fixed address).
5. Thunderbolt remove/rescan hook — the upstream `3aab5a0` script, unchanged in logic (it finds ports via the NHIs; 3 xHCIs for our four-port model), started from an `/etc` drop-in for `systemd-suspend.service`.
6. Wi-Fi unbind/rebind around sleep (PR #7333 logic; our kernel has the race fix).
7. Rewrite the USB-C pin-awake rule to match `8086:15d4` by ID (both sides; survives rescans).

**Test protocol:** charger connected, **nothing in the USB-C ports except the charger**, work saved, lid open. Set an RTC alarm 90–120 s ahead and `systemctl suspend` (`pm_print_times=1` for timing). Don't touch it for the first 10 s: early wakes strand the TB tree on the 14,2. Success = `PM: suspend entry (deep)` + `suspend exit`, short noirq resume, 3 xHCIs back, Wi-Fi reconnects, keyboard/trackpad/Touch Bar/audio OK. If it hangs: hold power and report; no repeat until the logs are reviewed.

### Phase 2 — only after Phase 1 passes
8. Real lid-close cycles (short and multi-hour), battery drain per hour, Touch Bar/audio/5 GHz after resume. Address only what is observed: FEMCTRL bit, SOCW(1), audio stream closing.
9. Then re-enable automatic idle suspend.

### Phase 3 — optional kernel-level fixes (unmerged upstream; would need a custom-built kernel on Silverblue)
- **ACPICA PR #1235** (open, not merged): fixes misdirected PCI config reads in Apple's Thunderbolt `_PS0`. Measured on 14,1: 6.9 s → 1.8 ms of firmware polling. Shortens resume; on its own it doesn't fix suspend.
- **Francisco Beltrán Millalén's series** (unmerged): PCI/PM v2, an Alpine Ridge "SXFP" quirk that cuts TB power at S3 entry the way macOS does (v1 withdrawn by author, v2 pending), and native PME on Apple, which fixes USB-C hotplug without the pin-awake rule. One 14,3 resumed S3 with TB intact and no hook. Wait for v2.
- **brcmfmac FEMCTRL v2** (covers our subsystem 0157).
Worth revisiting when they reach Fedora's kernel; building our own kernel is possible (same Podman container) but heavy and has to stay in sync with the akmods.

## 5. Not recommended / already ruled out
- s2idle as the "fix" (power draw, our hangs). `mem_sleep_default=s2idle + nvme APST=0 + intel_idle.max_cstate=1` bundle (PR #14409): tested on one 14,1 only, all three together; C1-only raises awake heat permanently.
- `pcie_port_pm=off`, `pcie_ports=compat`, D3cold off across the TB tree: measured not to help on the 14,2.
- `d3cold_allowed=0` on the **Wi-Fi** for real S3: breaks 5 GHz joins until reboot (14,3 report).
- `modprobe -r brcmfmac` (drops cfg80211 and the regdomain): use unbind or `rmmod`.
- Forcing `skip_acpi_power=0`, `acpi_osi` changes, DSDT patches, Apple vendor NVMe commands (S3X LPSR/0xcc research is unimplemented).
- Sleeping with a USB-C device plugged in: Apple firmware can disable that side until a cold boot (14,1/14,2/14,3 reports). Unplug data devices before sleep (the charger is fine).

## 6. Confidence
- High: the NVMe and Thunderbolt mechanisms (exact-model and same-topology evidence, plus matching log signatures here).
- Medium: Wi-Fi reset (same chip, different Mac models; our NVRAM integration adds a step).
- Unknown until tested: Touch Bar, audio and 5 GHz after resume, early self-wakes, standby drain on our battery (673 cycles).
- Several sources are community PRs (some AI-assisted write-ups). Each figure above is a reported measurement from a named machine, not a guarantee for ours.

## Sources
- Dunedan/mbp-2016-linux README "Suspend & Hibernation"; issue #37 (13,2 confirmation, comment 549038942); issue #133 (Apple NVMe LPSR notes).
- omacom/omarchy PR #11570 (TB remove/rescan, head 3aab5a0; full thread archived in `sleep/suspend-audit/research/omacom-omarchy-11570.txt`), PR #7333 (brcmfmac unbind/rebind, head e1f7b31), PR #10758 (14,1 TB shim + s2idle), PR #14409, PR #11624 (NVMe fix scoped to 106b:2003), PR #7589.
- omacom/omarchy-pkgs PR #544 → open-acpica/acpica PR #1235.
- simbilim/omarchy-macbookpro13-3-t1 (13,3 T1: deep S3, NO_D3 module, SOCW module, power measurements).
- linux-wireless FEMCTRL patch v1 (patchwork 20261018193950.14287-1) / v2 (lore 20261023143003.1307752-1); lore/patchwork were not readable from here (bot challenge), so their status comes from the PR thread (last checked 2026-10-31).
