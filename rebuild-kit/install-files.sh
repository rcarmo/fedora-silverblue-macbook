#!/usr/bin/bash
# Install every /etc and /usr/local file of the current MacBookPro13,2 setup (idempotent).
#   pkexec /usr/bin/bash /var/home/me/macbook-fedora-audit/rebuild-kit/install-files.sh
# Does NOT touch rpm-ostree, kernel arguments or GNOME settings - see README.md steps 2-6.
set -euo pipefail
export PATH=/usr/sbin:/usr/bin
umask 022
K=$(cd "$(dirname "$0")" && pwd)
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ $EUID == 0 ]] || fail "needs root (pkexec)"
[[ $(</sys/class/dmi/id/product_name) == MacBookPro13,2 ]] || fail "not a MacBookPro13,2"
[[ $(systemctl show systemd-suspend.service -p ActiveState --value) == inactive ]] || fail "suspend in progress"
cd "$K"; sha256sum -c --quiet SHA256SUMS || fail "kit hash mismatch"
R=$(mktemp -d /var/lib/macbook-rebuild-kit-XXXXXXXX)
cd "$K/files"
find . -type f | sort | while read -r f; do
  dst=${f#.}
  [[ -e $dst ]] && { mkdir -p "$R/backup$(dirname "$dst")"; cp -a "$dst" "$R/backup$dst"; }
  install -D -m "$(stat -c %a "$f")" "$f" "$dst"
  echo "$dst" >> "$R/installed.txt"
done
NV=/etc/firmware/macbook-wifi/brcm/brcmfmac43602-pcie.txt
if grep -q '^macaddr=00:90:4c:0d:f4:3e$' "$NV"; then   # public placeholder -> random local MAC
  mac=$(od -An -N5 -tx1 /dev/urandom | tr -s ' ' ':' | sed 's/^:/02:/')
  sed -i "s/^macaddr=.*/macaddr=$mac/" "$NV"; echo "Wi-Fi NVRAM macaddr set to $mac"
fi
restorecon -RF /etc/firmware/macbook-wifi $(cat "$R/installed.txt")
# SELinux type for the optional per-kernel SOCW fallback directory (akmod copy is used first)
semanage fcontext -l -C | grep -q 'macbook-t1-socw' || semanage fcontext -a -t modules_object_t "/usr/local/lib/macbook-t1-socw(/.*)?"
systemctl daemon-reload
systemctl enable macbook-usbc-runtime.service
udevadm control --reload
echo "Installed $(wc -l < "$R/installed.txt") files; receipt + backups: $R"
echo "Next: README.md steps (rpm-ostree packages, kargs, initramfs, reboot), then tools/audit.sh"
