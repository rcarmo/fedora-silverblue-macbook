#!/usr/bin/bash
# Undo Phase 1e: pkexec /usr/bin/bash .../undo-phase1e.sh /var/lib/macbook-sleep-phase1e-XXXXXXXX
set -euo pipefail
export PATH=/usr/sbin:/usr/bin
R=${1:?receipt dir}
echo "8c64221d42d19d66c71b20493b55a7db483ea5e37ef3a1664459ab48c44ac970  $R/macbook-sleep-hook.phase1d" | sha256sum -c
install -m 0755 "$R/macbook-sleep-hook.phase1d" /usr/local/sbin/macbook-sleep-hook; restorecon -F /usr/local/sbin/macbook-sleep-hook
grep -q '^LID0.*\*disabled' /proc/acpi/wakeup && echo LID0 > /proc/acpi/wakeup; echo UNDONE
