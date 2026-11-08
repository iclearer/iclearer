-- License / activation records for iClearer (company Supabase project)
create table if not exists public.iclearer_licenses (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  email text not null,
  license_key text not null,
  plan text not null check (plan in ('free', 'monthly', 'yearly', 'once')),
  macs int not null default 1 check (macs in (1, 2, 5)),
  marketing_opt_in boolean not null default false,
  device_hash text,
  device_name text,
  app_version text,
  last_seen_at timestamptz,
  notes text
);

create unique index if not exists iclearer_licenses_key_uidx
  on public.iclearer_licenses (license_key);

create index if not exists iclearer_licenses_email_idx
  on public.iclearer_licenses (lower(email));

alter table public.iclearer_licenses enable row level security;

-- Anon can insert a lead activation request; reads are service-role only for now.
drop policy if exists "iclearer_licenses_insert_anon" on public.iclearer_licenses;
create policy "iclearer_licenses_insert_anon"
  on public.iclearer_licenses
  for insert
  to anon, authenticated
  with check (true);

-- Seed one free Pro test user for development / QA
insert into public.iclearer_licenses (email, license_key, plan, macs, notes)
values (
  'test@iclearer.com',
  'ICLR-TEST-0001-FREE',
  'yearly',
  1,
  'Free test Pro user — no payment required'
)
on conflict (license_key) do nothing;
