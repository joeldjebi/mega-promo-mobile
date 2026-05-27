-- MegaPromo - Jeu concours standard qui se termine dans 1 minute
-- A executer dans Supabase SQL Editor apres:
-- 1) 20260525_create_manual_reward_fields.sql
-- 2) 20260525_seed_reward_catalog_all_types.sql
-- 3) 202605260009_process_contest_events_all.sql
-- 4) 202605260012_enable_contests_realtime.sql
-- Script idempotent: cree/met a jour un jeu concours tirage actif, non-live,
-- qui se termine 1 minute apres execution.

select public.process_contest_events();

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

insert into public.contest_types (key, name, description, is_active, order_index)
values
  ('tirage', 'Tirage', 'Participation simple avec selection de gagnants.', true, 2)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = true,
  order_index = excluded.order_index;

with category_seed as (
  insert into public.categories (
    name,
    description,
    icon,
    color,
    is_active,
    created_at
  )
  values (
    'Jeux concours',
    'Concours standard ouverts aux joueurs.',
    'game',
    '#2563EB',
    true,
    now()
  )
  on conflict (name) do update set
    description = excluded.description,
    icon = excluded.icon,
    color = excluded.color,
    is_active = true
  returning id, name
),
reward_seed as (
  select *
  from public.reward_catalog
  where id = '20260525-0000-4000-a000-000000000101'::uuid
  limit 1
),
contest_seed as (
  insert into public.contests (
    id,
    partner_id,
    title,
    description,
    image_url,
    brand_logo_url,
    brand_name,
    type,
    category,
    category_id,
    status,
    prize_description,
    prize_value,
    reward_type,
    reward_catalog_id,
    reward_delivery_mode,
    reward_delivery_instructions,
    reward_terms,
    winners_count,
    max_participants,
    starts_at,
    ends_at,
    is_boosted,
    allowed_player_plan_keys,
    is_live,
    live_starts_at,
    live_status,
    views_count,
    shares_count,
    created_at
  )
  select
    '20260526-0000-4000-9000-000000000401'::uuid,
    null,
    'Jeu Minute Mobile Money',
    'Participe maintenant: le tirage du gagnant se fait dans une minute.',
    'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=1200&q=80',
    null,
    'MegaPromo',
    'tirage',
    category_seed.name,
    category_seed.id,
    'active',
    reward_seed.value_label,
    reward_seed.estimated_value,
    reward_seed.reward_type,
    reward_seed.id,
    'manual',
    reward_seed.default_delivery_instructions,
    reward_seed.terms,
    1,
    null,
    now(),
    now() + interval '1 minute',
    true,
    array['free']::text[],
    false,
    null,
    'scheduled',
    0,
    0,
    now()
  from category_seed
  cross join reward_seed
  on conflict (id) do update set
    title = excluded.title,
    description = excluded.description,
    image_url = excluded.image_url,
    brand_name = excluded.brand_name,
    type = excluded.type,
    category = excluded.category,
    category_id = excluded.category_id,
    status = excluded.status,
    prize_description = excluded.prize_description,
    prize_value = excluded.prize_value,
    reward_type = excluded.reward_type,
    reward_catalog_id = excluded.reward_catalog_id,
    reward_delivery_mode = excluded.reward_delivery_mode,
    reward_delivery_instructions = excluded.reward_delivery_instructions,
    reward_terms = excluded.reward_terms,
    winners_count = excluded.winners_count,
    max_participants = excluded.max_participants,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    is_boosted = excluded.is_boosted,
    allowed_player_plan_keys = excluded.allowed_player_plan_keys,
    is_live = false,
    live_starts_at = null,
    live_status = 'scheduled'
  returning id
),
draw_settings_seed as (
  insert into public.contest_draw_settings (
    contest_id,
    standard_tickets,
    premium_tickets,
    confirmation_message,
    winner_announcement_at,
    rules,
    created_at
  )
  values (
    '20260526-0000-4000-9000-000000000401'::uuid,
    1,
    2,
    'Ta participation au Jeu Minute Mobile Money est enregistree.',
    now() + interval '1 minute',
    'Une participation par joueur. Tirage automatique a la fin du concours.',
    now()
  )
  on conflict (contest_id) do update set
    standard_tickets = excluded.standard_tickets,
    premium_tickets = excluded.premium_tickets,
    confirmation_message = excluded.confirmation_message,
    winner_announcement_at = excluded.winner_announcement_at,
    rules = excluded.rules
  returning contest_id
)
select
  contests.id,
  contests.title,
  contests.type,
  contests.is_live,
  contests.starts_at,
  contests.ends_at,
  contests.prize_description,
  contests.reward_catalog_id
from public.contests
where contests.id = '20260526-0000-4000-9000-000000000401'::uuid;
