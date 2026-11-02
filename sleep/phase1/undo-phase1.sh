#!/usr/bin/bash
# Undo Phase 1: remove S3 hook/config, restore previous files from the receipt.
#   pkexec /usr/bin/bash /var/home/me/macbook-fedora-audit/sleep/phase1/undo-phase1.sh /var/lib/macbook-sleep-phase1-csZYkCwn
# Karg removal (separate, needs reboot):
#   pkexec rpm-ostree kargs --delete=firmware_class.path=/etc/firmware/macbook-wifi
set -euo pipefail
export PATH=/usr/sbin:/usr/bin
R=${1:?receipt dir}
[[ $EUID == 0 && -d $R/backup ]] || { echo "need root and receipt"; exit 1; }
systemctl disable --now macbook-usbc-runtime.service || true
rm -f /usr/local/sbin/macbook-sleep-hook /usr/local/sbin/macbook-thunderbolt-remove-rescan \
      /etc/systemd/system/systemd-suspend.service.d/50-macbook-s3.conf /etc/systemd/sleep.conf.d/90-macbook-deep.conf \
      /etc/udev/rules.d/61-macbook-nvme-d3cold.rules /etc/udev/rules.d/99-macbook-usbc-runtime.rules \
      /etc/systemd/system/macbook-usbc-runtime.service
rmdir /etc/systemd/system/systemd-suspend.service.d 2>/dev/null || true
cp -a "$R/backup/99-macbook-right-usb3-runtime.rules" /etc/udev/rules.d/
cp -a "$R/backup/macbook-right-usb3-runtime.service" /etc/systemd/system/
cp -a "$R/backup/90-macbook-s2idle.conf" /etc/systemd/sleep.conf.d/
restorecon -F /etc/udev/rules.d/99-macbook-right-usb3-runtime.rules /etc/systemd/system/macbook-right-usb3-runtime.service /etc/systemd/sleep.conf.d/90-macbook-s2idle.conf
systemctl daemon-reload; udevadm control --reload
systemctl enable --now macbook-right-usb3-runtime.service
echo "Phase 1 files removed; previous state restored (NVMe d3cold/USB root hubs reset fully at next boot)."
