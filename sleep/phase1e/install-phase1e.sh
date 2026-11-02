#!/usr/bin/bash
# Phase 1e: hook disables LID0 S3 wake when the lid is open at suspend (GPE 0x6F instant wake).
set -euo pipefail
export PATH=/usr/sbin:/usr/bin
umask 022
SRC=/var/home/me/macbook-fedora-audit/sleep/phase1e/files
DST=/usr/local/sbin/macbook-sleep-hook
OLD=8c64221d42d19d66c71b20493b55a7db483ea5e37ef3a1664459ab48c44ac970   # Phase 1d hook
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ $EUID == 0 ]] || fail "needs root"
[[ $(systemctl show systemd-suspend.service -p ActiveState --value) == inactive ]] || fail "suspend active"
cd "$SRC"; sha256sum -c --status SHA256SUMS || fail "source hash changed"
echo "$OLD  $DST" | sha256sum -c --status || fail "installed hook is not the Phase 1d version"
R=$(mktemp -d /var/lib/macbook-sleep-phase1e-XXXXXXXX)
cp -a "$DST" "$R/macbook-sleep-hook.phase1d"
install -m 0755 macbook-sleep-hook "$DST"; restorecon -F "$DST"
{ echo "Receipt: $R"; ls -lZ "$DST"; sha256sum "$DST"; } | tee "$R/installed.txt"
