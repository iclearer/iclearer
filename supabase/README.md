# iClearer Supabase (licenses + payments)

## Schema

Apply in order (SQL Editor or `./apply.sh` with `SUPABASE_DB_URL`):

1. `001_iclearer_downloads.sql` — download leads / feedback  
2. `002_seed_feedback.sql` — optional  
3. `003_iclearer_licenses.sql` — licenses + test key  
4. `004_license_platform.sql` — devices, purchases, sign-in tokens, harden RLS  
5. `007_creem_columns.sql` — Creem customer/subscription columns  

## Edge Functions

| Function | Role |
|----------|------|
| `license-api` | `signup`, `activate`, `heartbeat`, `send_signin_link`, `resend_key`, `list_devices`, `remove_device`, `create_checkout` (Creem) |
| `creem-webhook` | Creem MoR events → upgrade license + email key |
| `paddle-webhook` | Legacy Paddle Billing (kept for old subscriptions) |

### Secrets (Dashboard → Edge Functions → Secrets)

```
LICENSE_SIGNING_PRIVATE_KEY_B64=
LICENSE_SIGNING_PUBLIC_KEY_B64=
RESEND_API_KEY=
RESEND_FROM_EMAIL=iClearer <licenses@iclearer.com>
SITE_URL=https://www.iclearer.com
CREEM_API_KEY=creem_test_...   # or creem_ live key — never expose to the browser
CREEM_WEBHOOK_SECRET=
CREEM_PRODUCT_MAP_JSON={"yearly:1":"prod_xxx","yearly:2":"prod_xxx","yearly:5":"prod_xxx","monthly:1":"prod_xxx","monthly:2":"prod_xxx","monthly:5":"prod_xxx","once:1":"prod_xxx","once:2":"prod_xxx","once:5":"prod_xxx"}
CREEM_PRODUCT_REVERSE_JSON={"prod_xxx":{"plan":"yearly","macs":1}}
GRACE_DAYS_OK=24
GRACE_DAYS_WARN=6
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically on hosted functions.

Seed Creem products (prints both JSON maps):

```bash
export CREEM_API_KEY=creem_test_...
node scripts/creem-seed-products.mjs
```

Webhook URL in Creem Developers → Webhooks:

`https://kzbimjneyhlivsodhpgm.supabase.co/functions/v1/creem-webhook`

Events: `checkout.completed`, `subscription.paid`, `subscription.canceled`, `subscription.expired`, `subscription.past_due`.

### Deploy

```bash
supabase login
supabase link --project-ref kzbimjneyhlivsodhpgm
supabase secrets set --env-file ../.env
supabase functions deploy license-api --no-verify-jwt
supabase functions deploy creem-webhook --no-verify-jwt
```

### Signup → email key → Sign in → Buy

1. Mac/website calls `action: "signup"` with email  
2. Creates `plan=free` license + `ICLR-…` key  
3. Resend emails the key  
4. Buy calls `action: "create_checkout"` → Creem hosted checkout (same key in metadata)  
5. Creem webhook upgrades that key to paid  
6. Mac `activate` / `heartbeat` returns signed license blob  

### Test key

`test@iclearer.com` / `ICLR-TEST-0001-FREE` (seeded). Mac also accepts `TEST` / `ONCE` keys offline if the API is down.
