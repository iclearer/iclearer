-- iClearer license platform (self-contained).
-- Creates licenses if missing, then devices / purchases / sign-in tokens.
-- Safe to re-run.

-- ---------------------------------------------------------------------------
-- Licenses (base table — required before anything else)
-- ---------------------------------------------------------------------------
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

-- Extra columns for payments / marketing / heartbeat
alter table public.iclearer_licenses
  add column if not exists marketing_opt_in_at timestamptz;

alter table public.iclearer_licenses
  add column if not exists status text;

alter table public.iclearer_licenses
  add column if not exists paddle_customer_id text;

alter table public.iclearer_licenses
  add column if not exists paddle_subscription_id text;

alter table public.iclearer_licenses
  add column if not exists updated_at timestamptz;

-- Backfill defaults for existing / new nulls
update public.iclearer_licenses set status = 'active' where status is null;
update public.iclearer_licenses set updated_at = now() where updated_at is null;

alter table public.iclearer_licenses
  alter column status set default 'active';

alter table public.iclearer_licenses
  alter column updated_at set default now();

alter table public.iclearer_licenses
  alter column status set not null;

alter table public.iclearer_licenses
  alter column updated_at set not null;

do $$ begin
  alter table public.iclearer_licenses
    drop constraint if exists iclearer_licenses_status_check;
  alter table public.iclearer_licenses
    add constraint iclearer_licenses_status_check
    check (status in ('active', 'past_due', 'cancelled', 'refunded'));
exception when others then null;
end $$;

create index if not exists iclearer_licenses_paddle_sub_idx
  on public.iclearer_licenses (paddle_subscription_id)
  where paddle_subscription_id is not null;

-- Edge Functions use the service role — no open anon inserts.
drop policy if exists "iclearer_licenses_insert_anon" on public.iclearer_licenses;
drop policy if exists iclearer_licenses_insert_anon on public.iclearer_licenses;

-- Seed free Pro test user
insert into public.iclearer_licenses (email, license_key, plan, macs, status, notes)
values (
  'test@iclearer.com',
  'ICLR-TEST-0001-FREE',
  'yearly',
  1,
  'active',
  'Free test Pro user — no payment required'
)
on conflict (license_key) do nothing;

-- ---------------------------------------------------------------------------
-- Devices (one row per Mac seat activation)
-- ---------------------------------------------------------------------------
create table if not exists public.iclearer_devices (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  license_id uuid not null references public.iclearer_licenses(id) on delete cascade,
  device_hash text not null,
  device_name text,
  app_version text,
  last_seen_at timestamptz not null default now(),
  unique (license_id, device_hash)
);

create index if not exists iclearer_devices_license_idx
  on public.iclearer_devices (license_id);

alter table public.iclearer_devices enable row level security;

-- ---------------------------------------------------------------------------
-- Purchases / Paddle events
-- ---------------------------------------------------------------------------
create table if not exists public.iclearer_purchases (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  license_id uuid references public.iclearer_licenses(id) on delete set null,
  email text not null,
  provider text not null default 'paddle',
  provider_event_id text,
  provider_transaction_id text,
  plan text not null check (plan in ('monthly', 'yearly', 'once')),
  macs int not null default 1 check (macs in (1, 2, 5)),
  amount_cents int,
  currency text default 'USD',
  raw jsonb,
  unique (provider, provider_event_id)
);

create index if not exists iclearer_purchases_email_idx
  on public.iclearer_purchases (lower(email));

alter table public.iclearer_purchases enable row level security;

-- ---------------------------------------------------------------------------
-- One-time sign-in / key-resend tokens
-- ---------------------------------------------------------------------------
create table if not exists public.iclearer_signin_tokens (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at timestamptz,
  email text not null,
  license_id uuid references public.iclearer_licenses(id) on delete cascade,
  token_hash text not null unique,
  purpose text not null default 'signin'
    check (purpose in ('signin', 'change_email', 'resend_key'))
);

create index if not exists iclearer_signin_tokens_email_idx
  on public.iclearer_signin_tokens (lower(email));

alter table public.iclearer_signin_tokens enable row level security;

-- ---------------------------------------------------------------------------
-- updated_at helper
-- ---------------------------------------------------------------------------
create or replace function public.iclearer_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists iclearer_licenses_updated_at on public.iclearer_licenses;
create trigger iclearer_licenses_updated_at
  before update on public.iclearer_licenses
  for each row execute function public.iclearer_set_updated_at();

drop trigger if exists iclearer_devices_updated_at on public.iclearer_devices;
create trigger iclearer_devices_updated_at
  before update on public.iclearer_devices
  for each row execute function public.iclearer_set_updated_at();

notify pgrst, 'reload schema';
