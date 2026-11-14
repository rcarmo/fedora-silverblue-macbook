# LG UltraFine brightness control

[Documentation index](README.md) · [Rebuild kit](../rebuild-kit/README.md)

## Tested scope and outcome

Tested **2026-11-14** on the reference MacBookPro13,2, Fedora Silverblue 44,
kernel 7.2.13, GNOME Wayland, with an LG UltraFine identifying as a **22-inch,
4096×2304** display. Its USB Controls device is **043e:9a40**, interface **01**.
Other LG models, the Kuycon P20, docks and general external-display support are
not established by this test. The tool deliberately rejects different HID
report descriptors even if they share the USB product ID.

The LG was detected on DP-2, enabled in GNOME, and reported a good DisplayPort
link and power-on state, but showed no image. A temporary native-resolution
test was restored. Writing **50% brightness** over USB HID, with confirmed
readback, was followed by the user's confirmation that the LG worked.
The preceding brightness readback was approximately **78%**, not zero. This
suggests a monitor brightness/backlight-state issue, but does not establish a
zero-brightness fault or a universal workaround. There was also an enumeration
failure on another device behind the LG's USB hub; it is not proven causal.

The earlier P20 connection supplied laptop charging but did not yield display
detection in the captured checks. Its failure remains unresolved.

## GNOME Quick Settings extension (Shell 50)

The main desktop interface is a separate **LG Brightness** slider in Quick
Settings. It does not replace GNOME's laptop brightness control. The optional
standalone GTK4 slider and CLI remain available as fallbacks.

Install the backend/permission rule first if not already present, then install
this extension **as your desktop user**, without sudo:

```bash
# First installation only; omit if the backend is already installed:
pkexec /usr/bin/bash "$PWD/tools/install-lg-brightness.sh"
# Per-user extension installation:
bash tools/install-lg-brightness-extension.sh
```

The extension source is
[`extensions/lg-brightness@macbook-fedora-audit/`](../extensions/lg-brightness@macbook-fedora-audit/).
The user installer packages all runtime modules and installs them under
`${XDG_DATA_HOME:-~/.local/share}/gnome-shell/extensions/`. It appends only this
extension's UUID to enabled extensions and removes only that UUID from the
disabled list; it preserves other extensions and does not globally enable user
extensions if you have switched them off. Prior installations are backed up
under `${XDG_STATE_HOME:-~/.local/state}/lg-brightness/`.

**On Wayland, log out and back in after first installation or JavaScript
updates.** The installer does not restart Shell or end your session. Shell can
cache extension modules until the next session. Once loaded, open Quick Settings
at the top right: the full-width LG row shows its percentage. It is hidden when
no supported monitor is accessible. Multiple matching LGs are intentionally not
chosen implicitly; use the CLI's explicit device selection instead.

The extension uses asynchronous, time-limited subprocess calls to the existing
backend. It coalesces slider writes with a 200 ms debounce and serializes backend
operations. Loading, opening the menu and updating the slider from readback do
not write brightness. Display reconfiguration drops queued writes and retries
read-only discovery after HID/ACL setup. Opening Quick Settings refreshes the
value, and polling runs every five seconds **only while that menu is open**.
Disabling the extension removes its UI/signals/timers and terminates any active
command. No brightness reset, extra root access, daemon, laptop-slider override
or keyboard shortcut is installed.

Errors reading the monitor hide the row and are logged once per distinct state
(except expected absence). Failed writes also show a GNOME notification. Check:

```bash
gnome-extensions info lg-brightness@macbook-fedora-audit
journalctl --user -b --no-pager | grep -F 'LG Brightness'
lg-brightness get
```

This targets **GNOME Shell 50 only**; private Shell APIs can change between
releases. The controller/async backend and package contents are tested with GJS;
live panel rendering, drag/keyboard input, disable/re-enable and reconnect still
need attended acceptance after login. Do not equate packaging tests with a
completed desktop UI acceptance test.

## Install the backend on an existing system

From the repository root:

```bash
pkexec /usr/bin/bash "$PWD/tools/install-lg-brightness.sh"
lg-brightness get
lg-brightness set 50
lg-brightness gui
```

The installer checks the rebuild-kit hashes, backs up replaced files under
`/var/lib/macbook-lg-brightness-*`, and installs only:

- `/usr/local/bin/lg-brightness` — Python CLI and optional GTK4 slider.
- `/etc/udev/rules.d/70-lg-ultrafine-brightness.rules` — active-seat access to
  this USB product's brightness interface only.
- `/usr/local/share/applications/lg-brightness.desktop` — **LG Brightness** in
  the application launcher.

It reloads udev rules and reapplies events to the LG HID nodes without a USB
reset. If permission is still denied, reconnect the monitor while logged into
the local desktop. No sudo is needed for subsequent brightness operations.
No world-writable device, blanket HID access, privileged daemon, auto-reset,
GNOME keybinding changes, or boot/resume brightness override is installed.
The full rebuild-kit installer also includes these three files; reconnect the
monitor after that installer to apply the new access rule.

The command needs only system Python 3 and Linux hidraw. The slider additionally
needs Python GObject bindings and GTK4 (available on the tested host). On a
minimal Silverblue deployment these may need layering as `python3-gobject` and
`gtk4`; the CLI does not require either. Run the GUI as the desktop user, not root.

## Daily use

```bash
lg-brightness             # read percentage, without changing it
lg-brightness set 50      # set and verify readback
lg-brightness up          # increase by 5 percentage points
lg-brightness down 10     # decrease by 10, clamped to 0..100
lg-brightness gui         # slider; opening it does not change brightness
lg-brightness list        # list supported brightness interfaces
lg-brightness --device /dev/hidraw2 get   # select explicitly if multiple LGs
```

HID device numbers are **not stable** across reconnect/reboot. Normally omit
`--device`; the tool discovers by USB HID identity and exact report descriptor.
With multiple matching monitors it refuses to choose implicitly. Reopen the
slider after unplug/replug rather than assuming an old device number is valid.
Zero brightness may make the panel appear off; use `set 50` to recover.
Hardware hotplug and suspend/resume behavior still need attended validation.
The extension rediscovers on display changes/menu open; the standalone GTK app
should be reopened after reconnect.

For optional GNOME custom shortcuts, assign `/usr/local/bin/lg-brightness up`
and `/usr/local/bin/lg-brightness down` in Settings → Keyboard → Custom Shortcuts.
No existing brightness keys are replaced automatically.

## Protocol and safety

This model uses HID feature report **0**, with six payload bytes: a little-endian
32-bit brightness value followed by a separate 16-bit field. Linux hidraw adds
the leading report-ID byte, so the ioctl buffer is seven bytes. The tool reads
the report before each write, preserves the trailing field, and reads back the
result. Unexpected report sizes, identity, descriptors, or out-of-range values
fail closed. It does not touch the vendor-control or ambient-light interfaces.

**Important:** although the HID descriptor advertises a logical maximum of
540, this device's actual wire brightness scale is **0..54000**. Thus 50% is
**27000**, not 270. The scale and interface were cross-checked against
[ycsos/LG-ultrafine-brightness, `UltrafineDisplay.cpp`](https://github.com/ycsos/LG-ultrafine-brightness/blob/master/UltrafineDisplay.cpp)
and verified by live write/readback on this monitor. Our implementation uses
Python's hidraw ioctl directly, without detaching any kernel drivers or copying
that project's C++ implementation. The recorded live readback and this guide
are the evidence for the tested scale; don't generalize it to other monitors.

The seat ACL grants the active local user access to this HID interface (including
its other feature fields), not to arbitrary HID devices. The program itself only
changes brightness. It is not a setuid helper and should not be made one.

## Tests and removal

```bash
/usr/bin/python3 -m unittest discover -s tools/tests -v
# Optional standalone JavaScript tests (requires GJS):
gjs -m tools/tests/lg_brightness_extension_test.js
```

Hardware-free tests cover exact discovery, multi-monitor selection, scaling,
percentage validation, report sizing, preservation of unrelated bytes, readback,
permission errors, reused device numbers, cleanup and relative-step clamping.
On the tested host, installation granted the active user access only to the
brightness HID interface; unprivileged `get` and `set 50` both passed, and the
GTK4 slider launched without errors. Live acceptance additionally needs
an image check by the user; successful readback alone is not proof of an image.

To remove only the GNOME extension:

```bash
gnome-extensions disable lg-brightness@macbook-fedora-audit
gnome-extensions uninstall lg-brightness@macbook-fedora-audit
```

If it has not yet been discovered by the running Shell, log out/in first so the
extension tools recognize it. Removing the extension leaves the backend and
monitor brightness unchanged.

To remove the backend, first close the GTK slider and disable/uninstall the
extension. Remove the three installed backend files listed above
(or restore their backups), reload udev rules, and reconnect the monitor so the
old seat ACL is removed. This does not reset the monitor's stored brightness.
The source files remain in the rebuild kit and will be reinstalled if the full
kit is run again.
