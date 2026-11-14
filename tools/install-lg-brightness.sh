#!/usr/bin/bash
# Install only the optional LG brightness command, launcher and permission rule.
set -euo pipefail
export PATH=/usr/sbin:/usr/bin
umask 022
KIT=$(cd "$(dirname "$0")/../rebuild-kit" && pwd)
[[ $EUID == 0 ]] || { echo "Run with pkexec /usr/bin/bash $0" >&2; exit 1; }
cd "$KIT"
sha256sum -c --quiet SHA256SUMS
RECEIPT=$(mktemp -d /var/lib/macbook-lg-brightness-XXXXXXXX)
for entry in \
    '755 /usr/local/bin/lg-brightness' \
    '644 /etc/udev/rules.d/70-lg-ultrafine-brightness.rules' \
    '644 /usr/local/share/applications/lg-brightness.desktop'; do
    read -r mode dst <<< "$entry"
    if [[ -e $dst ]]; then
        mkdir -p "$RECEIPT/backup$(dirname "$dst")"
        cp -a "$dst" "$RECEIPT/backup$dst"
    fi
    install -D -m "$mode" "files$dst" "$dst"
    restorecon "$dst"
    echo "$dst" >> "$RECEIPT/installed.txt"
done
udevadm control --reload-rules
# Reapply seat ACLs to LG hidraw nodes without resetting any USB device.
for node in /sys/class/hidraw/hidraw*; do
    if grep -q '^HID_ID=0003:0000043E:00009A40$' "$node/device/uevent"; then
        udevadm trigger --action=add "$node"
    fi
done
udevadm settle
command -v update-desktop-database >/dev/null && update-desktop-database /usr/local/share/applications
printf 'Installed LG brightness controls. Receipt/backups: %s\n' "$RECEIPT"
printf 'Run: lg-brightness get; lg-brightness set 50; lg-brightness gui\n'
printf 'If access is denied, reconnect the monitor from the active local desktop.\n'
