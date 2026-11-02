#!/usr/bin/bash
# ONE attended S3 test with automatic RTC wake (current setup). Results -> sleep/tests/test-<time>/
#   pkexec /usr/bin/bash /var/home/me/macbook-fedora-audit/tools/run-s3-test.sh 120
# Before: work saved, charger in (or battery >= 30%), NOTHING else in the USB-C ports, lid OPEN.
# Don't touch the machine for the first ~10 s after it goes dark.
set -uo pipefail
export PATH=/usr/sbin:/usr/bin
SECS=${1:-120}
NOLID=0; ALLOW_DEAD_TB=0; NOHDA=0; NOWAKE=()
for o in "${@:2}"; do case $o in nolid) NOLID=1;; nowake=*) NOWAKE+=("${o#nowake=}");; nohda) NOHDA=1;; allow-dead-tb) ALLOW_DEAD_TB=1;; *) echo "unknown option $o" >&2; exit 2;; esac; done
# Options: nolid = disable LID0 (GPE 0x6F) S3 wake for this test only (keyboard/power button still wake);
#          nohda = unbind the HDA controller 00:1f.3 before the test (no audio until REBOOT; never rebind after a sleep);
#          nowake=DEV = disable /proc/acpi/wakeup device DEV (e.g. SPIT = keyboard/trackpad) for this test only;
#          allow-dead-tb = run although the Alpine Ridge xHCIs are gone (after an instant wake).
W=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
OUT=$W/sleep/tests/test-$(date +%Y%m%d-%H%M%S)
fail() { echo "REFUSED: $*" >&2; exit 1; }
[[ $EUID == 0 ]] || fail "needs root"
[[ $SECS =~ ^[0-9]+$ ]] && (( SECS >= 60 && SECS <= 1800 )) || fail "seconds must be 60..1800"
[[ $(</sys/class/dmi/id/product_name) == MacBookPro13,2 ]] || fail "model"
grep -qw 'firmware_class.path=/etc/firmware/macbook-wifi' /proc/cmdline || fail "firmware_class.path karg not active (reboot first)"
[[ -x /usr/local/sbin/macbook-sleep-hook && -x /usr/local/sbin/macbook-thunderbolt-remove-rescan ]] || fail "hooks missing"
cmp -s /usr/local/sbin/macbook-sleep-hook "$W"/rebuild-kit/files/usr/local/sbin/macbook-sleep-hook || fail "installed hook != rebuild-kit copy"
[[ -e /sys/bus/usb/devices/1-3/product ]] || fail "iBridge (usb 1-3) missing - reboot first"
(( ALLOW_DEAD_TB || $(ls /sys/bus/pci/drivers/xhci_hcd | grep -c 0000) >= 3 )) || fail "USB-C xHCI controllers missing - reboot, or pass allow-dead-tb"
systemctl cat systemd-suspend.service | grep -q 'macbook-sleep-hook pre' || fail "suspend drop-in missing"
systemd-analyze cat-config systemd/sleep.conf | grep -qx 'MemorySleepMode=deep' || fail "deep not configured"
[[ $(</sys/bus/pci/devices/0000:01:00.0/d3cold_allowed) == 0 ]] || fail "NVMe d3cold_allowed != 0"
[[ $(</sys/module/apple_ibridge/parameters/skip_acpi_power) == 1 ]] || fail "Touch Bar guard"
if [[ $(</sys/class/power_supply/ADP1/online) == 1 ]]; then POWER=AC
else POWER=battery; (( $(</sys/class/power_supply/BAT0/capacity) >= 30 )) || fail "on battery below 30% - connect the charger"; fi
echo "Power: $POWER ($(</sys/class/power_supply/BAT0/capacity)%)"
[[ $(</sys/power/pm_test) == *'[none]'* ]] || fail "pm_test not none"
# No external USB devices on the Alpine Ridge (USB-C) controllers.
for d in /sys/bus/usb/devices/*; do
  [[ -e $d/idVendor && ${d##*/} != usb* && ${d##*/} != *:* ]] || continue
  p=$(readlink -f "$d")
  [[ $p == */0000:00:14.0/* ]] || fail "USB device ${d##*/} ($(cat $d/idVendor):$(cat $d/idProduct)) on a USB-C controller - unplug it"
done
mounts=$(lsblk -nrpo TRAN,MOUNTPOINT | awk '$1=="usb" && $2!=""')
[[ -z $mounts ]] || fail "USB storage mounted"

mkdir -p "$OUT"; chown "$(stat -c %U "$W")": "$OUT"; echo "$POWER $(</sys/class/power_supply/BAT0/capacity)%" > "$OUT/power.txt"
snap() {
  { date --iso-8601=ns; cat /sys/power/mem_sleep; cat /proc/cmdline
    ls /sys/bus/pci/drivers/xhci_hcd | grep 0000; ls /sys/bus/pci/devices | wc -l
    for u in /sys/bus/usb/devices/usb*; do echo "${u##*/} $(cat $u/idProduct) $(cat $u/power/control)"; done
    nmcli -t -f DEVICE,STATE,CONNECTION device; iw dev 2>/dev/null | grep -E 'Interface|channel|ssid'
    iw phy 2>/dev/null | grep -E 'Band [12]:'
    lsmod | grep -E '^(apple_|brcmfmac|applespi|snd_hda_codec_cs8409)'
    cat /sys/power/suspend_stats/success /sys/power/suspend_stats/fail 2>/dev/null
    echo "pm_wakeup_irq=$(cat /sys/power/pm_wakeup_irq 2>/dev/null)"; cat /proc/acpi/wakeup
    for g in /sys/firmware/acpi/interrupts/gpe* /sys/firmware/acpi/interrupts/sci*; do
      v=$(cat "$g"); [[ ${v%% *} == 0 ]] || echo "${g##*/}: $v"; done
    cat /sys/bus/usb/devices/1-3/{product,bConfigurationValue,power/runtime_status} 2>/dev/null
    ls -l /sys/bus/hid/devices/*/driver 2>/dev/null
  } > "$OUT/$1.txt" 2>&1
}
snap before
START=$(date '+%Y-%m-%d %H:%M:%S')
echo 1 > /sys/power/pm_print_times
echo 1 > /sys/power/pm_debug_messages
lidwake() { grep -q '^LID0.*enabled' /proc/acpi/wakeup && echo enabled || echo disabled; }
devwake() { awk -v d="$1" '$1==d {print ($3 ~ /enabled/) ? "enabled" : "disabled"}' /proc/acpi/wakeup; }
RESTORE=()
for d in "${NOWAKE[@]}"; do
  [[ $(devwake "$d") == enabled ]] && { echo "$d" > /proc/acpi/wakeup; RESTORE+=("$d"); }
  echo "$d wake for this test: $(devwake "$d")"
done
restore_wake() { for d in "${RESTORE[@]}"; do [[ $(devwake "$d") == disabled ]] && echo "$d" > /proc/acpi/wakeup; echo "$d wake restored: $(devwake "$d")"; done; RESTORE=(); }
trap restore_wake EXIT
if (( NOLID )); then
  [[ $(lidwake) == enabled ]] && echo LID0 > /proc/acpi/wakeup   # toggles
  trap 'restore_wake; [[ $(lidwake) == disabled ]] && echo LID0 > /proc/acpi/wakeup' EXIT
  echo "LID0 wake for this test: $(lidwake)"
fi
if (( NOHDA )) && [[ -e /sys/bus/pci/drivers/snd_hda_intel/0000:00:1f.3 ]]; then
  echo 0000:00:1f.3 > /sys/bus/pci/drivers/snd_hda_intel/unbind && echo "HDA controller unbound for this test (audio returns after reboot)"
fi
echo "options: nowake=${NOWAKE[*]} nolid=$NOLID nohda=$NOHDA allow-dead-tb=$ALLOW_DEAD_TB lid0=$(lidwake) hda=$([[ -e /sys/bus/pci/drivers/snd_hda_intel/0000:00:1f.3 ]] && echo bound || echo unbound)" >> "$OUT/power.txt"
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
echo 0 > /sys/power/pm_debug_messages
echo 0 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null
restore_wake
if (( NOLID )); then [[ $(lidwake) == disabled ]] && echo LID0 > /proc/acpi/wakeup; echo "LID0 wake restored: $(lidwake)"; fi
snap after
journalctl -b --since "$START" -o short-precise --no-pager > "$OUT/journal.log"
journalctl -k -b --since "$START" -o short-monotonic --no-pager > "$OUT/kernel.log"
grep -E 'LID0|SPIT|PM: suspend (entry|exit)|PM: Wakeup|PM: Triggering|wakeup IRQ|ACPI: PM: Wak|Low-level resume|Touchbar|noirq resume|Timekeeping suspended|macbook-sleep|thunderbolt-remove-rescan|macbook_t1_socw|SOCW|apple-touchbar|Unable to change power|not ready|brcmf_c_preinit|brcmf_msgbuf_query_dcmd|Direct firmware load' \
  "$OUT/journal.log" > "$OUT/summary.txt"
chown -R "$(stat -c %U "$W")": "$OUT"
cat "$OUT/summary.txt"
echo "Saved: $OUT"
