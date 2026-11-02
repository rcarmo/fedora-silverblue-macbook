#!/bin/bash
# Awake Wi-Fi unbind/rebind check (Phase 1 step 2). Run: pkexec /usr/bin/bash <this>
# Launches the worker as a transient systemd unit so it completes even if the
# caller (AI session / terminal) loses network or is killed. Worker ALWAYS
# rebinds (EXIT trap). Log: /var/log/macbook-wifi-rebind-test.log (+ copy here).
set -u
[[ $EUID == 0 ]] || { echo "run via pkexec" >&2; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)
LOG=/var/log/macbook-wifi-rebind-test.log
W=/run/macbook-wifi-rebind-worker.sh
UNIT=macbook-wifi-rebind-test
: > "$LOG"

cat > "$W" <<'EOF'
#!/bin/bash
set -u
LOG=/var/log/macbook-wifi-rebind-test.log
DRV=/sys/bus/pci/drivers/brcmfmac
A=""
log() { echo "$(date +%T.%3N) $*" >> "$LOG"; logger -t macbook-wifi-test -- "$*"; }
rebind() {
  [[ -n $A ]] || return 0
  if [[ ! -e /sys/bus/pci/devices/$A/driver ]]; then
    echo "$A" > "$DRV/bind" 2>>"$LOG" && log "rebound $A" || log "ERROR rebind $A failed"
  fi
}
trap 'rebind; log "worker exit"; echo DONE >> "$LOG"' EXIT
trap 'exit 1' TERM INT HUP
for d in /sys/bus/pci/devices/*; do
  [[ $(cat $d/vendor) == 0x14e4 && $(cat $d/device) == 0x43ba ]] && A=${d##*/}
done
[[ -n $A ]] || { log "ERROR BCM43602 not found"; exit 1; }
log "device $A driver=$(basename "$(readlink /sys/bus/pci/devices/$A/driver)")"
log "before: $(nmcli -t -f ACTIVE,SSID,FREQ dev wifi | grep '^yes')"
SINCE=$(date '+%Y-%m-%d %H:%M:%S')
echo "$A" > "$DRV/unbind" 2>>"$LOG" && log "unbound $A" || { log "ERROR unbind failed"; A=""; exit 1; }
sleep 3
rebind; A=""
# wait up to 90 s for NM to reconnect
for i in $(seq 1 90); do
  nmcli -t -f STATE general 2>/dev/null | grep -q '^connected' && break; sleep 1
done
sleep 2
log "after ${i}s: nm=$(nmcli -t -f STATE general) $(nmcli -t -f ACTIVE,SSID,FREQ dev wifi | grep '^yes')"
IF=$(ls /sys/bus/pci/devices/*/net 2>/dev/null | grep -m1 '^wl'); log "iface=$IF"
PHY=$(iw dev 2>/dev/null | awk '/^phy#/{print "phy"substr($1,5)}' | head -1)
log "Band2 enabled 5GHz channels: $(iw phy "$PHY" info 2>/dev/null | grep -E '\* 5[0-9]{3}' | grep -vc disabled)"
log "kernel since unbind:"
journalctl -k --since "$SINCE" --no-pager -q | grep -iE 'brcm|firmware|wlp|wlan' >> "$LOG"
ping -c2 -W3 1.1.1.1 >/dev/null 2>&1 && log "ping OK" || log "ping FAIL"
EOF
chmod 700 "$W"
systemctl reset-failed "$UNIT" 2>/dev/null
systemd-run --unit="$UNIT" --collect -q /usr/bin/bash "$W" || { echo "systemd-run failed"; exit 1; }
for i in $(seq 1 150); do grep -q '^DONE' "$LOG" && break; sleep 1; done
cp "$LOG" "$HERE/wifi-rebind-test.log"; chown --reference="$HERE" "$HERE/wifi-rebind-test.log"
cat "$LOG"
