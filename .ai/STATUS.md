# Status — tinsu-deploy

**2026-05-29 — Scaffolded.** Repo skeleton for the nightly/demo stack created
(compose + env template + snapshot/build/refresh scripts + AI context). **Not
yet dry-run on the box.**

## Done
- `docker-compose.nightly.yml` — 4 services, project `nightly`, isolated
  ports (8764/8765) / volumes / db.
- `.env.nightly.template`, `.gitignore` (.env.nightly + dumps + logs).
- `scripts/`: `snapshot-prod-to-nightly.sh`, `mint-nightly-token.sh`,
  `nightly-build.sh`, `refresh-now.sh`.
- `README.md`, `AGENTS.md`, `cron.example`, brief copy.

## Next (with the user, on the box)
1. Create GitHub repo `TinsuAI/tinsu-deploy`, push.
2. Clone to `/home/tinsu/tinsu-deploy`; `cp .env.nightly.template .env.nightly`,
   fill secrets, **verify** `PROD_DH_DB_CONTAINER` / `PROD_CO_DB_CONTAINER` /
   `PROD_DH_FILES_VOL` (`docker ps`, `docker volume ls`).
3. **Dry-run by hand**: `./scripts/nightly-build.sh`, then check
   `:8764` (DH) + `:8765` (CO) healthz, SSO login, and a CO→DH API call
   (verifies the issuer wiring + minted token end-to-end).
4. Only after a clean manual run: install `cron.example`.

## Known gotchas (see brief)
- Issuer pin: `NIGHTLY_DH_EXTERNAL_URL` == DH `sso_issuer_url` == CO
  `DATA_HUB_ISSUER_URL`, else 401.
- CO token re-minted every snapshot (prod `service_accounts` clobbers it);
  `dh_keys` volume keeps the issuer keys stable.
- ⚠️ Full unmasked prod data in the demo — accepted risk.
- Resource use: 2nd Postgres + 2 apps on the same box — watch memory.
