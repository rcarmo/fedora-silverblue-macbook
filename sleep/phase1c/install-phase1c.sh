#!/usr/bin/bash
# Phase 1c: hook adds T1 SOCW(0) pre / SOCW(1) post + Touch Bar mode re-send; installs macbook_t1_socw.ko
# Run: pkexec /usr/bin/bash /var/home/me/macbook-fedora-audit/sleep/phase1c/install-phase1c.sh
set -euo pipefail
export PATH=/usr/sbin:/usr/bin
umask 022
SRC=/var/home/me/macbook-fedora-audit/sleep/phase1c/files
DST=/usr/local/sbin/macbook-sleep-hook
KDIR=/usr/local/lib/macbook-t1-socw/$(uname -r)
OLD=6dd370ed3773f0e46166feeb2e79ac66b94944d281b7bc2c99ac918c3abdea0f   # Phase 1b hook
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ $EUID == 0 ]] || fail "needs root"
[[ $(</sys/class/dmi/id/product_name) == MacBookPro13,2 ]] || fail "wrong model"
[[ $(</sys/module/apple_ibridge/parameters/skip_acpi_power) == 1 ]] || fail "Touch Bar guard changed"
[[ $(systemctl show systemd-suspend.service -p ActiveState --value) == inactive ]] || fail "suspend active"
cd "$SRC"; sha256sum -c --status SHA256SUMS || fail "source hash changed"
echo "$OLD  $DST" | sha256sum -c --status || fail "installed hook is not the reviewed Phase 1b version"
[[ $(modinfo -F vermagic ./macbook_t1_socw.ko | awk '{print $1}') == $(uname -r) ]] || fail "module vermagic != running kernel"
R=$(mktemp -d /var/lib/macbook-sleep-phase1c-XXXXXXXX)
cp -a "$DST" "$R/macbook-sleep-hook.phase1b"
install -d -m 0755 "$KDIR"
install -m 0644 macbook_t1_socw.ko "$KDIR/macbook_t1_socw.ko"
install -m 0755 macbook-sleep-hook "$DST"
restorecon -RF /usr/local/lib/macbook-t1-socw "$DST"
{ echo "Receipt: $R"; ls -lZ "$DST" "$KDIR/macbook_t1_socw.ko"; sha256sum "$DST" "$KDIR/macbook_t1_socw.ko"; } | tee "$R/installed.txt"
echo "INSTALLED (takes effect on next suspend)."
