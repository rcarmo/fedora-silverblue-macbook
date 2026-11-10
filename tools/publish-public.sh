#!/usr/bin/bash
# Update the public repo (rcarmo/fedora-silverblue-macbook) with a normal commit.
#   bash tools/publish-public.sh "commit message"
set -euo pipefail
MSG=${1:?commit message}
SRC=$(cd "$(dirname "$0")/.." && pwd)
PUB=${PUB:-$HOME/macbook-fedora-audit-public}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
[[ -d $PUB/.git ]] || gh repo clone rcarmo/fedora-silverblue-macbook "$PUB"
GIT_AUTHOR_NAME="Rui Carmo" GIT_AUTHOR_EMAIL="392683+rcarmo@users.noreply.github.com" bash "$SRC/tools/make-public-export.sh" "$TMP/export" >/dev/null
cd "$PUB"; git pull -q --ff-only
rsync -a --delete --exclude=.git "$TMP/export/" ./
git add -A
if git diff --cached --quiet; then echo "No changes to publish."; exit 0; fi
git diff --cached --stat | tail -15
read -rp "Commit and push these changes? [y/N] " a; [[ $a == y ]] || { git reset -q; echo "Aborted."; exit 1; }
git -c user.name="Rui Carmo" -c user.email="392683+rcarmo@users.noreply.github.com" commit -qm "$MSG"
git push -q origin main && git log --oneline -1
