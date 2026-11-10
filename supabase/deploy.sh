#!/usr/bin/env bash
# Deploy iClearer Edge Functions + secrets.
# Needs: supabase login   OR   SUPABASE_ACCESS_TOKEN=sbp_...
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ -f .env ]]; then set -a; # shellcheck disable=SC1091
  # Load .env without breaking on JSON values
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" == *=* ]] || continue
    export "$line"
  done < .env
  set +a
fi

PROJECT_REF="${SUPABASE_PROJECT_REF:-kzbimjneyhlivsodhpgm}"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "No SUPABASE_ACCESS_TOKEN. Run:  supabase login"
  echo "Or create a token at https://supabase.com/dashboard/account/tokens"
  echo "then:  export SUPABASE_ACCESS_TOKEN=sbp_..."
  exit 1
fi

supabase link --project-ref "$PROJECT_REF"

echo "Setting secrets…"
supabase secrets set \
  LICENSE_SIGNING_PRIVATE_KEY_B64="$LICENSE_SIGNING_PRIVATE_KEY_B64" \
  LICENSE_SIGNING_PUBLIC_KEY_B64="$LICENSE_SIGNING_PUBLIC_KEY_B64" \
  RESEND_API_KEY="$RESEND_API_KEY" \
  RESEND_FROM_EMAIL="$RESEND_FROM_EMAIL" \
  SITE_URL="${SITE_URL:-$VITE_SITE_URL}" \
  GRACE_DAYS_OK="${GRACE_DAYS_OK:-24}" \
  GRACE_DAYS_WARN="${GRACE_DAYS_WARN:-6}" \
  PADDLE_WEBHOOK_SECRET="${PADDLE_WEBHOOK_SECRET:-}" \
  PADDLE_PRICE_MAP_JSON="${PADDLE_PRICE_MAP_JSON:-{}}" \
  PADDLE_API_KEY="${PADDLE_API_KEY:-}" \
  PADDLE_ENV="${PADDLE_ENV:-sandbox}"

echo "Deploying functions…"
supabase functions deploy license-api --project-ref "$PROJECT_REF" --no-verify-jwt
supabase functions deploy paddle-webhook --project-ref "$PROJECT_REF" --no-verify-jwt
echo "Done."
echo "Paddle webhook URL:"
echo "  ${SUPABASE_URL}/functions/v1/paddle-webhook"
