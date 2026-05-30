# tinsu-deploy

Deployment orchestration for the **nightly / demo stack** — a second, isolated
instance of **Data Hub + CO** on the demo VPS, for nightly builds + demos to
new customers.

> ⚠️ **Client-data exposure (accepted risk).** The nightly stack mirrors **full
> prod data, unmasked** — demos will show real client names + data
> (Growatt/Johnson). This was a deliberate decision (2026-05-29). Only demo to
> audiences for whom that exposure is acceptable. See
> `.ai/features/2026-05-29-nightly-demo-stack/brief.md`.

Prod stacks are untouched: prod DH `/home/tinsu/data-hub` (:8754), prod CO
`/home/tinsu/co` (:8755). This repo runs a separate `nightly` compose project.

📖 **Full operations guide: [`docs/RUNBOOK.md`](docs/RUNBOOK.md)** — architecture,
the three refresh paths, critical wiring (issuer/token/tunnel), and a
troubleshooting table. Read it before changing anything.

## Box layout

```
/home/tinsu/tinsu-deploy        <- this repo
/home/tinsu/tinsu-deploy/src/   <- nightly's OWN clones (gitignored), synced to
                                   latest main by nightly-build.sh:
                                     src/data-hub, src/co
/home/tinsu/data-hub            <- prod DH checkout (untouched by nightly)
/home/tinsu/co                  <- prod CO checkout (untouched by nightly)
```

Nightly builds from `src/` clones, **not** the prod checkouts, so a nightly
build never dirties prod's working tree.

## What it runs

`docker-compose.nightly.yml` — 4 services under project `nightly`:

| Service  | Host port | Internal | Volume(s)                  |
|----------|-----------|----------|----------------------------|
| dh-app   | 8764      | 8754     | dh_appfiles, dh_keys       |
| dh-db    | (none)    | 5432     | dh_pgdata                  |
| co-app   | 8765      | 8755     | co_appdata                 |
| co-db    | (none)    | 5432     | co_pgdata                  |

All names prefixed `nightly_` / `nightly-*` → zero overlap with prod.

## Issuer wiring (the easy thing to get wrong)

- `NIGHTLY_DH_EXTERNAL_URL` (e.g. `http://100.84.189.87:8764`) is browser-facing
  and becomes both DH `sso_issuer_url` (set by the snapshot script) **and** CO
  `DATA_HUB_ISSUER_URL` / `DATA_HUB_BASE_URL`. They must match or SSO + service
  tokens 401.
- CO→DH server-to-server uses the **internal** name `http://dh-app:8754`
  (`DATA_HUB_API_BASE_URL`, `DATA_HUB_JWKS_URL`) — faster, no host hairpin.
- The nightly CO service token is **re-minted after every snapshot** (the
  snapshot restores prod's `service_accounts`, which were signed by prod
  keys/issuer and are invalid here). Nightly keys persist in the `dh_keys`
  volume so the issuer identity is stable across rebuilds.

## First-time setup (on the box)

```bash
cp .env.nightly.template .env.nightly
# fill DH_POSTGRES_PASSWORD, CO_POSTGRES_PASSWORD, DH_SEED_PASSWORD, LLM_*,
# and VERIFY PROD_*_CONTAINER / PROD_DH_FILES_VOL via `docker ps` / `docker volume ls`
chmod +x scripts/*.sh
./scripts/nightly-build.sh        # build, snapshot prod, mint token
```

Then browse `http://100.84.189.87:8764` (DH) / `:8765` (CO).

## Operations

- **Nightly cron** (rebuild + re-snapshot): see `cron.example`.
- **Pre-demo refresh** (data only, no rebuild): `./scripts/refresh-now.sh`.
- **Logs:** `docker compose --env-file .env.nightly -f docker-compose.nightly.yml logs -f`.

## Triggers

- **Nightly:** cron runs `scripts/nightly-build.sh` (see `cron.example`).
- **On-merge (follow-up, not yet wired):** add a step to each app repo's
  self-hosted-runner deploy job to also rebuild that service in the nightly
  stack after prod deploys. Tracked in the brief.

## Standards

Follows TinsuAI cross-product standards (`TinsuAI/standards`). Secrets live only
in `.env.nightly` (gitignored) — never commit tokens/passwords.
