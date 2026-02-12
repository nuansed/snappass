#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/pinterest/snappass.git}"
LOCAL_BASE="${1:-master}"
SYNC_BRANCH="${2:-sync/upstream-$(date +%Y%m%d)}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Run this script from inside the repository." >&2
  exit 1
fi

if git remote | grep -qx "$UPSTREAM_REMOTE"; then
  git remote set-url "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
else
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

git fetch "$UPSTREAM_REMOTE" --tags --prune

echo "Ahead/behind ($LOCAL_BASE vs $UPSTREAM_REMOTE/master):"
git rev-list --left-right --count "$LOCAL_BASE...$UPSTREAM_REMOTE/master" | awk '{print "local=" $1 " upstream=" $2}'

echo

echo "Recent upstream commits not in $LOCAL_BASE:"
git log --oneline "$LOCAL_BASE..$UPSTREAM_REMOTE/master" | sed -n '1,20p'

git checkout -B "$SYNC_BRANCH" "$UPSTREAM_REMOTE/master"

echo

echo "Created $SYNC_BRANCH at $UPSTREAM_REMOTE/master"
echo "Next step:"
echo "  git checkout $LOCAL_BASE"
echo "  git merge --no-ff $SYNC_BRANCH"
