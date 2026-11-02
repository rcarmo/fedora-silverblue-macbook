#!/usr/bin/bash
# Offline recovery for a future, explicitly scoped MacBook Wi-Fi NVRAM trial.
# This does NOT recover arbitrary firmware changes or install a Wi-Fi fix.
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
umask 077

STATE=/var/lib/macbook-wifi-recovery
FIRMWARE=/etc/firmware/macbook-wifi/brcm/brcmfmac43602-pcie.txt
MODPROBE=/etc/modprobe.d/99-macbook-wifi-nvram.conf
DRACUT=/etc/dracut.conf.d/99-macbook-wifi-nvram.conf
FILES=("$FIRMWARE" "$MODPROBE" "$DRACUT")
# Trial NVRAM is mapped into the standard firmware location ONLY in initramfs.
# Remove both usr-merged spellings there; never delete generic firmware on host.
REMOVE_PATHS="/etc/firmware/macbook-wifi $MODPROBE $DRACUT /usr/lib/firmware/brcm/brcmfmac43602-pcie.txt /lib/firmware/brcm/brcmfmac43602-pcie.txt"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
usage() {
    printf '%s\n' \
        'Usage: recover-wifi.sh --dry-run | --arm | --recover' \
        '  --dry-run  Show scope; no privileges or changes (default).' \
        '  --arm      Root: record an empty baseline BEFORE the Wi-Fi trial.' \
        '  --recover  Root: back up/remove only trial files; stage clean initramfs.' \
        'Never downloads, reloads drivers, changes country/power, or reboots.'
}
# Refuse symlinks in every component, including absent file ancestors.
check_path() {
    local p=$1
    while [[ "$p" != / ]]; do
        [[ ! -L "$p" ]] || fail "Symlink not allowed: $p"
        p=${p%/*}; [[ -n "$p" ]] || p=/
    done
}
[[ $# -le 1 ]] || { usage; exit 2; }
MODE=${1:---dry-run}
case "$MODE" in
    --help|-h) usage; exit 0 ;;
    --dry-run)
        usage
        printf '\nOnly these trial files would be removed:\n'
        printf '  %s\n' "${FILES[@]}"
        printf '\nArming state: %s\n' "$STATE"
        printf 'Backups kept there. No /usr firmware or audio/Touch Bar files touched.\n'
        exit 0 ;;
    --arm|--recover) ;;
    *) usage; exit 2 ;;
esac
[[ $EUID -eq 0 ]] || fail 'Run this mode locally with sudo or pkexec; do not share passwords.'
[[ -e /run/ostree-booted ]] || fail 'Requires a normally booted OSTree/Silverblue system, not a rescue chroot.'
[[ $(</sys/class/dmi/id/product_name) == MacBookPro13,2 ]] || fail 'This script is scoped to MacBookPro13,2.'
command -v rpm-ostree >/dev/null || fail 'rpm-ostree is unavailable.'
command -v python3 >/dev/null || fail 'python3 is unavailable.'
check_path "$STATE"
for path in "${FILES[@]}"; do check_path "$path"; done

# Refuse to compete with an update or overwrite an unrelated pending deployment.
STATUS=$(rpm-ostree status --json)
printf '%s' "$STATUS" | python3 -c '
import json, sys
s=json.load(sys.stdin)
if s.get("transaction"):
    sys.exit("An rpm-ostree transaction is running. Wait and retry.")
d=s.get("deployments", [])
if not d or not d[0].get("booted"):
    sys.exit("A non-booted deployment is first. Inspect rpm-ostree status before proceeding.")
if any(x.get("staged") for x in d):
    sys.exit("A staged deployment exists. Review it before proceeding.")
' || fail 'Deployment preflight failed; no trial files changed.'

if [[ "$MODE" == --arm ]]; then
    [[ ! -e "$STATE" ]] || fail "State already exists at $STATE; preserve/review it rather than overwriting."
    for path in "${FILES[@]}"; do
        [[ ! -e "$path" ]] || fail "Baseline is not empty: $path. Nothing armed."
    done
    install -d -m 0700 "$STATE"
    printf '%s\n' 'macbook-wifi-recovery-v1-empty-baseline' > "$STATE/armed"
    printf '%s\n' "$STATUS" > "$STATE/baseline-deployments.json"
    printf 'Armed. Future trial MUST use only the three documented paths.\n'
    printf 'No Wi-Fi firmware or configuration installed. No reboot needed.\n'
    exit 0
fi

[[ -d "$STATE" && $(stat -c '%u:%a' "$STATE") == 0:700 ]] || fail 'Missing or unsafe root-owned recovery state. Arm before installing the trial.'
check_path "$STATE/armed"
[[ -f "$STATE/armed" && $(stat -c '%u' "$STATE/armed") == 0 ]] || fail 'Missing root-owned arming record.'
[[ $(<"$STATE/armed") == macbook-wifi-recovery-v1-empty-baseline ]] || fail 'Unrecognized arming record.'
for path in "${FILES[@]}"; do
    if [[ -e "$path" ]]; then
        [[ -f "$path" && $(stat -c '%u' "$path") == 0 ]] || fail "Not a root-owned regular trial file: $path"
    fi
done
exec 9>"$STATE/lock"
flock -n 9 || fail 'Another recovery is running.'
BACKUP=$(mktemp -d "$STATE/recovery-XXXXXXXX")
printf '%s\n' "$STATUS" > "$BACKUP/deployments-before.json"
# Back up ALL files before removing ANY, so a backup error leaves config intact.
for i in "${!FILES[@]}"; do
    path=${FILES[$i]}
    if [[ -e "$path" ]]; then
        cp --preserve=all -- "$path" "$BACKUP/$i.original"
        printf '%s\n' "$path" >> "$BACKUP/removed-paths.txt"
    fi
done
for path in "${FILES[@]}"; do rm -f -- "$path"; done
# Keep directories; never recursively delete firmware or unrelated content.
printf 'Trial files removed. Backups: %s\n' "$BACKUP"
printf 'The running radio still has the old firmware until a later reboot.\n'

# Preserve all existing dracut args and local generation needed by working drivers.
# Explicit removal also excludes trial files from the rebuilt boot image.
mapfile -d '' -t OLD_ARGS < <(printf '%s' "$STATUS" | python3 -c '
import json, sys
s=json.load(sys.stdin)
a=next(x for x in s["deployments"] if x.get("booted")).get("initramfs-args", [])
for v in a: sys.stdout.buffer.write(v.encode()+b"\0")
')
ARGS=(initramfs --enable)
for arg in "${OLD_ARGS[@]}"; do ARGS+=("--arg=$arg"); done
# Do not accumulate identical recovery args on subsequent runs.
FOUND=0
for ((i=0; i+1<${#OLD_ARGS[@]}; i++)); do
    if [[ ${OLD_ARGS[$i]} == --remove && ${OLD_ARGS[$((i+1))]} == "$REMOVE_PATHS" ]]; then FOUND=1; fi
done
if [[ $FOUND == 0 ]]; then ARGS+=(--arg=--remove "--arg=$REMOVE_PATHS"); fi
printf 'Staging initramfs recovery; do not interrupt composition.\n'
if ! rpm-ostree "${ARGS[@]}" 2>&1 | tee "$BACKUP/initramfs.log"; then
    printf '\nBoot-image composition failed. Files remain removed; backups are retained.\n' >&2
    printf 'Do NOT assume recovery is complete or reboot into the trial image.\n' >&2
    printf 'Inspect rpm-ostree status/log, resolve the error, then retry when idle.\n' >&2
    exit 1
fi
rpm-ostree status | tee "$BACKUP/deployments-after.txt"
printf '\nNo reboot performed. No live module reload performed.\n'
printf 'Verify the staged boot image excludes the trial before rebooting.\n'
printf 'Existing audio/Touch Bar packages and local initramfs generation are preserved.\n'
printf 'Recovery does not repair other override paths or rewrite older boot images.\n'
