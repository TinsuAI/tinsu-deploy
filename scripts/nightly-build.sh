#!/usr/bin/env bash
# Full nightly cycle: pull both apps from main, rebuild, snapshot prod data,
# re-mint the CO token. Intended for the nightly cron (see README).
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env.nightly; set +a
C="docker compose --env-file .env.nightly -f docker-compose.nightly.yml"

echo "[nightly] $(date -u +%FT%TZ) syncing nightly source clones (latest main)"
mkdir -p src
[ -d src/data-hub/.git ] || git clone "${DH_REPO_URL}" src/data-hub
[ -d src/co/.git ]       || git clone "${CO_REPO_URL}" src/co
git -C src/data-hub fetch --quiet origin main && git -C src/data-hub reset --hard origin/main
git -C src/co        fetch --quiet origin main && git -C src/co        reset --hard origin/main

echo "[nightly] build + up"
$C up -d --build

echo "[nightly] snapshot prod -> nightly"
./scripts/snapshot-prod-to-nightly.sh

echo "[nightly] mint + wire CO token"
./scripts/mint-nightly-token.sh

echo "[nightly] status"
$C ps
echo "[nightly] done $(date -u +%FT%TZ)"
