# Manual Wi-Fi trial recovery (Fedora Silverblue)

**Current status (2026-11-01): a NEW corrected-integration trial39e497f.0 is staged and independently verified, not yet booted.** It explicitly includes the previously missing brcmfmac-wcc helper. Current working c4ebdd8 recovery is booted/pinned; old failed b0a3115 remains retained. See **PROGRESS.md** and **wifi-trial-v2/README.md** for exact state and expected next boot menu (new trial:0, working recovery:1, OLD FAILED:2—avoid). All three scoped trial files are installed again for the new candidate; original recovery state/baseline/backups remain intact with a separate v2 receipt. **Do not blindly rollback or rerun either installer.** If manually booting a fallback leaves booted-not-first, review exact deployment/default state before using make restore; the script deliberately refuses that condition. No reboot or live reload performed.

**Recovery is for the explicitly scoped Wi-Fi trial described below; check `PROGRESS.md` for current staging/boot status.** This is a scoped recovery tool, not a universal repair tool. It restores the pre-trial **stock Wi-Fi firmware/configuration** (currently working 2.4 GHz), not macOS behavior or a general system rollback. Audio, Touch Bar, user packages and volume settings are left alone.

## Simple commands

From a terminal on the Mac:

```sh
cd /var/home/me/macbook-fedora-audit
make recovery-plan   # read-only: inspect scope
make check           # read-only: syntax and plan checks
make arm-wifi        # BEFORE installing the trial; admin authentication
# ... future trial installed separately, using the exact paths below ...
make restore         # if the trial fails, after booting a usable deployment
```

`make restore` is the manual recovery command. It needs no network connection. By default it uses sudo's local password prompt; never send a password in chat. In a normal desktop session you can instead use:

```sh
make arm-wifi ADMIN=pkexec
make restore ADMIN=pkexec
```

Root shell: `make restore ADMIN=`. Without make: `sudo /usr/bin/bash /var/home/me/macbook-fedora-audit/wifi/recover-wifi.sh --recover`.

**Arming is mandatory before a future trial.** It records an empty baseline and the current deployments in root-owned `/var/lib/macbook-wifi-recovery`. It refuses existing files at the managed paths. It does not install firmware. If recovery state already exists, stop and review it; do not delete/re-arm blindly after a failed trial.

## Exact future-trial contract

The future installer MUST restrict changes to these dedicated paths:

- `/etc/firmware/macbook-wifi/brcm/brcmfmac43602-pcie.txt`
- `/etc/modprobe.d/99-macbook-wifi-nvram.conf`
- `/etc/dracut.conf.d/99-macbook-wifi-nvram.conf`

Actual trial integration: the dedicated modprobe file contains comments ONLY (no alternative_fw_path). The dracut file forces early loading of brcmfmac and maps the dedicated /etc NVRAM file to `/usr/lib/firmware/brcm/brcmfmac43602-pcie.txt` ONLY INSIDE the generated initramfs. Generic host /usr firmware stays untouched. Recovery explicitly removes both `/usr/lib/firmware/brcm/brcmfmac43602-pcie.txt` and its `/lib` spelling from the rebuilt initramfs. Do not install to these generic locations on the HOST, add other firmware paths, or change kernel arguments/other configuration. Otherwise this recovery script is insufficient.

This is an early-boot-only experimental trial. A later live module unload/reload would not find the NVRAM in the host's normal firmware search path. Do not reload brcmfmac live. Suspend/reset behavior is not established; reliable long-term firmware packaging remains a separate follow-up after a successful reboot test.

## What restoration does

1. Checks model, normal OSTree boot, root privileges, safe file paths, and deployment state. Refuses a running transaction or a non-booted deployment first in the list; review `rpm-ostree status` before proceeding.
2. Requires the root-owned arming record. Backs up all present managed files before deleting any; rejects symlinks and non-root-owned/non-regular trial files.
3. Removes only those three files, retaining backups under `/var/lib/macbook-wifi-recovery/recovery-*`. Does not recursively delete directories or touch generic firmware.
4. Uses `rpm-ostree initramfs --enable`, preserving existing dracut arguments and adding `--remove` for the dedicated trial paths and the standard NVRAM paths INSIDE the initramfs. This stages a recovery deployment while keeping local generation required by the working audio/Touch Bar setup. No /usr remount or direct dracut overwrite.
5. Prints status and saves composition logs. **Never reloads Wi-Fi or reboots automatically.** The running radio keeps its loaded firmware until reboot.

If composition fails, backups remain and trial files stay removed. Do not assume the boot image is repaired. Resolve the error, inspect status, and retry when idle. A transaction still completing after an interrupted terminal must be allowed to finish before another attempt.

## Before manually rebooting

Save work and connect power. Inspect `make status` and the new staged image with `lsinitrd` (using graphical/admin approval if necessary). Verify it excludes `/etc/firmware/macbook-wifi`, the dedicated trial configuration, and `brcm/brcmfmac43602-pcie.txt` under both `/usr/lib/firmware` and `/lib/firmware`, and still contains the working audio/Touch Bar modules with `skip_acpi_power=1`. Then reboot manually only when ready; boot the new recovery deployment. Recheck `iw phy` and connectivity.

The script stages recovery; it does NOT prove recovery succeeded just because composition returned success. Existing dracut arguments/configuration outside its scope may require review. It does not rewrite other deployment boot images, and OSTree rollback does not necessarily undo shared configuration.

## If the trial boot hangs or you cannot log in

Use the bootloader to select the retained stock Fedora 44.20261031.0 / kernel 7.2.13, or pinned original Fedora 44.1.7 / kernel 6.19.10. That fallback must be checked/preserved BEFORE installing a trial; arming alone does not pin it. Avoid composing the trial into the fallback's boot image. A desktop from the fallback can provide access to this script and backups; audio/Touch Bar may be absent on stock images.

As an additional emergency boot-menu workaround, append BOTH:

```text
rd.driver.blacklist=brcmfmac modprobe.blacklist=brcmfmac
```

This disables Wi-Fi for that boot rather than fixing it, and is not guaranteed to solve every boot failure. Once normally booted, use `make restore` and review the resulting deployment. Do not change Touch Bar ACPI guards.

This script intentionally does not operate inside a live-USB rescue chroot. If no retained deployment can boot, stop for a separate OSTree-aware rescue procedure instead of running generic dracut or making /usr writable.

## Validation performed

`make check`, `make recovery-plan`, and `make -n restore` are safe checks. Sandbox tests with mocked rpm-ostree passed for arming, missing-state refusal, busy transactions, symlink refusal, backup/removal, unrelated-file preservation, dracut argument preservation/addition and retry. Root arming has now completed on the host before the user-authorized trial installation. Trial boot-image composition and read-only image/fallback verification succeeded; see `PROGRESS.md` and `wifi/trial-v1/boot-verification.log`. After the user reported failure and a revert, read-only host inspection confirmed that the dedicated files are absent and a recovery deployment with explicit initramfs removal arguments is booted. Its image contents were not independently extracted in the follow-up session. The user confirms the trial caused no Wi-Fi at all; the specific driver/scan/connection failure and recovery commands used have not yet been established. Do not repeat staging or reboot into the failed trial.
