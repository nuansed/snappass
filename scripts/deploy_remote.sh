#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SSH_TARGET="${SSH_TARGET:-root@140.82.33.152}"
SSH_PORT="${SSH_PORT:-8765}"
REMOTE_USER="${REMOTE_USER:-tutima}"
REMOTE_REPO="${REMOTE_REPO:-/home/tutima/public_html/snappass/repo}"
REMOTE_APP_DIR="${REMOTE_APP_DIR:-/home/tutima/public_html/snappass/repo/snappass}"
REMOTE_VENV="${REMOTE_VENV:-/home/tutima/virtualenv/snappass-311}"
REF="${REF:-master}"
BASE_URL="${BASE_URL:-https://snappass.tutima.com}"
ALLOW_DIRTY=0
RUN_SMOKE=1

usage() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --ref <git_ref>           Branch/tag/SHA to deploy (default: master)
  --host <user@host>        SSH target (default: root@140.82.33.152)
  --port <port>             SSH port (default: 8765)
  --remote-user <user>      User owning app repo (default: tutima)
  --remote-repo <path>      Repo path on server
  --remote-app-dir <path>   Passenger app root on server
  --remote-venv <path>      Python venv path on server
  --base-url <url>          URL used for smoke test
  --allow-dirty             Allow deploy even with dirty remote git tree
  --no-smoke                Skip post-deploy smoke test
  --help                    Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)
      REF="$2"
      shift 2
      ;;
    --host)
      SSH_TARGET="$2"
      shift 2
      ;;
    --port)
      SSH_PORT="$2"
      shift 2
      ;;
    --remote-user)
      REMOTE_USER="$2"
      shift 2
      ;;
    --remote-repo)
      REMOTE_REPO="$2"
      shift 2
      ;;
    --remote-app-dir)
      REMOTE_APP_DIR="$2"
      shift 2
      ;;
    --remote-venv)
      REMOTE_VENV="$2"
      shift 2
      ;;
    --base-url)
      BASE_URL="$2"
      shift 2
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    --no-smoke)
      RUN_SMOKE=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

echo "Deploying '$REF' to $SSH_TARGET:$REMOTE_REPO"

ssh -p "$SSH_PORT" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$SSH_TARGET" /bin/bash -s -- \
  "$REMOTE_USER" "$REMOTE_REPO" "$REMOTE_VENV" "$REMOTE_APP_DIR" "$REF" "$ALLOW_DIRTY" <<'REMOTE'
set -euo pipefail

REMOTE_USER="$1"
REMOTE_REPO="$2"
REMOTE_VENV="$3"
REMOTE_APP_DIR="$4"
REF="$5"
ALLOW_DIRTY="$6"

if [[ ! -d "$REMOTE_REPO/.git" ]]; then
  echo "Remote repository not found: $REMOTE_REPO" >&2
  exit 2
fi

sudo -u "$REMOTE_USER" -H bash -s -- "$REMOTE_REPO" "$REMOTE_VENV" "$REMOTE_APP_DIR" "$REF" "$ALLOW_DIRTY" <<'INNER'
set -euo pipefail

REMOTE_REPO="$1"
REMOTE_VENV="$2"
REMOTE_APP_DIR="$3"
REF="$4"
ALLOW_DIRTY="$5"

cd "$REMOTE_REPO"

if [[ "$ALLOW_DIRTY" != "1" ]]; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Remote repo has unstaged/staged changes. Re-run with --allow-dirty if intentional." >&2
    exit 11
  fi
fi

git fetch --all --tags --prune

if git show-ref --verify --quiet "refs/remotes/origin/$REF"; then
  if git show-ref --verify --quiet "refs/heads/$REF"; then
    git checkout "$REF"
  else
    git checkout -B "$REF" "origin/$REF"
  fi
  git pull --ff-only origin "$REF"
else
  git checkout --detach "$REF"
fi

source "$REMOTE_VENV/bin/activate"
pip install --upgrade -r "$REMOTE_REPO/requirements.txt"
pip check

mkdir -p "$REMOTE_APP_DIR/tmp"
touch "$REMOTE_APP_DIR/tmp/restart.txt"

echo "Deployed commit: $(git rev-parse --short HEAD)"
INNER
REMOTE

if [[ "$RUN_SMOKE" == "1" ]]; then
  echo "Running smoke test against $BASE_URL"
  "$SCRIPT_DIR/smoke_test.sh" "$BASE_URL"
fi

echo "Deployment finished."
