#!/usr/bin/env bash
# Snapshot prod DB + DH files into the nightly stack.
#
# READ-ONLY against prod (pg_dump only). OVERWRITES nightly data.
# ⚠️ Copies real client data UNMASKED (Growatt/Johnson) into the demo stack —
#    accepted risk, see .ai/features/2026-05-29-nightly-demo-stack/brief.md.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env.nightly; set +a
C="docker compose --env-file .env.nightly -f docker-compose.nightly.yml"

echo "[snapshot] stopping nightly apps for a clean restore"
$C stop dh-app co-app

# Drop + recreate the target DB then restore a plain dump. Cleaner than
# `pg_dump --clean` into an existing DB, which fails to drop the `hub` schema
# while extensions (pg_trgm, vector) still depend on it.
echo "[snapshot] Data Hub  prod(${PROD_DH_DB_CONTAINER}) -> nightly (drop+recreate)"
$C exec -T dh-db psql -v ON_ERROR_STOP=1 -U hub -d postgres -c \
  "drop database if exists data_hub with (force); create database data_hub owner hub;"
docker exec "${PROD_DH_DB_CONTAINER}" pg_dump -U hub -d data_hub --no-owner --no-privileges \
  | $C exec -T dh-db psql -q -v ON_ERROR_STOP=1 -U hub -d data_hub

echo "[snapshot] CO        prod(${PROD_CO_DB_CONTAINER}) -> nightly (drop+recreate)"
$C exec -T co-db psql -v ON_ERROR_STOP=1 -U co -d postgres -c \
  "drop database if exists barry_co with (force); create database barry_co owner co;"
docker exec "${PROD_CO_DB_CONTAINER}" pg_dump -U co -d barry_co --no-owner --no-privileges \
  | $C exec -T co-db psql -q -v ON_ERROR_STOP=1 -U co -d barry_co

echo "[snapshot] DH files volume  ${PROD_DH_FILES_VOL} -> nightly_dh_appfiles"
docker run --rm \
  -v "${PROD_DH_FILES_VOL}":/from:ro \
  -v nightly_dh_appfiles:/to \
  alpine sh -c 'rm -rf /to/* && cp -a /from/. /to/ 2>/dev/null || true'

# The snapshot overwrote app_settings with prod's values, incl. sso_issuer_url
# (= prod URL). Re-point it at the nightly issuer so JWT `iss` matches CO.
echo "[snapshot] fixing nightly DH sso_issuer_url -> ${NIGHTLY_DH_EXTERNAL_URL}"
$C up -d dh-db
$C exec -T dh-db psql -v ON_ERROR_STOP=1 -U hub -d data_hub -c \
  "update hub.app_settings set value='${NIGHTLY_DH_EXTERNAL_URL}' where key='sso_issuer_url';"

echo "[snapshot] starting nightly apps (migrations run forward on the snapshot)"
$C up -d dh-app co-app

echo "[snapshot] done. Re-mint the CO token next: scripts/mint-nightly-token.sh"
