# iClearer

Free Mac disk cleaner. Finds caches and leftover files, then lets you move them to Trash.

Official repo for the Mac app, marketing site, and Supabase schema.

## Repo layout

| Path | What it is |
|------|------------|
| `mac/` | Native macOS app sources + build scripts + `dist/iClearer.dmg` |
| `website/` | Vite + React landing page (download, feedback, install) |
| `supabase/` | SQL to create `iclearer_downloads` on the **company** Supabase project |

## Architecture

The website talks to Supabase directly for download counts, leads, and feedback. No Python backend.

## Supabase (company project)

Create this table on the iClearer company Supabase (not MealLens):

1. Open **Supabase → SQL Editor**
2. Run `supabase/001_iclearer_downloads.sql`
3. Optionally run `supabase/002_seed_feedback.sql`

Or with a Postgres URI:

```bash
cp .env.example .env
# fill SUPABASE_DB_URL
./supabase/apply.sh
```

Table: `iclearer_downloads`

| Column | Use |
|--------|-----|
| `id`, `created_at` | Row identity |
| `name`, `email` | Lead before download |
| `feedback` | Public feedback text (`null` = download/lead only) |

Download counter = rows where `feedback is null`.

## Website

```bash
cd website
cp ../.env.example .env
# set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY
npm install
npm run dev
```

Build:

```bash
cd website && npm run build
```


## Mac app

```bash
cd mac
./build.sh
open iClearer.app   # after rename in build script, or open Clearaer.app from current build
```

Ship `mac/dist/iClearer.dmg` (also mirrored under `website/public/downloads/`).

## Deploy notes

Next deploys should come from this repo:

- **Site**: deploy `website/` (static Vite build) with `VITE_SUPABASE_*` pointed at company Supabase
- **DB**: keep `iclearer_downloads` on the company Supabase project
