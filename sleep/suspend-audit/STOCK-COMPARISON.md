# Prepared stock-deployment suspend comparison — 2026-11-01

User approved preparing this comparison. No reboot or suspend has been initiated.

## Boot menu preparation
- Current recovery is still `c4ebdd857316f64e6b97b3c29f64993fef8ebe82824484091bc4d848b2ae39bc.0`, index 0, kernel 7.2.13. rpm-ostree idle, no staged deployment at preparation.
- Exact stock entry `/boot/loader/entries/ostree-2.conf` resolves through its `ostree=` boot-root link to `f1365bcef08f98f305177529b4132dbef7c2a4d4ad1fc38de9b24fc85c306517.0`, currently index 3.
- Its title is **Fedora Linux 44.20261031.0 (Silverblue) (ostree:3)** and its kernel is **7.2.13-200.fc44.x86_64**.
- Read-only stock modinfo selects the stock `kernel/sound/hda/codecs/cirrus/snd-hda-codec-cs8409.ko.xz`; apple_ibridge is absent. Stock has no local sleep.conf or sleep.conf.d directory. Do not assume it will use s2idle without explicitly selecting it after boot.
- Actual bootupd-generated GRUB config archived in `grub-before-stock-test.cfg`. It explicitly supports `menu_show_once_timeout` and consumes/unsets this variable when displaying the menu. EFI stub hands off to `/boot/grub2/grub.cfg`. `/boot` is an ext4 NVMe partition.
- Applied ONLY `pkexec /usr/bin/grub2-editenv /boot/grub2/grubenv set menu_show_once_timeout=60` and verified the environment lists `boot_success=1` and `menu_show_once_timeout=60`. No saved_entry/next_entry/default or OSTree ordering changes. This makes the menu visible for 60 seconds on the next boot; **it does NOT automatically select stock**. No assumption that grub2-reboot's next_entry works with this bootloader configuration.
- Battery was 60%, discharging. Connect charger before testing.

## User boot procedure
1. Save all work, connect power, unplug headphones. Keep lid open.
2. Restart when ready; this ends the current session.
3. In the GRUB menu, choose the exact title ending **(ostree:3)**, not by kernel/version alone (four entries share those). Press Enter.
4. **Do not choose (ostree:1): it is the failed Wi-Fi trial.** If the expected title is missing or uncertain, choose recovery **(ostree:0)** rather than guessing. Entry identities/order can change after deployment operations; these instructions are valid only for the verified current layout.
5. Stock audio and Touch Bar will likely not function. That is expected during the temporary comparison, not an instruction to reinstall/uninstall anything.
6. After login, keep lid open and promptly resume the assistant with: “Read PROGRESS.md; I booted (ostree:3) for the stock suspend comparison.” **Do not suspend/close the lid yet.** User GNOME settings persist and automatically suspend after 15 minutes on AC and battery unless explicitly contained; no containment has been applied.

## Assistant after-stock audit and test plan
- Recheck rpm-ostree status/transaction and exact booted checksum, kernel, codec path and absence of custom Touch Bar modules. Check Wi-Fi/link, power and current `mem_sleep`/merged sleep config. Do not reinstall drivers or run upgrade/rollback on stock as part of this test.
- Do not blindly compare stock deep with the failed custom s2idle trial. For a same-mode comparison, prepare the same s2idle selection explicitly after stock boot (reversible drop-in with approval or a reviewed one-test method). Explain any test configuration change and verify the log actually says s2idle.
- Ask for saved work/user readiness immediately before any suspend. A PM callback-only diagnostic may be preferable before another real sleep but can still hang; no PM test has yet been armed or run.
- Use one controlled attempt with user present; preserve the exact boot-ID logs either way. Require recorded suspend entry AND exit plus responsive display/input and devices for success; lit Touch Bar alone is insufficient.
- If stock same-mode works, return to recovery and isolate custom drivers one at a time at boot. If stock also fails, investigate stock drivers/platform/kernel and consider the original pinned kernel in a separate test. A stock result is a deployment comparison, not proof of an individual culprit.
- Return to recovery **(ostree:0)** with boot menu verification/readiness. Manual stock selection did not reorder OSTree deployments. Check GRUB environment/default behavior after boot rather than promising automatic return. If needed, re-arm only the one-time menu visibility on stock before the return restart.

## Cancel menu visibility before reboot
With graphical admin approval:
```
pkexec /usr/bin/grub2-editenv /boot/grub2/grubenv unset menu_show_once_timeout
```
This only removes the next-boot 60-second menu wait; it does not undo any deployment or sleep configuration.

## Current verified entry mapping
| Menu suffix | BLS ID | Deployment | Meaning |
| --- | --- | --- | --- |
| ostree:0 | ostree-5 | c4ebdd8 | Recovery, current default/booted |
| ostree:1 | ostree-4 | b0a3115 | FAILED Wi-Fi trial — avoid |
| ostree:2 | ostree-3 | 43e45ec | Pinned pre-Wi-Fi custom driver baseline |
| ostree:3 | ostree-2 | f1365bc | Pinned stock updated — comparison target |
| ostree:4 | ostree-1 | b8e75b7 | Pinned original, kernel 6.19.10 |

Deployment receipt: `before-stock-comparison-deployments.json`.
