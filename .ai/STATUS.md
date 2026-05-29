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

## Follow-ups (not done)
- **On-merge trigger** (brief item): add a step to each app repo's deploy job to
  rebuild that service in the nightly stack after prod deploys. Currently
  nightly refreshes on the 02:30 cron only.
- Watch box RAM (2nd Postgres + 2 apps alongside prod + many other stacks).
- ⚠️ Full unmasked prod client data in the demo — accepted risk (see brief).
