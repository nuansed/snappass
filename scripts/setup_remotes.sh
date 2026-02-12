#!/usr/bin/env bash
set -euo pipefail

ORIGIN_URL="${1:-https://github.com/mdelecate/snappass.git}"
UPSTREAM_URL="${2:-https://github.com/pinterest/snappass.git}"
NUANSED_URL="${3:-https://github.com/nuansed/snappass.git}"

add_or_set_remote() {
  local name="$1"
  local url="$2"

  if git remote | grep -qx "$name"; then
    git remote set-url "$name" "$url"
  else
    git remote add "$name" "$url"
  fi
}

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Run this script from inside a git repository." >&2
  exit 1
fi

add_or_set_remote origin "$ORIGIN_URL"
add_or_set_remote upstream "$UPSTREAM_URL"
add_or_set_remote nuansed "$NUANSED_URL"

git fetch --all --tags --prune

echo "Configured remotes:"
git remote -v

echo

echo "Ahead/behind summary vs upstream/master:"
if git rev-parse --verify --quiet upstream/master >/dev/null; then
  git rev-list --left-right --count HEAD...upstream/master | awk '{print "local=" $1 " upstream=" $2}'
else
  echo "upstream/master not found"
fi
