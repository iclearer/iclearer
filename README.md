# iClearer

Clear space. Keep control.

Native Mac disk cleaner plus marketing site. Finds caches and leftovers, shows what you’ll free, and moves it to Trash.

Official repo for the Mac app, marketing site, design handoff, and Supabase schema.

## Repo layout

| Path | What it is |
|------|------------|
| `mac/` | Native macOS app (AppKit) + build scripts + `iClearer.app` / DMG |
| `website/` | Vite landing page (ported from the design prototype) |
| `supabase/` | SQL for downloads + licenses on the **company** Supabase project |
| `iClearer-developer-handoff/` | Prototypes, brand pack, design tokens, handoff PDF |

## Architecture

- **Website** talks to Supabase for download leads. Buy is stubbed with a free test Pro license until payments go live.
- **Mac app** enforces free vs paid locally (500 MB free cleanup, name/path masking). Activate Pro with the test key below.
- No Python backend.

## Free test Pro user

Payments are not live yet. Use this to unlock paid features in the Mac app:

| Field | Value |
|-------|--------|
| Email | `test@iclearer.com` |
| License key | `ICLR-TEST-0001-FREE` |

Any key containing `TEST` activates Yearly/Pro. A key containing `ONCE` activates the one-time plan.

On the website, **Buy iClearer** opens the same test activation flow.

## Supabase (company project)

1. Open **Supabase → SQL Editor**
2. Run `supabase/001_iclearer_downloads.sql`
3. Optionally run `supabase/002_seed_feedback.sql`
4. Run `supabase/003_iclearer_licenses.sql` (seeds the free test license row)

Or with a Postgres URI:

```bash
cp .env.example .env
# fill SUPABASE_DB_URL
./supabase/apply.sh
```

## Website

```bash
cd website
cp ../.env .env   # or copy from .env.example and fill VITE_SUPABASE_*
npm install
npm run dev
```

Open http://127.0.0.1:5173/

## Mac app

```bash
cd mac
./build.sh
open iClearer.app
```

Ship `mac/dist/iClearer.dmg` (mirrored under `website/public/downloads/`).

## Design source

See `iClearer-developer-handoff/`:

- `prototypes/iclearer-landing.html` — marketing site
- `prototypes/iclearer-app-prototype.html` — Mac app screens
- `design-tokens.json` — colors, radii, prices
- `brand/logo-pack/` — logos / favicon

## Deploy notes

- **Site**: deploy `website/` (static Vite build) with `VITE_SUPABASE_*`
- **DB**: `iclearer_downloads` + `iclearer_licenses` on the company Supabase project
- **App**: notarized direct download (not Mac App Store)
