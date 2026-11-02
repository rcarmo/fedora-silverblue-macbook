#!/usr/bin/python3
"""Ask Mutter to verify a lower-bandwidth LG mode (automatic rollback)."""
import time
from gi.repository import Gio, GLib

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
def call(method, args=None):
    return bus.call_sync('org.gnome.Mutter.DisplayConfig',
                         '/org/gnome/Mutter/DisplayConfig',
                         'org.gnome.Mutter.DisplayConfig', method,
                         args, None, Gio.DBusCallFlags.NONE, 10000, None)
serial, monitors, logical, properties = call('GetCurrentState').unpack()
physical = {m[0][0]: m for m in monitors}
config = []
original = []
for x, y, scale, transform, primary, members, _ in logical:
    old_outputs = []
    outputs = []
    for member in members:
        connector = member[0]
        current = next(mode[0] for mode in physical[connector][1]
                       if mode[6].get('is-current'))
        old_outputs.append((connector, current, {}))
        if connector == 'DP-2':
            if member[1:3] != ('GSM', 'LG UltraFine'):
                raise RuntimeError('Unexpected display on DP-2')
            current = next(mode[0] for mode in physical[connector][1]
                           if mode[1:3] == (1920, 1080) and 59 < mode[3] < 61)
            scale = 1.0
        outputs.append((connector, current, {}))
    old_scale = next(l[2] for l in logical if l[0:2] == (x, y))
    original.append((x, y, old_scale, transform, primary, old_outputs))
    config.append((x, y, scale, transform, primary, outputs))
print('Testing configuration:', config, flush=True)
# TEMPORARY=1 does not save configuration. Restore explicitly after 30s.
settings = {'layout-mode': GLib.Variant('u', properties['layout-mode'])}
call('ApplyMonitorsConfig', GLib.Variant('(uua(iiduba(ssa{sv}))a{sv})',
    (serial, 1, config, settings)))
print('1080p test active for 30 seconds; will restore original settings.', flush=True)
time.sleep(30)
new_serial = call('GetCurrentState').unpack()[0]
call('ApplyMonitorsConfig', GLib.Variant('(uua(iiduba(ssa{sv}))a{sv})',
    (new_serial, 1, original, settings)))
print('Original configuration restored.', flush=True)
