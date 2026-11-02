#!/usr/bin/bash
# Phase 1d: hook loads macbook_t1_socw via modprobe (akmod 0.1.20261101), insmod fallback.
set -euo pipefail
export PATH=/usr/sbin:/usr/bin
umask 022
SRC=/var/home/me/macbook-fedora-audit/sleep/phase1d/files
DST=/usr/local/sbin/macbook-sleep-hook
OLD=e0739d7cd25c387d2715c898680b7c719d7da8b3b73bf87f3338fb4367936855   # Phase 1c hook
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ $EUID == 0 ]] || fail "needs root"
[[ $(systemctl show systemd-suspend.service -p ActiveState --value) == inactive ]] || fail "suspend active"
cd "$SRC"; sha256sum -c --status SHA256SUMS || fail "source hash changed"
echo "$OLD  $DST" | sha256sum -c --status || fail "installed hook is not the Phase 1c version"
R=$(mktemp -d /var/lib/macbook-sleep-phase1d-XXXXXXXX)
cp -a "$DST" "$R/macbook-sleep-hook.phase1c"
install -m 0755 macbook-sleep-hook "$DST"; restorecon -F "$DST"
{ echo "Receipt: $R"; ls -lZ "$DST"; sha256sum "$DST"; } | tee "$R/installed.txt"
