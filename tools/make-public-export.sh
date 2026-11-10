#!/usr/bin/bash
# Build a sanitized PUBLIC copy of this workspace with fresh git history.
#   bash tools/make-public-export.sh [DEST]   (default ~/macbook-fedora-audit-public)
# The private repo is not modified. Re-runnable (DEST is recreated).
set -euo pipefail
SRC=$(cd "$(dirname "$0")/.." && pwd)
DEST=${1:-$HOME/macbook-fedora-audit-public}
[[ "$DEST/" != "$SRC/"* ]] || { echo "DEST must be outside the workspace" >&2; exit 1; }
rm -rf "$DEST"; mkdir -p "$DEST"

# ---- 1. exclusions (privacy, third-party dumps, firmware tables, superseded binaries) ----
EXCL=$(mktemp)
cat > "$EXCL" <<'EOF'
^\.tidy/
^audio/microphone-test/
^audio/logs/audio-sinks-before-test\.txt$
^audio/raw/
^touchbar/raw/
^wifi/raw/
^misc/session-reference\.txt$
^misc/kernel-current\.log$
^misc/camera/
/journal\.log$
journal.*\.log$
-ending\.log$
^sleep/idle-trackpad-audit/previous-boot\.log$
^wifi/wpa3-audit/connection\.log$
^wifi/research-20261101/review/.*\.(html|json|txt)$
^wifi/comment97/.*\.(html|json)$
\.json$
\.html$
^sleep/suspend-audit/research/
^sleep/suspend-audit/usb-repo-research/
^sleep/research-20261101/raw/
^sleep/acpi-tables/
^build/inputs/wifi-source/
^build/artifacts/
^packaging/rpms/
^packaging/akmods-tests/
\.ko$
^tools/logs/
EOF
# keep-list overrides (GPL sources from other owners that the docs discuss)
KEEP='^sleep/research-20261101/raw/simbilim/.*\.c$'
cd "$SRC"
git ls-files | grep -vEf "$EXCL" > /tmp/export-files.txt || true
git ls-files | grep -E "$KEEP" >> /tmp/export-files.txt || true
rsync -a --files-from=/tmp/export-files.txt "$SRC/" "$DEST/"
git ls-files | grep -Ef "$EXCL" | grep -vE "$KEEP" > "$DEST/.excluded-files.txt" || true

# ---- 2. public replacements ----
NV=rebuild-kit/files/etc/firmware/macbook-wifi/brcm/brcmfmac43602-pcie.txt
sed -i 's/^macaddr=.*/macaddr=00:90:4c:0d:f4:3e/' "$DEST/$NV"     # attachment 290569's public placeholder
mkdir -p "$DEST/sleep/acpi-tables"
cp "$SRC/tools/public/acpi-excerpt.md" "$DEST/sleep/acpi-tables/README.md"
# README.md and LICENSE are canonical tracked files, copied in step 1.
# Do not replace the front page with a separate template that can drift.
rm -rf "$DEST/tools/public"
python3 - "$DEST" <<'PY'
import os, re, sys
root = sys.argv[1]
# install-files.sh: give each install its own random locally-administered Wi-Fi MAC
p = os.path.join(root, 'rebuild-kit/install-files.sh'); s = open(p).read()
s = s.replace('restorecon -RF /etc/firmware/macbook-wifi',
 '''NV=/etc/firmware/macbook-wifi/brcm/brcmfmac43602-pcie.txt
if grep -q '^macaddr=00:90:4c:0d:f4:3e$' "$NV"; then   # public placeholder -> random local MAC
  mac=$(od -An -N5 -tx1 /dev/urandom | tr -s ' ' ':' | sed 's/^:/02:/')
  sed -i "s/^macaddr=.*/macaddr=$mac/" "$NV"; echo "Wi-Fi NVRAM macaddr set to $mac"
fi
restorecon -RF /etc/firmware/macbook-wifi''', 1)
open(p, 'w').write(s)
# audit.sh: NVRAM differs only in macaddr on other machines
p = os.path.join(root, 'tools/audit.sh'); s = open(p).read()
s = s.replace('''  cmp -s "$f" "${M[$f]}" && ok "$f" || bad "$f differs from ${M[$f]}"''',
 '''  if [[ $f == */brcmfmac43602-pcie.txt ]]; then cmp -s <(grep -v '^macaddr=' "$f") <(grep -v '^macaddr=' "${M[$f]}") && ok "$f (ignoring macaddr)" || bad "$f differs from ${M[$f]}"
  else cmp -s "$f" "${M[$f]}" && ok "$f" || bad "$f differs from ${M[$f]}"; fi''', 1)
open(p, 'w').write(s)
PY
( cd "$DEST/rebuild-kit" && find . -type f ! -name SHA256SUMS | sort | xargs sha256sum > SHA256SUMS )

# ---- 3. redaction of text files ----
python3 - "$DEST" <<'PY'
import os, re, sys
root = sys.argv[1]
SRC_EXT = ('.c', '.h', '.patch', '.diff')
KEEP_MACS = {'00:90:4c:0d:f4:3e', '00:00:00:00:00:00', 'ff:ff:ff:ff:ff:ff'}
mac = re.compile(r'\b(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b')
ip4 = re.compile(r'\b(?:192\.168|10\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01]))\.\d{1,3}\.\d{1,3}\b')
ip6 = re.compile(r'\b(?:fe80|2[0-9a-f]{3}):(?:[0-9a-f]{0,4}:){2,7}[0-9a-f]{1,4}\b', re.I)
uuid = re.compile(r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b', re.I)
names = [('speaker-4', 'speaker-4'), ('speaker-3', 'speaker-3'), ('speaker-2', 'speaker-2'),
         ('speaker-1', 'speaker-1'), ('airplay-1', 'airplay-1'), ('airplay-2', 'airplay-2')]
ssid = [(re.compile(r'SSID `<home-5g>`'), 'SSID `<home-5g>`'), (re.compile(r'`<home-5g>`'), '`<home-5g>`'),
        (re.compile(r'SSID `<home>`'), 'SSID `<home>`'), (re.compile(r'(connected:)7\b'), r'\1<home>'),
        (re.compile(r'(\bssid )7( 5GHz)?\b'), lambda m: m.group(1) + ('<home-5g>' if m.group(2) else '<home>')),
        (re.compile(r'(\bSSID:? )7\b'), r'\1<home>'), (re.compile(r'"<home-5g>"'), '"<home-5g>"'), (re.compile(r'"<home>"'), '"<home>"')]
stats = {}
for d, _, fs in os.walk(root):
    if '/.git' in d: continue
    for f in fs:
        p = os.path.join(d, f)
        try: s = open(p, encoding='utf-8').read()
        except Exception: continue
        o = s
        if not f.endswith(SRC_EXT):
            s = mac.sub(lambda m: m.group(0) if m.group(0).lower() in KEEP_MACS else 'XX:XX:XX:XX:XX:XX', s)
            s = ip4.sub('<private-ip>', s); s = ip6.sub('<ipv6>', s)
            s = re.sub(r'root=UUID=[0-9a-f-]+', 'root=UUID=<redacted>', s)
            if f.endswith(('.log', '.txt', '.md', '.sh')): s = uuid.sub('<uuid>', s)
        for a, b in names: s = s.replace(a, b)
        for rx, b in ssid: s = rx.sub(b, s)
        if s != o:
            open(p, 'w', encoding='utf-8').write(s); stats[os.path.relpath(p, root)] = 1
print(f"redacted {len(stats)} files")
PY
( cd "$DEST/rebuild-kit" && find . -type f ! -name SHA256SUMS | sort | xargs sha256sum > SHA256SUMS )

# ---- 4. fresh repo ----
cd "$DEST"
cp "$SRC/.gitignore" .gitignore
git init -q -b main
git add -A
git -c user.name="${GIT_AUTHOR_NAME:-macbook-audit}" -c user.email="${GIT_AUTHOR_EMAIL:-macbook-audit@users.noreply.github.com}" commit -qm "MacBookPro13,2 on Fedora Silverblue 44: Touch Bar, audio, 5 GHz Wi-Fi, USB-C and working S3 sleep"
echo "Exported $(git ls-files | wc -l) files to $DEST ($(du -sh --exclude=.git . | cut -f1)); excluded list: .excluded-files.txt"
