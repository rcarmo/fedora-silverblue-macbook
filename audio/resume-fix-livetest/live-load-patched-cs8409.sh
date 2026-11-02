#!/usr/bin/bash
# Live-load the patched CS8409 codec module (0.1.20261101, not persistent; reboot = packaged r2 module again).
# pkexec /usr/bin/bash /var/home/me/macbook-fedora-audit/audio/resume-fix-livetest/live-load-patched-cs8409.sh
set -euo pipefail
export PATH=/usr/sbin:/usr/bin
H=/var/home/me/macbook-fedora-audit/audio/resume-fix-livetest
D=0000:00:1f.3
[[ $EUID == 0 ]] || { echo "needs root" >&2; exit 1; }
cd "$H"; sha256sum -c --status SHA256SUMS || { echo "hash changed" >&2; exit 1; }
[[ $(modinfo -F vermagic ./snd-hda-codec-cs8409.ko | awk '{print $1}') == $(uname -r) ]] || { echo "vermagic" >&2; exit 1; }
[[ -e /sys/bus/pci/drivers/snd_hda_intel/$D ]] && echo "$D" > /sys/bus/pci/drivers/snd_hda_intel/unbind
sleep 1
modprobe -r snd_hda_codec_cs8409
modprobe snd_hda_codec_generic; modprobe snd_hda_scodec_component
insmod ./snd-hda-codec-cs8409.ko || { echo "insmod failed; restoring packaged module" >&2; modprobe snd_hda_codec_cs8409; }
echo "$D" > /sys/bus/pci/drivers/snd_hda_intel/bind
sleep 5
echo "codec driver: $(basename "$(readlink /sys/bus/hdaudio/devices/hdaudioC0D0/driver)")"
echo "resume_reinit: $(cat /sys/module/snd_hda_codec_cs8409/parameters/resume_reinit)"
journalctl -k --since -20s | grep -E 'cs8409|WARNING|failed' | grep -v myprintk | tail -5 || true
