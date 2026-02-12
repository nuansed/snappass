# SnapPass Workflow

This repository is your source of truth for SnapPass changes. Production should be deploy-only.

## Branch model

- `master`: production branch
- `feature/<name>`: normal work
- `sync/upstream-<date>`: temporary branches for upstream merges

## One-time setup

```bash
cd /Users/markd/Github/snappass
./scripts/setup_remotes.sh
```

This ensures these remotes are configured:

- `origin` -> `https://github.com/mdelecate/snappass.git`
- `upstream` -> `https://github.com/pinterest/snappass.git`
- `nuansed` -> `https://github.com/nuansed/snappass.git`

## Daily development

```bash
cd /Users/markd/Github/snappass
git checkout master
git pull --ff-only origin master
git checkout -b feature/ui-<topic>
# make changes
```

Run local tests:

```bash
make test
```

Commit and push:

```bash
git add -A
git commit -m "Describe change"
git push -u origin feature/ui-<topic>
```

Merge to `master` only after review/testing.

## Upstream sync workflow

Use this when pulling newer changes from `pinterest/snappass`:

```bash
cd /Users/markd/Github/snappass
./scripts/sync_upstream.sh master
# script creates sync/upstream-<date>

git checkout master
git merge --no-ff sync/upstream-<date>
```

Then resolve conflicts, test, and push.

## Deploy to server

Default deploy target is already configured for your server.

```bash
cd /Users/markd/Github/snappass
./scripts/deploy_remote.sh --ref master
```

What deploy does:

1. SSH to server (`root@140.82.33.152:8765`)
2. Fetch and checkout the target ref in `/home/tutima/public_html/snappass/repo`
3. Install dependencies into `/home/tutima/virtualenv/snappass-311`
4. Restart Passenger (`tmp/restart.txt`)
5. Run smoke tests against `https://snappass.tutima.com`

Useful options:

```bash
./scripts/deploy_remote.sh --ref <branch-or-sha>
./scripts/deploy_remote.sh --ref master --no-smoke
./scripts/deploy_remote.sh --ref <ref> --allow-dirty
```

`--allow-dirty` should be temporary only.

## Smoke tests only

```bash
cd /Users/markd/Github/snappass
./scripts/smoke_test.sh https://snappass.tutima.com
```

Checks:

- home page
- query-token flow
- path-token flow
- legacy API
- v2 API single-use behavior
- health endpoint

## Rollback

Deploy a known-good commit SHA:

```bash
./scripts/deploy_remote.sh --ref <known_good_sha>
```

Keep a list of known-good SHAs from successful production deploys.
