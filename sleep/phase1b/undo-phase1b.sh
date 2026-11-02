#!/usr/bin/bash
# Undo Phase 1b: pkexec /usr/bin/bash .../undo-phase1b.sh /var/lib/macbook-sleep-phase1b-XXXXXXXX
set -euo pipefail
export PATH=/usr/sbin:/usr/bin
R=${1:?receipt dir}
[[ $EUID == 0 ]] || { echo "needs root" >&2; exit 1; }
echo "db5b21ecd906ea602908d2d4c4ef5e0600a4e1bfce08708967c0eee12bb9bfa2  $R/macbook-sleep-hook.phase1" | sha256sum -c
install -m 0755 "$R/macbook-sleep-hook.phase1" /usr/local/sbin/macbook-sleep-hook
restorecon -F /usr/local/sbin/macbook-sleep-hook
echo 'enabled' > /sys/bus/pci/devices/0000:00:14.0/power/wakeup
sha256sum /usr/local/sbin/macbook-sleep-hook; echo "UNDONE"
