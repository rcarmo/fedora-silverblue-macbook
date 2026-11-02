#!/usr/bin/bash
# Corrected integration ONLY; no reboot, sleep, or live Wi-Fi reload.
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
umask 077
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $# == 0 && $EUID == 0 ]] || fail 'Run with graphical admin approval, no arguments.'
[[ -e /run/ostree-booted && $(uname -r) == 7.2.13-200.fc44.x86_64 ]] || fail 'Unexpected OS/kernel.'
[[ $(</proc/sys/kernel/random/boot_id) == <uuid> ]] || fail 'Boot changed; re-audit.'
[[ $(</sys/class/dmi/id/product_name) == MacBookPro13,2 ]] || fail 'Wrong model.'
[[ $(</sys/bus/pci/devices/0000:02:00.0/vendor) == 0x14e4 && $(</sys/bus/pci/devices/0000:02:00.0/device) == 0x43ba && $(</sys/bus/pci/devices/0000:02:00.0/subsystem_vendor) == 0x106b && $(</sys/bus/pci/devices/0000:02:00.0/subsystem_device) == 0x0157 ]] || fail 'Wrong Wi-Fi board.'
# This SBS battery exports a misleading capacity percentage. UPower agrees
# with charge_now/charge_full (~47%), not capacity (~34%). Check usable charge.
CHARGE_NOW=$(</sys/class/power_supply/BAT0/charge_now)
CHARGE_FULL=$(</sys/class/power_supply/BAT0/charge_full)
[[ $CHARGE_NOW =~ ^[0-9]+$ && $CHARGE_FULL =~ ^[0-9]+$ ]] || fail 'Invalid battery charge readings.'
(( CHARGE_FULL > 0 && CHARGE_NOW * 100 >= CHARGE_FULL * 40 )) || fail 'At least 40% usable charge required; connect charger otherwise.'
printf 'Power: adapter online=%s, usable charge=%s/%s.\n' "$(</sys/class/power_supply/ADP1/online)" "$CHARGE_NOW" "$CHARGE_FULL"
[[ $(</sys/module/apple_ibridge/parameters/skip_acpi_power) == 1 ]] || fail 'Touch Bar ACPI guard changed.'
cd -- "$HERE"
printf '%s\n' \
 '90f3f15991fcd8dc3b29a3cfda7859fd4faf9fe275cbef7b522658ff9971fa74  brcmfmac43602-pcie.txt' \
 '4a6b75b6313143ee1214c8ece7ba3e7583e4dee4e112c0d6794f1840d4d574ec  99-macbook-wifi-nvram.conf.dracut' \
 '1c897b52f36e8f2e7682e5daeb99cf61cd2ae635aa058218949062ed6c52ba96  99-macbook-wifi-nvram.conf.modprobe' | sha256sum --check --status || fail 'Input hashes changed.'
STATUS=$(rpm-ostree status --json)
printf '%s' "$STATUS" | python3 -I -c '
import json,sys
s=json.load(sys.stdin);d=s["deployments"]
assert not s.get("transaction") and not any(x.get("staged") for x in d)
assert d[0].get("booted") and d[0]["checksum"]=="c4ebdd857316f64e6b97b3c29f64993fef8ebe82824484091bc4d848b2ae39bc"
assert [x["checksum"][:7] for x in d]==["c4ebdd8","b0a3115","43e45ec","f1365bc","b8e75b7"]
assert d[0].get("regenerate-initramfs")
assert d[0].get("initramfs-args")==["--force","--remove","/etc/firmware/macbook-wifi /etc/modprobe.d/99-macbook-wifi-nvram.conf /etc/dracut.conf.d/99-macbook-wifi-nvram.conf /usr/lib/firmware/brcm/brcmfmac43602-pcie.txt /lib/firmware/brcm/brcmfmac43602-pcie.txt"]
assert all(x.get("pinned") for x in d[2:])
' || fail 'Deployment preflight failed.'
check_path() {
 local p=$1
 while [[ $p != / ]]; do [[ ! -L $p ]] || fail "Symlink: $p"; p=${p%/*}; [[ -n $p ]] || p=/; done
}
STATE=/var/lib/macbook-wifi-recovery
check_path "$STATE"; check_path "$STATE/armed"; check_path "$STATE/baseline-deployments.json"
[[ -d $STATE && $(stat -c '%u:%a' "$STATE") == 0:700 ]] || fail 'Unsafe recovery state.'
[[ -f $STATE/armed && $(stat -c '%u' "$STATE/armed") == 0 && $(<"$STATE/armed") == macbook-wifi-recovery-v1-empty-baseline ]] || fail 'Invalid arming record.'
[[ -f $STATE/baseline-deployments.json && $(stat -c '%u' "$STATE/baseline-deployments.json") == 0 ]] || fail 'Unsafe baseline.'
python3 -I -c 'import json; from pathlib import Path; d=json.loads(Path("/var/lib/macbook-wifi-recovery/baseline-deployments.json").read_text())["deployments"]; assert d[0]["checksum"]=="43e45ec36e83466bf11fe72de61a2e844342182d820de150ddf99c880c38951f"' || fail 'Baseline changed.'
FIRMWARE=/etc/firmware/macbook-wifi/brcm/brcmfmac43602-pcie.txt
MODPROBE=/etc/modprobe.d/99-macbook-wifi-nvram.conf
DRACUT=/etc/dracut.conf.d/99-macbook-wifi-nvram.conf
for p in "$FIRMWARE" "$MODPROBE" "$DRACUT" /usr/lib/firmware/brcm/brcmfmac43602-pcie.txt /usr/lib/firmware/updates/brcm/brcmfmac43602-pcie.txt; do
 check_path "$p"; [[ ! -e $p ]] || fail "Unexpected override: $p"
done
modinfo -F filename brcmfmac-wcc | grep -Fx '/lib/modules/7.2.13-200.fc44.x86_64/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac/wcc/brcmfmac-wcc.ko.xz' >/dev/null || fail 'Unexpected helper module.'
exec 9>"$STATE/lock"; flock -n 9 || fail 'Recovery/staging already running.'
RECEIPT=$(mktemp -d "$STATE/trial-v2-XXXXXXXX")
printf '%s\n' "$STATUS" > "$RECEIPT/before-deployments.json"
cp -- "$STATE/armed" "$STATE/baseline-deployments.json" "$RECEIPT/"
# Keep recovery and old pinned fallbacks; do not pin or boot the failed trial.
ostree admin pin 0
install -d -m 0755 /etc/firmware /etc/firmware/macbook-wifi /etc/firmware/macbook-wifi/brcm
install -m 0644 brcmfmac43602-pcie.txt "$FIRMWARE"
install -m 0644 99-macbook-wifi-nvram.conf.modprobe "$MODPROBE"
install -m 0644 99-macbook-wifi-nvram.conf.dracut "$DRACUT"
restorecon /etc/firmware /etc/firmware/macbook-wifi /etc/firmware/macbook-wifi/brcm "$FIRMWARE" "$MODPROBE" "$DRACUT"
sha256sum "$FIRMWARE" "$MODPROBE" "$DRACUT" > "$RECEIPT/installed.sha256"
ls -lZ "$FIRMWARE" "$MODPROBE" "$DRACUT"
printf 'Installed only scoped trial files. Recovery receipt: %s\n' "$RECEIPT"
# Reviewed API replaces argument vector; exact known recovery exclusions removed.
# Keep --force, local regeneration, and all package/kernel/driver choices.
if ! rpm-ostree initramfs --enable --arg=--force 2>&1 | tee "$RECEIPT/composition.log"; then
 printf 'Composition failed/interrupted. Inspect transaction/status; DO NOT rerun blindly or reboot. Scoped files/receipt retained.\n' >&2
 exit 1
fi
rpm-ostree status --json > "$RECEIPT/after-deployments.json"
rpm-ostree status
printf 'STAGED ONLY. Verify actual new image/helper and fallbacks before user reboot.\n'
