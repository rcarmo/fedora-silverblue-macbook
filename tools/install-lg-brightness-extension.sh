#!/usr/bin/bash
# Install only the per-user GNOME extension; never run this as root.
set -euo pipefail
export PATH=/usr/local/bin:/usr/bin:/usr/sbin
umask 022
[[ $EUID != 0 ]] || { echo 'Run as your desktop user, NOT with sudo/pkexec.' >&2; exit 1; }
ROOT=$(cd "$(dirname "$0")/.." && pwd)
UUID=lg-brightness@macbook-fedora-audit
SOURCE="$ROOT/extensions/$UUID"
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}
[[ $(gnome-shell --version) == 'GNOME Shell 50.'* ]] || {
    echo 'This extension targets GNOME Shell 50 only.' >&2; exit 1;
}
[[ -x /usr/local/bin/lg-brightness ]] || {
    echo 'First install the brightness backend: see docs/LG-BRIGHTNESS.md.' >&2; exit 1;
}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DEST="$DATA/gnome-shell/extensions/$UUID"
if [[ -d $DEST ]]; then
    mkdir -p "$STATE/lg-brightness"
    BACKUP=$(mktemp -d "$STATE/lg-brightness/extension-backup-XXXXXXXX")
    cp -a "$DEST" "$BACKUP/extension"
    echo "Previous extension saved to $BACKUP/extension"
fi
gnome-extensions pack "$SOURCE" --force --out-dir "$TMP" \
    --extra-source=controller.js --extra-source=subprocess.js
gnome-extensions install --force "$TMP/$UUID.shell-extension.zip"
# The running Shell may not discover a NEW local extension until next login.
# Queue only this UUID; preserve every unrelated enabled/disabled extension.
/usr/bin/python3 - "$UUID" <<'PY'
import sys
from gi.repository import Gio
uuid = sys.argv[1]
settings = Gio.Settings.new('org.gnome.shell')
enabled = settings.get_strv('enabled-extensions')
if uuid not in enabled:
    if not settings.set_strv('enabled-extensions', enabled + [uuid]):
        raise SystemExit('Unable to queue extension enablement')
disabled = settings.get_strv('disabled-extensions')
if uuid in disabled:
    if not settings.set_strv('disabled-extensions', [item for item in disabled if item != uuid]):
        raise SystemExit('Unable to remove this extension from disabled-extensions')
Gio.Settings.sync()
if settings.get_boolean('disable-user-extensions'):
    print('User extensions are globally disabled; enable them in Extensions when ready.')
PY
printf 'Installed and queued %s for your desktop user.\n' "$UUID"
printf 'If this is a new extension, log out and back in to load it on Wayland.\n'
printf 'If replacing loaded JavaScript, log out/in to avoid stale module caches.\n'
printf 'No session restart, system files, or other extension preferences were changed.\n'
