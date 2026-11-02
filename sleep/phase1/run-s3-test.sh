#!/usr/bin/bash
# ONE attended S3 test with automatic RTC wake. Run after the reboot:
#   pkexec /usr/bin/bash /var/home/me/macbook-fedora-audit/sleep/phase1/run-s3-test.sh 120
# Before: work saved, charger in, NOTHING else in the USB-C ports, lid OPEN.
# Don't touch the machine for the first ~10 s after it goes dark.
set -uo pipefail
export PATH=/usr/sbin:/usr/bin
SECS=${1:-120}
OUT=/var/home/me/macbook-fedora-audit/sleep/phase1/test-$(date +%Y%m%d-%H%M%S)
fail() { echo "REFUSED: $*" >&2; exit 1; }
[[ $EUID == 0 ]] || fail "needs root"
[[ $SECS =~ ^[0-9]+$ ]] && (( SECS >= 60 && SECS <= 1800 )) || fail "seconds must be 60..1800"
[[ $(</sys/class/dmi/id/product_name) == MacBookPro13,2 ]] || fail "model"
grep -qw 'firmware_class.path=/etc/firmware/macbook-wifi' /proc/cmdline || fail "firmware_class.path karg not active (reboot first)"
[[ -x /usr/local/sbin/macbook-sleep-hook && -x /usr/local/sbin/macbook-thunderbolt-remove-rescan ]] || fail "hooks missing"
systemctl cat systemd-suspend.service | grep -q 'macbook-sleep-hook pre' || fail "suspend drop-in missing"
systemd-analyze cat-config systemd/sleep.conf | grep -qx 'MemorySleepMode=deep' || fail "deep not configured"
[[ $(</sys/bus/pci/devices/0000:01:00.0/d3cold_allowed) == 0 ]] || fail "NVMe d3cold_allowed != 0"
[[ $(</sys/module/apple_ibridge/parameters/skip_acpi_power) == 1 ]] || fail "Touch Bar guard"
[[ $(</sys/class/power_supply/ADP1/online) == 1 ]] || fail "connect the charger"
[[ $(</sys/power/pm_test) == *'[none]'* ]] || fail "pm_test not none"
# No external USB devices on the Alpine Ridge (USB-C) controllers.
for d in /sys/bus/usb/devices/*; do
  [[ -e $d/idVendor && ${d##*/} != usb* && ${d##*/} != *:* ]] || continue
  p=$(readlink -f "$d")
  [[ $p == */0000:00:14.0/* ]] || fail "USB device ${d##*/} ($(cat $d/idVendor):$(cat $d/idProduct)) on a USB-C controller - unplug it"
done
mounts=$(lsblk -nrpo TRAN,MOUNTPOINT | awk '$1=="usb" && $2!=""')
[[ -z $mounts ]] || fail "USB storage mounted"

mkdir -p "$OUT"; chown me:me "$OUT"
snap() {
  { date --iso-8601=ns; cat /sys/power/mem_sleep; cat /proc/cmdline
    ls /sys/bus/pci/drivers/xhci_hcd | grep 0000; ls /sys/bus/pci/devices | wc -l
    for u in /sys/bus/usb/devices/usb*; do echo "${u##*/} $(cat $u/idProduct) $(cat $u/power/control)"; done
    nmcli -t -f DEVICE,STATE,CONNECTION device; iw dev 2>/dev/null | grep -E 'Interface|channel|ssid'
    iw phy 2>/dev/null | grep -E 'Band [12]:'
    lsmod | grep -E '^(apple_|brcmfmac|applespi|snd_hda_codec_cs8409)'
    cat /sys/power/suspend_stats/success /sys/power/suspend_stats/fail 2>/dev/null
  } > "$OUT/$1.txt" 2>&1
}
snap before
START=$(date '+%Y-%m-%d %H:%M:%S')
echo 1 > /sys/power/pm_print_times
rtcwake -m no -s "$SECS" || fail "rtcwake"
echo "Suspending now; RTC wake in ${SECS}s. Hands off for 10 s."
sync
systemctl suspend
# Wait for the suspend job to run and finish (max SECS+600 s).
sleep 5
for ((i = 0; i < SECS + 600; i++)); do
  [[ $(systemctl show systemd-suspend.service -p ActiveState --value) == inactive ]] && \
    journalctl -k --since "$START" | grep -q 'PM: suspend exit' && break
  sleep 1
done
sleep 20   # let Wi-Fi/Thunderbolt settle
echo 0 > /sys/power/pm_print_times
echo 0 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null
snap after
journalctl -b --since "$START" -o short-precise --no-pager > "$OUT/journal.log"
journalctl -k -b --since "$START" -o short-monotonic --no-pager > "$OUT/kernel.log"
grep -E 'PM: suspend (entry|exit)|noirq resume|Timekeeping suspended|macbook-sleep|thunderbolt-remove-rescan|Unable to change power|not ready|brcmf_c_preinit|brcmf_msgbuf_query_dcmd|Direct firmware load' \
  "$OUT/journal.log" > "$OUT/summary.txt"
chown -R me:me "$OUT"
cat "$OUT/summary.txt"
echo "Saved: $OUT"
