# Status — tinsu-deploy

**2026-05-29 — LIVE on the demo box.** Nightly/demo stack deployed + verified
end-to-end. Nightly cron installed.

## Deployed state (box 100.84.189.87)
- Repo at `/home/tinsu/tinsu-deploy`; `.env.nightly` filled (generated DB
  passwords, prod LLM config copied, clone URLs `TinsuAI/data-hub` +
  `TinsuAI/co`).
- 4 containers `nightly-*` up: dh-app `:8764`, co-app `:8765`, dh-db, co-db.
- Verified: DH/CO healthz 200; nightly service token authenticates against DH
  (`/v1/hub/dncxs` → real prod clients); CO→DH internal call (`dh-app:8754` +
  token) → 200; `sso_issuer_url = http://100.84.189.87:8764`.
- Prod data mirrored (johnson-vn 65846 BCCT / 13132 materials, growatt-vn).
- Cron: `30 2 * * *` → `scripts/nightly-build.sh`, log `~/nightly-build.log`.

## How it runs
- **Nightly (auto):** cron rebuilds from latest main of both repos (clones in
  `src/`), re-snapshots prod data, re-mints the CO token.
- **Pre-demo (manual):** `./scripts/refresh-now.sh` (data refresh, no rebuild).
- Browse: `http://100.84.189.87:8764` (DH) / `:8765` (CO). Admin login = prod's
  admin (snapshot copies prod users).

## Bugs fixed during the live bring-up
- snapshot used `pg_dump --clean` → couldn't drop `hub` schema (pg_trgm/vector
  dep) → switched to drop+recreate DB + plain restore.
- `DROP DATABASE` inside a txn block → split into separate `psql -c`.
- cron logged to `/var/log` (not writable by tinsu) → `$HOME`.

## Follow-ups
- **On-merge trigger** — DONE 2026-05-29: each app's self-hosted deploy job runs
  `tinsu-deploy/scripts/rebuild-app.sh {dh,co}` after prod deploys (pulls
  tinsu-deploy, rebuilds that nightly service from latest main; continue-on-error).
  Verified live on both DH + CO.
- Watch box RAM (2nd Postgres + 2 apps alongside prod + many other stacks).
- ⚠️ Full unmasked prod client data in the demo — accepted risk (see brief).

## 2026-05-29 PM — Public HTTPS domains live
- `https://demo-datahub.tinsu.ai` (→ nightly DH :8764), `https://demo-co.tinsu.ai` (→ nightly CO :8765).
- Via the existing **dashboard-managed** Cloudflare tunnel `tinsu-online-server`
  (NOT the local `/etc/cloudflared/config.yml` — that file is ignored). Public
  Hostnames added in the CF Zero Trust dashboard; DNS via `cloudflared tunnel route dns`.
- `.env.nightly` flipped to the https URLs + `*_FORCE_HTTPS_COOKIE=1`; DH
  `sso_issuer_url` = `https://demo-datahub.tinsu.ai`; CO token re-minted with the
  matching `iss`. Snapshot + mint scripts already reset both on every nightly run,
  so the https config self-heals across snapshots.
- Verified: both healthz 200 over HTTPS, DH API w/ token 200, CO->DH 200, issuer match.
- Gotcha for future domains on this tunnel: add Public Hostnames in the CF
  **dashboard** (or via API), not the local config.yml.
