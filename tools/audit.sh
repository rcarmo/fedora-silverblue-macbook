#!/usr/bin/bash
# Read-only consistency audit of the current driver set + sleep files. Run as root (initramfs, /var/lib).
# pkexec /usr/bin/bash /var/home/me/macbook-fedora-audit/tools/audit.sh
set -u
export PATH=/usr/sbin:/usr/bin LC_ALL=C
A=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
P=$A/packaging
TV=0.1.20261110
AV=0.1.20261101
rpm_dir() { local d=$P/rpms/$1; [[ -d $d ]] || d=$A/rebuild-kit/rpms; echo "$d"; }
skip() { echo "  skip $* (not in this checkout)"; }
KV=7.2.13-200.fc44.x86_64
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0
ok()   { echo "  OK   $*"; }
bad()  { echo "  FAIL $*"; fails=$((fails + 1)); }
chk()  { if eval "$1" >/dev/null 2>&1; then ok "$2"; else bad "$2"; fi; }
# code fingerprint: .text + .modinfo (+ .rodata) of the (decompressed) module; build-path independent
fp() { local f=$1 k="$T/fp.$$.ko"; [[ -f $f ]] || { echo none; return; }
  case $f in *.xz) xz -dc "$f" > "$k" 2>/dev/null;; *) cp "$f" "$k";; esac
  [[ -s $k ]] && readelf -h "$k" >/dev/null 2>&1 || { rm -f "$k"; echo unreadable; return; }
  local out="" sec h
  for sec in .text .modinfo .rodata; do
    rm -f "$k.sec"; objcopy -O binary --only-section=$sec "$k" "$k.sec" 2>/dev/null
    [[ -s $k.sec ]] || { rm -f "$k" "$k.sec"; echo unreadable; return; }
    h=$(sha256sum < "$k.sec" | cut -c1-8); out+="${out:+-}$h"
  done; rm -f "$k" "$k.sec"; echo "$out"; }

# Deployment to audit: the staged one if any, else the booted one ("staged" below = that target)
STAGED=$(rpm-ostree status --json | python3 -c 'import json,sys; d=json.load(sys.stdin)["deployments"]; s=[x for x in d if x.get("staged")] or [x for x in d if x.get("booted")]; print(s[0]["checksum"])')
TARGET_KIND=$(rpm-ostree status --json | python3 -c 'import json,sys; print("staged" if any(x.get("staged") for x in json.load(sys.stdin)["deployments"]) else "booted")')
echo "Auditing $TARGET_KIND deployment ${STAGED:0:12}"

echo "== A. sources / patches / tarballs / specs / SRPMs"
for pkg in macbook-t1-touchbar macbook-cs8409; do
  ver=$AV; [[ $pkg == macbook-t1-touchbar ]] && ver=$TV
  RPMDIR=$(rpm_dir "$ver")
  old=$P/sources/$pkg-0.1.20261031 new=$P/sources/$pkg-$ver
  mkdir -p "$T/tar-$pkg"; tar -xzf "$P/tarballs/$pkg-$ver.tar.gz" -C "$T/tar-$pkg"
  chk "diff -r '$new' '$T/tar-$pkg/$pkg-$ver'" "$pkg: local tarball == source dir"
  echo "       changed files vs 0.1.20261031: $(diff -rq "$old" "$new" | sed -E "s#$P/sources/##g; s#Files ([^ ]+) and [^ ]+ differ#\1#; s#Only in ([^:]+): #+\1/#" | tr '\n' ' ')"
  # SRPM embedded in the akmod RPM that rpm-ostree layered
  mkdir -p "$T/akmod-$pkg" && (cd "$T/akmod-$pkg" && rpm2cpio "$RPMDIR/akmod-$pkg-$ver-1.fc44.x86_64.rpm" | cpio -idm --quiet)
  srpm=$(ls "$T/akmod-$pkg"/usr/src/akmods/*.src.rpm)
  mkdir -p "$T/srpm-$pkg" && (cd "$T/srpm-$pkg" && rpm2cpio "$srpm" | cpio -idm --quiet)
  chk "[[ \$(basename '$srpm') == $pkg-kmod-$ver-1.fc44.src.rpm ]]" "$pkg: akmod embeds SRPM $(basename "$srpm")"
  chk "cmp '$T/srpm-$pkg/$pkg-$ver.tar.gz' '$P/tarballs/$pkg-$ver.tar.gz'" "$pkg: SRPM tarball == local tarball"
  chk "cmp '$T/srpm-$pkg/$pkg-kmod.spec' '$P/$pkg-kmod.spec'" "$pkg: SRPM spec == packaging/$pkg-kmod.spec"
done
cp -a $P/sources/macbook-t1-touchbar-0.1.20261031 "$T/p1" && (cd "$T/p1" && patch -s -p1 < $P/patches/0001-appletb-reset-resume-invalidate-cached-mode.patch)
chk "cmp '$T/p1/apple-touchbar.c' '$P/sources/macbook-t1-touchbar-0.1.20261101/apple-touchbar.c'" "patch 0001 reproduces apple-touchbar.c"
cp -a $P/sources/macbook-cs8409-0.1.20261031 "$T/p2" && (cd "$T/p2/hda/codecs/cirrus" && patch -s -p4 < $P/patches/0002-cs8409-apple-probe-op-and-resume-reinit.patch)
chk "cmp '$T/p2/hda/codecs/cirrus/cirrus_apple.h' '$P/sources/macbook-cs8409-0.1.20261101/hda/codecs/cirrus/cirrus_apple.h'" "patch 0002 reproduces cirrus_apple.h"
chk "cmp '$A/touchbar/t1-socw/macbook_t1_socw.c' '$P/sources/macbook-t1-touchbar-$TV/macbook_t1_socw.c'" "touchbar/t1-socw/macbook_t1_socw.c == packaged copy"
cp -a "$P/sources/macbook-t1-touchbar-0.1.20261101" "$T/p3" && (cd "$T/p3" && patch -s -p1 < "$P/patches/0003-appletb-t1-idle-mode-off.patch")
chk "cmp '$T/p3/apple-touchbar.c' '$P/sources/macbook-t1-touchbar-$TV/apple-touchbar.c'" "patch 0003 reproduces T1 idle fix"
for ver in "$TV" "$AV"; do
  [[ -f $P/rpms/$ver/SHA256SUMS ]] && chk "(cd '$P/rpms/$ver' && sha256sum -c --quiet SHA256SUMS)" "packaging/rpms/$ver SHA256SUMS" || skip "packaging/rpms/$ver"
done

echo "== B. module code fingerprints (.text-.modinfo-.rodata): staged / akmods test / live-loaded / fallback"
declare -A FP
for m in macbook-t1-touchbar/apple-touchbar macbook-t1-touchbar/apple-ibridge macbook-t1-touchbar/macbook_t1_socw macbook-cs8409/snd-hda-codec-cs8409; do
  n=${m#*/}
  ostree cat "$STAGED" /usr/lib/modules/$KV/extra/$m.ko.xz > "$T/$n.staged.ko.xz" 2>/dev/null
  s=$(fp "$T/$n.staged.ko.xz"); FP[$n]=$s
  ver=$AV; [[ $m == macbook-t1-touchbar/* ]] && ver=$TV
  tf=$P/akmods-tests/$ver/x/lib/modules/$KV/extra/$m.ko.xz
  [[ $s != none && $s != unreadable ]] || { bad "$n: cannot read module from deployment"; continue; }
  if [[ -f $tf ]]; then t=$(fp "$tf"); [[ $s == "$t" ]] && ok "$n deployment == akmods test ($s)" || bad "$n deployment=$s test=$t"
  else ok "$n readable in deployment ($s)"; fi
done
for f in /usr/local/lib/macbook-t1-socw/$KV/macbook_t1_socw.ko $A/touchbar/t1-socw/macbook_t1_socw.ko $A/sleep/phase1c/files/macbook_t1_socw.ko; do
  [[ -f $f ]] || { skip "$f"; continue; }
  [[ $(fp "$f") == "${FP[macbook_t1_socw]}" ]] && ok "socw == staged: $f" || bad "socw differs: $f ($(fp "$f"))"
done
if [[ -f $A/audio/resume-fix-livetest/snd-hda-codec-cs8409.ko ]]; then c=$(fp $A/audio/resume-fix-livetest/snd-hda-codec-cs8409.ko)
[[ $c != unreadable && ${c%-*} == "${FP[snd-hda-codec-cs8409]%-*}" ]] && ok "audio/resume-fix-livetest (live-loaded) cs8409 code == staged (.text/.modinfo; rodata ${c##*-} vs ${FP[snd-hda-codec-cs8409]##*-})" || bad "audio/resume-fix-livetest cs8409 differs ($c vs ${FP[snd-hda-codec-cs8409]})"
else skip "audio/resume-fix-livetest ko"; fi
echo "  info live modules: $(for m in apple_touchbar apple_ibridge macbook_t1_socw snd_hda_codec_cs8409; do printf '%s:%s ' $m "$(grep -o '^parm.*' /dev/null; [[ -d /sys/module/$m ]] && echo loaded || echo absent)"; done)"
for m in apple_touchbar apple_ibridge macbook_t1_socw snd_hda_codec_cs8409; do
  f=$(modinfo -n $m 2>/dev/null); n=$(basename "${f%.ko.xz}")
  if [[ -d /sys/module/$m && $f == */extra/* ]]; then
    [[ $TARGET_KIND == booted ]] && { [[ $(fp "$f") == "${FP[$n]}" ]] && ok "loaded $m from booted tree == audited build" || bad "loaded $m ($f) differs"; }
  else echo "  info $m: $( [[ -d /sys/module/$m ]] && echo "loaded from $f" || echo 'not loaded')"; fi
done
echo "  info live cs8409 has resume_reinit: $([[ -e /sys/module/snd_hda_codec_cs8409/parameters/resume_reinit ]] && echo yes || echo NO)"
echo "== C. target deployment (staged, else booted)"
rpm-ostree status --json | python3 -c 'import json,sys
dd=json.load(sys.stdin)["deployments"]; d=([x for x in dd if x.get("staged")] or [x for x in dd if x.get("booted")])[0]
print("       target", d["checksum"][:12], "local:", " ".join(sorted(d.get("requested-local-packages",[]))))'
ostree cat "$STAGED" /usr/lib/modules/$KV/initramfs.img > "$T/initrd.img"
L=$(lsinitrd "$T/initrd.img" 2>/dev/null)
for f in extra/macbook-cs8409/snd-hda-codec-cs8409.ko.xz extra/macbook-t1-touchbar/apple-touchbar.ko.xz extra/macbook-t1-touchbar/apple-ibridge.ko.xz usr/lib/modprobe.d/macbook-t1-touchbar.conf usr/lib/firmware/brcm/brcmfmac43602-pcie.txt; do
  grep -q "$f\$" <<<"$L" && ok "initramfs has $f" || bad "initramfs lacks $f"
done
lsinitrd -f usr/lib/modprobe.d/macbook-t1-touchbar.conf "$T/initrd.img" 2>/dev/null | grep -qx 'options apple_ibridge skip_acpi_power=1' && ok "initramfs skip_acpi_power=1" || bad "initramfs guard missing"
lsinitrd -f usr/lib/firmware/brcm/brcmfmac43602-pcie.txt "$T/initrd.img" 2>/dev/null | cmp -s - /etc/firmware/macbook-wifi/brcm/brcmfmac43602-pcie.txt && ok "initramfs NVRAM == /etc copy" || bad "initramfs NVRAM differs"
for m in snd-hda-codec-cs8409 apple-touchbar; do
  p=$(grep -o "usr/lib/modules/.*/extra/.*/$m.ko.xz" <<<"$L" | head -1)
  lsinitrd -f "$p" "$T/initrd.img" > "$T/$m.initrd.ko.xz" 2>/dev/null
  cmp -s "$T/$m.initrd.ko.xz" "$T/$m.staged.ko.xz" && ok "initramfs $m == staged tree" || bad "initramfs $m differs"
done
chk "ostree cat '$STAGED' /usr/lib/depmod.d/macbook-cs8409.conf | grep -qx 'override snd-hda-codec-cs8409 \* extra/macbook-cs8409'" "staged depmod override"
chk "ostree cat '$STAGED' /usr/lib/modules/$KV/modules.dep | grep -q '^extra/macbook-cs8409/snd-hda-codec-cs8409.ko.xz:'" "staged modules.dep uses extra/ cs8409"
chk "ostree cat '$STAGED' /usr/lib/modules/$KV/modules.dep | grep -q '^extra/macbook-t1-touchbar/macbook_t1_socw.ko.xz:'" "staged modules.dep knows macbook_t1_socw"
chk "rpm-ostree kargs | grep -qw 'firmware_class.path=/etc/firmware/macbook-wifi'" "karg firmware_class.path (booted+staged inherit)"

echo "== D. installed host files vs manifests"
declare -A M=()
while read -r f; do M[${f#$A/rebuild-kit/files}]=$f; done < <(find $A/rebuild-kit/files -type f | sort)
chk "(cd $A/rebuild-kit && sha256sum -c --quiet SHA256SUMS)" "rebuild-kit SHA256SUMS"
for r in $A/rebuild-kit/rpms/*.rpm; do ver=$AV; [[ $(basename "$r") == *macbook-t1-touchbar* ]] && ver=$TV; q=$P/rpms/$ver/$(basename "$r"); [[ -f $q ]] || { skip "$q"; continue; }; cmp -s "$r" "$q" && ok "kit rpm == packaging: $(basename "$r")" || bad "kit rpm differs: $r"; done
if [[ -f /usr/local/lib/macbook-t1-socw/$KV/macbook_t1_socw.ko ]]; then
  [[ $(fp /usr/local/lib/macbook-t1-socw/$KV/macbook_t1_socw.ko) == "${FP[macbook_t1_socw]}" ]] && ok "optional /usr/local socw fallback == akmod build" || bad "socw fallback differs"
fi
for f in $(printf '%s\n' "${!M[@]}" | sort); do
  if [[ ! -e $f ]]; then bad "missing $f"; continue; fi
  if [[ $f == */brcmfmac43602-pcie.txt ]]; then cmp -s <(grep -v '^macaddr=' "$f") <(grep -v '^macaddr=' "${M[$f]}") && ok "$f (ignoring macaddr)" || bad "$f differs from ${M[$f]}"
  else cmp -s "$f" "${M[$f]}" && ok "$f" || bad "$f differs from ${M[$f]}"; fi
  ctx=$(stat -c %C "$f"); exp=$(matchpathcon -n "$f" 2>/dev/null)
  [[ $ctx == "$exp" ]] || bad "  SELinux $f is $ctx, policy says $exp"
done
[[ ! -e /usr/local/lib/macbook-t1-socw ]] || { [[ $(stat -c %C /usr/local/lib/macbook-t1-socw/$KV/macbook_t1_socw.ko) == *modules_object_t* ]] && ok "fallback ko labelled modules_object_t" || bad "fallback ko label"; }
chk "semanage fcontext -l -C | grep -q '/usr/local/lib/macbook-t1-socw(/.\*)?.*modules_object_t'" "semanage local fcontext rule present"
chk "systemctl is-enabled macbook-usbc-runtime.service" "macbook-usbc-runtime.service enabled"
chk "systemctl cat systemd-suspend.service | grep -q 'macbook-sleep-hook pre'" "suspend drop-in active"
chk "[[ \$(cat /sys/module/apple_ibridge/parameters/skip_acpi_power) == 1 ]]" "live skip_acpi_power=1"
for f in /etc/systemd/sleep.conf.d/* /etc/systemd/system/systemd-suspend.service.d/* /etc/udev/rules.d/* /usr/local/sbin/* /etc/modprobe.d/* /etc/dracut.conf.d/*; do
  [[ -n ${M[$f]+x} ]] || echo "  info unmanaged: $f"
done
for r in /var/lib/macbook-sleep-phase1*; do echo "  info receipt $r"; done

echo "== RESULT: $fails failure(s)"
(( fails == 0 ))
