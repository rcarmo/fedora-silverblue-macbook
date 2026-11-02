#!/usr/bin/bash
# Undo Phase 1c: pkexec /usr/bin/bash .../undo-phase1c.sh /var/lib/macbook-sleep-phase1c-XXXXXXXX
set -euo pipefail
export PATH=/usr/sbin:/usr/bin
R=${1:?receipt dir}
[[ $EUID == 0 ]] || { echo "needs root" >&2; exit 1; }
echo "6dd370ed3773f0e46166feeb2e79ac66b94944d281b7bc2c99ac918c3abdea0f  $R/macbook-sleep-hook.phase1b" | sha256sum -c
install -m 0755 "$R/macbook-sleep-hook.phase1b" /usr/local/sbin/macbook-sleep-hook
restorecon -F /usr/local/sbin/macbook-sleep-hook
rmmod macbook_t1_socw 2>/dev/null || true
rm -rf /usr/local/lib/macbook-t1-socw
sha256sum /usr/local/sbin/macbook-sleep-hook; echo "UNDONE"
