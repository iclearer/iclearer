-- Creem payment provider columns (Paddle columns kept for history).
alter table public.iclearer_licenses
  add column if not exists creem_customer_id text;

alter table public.iclearer_licenses
  add column if not exists creem_subscription_id text;

create index if not exists iclearer_licenses_creem_sub_idx
  on public.iclearer_licenses (creem_subscription_id)
  where creem_subscription_id is not null;
