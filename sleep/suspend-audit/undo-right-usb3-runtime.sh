#!/usr/bin/bash
# Undo only this workaround; never remove unrelated USB configuration.
set -euo pipefail
exec /usr/bin/pkexec /usr/bin/python3 -I -c '
import hashlib, pathlib, subprocess
unit="macbook-right-usb3-runtime.service"
files=[("/etc/udev/rules.d/99-macbook-right-usb3-runtime.rules","96a25429a5879959a6e70f92a21b70eb6c448de11ed4631060bb299a3d5f708a"),("/etc/systemd/system/"+unit,"3e0806921421a637348714228ab991c9394c8bd7d336a1c89657f56816b8952e")]
for name,digest in files:
    p=pathlib.Path(name)
    if p.is_symlink() or not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=digest:
        raise SystemExit("REFUSED: installed file differs or is absent; review before removal: "+name)
subprocess.run(["/usr/bin/systemctl","disable","--now",unit],check=True,timeout=45)
for name,_ in files: pathlib.Path(name).unlink()
subprocess.run(["/usr/bin/systemctl","daemon-reload"],check=True,timeout=45)
subprocess.run(["/usr/bin/udevadm","control","--reload-rules"],check=True,timeout=45)
# Restore baseline auto only on the exact reviewed USB3 root/PCI ancestor.
pci=pathlib.Path("/sys/bus/pci/devices/0000:7c:00.0")
if pci.exists() and (pci/"vendor").read_text().strip()=="0x8086" and (pci/"device").read_text().strip()=="0x15d4":
    for hub in pci.glob("usb*"):
        if not (hub/"idVendor").exists(): continue
        if (hub/"idVendor").read_text().strip()=="1d6b" and (hub/"idProduct").read_text().strip()=="0003" and (hub/"devpath").read_text().strip()=="0":
            (hub/"power/control").write_text("auto\n")
            if (hub/"power/control").read_text().strip()!="auto": raise SystemExit("Runtime policy restoration failed")
            print("RESTORED "+str(hub)+"/power/control=auto")
print("Removed only right-side USB3 workaround rule/service and enable link. Root receipt preserved.")
'
