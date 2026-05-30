# Nightly / Demo Stack — Runbook

Operations guide for the **nightly/demo instance** of Data Hub + CO running on
the demo VPS (`100.84.189.87`). Read this before touching the stack, adding a
domain, or debugging a demo that's down.

> ⚠️ **Accepted risk — unmasked client data.** This stack mirrors **full prod
> data** (real Growatt/Johnson customs declarations, BOMs, catalogs) with **no
> masking**. It is reachable on the public internet behind login. Only demo to
> audiences for whom that exposure is acceptable. Decision recorded in the
> Data Hub repo `.ai/DECISIONS.md` (2026-05-29) and `.ai/features/2026-05-29-nightly-demo-stack/brief.md`.

---

## 1. What this is

A second, fully isolated copy of both apps, for **nightly builds + demos to new
customers**:

| | Public URL | Box port | Container | Build context |
|---|---|---|---|---|
| Data Hub | https://demo-datahub.tinsu.ai | :8764 | `nightly-dh-app-1` | `src/data-hub` |
| CO | https://demo-co.tinsu.ai | :8765 | `nightly-co-app-1` | `src/co` |
| DH Postgres | — | — | `nightly-dh-db-1` | pgvector/pgvector:pg16 |
| CO Postgres | — | — | `nightly-co-db-1` | postgres:16 |

Everything runs under docker-compose **project `nightly`** (set via
`COMPOSE_PROJECT_NAME` in `.env.nightly`), which prefixes every container /
volume / network — so it **cannot collide with the prod stacks** at
`/home/tinsu/data-hub` (:8754) and `/home/tinsu/co` (:8755).

Prod is never written to; the only interaction is a **read-only `pg_dump`**.

## 2. Login

- Browse https://demo-co.tinsu.ai (or the DH URL) → redirected to DH SSO.
- **Stable demo user:** `demo@tinsu.ai` (role `admin`). Password lives in
  `~/tinsu-deploy/.env.nightly` (`DEMO_USER_PASSWORD`). It is **re-created after
  every snapshot** (see §4) so it survives the nightly prod-data refresh.
- The snapshot also copies prod's real users, so prod admin creds work too —
  but their passwords are prod's, not known here. Use the demo user.

## 3. Box layout

```
/home/tinsu/tinsu-deploy        ← this repo
/home/tinsu/tinsu-deploy/src/   ← nightly's OWN clones (gitignored), synced to
                                  latest main each build: src/data-hub, src/co
/home/tinsu/tinsu-deploy/.env.nightly   ← secrets (gitignored)
/home/tinsu/data-hub            ← prod DH checkout (untouched by nightly)
/home/tinsu/co                  ← prod CO checkout (untouched by nightly)
```

Nightly builds from `src/` clones, **not** the prod checkouts, so a nightly
build never dirties prod's working tree.

## 4. How it stays current — three refresh paths

| Trigger | Script | What it does | Data |
|---|---|---|---|
| **Cron 02:30** | `scripts/nightly-build.sh` | sync `src/` → main, `up --build`, snapshot prod, re-mint token, ensure demo user | refreshed |
| **On merge to main** (per app) | `scripts/rebuild-app.sh {dh,co}` | sync that app's `src/`, `up --build` that service | unchanged |
| **Before a demo** (manual) | `scripts/refresh-now.sh` | snapshot prod, re-mint token, ensure demo user | refreshed |

- **Cron**: `crontab -l` shows `30 2 * * * … nightly-build.sh >> ~/nightly-build.log`.
- **On-merge**: each app repo's self-hosted deploy job (Data Hub `ci-cd.yml`,
  CO `ci.yml`) ends with a `continue-on-error` step that pulls this repo and
  runs `rebuild-app.sh`. A nightly hiccup never fails a prod deploy.
- **Pre-demo**: `cd ~/tinsu-deploy && ./scripts/refresh-now.sh`.

### The snapshot pipeline (`snapshot-prod-to-nightly.sh`)
1. Stop nightly apps.
2. For each DB: **drop + recreate** the nightly DB, then restore a **plain**
   `pg_dump` of prod (NOT `pg_dump --clean` — that fails to drop the `hub`
   schema while pg_trgm/vector extensions depend on it).
3. Copy prod's DH files volume → `nightly_dh_appfiles`.
4. Reset DH `sso_issuer_url` to `NIGHTLY_DH_EXTERNAL_URL` (the snapshot
   overwrote it with prod's value).
5. Start apps → their migrations run forward on the prod snapshot (a free
   **migration canary**).

## 5. Critical wiring — read before changing anything

These are the things that silently break the stack. They're all handled by the
scripts; this is so you understand *why*.

- **Issuer pin.** `NIGHTLY_DH_EXTERNAL_URL` (`https://demo-datahub.tinsu.ai`)
  must equal: DH `sso_issuer_url` (set by snapshot) **and** CO
  `DATA_HUB_ISSUER_URL` (`.env.nightly`). The JWT `iss` is checked against it on
  every CO→DH call and the SSO callback. Mismatch → 401 / login fails.
  CO→DH server-to-server uses the **internal** name `http://dh-app:8754`
  (`DATA_HUB_API_BASE_URL`, `DATA_HUB_JWKS_URL`) for speed.
- **CO service token is re-minted every snapshot.** The snapshot restores prod's
  `hub.service_accounts`, whose tokens were signed by **prod keys + prod issuer**
  → invalid here. `mint-nightly-token.sh` mints a fresh token (signed by the
  nightly keys, `iss` = nightly issuer) and writes it to `.env.nightly`. The
  nightly **signing keys persist** in the `dh_keys` volume so the issuer
  identity is stable across rebuilds.
- **Demo user is re-created every snapshot** (`ensure-demo-user.sh`) for the same
  reason — the snapshot restores prod's `hub.users`.
- **The Cloudflare tunnel is DASHBOARD-managed.** Tunnel `tinsu-online-server`
  loads its ingress from the Cloudflare Zero Trust dashboard, **NOT**
  `/etc/cloudflared/config.yml` (that file is ignored — editing it does
  nothing). To add/remove a public hostname you MUST use the dashboard (or the
  CF API). DNS records are created with `cloudflared tunnel route dns`.
- **`FORCE_HTTPS_COOKIE=1`** on both apps because they're served behind HTTPS
  (Cloudflare terminates TLS; the apps see http internally). Only valid when
  reached via the https domain — the raw `:8764`/`:8765` http access will have
  cookie issues (don't use it for login).

## 6. Common tasks

**Refresh data right before a demo**
```bash
ssh tinsu@100.84.189.87
cd ~/tinsu-deploy && ./scripts/refresh-now.sh
```

**Change the demo password / email**
```bash
# edit ~/tinsu-deploy/.env.nightly  → DEMO_USER_PASSWORD / DEMO_USER_EMAIL
./scripts/ensure-demo-user.sh      # applies immediately
```

**Add a new public domain on this tunnel** (e.g. another demo host)
1. Cloudflare → Zero Trust → Networks → Tunnels → `tinsu-online-server` →
   **Public Hostname → Add**: `<sub>.tinsu.ai` → Service **HTTP** →
   `localhost:<port>`. (DNS is auto-created, or pre-create with
   `cloudflared tunnel route dns tinsu-online-server <sub>.tinsu.ai`.)
2. If it's a new app served over https, set its issuer/cookie env like §5.

**Tear down / rebuild from scratch**
```bash
cd ~/tinsu-deploy
docker compose --env-file .env.nightly -f docker-compose.nightly.yml down -v   # drops nightly volumes
./scripts/nightly-build.sh
```

**Logs**
```bash
docker compose --env-file .env.nightly -f docker-compose.nightly.yml logs -f dh-app
cat ~/nightly-build.log        # cron output
```

## 7. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Domain returns **404** (empty body, `server: cloudflare`) | Public Hostname missing in the CF **dashboard** for that tunnel | Add it in the dashboard (§6). Editing local `config.yml` does nothing. |
| Domain **doesn't resolve** (curl → 000) | DNS record not created | `cloudflared tunnel route dns tinsu-online-server <host>` |
| CO→DH **401** / SSO login bounces back to login | Issuer mismatch, or CO token not re-minted after a snapshot | Check DH `sso_issuer_url` == CO `DATA_HUB_ISSUER_URL`; run `./scripts/mint-nightly-token.sh` |
| Can't log in as demo user | snapshot wiped it / wrong password | `./scripts/ensure-demo-user.sh`; check `.env.nightly` `DEMO_USER_*` |
| Snapshot aborts on `cannot drop schema hub` | someone reverted to `pg_dump --clean` | use drop+recreate + plain restore (already in the script) |
| `DROP DATABASE cannot run inside a transaction block` | two statements in one `psql -c` | separate `-c` flags (already in the script) |
| App unhealthy after rebuild | a new migration failed on prod-shaped data (the canary firing) | check `logs dh-app`; fix the migration in the app repo |

## 8. Notes

- **No passwordless sudo.** The box uses `sudo-rs 0.2.8`; a scoped NOPASSWD
  drop-in (`/etc/sudoers.d/tinsu-cloudflared`) was installed but is **not
  honored** by this sudo version (a blanket `(ALL:ALL) ALL` takes precedence).
  Root-needing tunnel ops therefore still require an interactive sudo password.
  Dashboard hostname changes need no sudo.
- **Resource use.** A 2nd Postgres + 2 apps run alongside prod + many other
  stacks on this box (~21 GB RAM free at setup). Watch memory.
- **Self-healing config.** Issuer + token + demo user are all reset by the
  snapshot/mint/ensure scripts on every refresh, so the https setup survives
  nightly snapshots automatically.
