#!/usr/bin/bash
# Reviewed persistent workaround: TWO /etc files + enabled boot replay service.
# No global trigger, PCI write, initramfs regeneration, sleep, driver reset.
set -euo pipefail
exec /usr/bin/pkexec /usr/bin/python3 -I -c '
import hashlib, json, os, pathlib, subprocess, tempfile, datetime

def read(p): return pathlib.Path(p).read_text().strip()
def require(ok,msg):
    if not ok: raise SystemExit("REFUSED: "+msg)
def run(*args): return subprocess.run(args,check=True,text=True,timeout=45)
def output(*args): return subprocess.check_output(args,text=True,timeout=15)
require(read("/proc/sys/kernel/random/boot_id")=="<uuid>","boot changed")
require(read("/sys/class/dmi/id/product_name")=="MacBookPro13,2","model changed")
require(output("/usr/bin/uname","-r").strip()=="7.2.13-200.fc44.x86_64","kernel changed")
s=json.loads(output("/usr/bin/rpm-ostree","status","--json"))
require(not s.get("transaction") and not any(d.get("staged") for d in s["deployments"]),"transaction/staged deployment")
require(s["deployments"][0].get("booted") and s["deployments"][0]["checksum"]=="39e497fbe6383c8b5c9dda53c1bdaab1e3e77291c81cef20ceace9017ab5c936","deployment changed")
require(read("/sys/module/apple_ibridge/parameters/skip_acpi_power")=="1","Touch Bar guard changed")
require(read("/sys/power/pm_test").startswith("[none]") and read("/sys/power/pm_print_times")=="0","PM diagnostic active")
require(output("/usr/bin/systemctl","show","systemd-suspend.service","-p","ActiveState","--value").strip()=="inactive","sleep active")
hub=pathlib.Path("/sys/bus/usb/devices/usb6")
pci=pathlib.Path("/sys/bus/pci/devices/0000:7c:00.0")
expected="/sys/devices/pci0000:00/0000:00:1d.0/0000:79:00.0/0000:7a:02.0/0000:7c:00.0/usb6"
require(str(hub.resolve())==expected and read(hub/"idVendor")=="1d6b" and read(hub/"idProduct")=="0003","hub identity changed")
require(read(pci/"vendor")=="0x8086" and read(pci/"device")=="0x15d4" and (pci/"driver").resolve().name=="xhci_hcd","PCI identity/binding changed")
original=read(hub/"power/control")
require(original=="auto" and read(pci/"power/control")=="auto","policy changed")
# Existing working adapter allowed; no USB storage or other external devices.
for d in pathlib.Path("/sys/bus/usb/devices").iterdir():
    if ":" in d.name or d.name.startswith("usb") or not (d/"idVendor").exists(): continue
    require((d.name=="1-3" and read(d/"idVendor")=="05ac" and read(d/"idProduct")=="8600") or (d.name=="6-2" and read(d/"idVendor")=="0bda" and read(d/"idProduct")=="8153"),"unexpected USB device; review attached devices")
unit="macbook-right-usb3-runtime.service"
files=[("99-macbook-right-usb3-runtime.rules","/etc/udev/rules.d/99-macbook-right-usb3-runtime.rules","96a25429a5879959a6e70f92a21b70eb6c448de11ed4631060bb299a3d5f708a"),(unit,"/etc/systemd/system/"+unit,"3e0806921421a637348714228ab991c9394c8bd7d336a1c89657f56816b8952e")]
data=[]
for source,dest,digest in files:
    p=pathlib.Path(dest)
    require(not p.exists() and not p.is_symlink(),"destination exists: "+dest)
    b=(pathlib.Path("/var/home/me/macbook-fedora-audit/sleep/suspend-audit")/source).read_bytes()
    require(hashlib.sha256(b).hexdigest()==digest,"reviewed source hash changed: "+source)
    data.append(b)
require(output("/usr/bin/systemctl","show",unit,"-p","LoadState","--value").strip()=="not-found","unit already provided")
require(not pathlib.Path("/etc/systemd/system/multi-user.target.wants/"+unit).is_symlink(),"enable link already exists")
run("/usr/bin/udevadm","verify","/var/home/me/macbook-fedora-audit/sleep/suspend-audit/99-macbook-right-usb3-runtime.rules")
# Preserve a root-owned receipt; no earlier recovery state is reused/overwritten.
receipt=pathlib.Path(tempfile.mkdtemp(prefix="macbook-usb-runtime-",dir="/var/lib"))
(receipt/"before.json").write_text(json.dumps({"boot":read("/proc/sys/kernel/random/boot_id"),"hub":expected,"original_control":original,"files":[x[1] for x in files]},indent=2)+"\n")
installed=[]
try:
    for (_,dest,_),b in zip(files,data):
        fd,tmp=tempfile.mkstemp(prefix=".macbook-usb-",dir=str(pathlib.Path(dest).parent))
        try:
            with os.fdopen(fd,"wb") as f:
                os.fchmod(f.fileno(),0o644); f.write(b); f.flush(); os.fsync(f.fileno())
            os.replace(tmp,dest); installed.append(dest)
            run("/usr/sbin/restorecon",dest)
        finally:
            if os.path.exists(tmp): os.unlink(tmp)
    run("/usr/bin/udevadm","verify",files[0][1])
    run("/usr/bin/systemd-analyze","verify",files[1][1])
    run("/usr/bin/udevadm","control","--reload-rules")
    run("/usr/bin/systemctl","daemon-reload")
    run("/usr/bin/systemctl","enable","--now",unit)
    require(read(hub/"power/control")=="on","rule did not apply")
    require(output("/usr/bin/systemctl","is-enabled",unit).strip()=="enabled","service not enabled")
    require(output("/usr/bin/systemctl","is-active",unit).strip()=="active","service not active")
    for (_,dest,digest) in files:
        require(hashlib.sha256(pathlib.Path(dest).read_bytes()).hexdigest()==digest,"installed bytes changed")
    (receipt/"success.json").write_text(json.dumps({"time":datetime.datetime.now().astimezone().isoformat(),"files":files,"control":read(hub/"power/control"),"enabled":True},indent=2)+"\n")
    print("INSTALLED + ENABLED: only tested right-side USB3 root-hub workaround",flush=True)
    print("Root receipt: "+str(receipt),flush=True)
except BaseException:
    subprocess.run(["/usr/bin/systemctl","disable","--now",unit],timeout=45)
    for dest in installed:
        pathlib.Path(dest).unlink(missing_ok=True)
    subprocess.run(["/usr/bin/systemctl","daemon-reload"],timeout=45)
    subprocess.run(["/usr/bin/udevadm","control","--reload-rules"],timeout=45)
    if str(hub.resolve())==expected: (hub/"power/control").write_text(original+"\n")
    print("Install failed; removed only newly installed files/link and restored hub policy. Receipt: "+str(receipt),flush=True)
    raise
'
