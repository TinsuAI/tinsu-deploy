#!/usr/bin/env bash
# Manual pre-demo refresh: re-snapshot prod data + re-mint the CO token.
# Does NOT rebuild images (no git pull / no --build) — use this right before a
# demo to get current prod data without risking a code change mid-session.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/snapshot-prod-to-nightly.sh
./scripts/mint-nightly-token.sh
echo "[refresh] done — nightly now mirrors current prod data"
