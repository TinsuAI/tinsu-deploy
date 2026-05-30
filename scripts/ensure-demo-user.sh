#!/usr/bin/env bash
# Ensure a stable demo user on nightly DH. Runs after every snapshot (the
# snapshot restores prod's hub.users and would otherwise wipe any nightly-only
# user). Role 'admin' = cross-client visibility; resets daily anyway.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env.nightly ] || { echo "[demo-user] no .env.nightly — skip" >&2; exit 0; }
set -a; . ./.env.nightly; set +a
C="docker compose --env-file .env.nightly -f docker-compose.nightly.yml"

EMAIL="${DEMO_USER_EMAIL:-demo@tinsu.ai}"
PW="${DEMO_USER_PASSWORD:?set DEMO_USER_PASSWORD in .env.nightly}"
NAME="${DEMO_USER_NAME:-Demo}"

echo "[demo-user] waiting for nightly DH /healthz"
for _ in $(seq 1 30); do
  $C exec -T dh-app curl -fsS http://127.0.0.1:8754/healthz >/dev/null 2>&1 && break || sleep 2
done

$C exec -T -e DEMO_EMAIL="$EMAIL" -e DEMO_PW="$PW" -e DEMO_NAME="$NAME" dh-app \
  uv run python - <<'PY'
import os
from app import auth
from app.database import connect
email, pw, name = os.environ["DEMO_EMAIL"], os.environ["DEMO_PW"], os.environ["DEMO_NAME"]
with connect() as c:
    cur = c.cursor()
    cur.execute(
        """insert into hub.users (user_id, email, display_name, password_hash, role, status)
           values (%s, %s, %s, %s, 'admin', 'active')
           on conflict (email) do update set
             password_hash = excluded.password_hash,
             display_name  = excluded.display_name,
             role          = 'admin',
             status        = 'active'""",
        ("u_demo_fixed", email, name, auth.hash_password(pw)),
    )
print("[demo-user] ensured:", email, "(admin)")
PY
