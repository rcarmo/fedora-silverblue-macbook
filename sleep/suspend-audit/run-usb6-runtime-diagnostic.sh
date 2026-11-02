#!/usr/bin/bash
# One approved transient root-hub-only PM diagnostic; no system sleep/reset.
set -euo pipefail
exec /usr/bin/pkexec /usr/bin/systemd-inhibit --what=sleep --mode=block --who=MacBook-USB-audit --why='Brief attended USB root-hub diagnostic' /usr/bin/systemd-run --unit=macbook-usb6-runtime-audit --collect --wait --pipe --service-type=exec /usr/bin/python3 -I -c '
import datetime, json, pathlib, signal, subprocess, time

def read(p): return pathlib.Path(p).read_text().strip()
def require(ok,msg):
    if not ok: raise SystemExit("REFUSED: " + msg)
def command(*args): return subprocess.check_output(args, text=True, timeout=15)
def stamp(): return datetime.datetime.now().astimezone().isoformat()

usb=pathlib.Path("/sys/bus/usb/devices/usb6")
pci=pathlib.Path("/sys/bus/pci/devices/0000:7c:00.0")
expected="/sys/devices/pci0000:00/0000:00:1d.0/0000:79:00.0/0000:7a:02.0/0000:7c:00.0/usb6"
require(read("/proc/sys/kernel/random/boot_id")=="<uuid>", "boot changed")
require(read("/sys/class/dmi/id/product_name")=="MacBookPro13,2", "model changed")
require(command("/usr/bin/uname","-r").strip()=="7.2.13-200.fc44.x86_64", "kernel changed")
s=json.loads(command("/usr/bin/rpm-ostree","status","--json"))
require(not s.get("transaction") and not any(d.get("staged") for d in s["deployments"]), "transaction/staged deployment")
require(s["deployments"][0].get("booted") and s["deployments"][0]["checksum"]=="39e497fbe6383c8b5c9dda53c1bdaab1e3e77291c81cef20ceace9017ab5c936", "deployment changed")
require(str(usb.resolve())==expected,"root-hub topology changed")
require(read(usb/"idVendor")=="1d6b" and read(usb/"idProduct")=="0003", "not expected USB3 root hub")
require(read(pci/"vendor")=="0x8086" and read(pci/"device")=="0x15d4", "PCI identity changed")
require((pci/"driver").resolve().name=="xhci_hcd", "controller binding changed")
require(read("/sys/module/apple_ibridge/parameters/skip_acpi_power")=="1", "Touch Bar guard changed")
require(read("/sys/power/pm_test").startswith("[none]") and read("/sys/power/pm_print_times")=="0", "PM diagnostic flags changed")
require(command("/usr/bin/systemctl","show","systemd-suspend.service","-p","ActiveState","--value").strip()=="inactive", "sleep service active")
# No attached external USB data devices: do not disturb storage or a working network.
for d in pathlib.Path("/sys/bus/usb/devices").iterdir():
    if ":" in d.name or d.name.startswith("usb") or not (d/"idVendor").exists(): continue
    require(d.name=="1-3" and read(d/"idVendor")=="05ac" and read(d/"idProduct")=="8600", "external USB device detected; re-audit before policy change")
original=read(usb/"power/control")
require(original=="auto" and read(usb/"power/runtime_status")=="suspended", "hub no longer auto/suspended")
require(read(pci/"power/control")=="auto", "PCI policy changed")

def snapshot(label):
    print(stamp(),label,flush=True)
    for d in (usb,pci):
        print(str(d),"control="+read(d/"power/control"),"runtime="+read(d/"power/runtime_status"),flush=True)
    print(command("/usr/bin/lsusb"),flush=True)
    print(command("/usr/bin/nmcli","device","status"),flush=True)

def interrupted(sig,frame): raise KeyboardInterrupt("interrupted")
for sig in (signal.SIGINT,signal.SIGTERM,signal.SIGHUP): signal.signal(sig,interrupted)
snapshot("BEFORE")
try:
    print(stamp(),"WRITE ONLY usb6/power/control: auto -> on",flush=True)
    (usb/"power/control").write_text("on\n")
    require(read(usb/"power/control")=="on","write readback failed")
    snapshot("AFTER WRITE")
    time.sleep(5)
    snapshot("AFTER 5 SECONDS")
    time.sleep(10)
    snapshot("AFTER 15 SECONDS")
finally:
    # Do not let an extra interrupt prevent restoration.
    for sig in (signal.SIGINT,signal.SIGTERM,signal.SIGHUP): signal.signal(sig,signal.SIG_IGN)
    require(str(usb.resolve())==expected,"topology changed before restoration")
    (usb/"power/control").write_text(original+"\n")
    require(read(usb/"power/control")==original,"RESTORATION FAILED")
    print(stamp(),"RESTORED usb6/power/control="+original,flush=True)
snapshot("AFTER RESTORATION")
print("Root-hub diagnostic ended; no connectivity or system sleep claim.",flush=True)
'
