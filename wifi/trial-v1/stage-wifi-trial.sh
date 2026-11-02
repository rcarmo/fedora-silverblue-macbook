#!/usr/bin/bash
# One-shot, narrowly scoped staging of the reviewed early-boot-only Wi-Fi trial.
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
umask 077
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $# == 0 && $EUID == 0 ]] || fail 'Run with admin approval, without arguments.'
[[ -e /run/ostree-booted ]] || fail 'Requires normally booted Silverblue.'
[[ $(</sys/class/dmi/id/product_name) == MacBookPro13,2 ]] || fail 'Wrong model.'
[[ $(</sys/bus/pci/devices/0000:02:00.0/vendor) == 0x14e4 && $(</sys/bus/pci/devices/0000:02:00.0/device) == 0x43ba && $(</sys/bus/pci/devices/0000:02:00.0/subsystem_vendor) == 0x106b && $(</sys/bus/pci/devices/0000:02:00.0/subsystem_device) == 0x0157 ]] || fail 'Wrong Wi-Fi board.'
cd -- "$HERE"
printf '%s\n' \
 '90f3f15991fcd8dc3b29a3cfda7859fd4faf9fe275cbef7b522658ff9971fa74  brcmfmac43602-pcie.txt' \
 '355f53091926fd7904f792e248709015c510e16d04bcdfbe283d0af451e37ee2  99-macbook-wifi-nvram.conf.dracut' \
 '1c897b52f36e8f2e7682e5daeb99cf61cd2ae635aa058218949062ed6c52ba96  99-macbook-wifi-nvram.conf.modprobe' | sha256sum --check --status || fail 'Reviewed input hash mismatch.'
STATUS=$(rpm-ostree status --json)
printf '%s' "$STATUS" | python3 -c '
import json,sys
s=json.load(sys.stdin);d=s["deployments"]
assert not s.get("transaction"), "Transaction running"
assert d[0].get("booted") and not any(x.get("staged") for x in d), "Pending deployment exists"
assert d[0]["checksum"]=="43e45ec36e83466bf11fe72de61a2e844342182d820de150ddf99c880c38951f", "Unexpected booted deployment"
assert d[0].get("regenerate-initramfs") and not d[0].get("initramfs-args"), "Unexpected initramfs configuration"
assert len(d)>=2 and d[1]["checksum"]=="f1365bcef08f98f305177529b4132dbef7c2a4d4ad1fc38de9b24fc85c306517", "Stock fallback changed"
' || fail 'Deployment preflight failed.'
# Do not alter vendor firmware on the host or overwrite an existing board config.
for p in /usr/lib/firmware/brcm/brcmfmac43602-pcie.txt /usr/lib/firmware/updates/brcm/brcmfmac43602-pcie.txt; do
    [[ ! -e "$p" && ! -L "$p" ]] || fail "Existing firmware override: $p"
done
/usr/bin/bash "$HERE/../recover-wifi.sh" --arm
# Both current working drivers and stock updated image retained unchanged.
ostree admin pin 0
ostree admin pin 1
FIRMWARE=/etc/firmware/macbook-wifi/brcm/brcmfmac43602-pcie.txt
MODPROBE=/etc/modprobe.d/99-macbook-wifi-nvram.conf
DRACUT=/etc/dracut.conf.d/99-macbook-wifi-nvram.conf
# Recovery --arm checked no path components are symlinks and baseline is empty.
install -d -m 0755 /etc/firmware /etc/firmware/macbook-wifi /etc/firmware/macbook-wifi/brcm
install -m 0644 brcmfmac43602-pcie.txt "$FIRMWARE"
install -m 0644 99-macbook-wifi-nvram.conf.modprobe "$MODPROBE"
install -m 0644 99-macbook-wifi-nvram.conf.dracut "$DRACUT"
restorecon /etc/firmware /etc/firmware/macbook-wifi /etc/firmware/macbook-wifi/brcm "$FIRMWARE" "$MODPROBE" "$DRACUT"
sha256sum "$FIRMWARE" "$MODPROBE" "$DRACUT" > /var/lib/macbook-wifi-recovery/trial-installed.sha256
printf 'Trial files installed. Current loaded Wi-Fi is untouched. Composing boot image.\n'
# --force changes previously empty dracut args, forcing an OSTree regeneration.
if ! rpm-ostree initramfs --enable --arg=--force; then
    printf 'Composition failed or interrupted. Inspect status before retry/recovery.\n' >&2
    printf 'Recovery state and files retained. NO reboot or module reload performed.\n' >&2
    exit 1
fi
rpm-ostree status
printf 'Staged only. Inspect new initramfs and obtain approval before reboot.\n'
