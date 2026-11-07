-- Seed public feedback copied from the MealLens Clearaer table.
-- Safe to re-run: skips exact name+feedback duplicates.

insert into public.iclearer_downloads (name, email, feedback)
select v.name, v.email, v.feedback
from (values
  ('Israel Afolabi', 'seed@iclearer.local', 'Thank you so much for this product, I have downloaded and used it. Well done.'),
  ('Benjamin Mpano', 'seed@iclearer.local', 'Thank you so much, this saved me almost 30GBs of cache.'),
  ('Digital Dreams', 'seed@iclearer.local', 'I mean… the fuck. This worked. Thank you so much.'),
  ('Chris Eminence', 'seed@iclearer.local', 'You will get one canopy to yourself alone on my wedding day. God bless you.'),
  ('Emmanuel Eves', 'seed@iclearer.local', 'Works perfectly. I recovered around 98GB total mostly Xcode cache, browser cache and old system logs. Cleaned my Mac in seconds, no problems. Best cleaner I''ve tried.'),
  ('Hszucsp Vwdgjndvg', 'reh.i.l.aka.le7.5@gmail.com', 'iuUeDblLimyGPTGYovYvDDv'),
  ('Zjyj Niqcqba', 'i.h.e.b.i.j.eqe.63@gmail.com', 'FsWPrQmJLvcPAbIFK'),
  ('Dbmmo Hqgsazod', 'do.s.a.jobav.i34@gmail.com', 'xaWpRWSEGCiTyqPLARZ')
) as v(name, email, feedback)
where not exists (
  select 1 from public.iclearer_downloads d
  where d.feedback = v.feedback and coalesce(d.name, '') = coalesce(v.name, '')
);
