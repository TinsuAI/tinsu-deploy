#!/usr/bin/env bash
# Re-mint the nightly CO service token and wire it into co-app.
#
# Needed after every snapshot: the snapshot restores prod's `service_accounts`
# rows (signed by prod keys/issuer → invalid on nightly), so the nightly token
# must be recreated against the nightly keys (persistent in the dh_keys volume).
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env.nightly; set +a
C="docker compose --env-file .env.nightly -f docker-compose.nightly.yml"

echo "[token] waiting for nightly DH /healthz"
for _ in $(seq 1 30); do
  if $C exec -T dh-app curl -fsS http://127.0.0.1:8754/healthz >/dev/null 2>&1; then break; fi
  sleep 2
done

echo "[token] re-minting nightly CO service token (name=co, all clients)"
$C exec -T dh-app uv run python scripts/mint_service_token.py delete --name co >/dev/null 2>&1 || true
TOKEN=$(
  $C exec -T dh-app uv run python scripts/mint_service_token.py create \
    --name co --scopes hub:read,bom:propose \
    --description "nightly CO" --created-by nightly@tinsu \
  | grep -E '^eyJ' | tail -1
)
if [ -z "${TOKEN}" ]; then
  echo "[token] FAILED to mint token" >&2
  exit 1
fi

echo "[token] writing NIGHTLY_DH_SERVICE_TOKEN into .env.nightly + recreating co-app"
if grep -q '^NIGHTLY_DH_SERVICE_TOKEN=' .env.nightly; then
  sed -i "s#^NIGHTLY_DH_SERVICE_TOKEN=.*#NIGHTLY_DH_SERVICE_TOKEN=${TOKEN}#" .env.nightly
else
  echo "NIGHTLY_DH_SERVICE_TOKEN=${TOKEN}" >> .env.nightly
fi
$C up -d co-app
echo "[token] done"
