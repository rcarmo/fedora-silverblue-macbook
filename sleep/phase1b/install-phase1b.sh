#!/usr/bin/bash
# Phase 1b: replace ONLY /usr/local/sbin/macbook-sleep-hook (adds XHC1 wake disable/restore).
# Run: pkexec /usr/bin/bash /var/home/me/macbook-fedora-audit/sleep/phase1b/install-phase1b.sh
set -euo pipefail
export PATH=/usr/sbin:/usr/bin
umask 022
SRC=/var/home/me/macbook-fedora-audit/sleep/phase1b/files
DST=/usr/local/sbin/macbook-sleep-hook
OLD=db5b21ecd906ea602908d2d4c4ef5e0600a4e1bfce08708967c0eee12bb9bfa2   # Phase 1 hook
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ $EUID == 0 ]] || fail "needs root"
[[ $(</sys/class/dmi/id/product_name) == MacBookPro13,2 ]] || fail "wrong model"
[[ $(</sys/module/apple_ibridge/parameters/skip_acpi_power) == 1 ]] || fail "Touch Bar guard changed"
[[ $(systemctl show systemd-suspend.service -p ActiveState --value) == inactive ]] || fail "suspend active"
cd "$SRC"; sha256sum -c --status SHA256SUMS || fail "source hash changed"
echo "$OLD  $DST" | sha256sum -c --status || fail "installed hook is not the reviewed Phase 1 version"
R=$(mktemp -d /var/lib/macbook-sleep-phase1b-XXXXXXXX)
cp -a "$DST" "$R/macbook-sleep-hook.phase1"
install -m 0755 macbook-sleep-hook "$DST"
restorecon -F "$DST"
{ echo "Receipt: $R"; ls -lZ "$DST"; sha256sum "$DST"; } | tee "$R/installed.txt"
echo "INSTALLED (no reboot needed; takes effect on next suspend)."
