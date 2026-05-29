# tinsu-deploy — agent notes

Deploy/ops repo for the **nightly/demo stack** (Data Hub + CO) on the demo VPS.
Not an application — it holds compose + shell scripts + env templates only.

## Rules

- **Never commit secrets.** Tokens/passwords live only in `.env.nightly`
  (gitignored). Commit `.env.nightly.template` instead.
- **Prod is read-only from here.** Scripts `pg_dump` prod but must never write
  to prod DBs/volumes. The nightly stack is fully isolated (project `nightly`).
- **Scripts run on the box** (`/home/tinsu/tinsu-deploy`), bash, `set -euo
  pipefail`. Build contexts `../data-hub` and `../co` assume the box layout.
- Commit messages in English, no AI co-author trailers.

## Context

- Design + accepted risks: `.ai/features/2026-05-29-nightly-demo-stack/brief.md`.
- Service-token + issuer mechanics: see the Data Hub repo
  (`app/jwt_issuer.py`, `/admin/service-accounts`) and its sister-app note
  `.ai/sister-app-notes/2026-05-29-service-account-admin-ui-and-1y-tokens.md`.
- Standards: `TinsuAI/standards`.

## Status

`.ai/STATUS.md` — current scaffold state + next steps (dry-run pending).
