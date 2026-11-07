-- iClearer downloads + leads + feedback (company Supabase)
-- One table powers download counts, lead capture, and public feedback.

create table if not exists public.iclearer_downloads (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text,
  email text,
  feedback text
);

create index if not exists iclearer_downloads_created_at_idx
  on public.iclearer_downloads (created_at desc);

create index if not exists iclearer_downloads_feedback_idx
  on public.iclearer_downloads (created_at desc)
  where feedback is not null;

alter table public.iclearer_downloads enable row level security;

drop policy if exists iclearer_downloads_read on public.iclearer_downloads;
create policy iclearer_downloads_read
  on public.iclearer_downloads
  for select
  to anon, authenticated
  using (true);

drop policy if exists iclearer_downloads_insert on public.iclearer_downloads;
create policy iclearer_downloads_insert
  on public.iclearer_downloads
  for insert
  to anon, authenticated
  with check (true);

grant select, insert on public.iclearer_downloads to anon, authenticated;

notify pgrst, 'reload schema';
