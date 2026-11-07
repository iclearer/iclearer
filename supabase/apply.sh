#!/usr/bin/env bash
# Apply iClearer SQL to the company Supabase project.
# Requires: SUPABASE_DB_URL  (Postgres URI from Project Settings → Database)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then set -a; source "$ROOT/.env"; set +a; fi
if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "Set SUPABASE_DB_URL to your company Supabase Postgres URI." >&2
  echo "Or paste supabase/001_iclearer_downloads.sql in the Supabase SQL Editor." >&2
  exit 1
fi
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$ROOT/supabase/001_iclearer_downloads.sql"
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$ROOT/supabase/002_seed_feedback.sql"
echo "Done."
