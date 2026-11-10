# Local T1 Touch Bar akmod

Upstream: AJ-dev-i60/t1-touchbar, commit 20d65c7b0fe6d05ea9734f869b27384a62de5109, apple-ib-drv directory, GPL-2.0.
Local changes: normalize successful USB command byte count to zero for worker state tracking; allow T1 reset-resume without a separate display HID; (0.1.20261101) reset-resume invalidates the cached mode/disp so the bar mode is actually re-sent after S3.
Native applespi is not replaced. No firmware provisioning, USB configuration rewrite, global HID blacklist, or live rebind service is installed.

Explicit skip_acpi_power=1 is required. Never set it to zero: the T1 SOCW ACPI call can freeze the system. Modules are force-included/loaded in locally regenerated initramfs so they can claim the HID before generic drivers; camera UVC interfaces are not claimed by this driver.

Recovery: select pinned original deployment. For temporary boot debugging, add BOTH rd.driver.blacklist=apple_ibridge,apple_touchbar and modprobe.blacklist=apple_ibridge,apple_touchbar. An experimental driver can still hang hardware; save work before reboot/suspend tests.

## 0.1.20261110 additions
- T1 idle timeout blanks the strip with MODE_OFF instead of the no-op display
  command. Successful commands update cur_tb_mode so normal input restores the
  configured Fn mode. Non-T1 display handling and suspend hooks are unchanged.
- Ported from mikeypdev/macbook-t1-suspend apple-ib-t1-idle-off.patch, reviewed at
  ef2148bcd94e1a5b82c86a1a7905f03b195b801b (original idle fix: 4414905).
  https://github.com/mikeypdev/macbook-t1-suspend/blob/ef2148bcd94e1a5b82c86a1a7905f03b195b801b/apple-ib-t1-idle-off.patch
  That project ports this driver's earlier Fedora fixes back to Arch.
- Default idle timeout remains 300 seconds; no TLP, ASPM, wake masks, Wi-Fi
  watchdog, or SOCW policy changes are bundled with this driver update.

## 0.1.20261101 additions
- apple-touchbar.c: reset-resume invalidates cached mode/disp (patch ../../0001-appletb-reset-resume-invalidate-cached-mode.patch).
- macbook_t1_socw.c: separate module, adapted from simbilim/omarchy-macbookpro13-3-t1 (GPL-2.0; copy in
  sleep-research-20261101/raw/simbilim/). DMI 13,2/13,3; evaluates ASOC.SOCW(0|1) ONLY when written to its
  `socw` parameter (sleep hook: 0 before S3, 1 after); nothing at load; auto_resume opt-in. Not auto-loaded.
  apple_ibridge keeps skip_acpi_power=1 (no SOCW at probe).
