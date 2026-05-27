-- MegaPromo - Backfill des parametres de tirage manquants
-- Evite les logs "No row found in contest_draw_settings" pour les concours
-- standard qui n'ont pas encore de configuration.

create table if not exists public.contest_draw_settings (
  id uuid primary key default gen_random_uuid(),
  contest_id uuid not null unique references public.contests(id) on delete cascade,
  standard_tickets int4 not null default 1,
  premium_tickets int4 not null default 2,
  confirmation_message text,
  winner_announcement_at timestamptz,
  rules text,
  created_at timestamptz default now()
);

insert into public.contest_draw_settings (
  contest_id,
  standard_tickets,
  premium_tickets,
  confirmation_message,
  winner_announcement_at,
  rules,
  created_at
)
select
  contests.id,
  1,
  2,
  'Ta participation est enregistree.',
  coalesce(contests.ends_at, now()),
  'Une participation par joueur. Les gagnants sont designes automatiquement a la fin du concours.',
  now()
from public.contests
where coalesce(contests.is_live, false) = false
  and not exists (
    select 1
    from public.contest_draw_settings
    where contest_draw_settings.contest_id = contests.id
  )
on conflict (contest_id) do nothing;

select count(*) as draw_settings_count
from public.contest_draw_settings;
