# Local T1 Touch Bar akmod

Upstream: AJ-dev-i60/t1-touchbar, commit 20d65c7b0fe6d05ea9734f869b27384a62de5109, apple-ib-drv directory, GPL-2.0.
Local changes: normalize successful USB command byte count to zero for worker state tracking; allow T1 reset-resume without a separate display HID.
Native applespi is not replaced. No firmware provisioning, USB configuration rewrite, global HID blacklist, or live rebind service is installed.

Explicit skip_acpi_power=1 is required. Never set it to zero: the T1 SOCW ACPI call can freeze the system. Modules are force-included/loaded in locally regenerated initramfs so they can claim the HID before generic drivers; camera UVC interfaces are not claimed by this driver.

Recovery: select pinned original deployment. For temporary boot debugging, add BOTH rd.driver.blacklist=apple_ibridge,apple_touchbar and modprobe.blacklist=apple_ibridge,apple_touchbar. An experimental driver can still hang hardware; save work before reboot/suspend tests.
