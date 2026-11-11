# iClearer Supabase (licenses + payments)

## Schema

Apply in order (SQL Editor or `./apply.sh` with `SUPABASE_DB_URL`):

1. `001_iclearer_downloads.sql` — download leads / feedback  
2. `002_seed_feedback.sql` — optional  
3. `003_iclearer_licenses.sql` — licenses + test key  
4. `004_license_platform.sql` — devices, purchases, sign-in tokens, harden RLS  

## Edge Functions

| Function | Role |
|----------|------|
| `license-api` | `signup`, `activate`, `heartbeat`, `send_signin_link`, `resend_key`, `list_devices`, `remove_device` |
| `paddle-webhook` | Paddle Billing events → upgrade license + email key |

### Secrets (Dashboard → Edge Functions → Secrets)

```
LICENSE_SIGNING_PRIVATE_KEY_B64=
LICENSE_SIGNING_PUBLIC_KEY_B64=
RESEND_API_KEY=
RESEND_FROM_EMAIL=iClearer <licenses@iclearer.com>
SITE_URL=https://iclearer.com
PADDLE_WEBHOOK_SECRET=pdl_ntfset_...
PADDLE_PRICE_MAP_JSON={"pri_LIVE_YEARLY_1":{"plan":"yearly","macs":1}}
# Optional: set PADDLE_IP_ALLOWLIST=1 to reject non-Paddle source IPs (fetches https://api.paddle.com/ips)
GRACE_DAYS_OK=24
GRACE_DAYS_WARN=6
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically on hosted functions.

### Deploy

```bash
supabase login
supabase link --project-ref kzbimjneyhlivsodhpgm
supabase secrets set --env-file ../.env
supabase functions deploy license-api --no-verify-jwt
supabase functions deploy paddle-webhook --no-verify-jwt
```

### Signup → email key → Sign in

1. Mac/website calls `action: "signup"` with email  
2. Creates `plan=free` license + `ICLR-…` key  
3. Resend emails the key  
4. Mac opens **Sign in or activate**  
5. `action: "activate"` binds `device_hash`, returns **signed license blob** (Keychain)  
6. Offline: app verifies blob with embedded public key (24+6 day grace)  
7. Online: `heartbeat` refreshes the blob  

### Test key

`test@iclearer.com` / `ICLR-TEST-0001-FREE` (seeded). Mac also accepts `TEST` / `ONCE` keys offline if the API is down.
