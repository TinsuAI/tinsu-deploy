#!/usr/bin/env bash
# On-merge trigger: rebuild ONE app in the nightly stack from latest main.
# Code only — no prod-data snapshot, no token re-mint (those stay on the
# nightly cron). Called by each app's self-hosted deploy job after it deploys
# prod. Safe to fail without failing the prod deploy (caller uses
# continue-on-error).
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:?usage: rebuild-app.sh <dh|co>}"
case "$app" in
  dh) svc=dh-app; src=src/data-hub ;;
  co) svc=co-app; src=src/co ;;
  *)  echo "unknown app: $app (use dh|co)" >&2; exit 2 ;;
esac

[ -f .env.nightly ] || { echo "[rebuild:$app] no .env.nightly — skipping" >&2; exit 0; }
C="docker compose --env-file .env.nightly -f docker-compose.nightly.yml"

echo "[rebuild:$app] syncing $src to origin/main"
git -C "$src" fetch --quiet origin main
git -C "$src" reset --hard origin/main

echo "[rebuild:$app] up --build $svc (migrations run forward on the snapshot data)"
$C up -d --build "$svc"
echo "[rebuild:$app] done $(date -u +%FT%TZ)"
