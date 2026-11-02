#!/usr/bin/bash
# Phase 1 S3 recipe installer (files only; the karg is applied separately).
# Run: pkexec /usr/bin/bash /var/home/me/macbook-fedora-audit/sleep/phase1/install-phase1.sh
set -euo pipefail
export PATH=/usr/sbin:/usr/bin
umask 022
SRC=/var/home/me/macbook-fedora-audit/sleep/phase1/files
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ $EUID == 0 ]] || fail "needs root"
[[ $(</sys/class/dmi/id/product_name) == MacBookPro13,2 ]] || fail "wrong model"
[[ $(uname -r) == 7.2.13-200.fc44.x86_64 ]] || fail "unexpected kernel"
[[ $(</sys/module/apple_ibridge/parameters/skip_acpi_power) == 1 ]] || fail "Touch Bar guard changed"
[[ $(systemctl show systemd-suspend.service -p ActiveState --value) == inactive ]] || fail "suspend active"
cd "$SRC"
sha256sum -c --status SHA256SUMS || fail "source hashes changed"

OLD_RULE=/etc/udev/rules.d/99-macbook-right-usb3-runtime.rules
OLD_UNIT=/etc/systemd/system/macbook-right-usb3-runtime.service
OLD_SLEEP=/etc/systemd/sleep.conf.d/90-macbook-s2idle.conf
echo "96a25429a5879959a6e70f92a21b70eb6c448de11ed4631060bb299a3d5f708a  $OLD_RULE
3e0806921421a637348714228ab991c9394c8bd7d336a1c89657f56816b8952e  $OLD_UNIT
dc1ae01b5e8e4dc09e95bc00cd5139356bc6b122b327f09afb69141f4c9d1ec8  $OLD_SLEEP" | sha256sum -c --status || fail "existing files differ from reviewed versions"
for f in /usr/local/sbin/macbook-sleep-hook /usr/local/sbin/macbook-thunderbolt-remove-rescan \
         /etc/systemd/system/systemd-suspend.service.d/50-macbook-s3.conf /etc/systemd/sleep.conf.d/90-macbook-deep.conf \
         /etc/udev/rules.d/61-macbook-nvme-d3cold.rules /etc/udev/rules.d/99-macbook-usbc-runtime.rules \
         /etc/systemd/system/macbook-usbc-runtime.service; do
  [[ ! -e $f ]] || fail "destination already exists: $f"
done

R=$(mktemp -d /var/lib/macbook-sleep-phase1-XXXXXXXX)
mkdir "$R/backup"
cp -a "$OLD_RULE" "$OLD_UNIT" "$OLD_SLEEP" "$R/backup/"
echo "Receipt: $R"

install -m 0755 macbook-sleep-hook macbook-thunderbolt-remove-rescan /usr/local/sbin/
install -d -m 0755 /etc/systemd/system/systemd-suspend.service.d
install -m 0644 50-macbook-s3.conf /etc/systemd/system/systemd-suspend.service.d/
install -m 0644 90-macbook-deep.conf /etc/systemd/sleep.conf.d/
install -m 0644 61-macbook-nvme-d3cold.rules 99-macbook-usbc-runtime.rules /etc/udev/rules.d/
install -m 0644 macbook-usbc-runtime.service /etc/systemd/system/

# Retire the right-side-only workaround (superseded by the ID-matched rule).
systemctl disable macbook-right-usb3-runtime.service
rm -f -- "$OLD_RULE" "$OLD_UNIT" "$OLD_SLEEP"

restorecon -RF /usr/local/sbin/macbook-sleep-hook /usr/local/sbin/macbook-thunderbolt-remove-rescan \
  /etc/systemd/system/systemd-suspend.service.d /etc/systemd/sleep.conf.d \
  /etc/udev/rules.d/61-macbook-nvme-d3cold.rules /etc/udev/rules.d/99-macbook-usbc-runtime.rules \
  /etc/systemd/system/macbook-usbc-runtime.service

systemctl daemon-reload
udevadm control --reload
systemctl enable --now macbook-usbc-runtime.service
udevadm trigger --action=change --settle --subsystem-match=pci --attr-match=vendor=0x106b --attr-match=device=0x2003

{ ls -lZ /usr/local/sbin/macbook-* /etc/systemd/system/systemd-suspend.service.d/* /etc/systemd/sleep.conf.d/* \
     /etc/udev/rules.d/6*-macbook* /etc/udev/rules.d/99-macbook* /etc/systemd/system/macbook-usbc-runtime.service
  sha256sum /usr/local/sbin/macbook-* /etc/systemd/system/systemd-suspend.service.d/* /etc/systemd/sleep.conf.d/* \
     /etc/udev/rules.d/61-macbook-nvme-d3cold.rules /etc/udev/rules.d/99-macbook-usbc-runtime.rules /etc/systemd/system/macbook-usbc-runtime.service
} | tee "$R/installed.txt"
echo "INSTALLED. Karg firmware_class.path still to be applied separately; reboot required for it."
