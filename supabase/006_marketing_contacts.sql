-- Marketing opt-in list: who asked to be emailed about updates / new products.
-- Source of truth for campaigns; kept in sync from signup + Settings toggle.
-- Safe to re-run.

create table if not exists public.iclearer_marketing_contacts (
  email text primary key,
  opted_in boolean not null default true,
  opted_in_at timestamptz not null default now(),
  opted_out_at timestamptz,
  source text not null default 'signup',
  updated_at timestamptz not null default now()
);

create index if not exists iclearer_marketing_contacts_opted_in_idx
  on public.iclearer_marketing_contacts (opted_in)
  where opted_in = true;

alter table public.iclearer_marketing_contacts enable row level security;

-- Backfill from licenses that already opted in.
insert into public.iclearer_marketing_contacts (email, opted_in, opted_in_at, source, updated_at)
select
  lower(trim(email)),
  true,
  coalesce(marketing_opt_in_at, created_at, now()),
  'backfill',
  now()
from public.iclearer_licenses
where marketing_opt_in = true
  and email is not null
  and length(trim(email)) > 3
on conflict (email) do update set
  opted_in = true,
  opted_out_at = null,
  updated_at = now();

-- Query helper: everyone we can email about updates.
create or replace view public.iclearer_marketing_audience as
select email, opted_in_at, source, updated_at
from public.iclearer_marketing_contacts
where opted_in = true;
