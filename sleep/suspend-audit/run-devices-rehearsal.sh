#!/usr/bin/bash
# ONE user-triggered devices rehearsal; no flags are left armed in advance.
# Reviewed scope: pm_print_times, pm_test, and one standard suspend.target start.
# No driver resets, PCI policy, sleep config, firmware, or deployment changes.
set -euo pipefail
exec /usr/bin/pkexec /usr/bin/systemd-run --unit=macbook-devices-rehearsal --collect --wait --pipe --service-type=exec /usr/bin/python3 -I -c '
import json, pathlib, re, signal, subprocess, sys, time

def read(path):
    return pathlib.Path(path).read_text().strip()
def command(*args):
    return subprocess.check_output(args, text=True)
def require(ok, message):
    if not ok:
        raise SystemExit("REFUSED: " + message)
def write(path, value):
    pathlib.Path(path).write_text(value + "\n")

require(read("/proc/sys/kernel/random/boot_id") == "<uuid>", "boot changed; re-audit")
require(read("/sys/class/dmi/id/product_name") == "MacBookPro13,2", "unexpected model")
require(command("/usr/bin/uname", "-r").strip() == "7.2.13-200.fc44.x86_64", "kernel changed")
status = json.loads(command("/usr/bin/rpm-ostree", "status", "--json"))
require(not status.get("transaction") and not any(d.get("staged") for d in status["deployments"]), "deployment transaction/staging present")
require(status["deployments"][0].get("booted") and status["deployments"][0]["checksum"] == "39e497fbe6383c8b5c9dda53c1bdaab1e3e77291c81cef20ceace9017ab5c936", "deployment changed")
require(read("/sys/module/apple_ibridge/parameters/skip_acpi_power") == "1", "Touch Bar guard changed")
battery = command("/usr/bin/upower", "-i", "/org/freedesktop/UPower/devices/battery_BAT0")
percentage = re.search(r"percentage:\s*([0-9.]+)%", battery)
require(percentage and float(percentage[1]) >= 25, "usable battery below 25% or unavailable")
require(re.search(r"warning-level:\s*none", battery), "battery warning present")
config = command("/usr/bin/systemd-analyze", "cat-config", "systemd/sleep.conf")
settings = {}
for line in config.splitlines():
    line = line.strip()
    if line and not line.startswith(("#", ";", "[")) and "=" in line:
        key, value = line.split("=", 1)
        settings[key.strip()] = value.strip()
require(settings.get("SuspendState") == "mem" and settings.get("MemorySleepMode") == "s2idle", "effective sleep mode changed")
require(command("/usr/bin/systemctl", "show", "systemd-suspend.service", "-p", "ActiveState", "--value").strip() == "inactive", "sleep service not idle")
require(read("/sys/power/pm_test").startswith("[none]"), "PM diagnostic already active")
require(read("/sys/power/pm_print_times") == "0", "callback timing baseline changed")
require(read("/sys/module/suspend/parameters/pm_test_delay") == "5", "test delay changed")
require("[none]" in read("/sys/power/pm_test") and "devices" in read("/sys/power/pm_test"), "devices rehearsal unavailable")

# Keep the supervisor in the system slice, NOT the frozen user.slice.
# Prevent a terminal interrupt from restoring pm_test before the queued
# transition has reached its devices checkpoint. A hard hang requires reboot.
for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
    signal.signal(sig, signal.SIG_IGN)
print("One devices rehearsal: battery " + percentage[1] + "%; s2idle; delay 5s.", flush=True)
print("Keep lid open. Do not interrupt/repeat. Allow up to 3 minutes for recovery.", flush=True)
started = time.time()
try:
    write("/sys/power/pm_print_times", "1")
    write("/sys/power/pm_test", "devices")
    require("[devices]" in read("/sys/power/pm_test"), "failed to arm devices-only checkpoint")
    # Unlike systemctl suspend (asynchronous), start waits for the oneshot
    # systemd-suspend.service dependency to complete, including resume/hooks.
    result = subprocess.run(["/usr/bin/systemctl", "start", "suspend.target"])
    print("Suspend target returned: exit=" + str(result.returncode) + ", elapsed=" + str(round(time.time()-started, 2)) + "s", flush=True)
finally:
    write("/sys/power/pm_test", "none")
    write("/sys/power/pm_print_times", "0")
    require("[none]" in read("/sys/power/pm_test") and read("/sys/power/pm_print_times") == "0", "diagnostic flag restoration failed")
    print("RESTORED: pm_test=none, pm_print_times=0", flush=True)
print("Rehearsal ended, NOT proof of real sleep/wake. Return to the audit before another test.", flush=True)
'
