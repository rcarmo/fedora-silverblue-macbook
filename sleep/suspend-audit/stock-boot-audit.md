# Stock comparison: post-boot audit — 2026-11-01, 08:48–08:50 WET

## Verified
- Boot ID `5e39fd98c9a14bbebcbc687a0b949f41`, boot beginning 08:47:18 WET.
- Booted checksum `f1365bcef08f98f305177529b4132dbef7c2a4d4ad1fc38de9b24fc85c306517`, serial 0, pinned, stock Fedora 44.20261031.0.
- Same kernel as failed custom-driver trials: `7.2.13-200.fc44.x86_64`.
- rpm-ostree idle, no staged deployment. Order unchanged: recovery c4ebdd8, FAILED Wi-Fi trial b0a3115, pinned custom baseline 43e45ec, booted pinned stock f1365bc, pinned original b8e75b7. No rollback/deployment changes performed.
- Stock `snd_hda_codec_cs8409` selected from `kernel/sound/hda/codecs/cirrus/snd-hda-codec-cs8409.ko.xz`, loaded with generic parser. `apple_ibridge` and `apple_touchbar` absent from modinfo and loaded-module list. No driver installation or device reload performed. Loss of custom audio/Touch Bar is expected during this comparison.
- Native applespi loaded; keyboard and touchpad input devices present. i915 loaded; UVC iBridge camera detected in kernel log. Physical camera/audio/other-device operation not retested.
- NetworkManager reports wlp2s0 connected. Internet/5 GHz/pairing not tested.
- Battery about 74.5%, DISCHARGING; `/sys/class/power_supply/ADP1/online` reads 0. Connect charger before a controlled test.

## Sleep comparison is NOT armed
- `/sys/power/mem_sleep`: `s2idle [deep]`.
- Merged sleep.conf contains only stock commented defaults; no local sleep override or sleep hooks found. Recovery's s2idle drop-in is NOT active on stock.
- `/sys/power/pm_test`: `[none] core processors platform devices freezer`; no PM diagnostic armed.
- GNOME AC and battery automatic-suspend types remain `suspend`, each timeout 900 seconds. No containment applied. Keep lid open and remain active; an awake laptop must not go in a bag.
- No recorded suspend entry/exit in current kernel journal at audit. No suspend/reboot/privileged system change initiated.

## User-selected next test — normal/deep on battery; outcome PENDING
User requested normal suspend first, then explicitly reported readiness but no charger. This is a valid comparison against the earlier failed custom-driver DEEP test. It does not match the failed s2idle test. No s2idle setting has been installed on stock.

Pre-test recheck around 08:50–08:51 WET confirms same stock boot/checksum, rpm-ostree idle/no staged deployment, no sleep override, `s2idle [deep]`, PM test `none`, no prior suspend entry/exit, battery 74.3% discharging and adapter online=0. Battery charge is sufficient for one short attended test, though AC is unavailable; record this as a battery trial.

Giving user instructions to unplug headphones, close lid for 15 seconds, then open it and check responsiveness. Another forced restart remains possible. No assistant-triggered suspend or reboot. Result is pending; do not assume the test has happened. Success requires actual DEEP entry AND suspend exit logs, responsive display/input, and device checks; absence of custom drivers does not prove any individual culprit. Stop repeated attempts if it fails.

For return to recovery, recheck boot menu identities/environment and arrange menu visibility if needed. Recovery remains index 0 at audit; NEVER blindly rollback into failed Wi-Fi trial index 1. No GRUB environment/default behavior was audited in this session yet.

## Evidence
- `stock-boot-deployments.json`
- `stock-boot-kernel.log`
- `stock-boot-sleep-config.txt`
