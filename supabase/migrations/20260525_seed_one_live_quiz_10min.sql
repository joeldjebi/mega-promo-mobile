-- MegaPromo - 1 Quiz Live dans 10 minutes
-- A executer dans Supabase SQL Editor apres:
-- 1) 20260525_create_manual_reward_fields.sql
-- 2) 20260525_seed_reward_catalog_all_types.sql
-- Script idempotent: cloture les QL expires puis cree/met a jour un QL actif.

alter table public.contests
add column if not exists is_live bool not null default false,
add column if not exists live_starts_at timestamptz,
add column if not exists live_status varchar not null default 'scheduled',
add column if not exists registered_count int4 not null default 0,
add column if not exists connected_count int4 not null default 0,
add column if not exists current_question_index int4 not null default 0,
add column if not exists question_started_at timestamptz,
add column if not exists allowed_player_plan_keys text[] default array[]::text[];

update public.contests
set
  status = 'ended',
  live_status = 'ended'
where coalesce(is_live, false) = true
  and coalesce(status, 'active') = 'active'
  and coalesce(live_status, 'scheduled') in ('scheduled', 'waiting', 'live', 'active')
  and ends_at <= now();

insert into public.contest_types (key, name, description, is_active, order_index)
values
  ('quiz', 'Quiz', 'Concours avec questions, reponses et score.', true, 1)
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
    'Quiz Live',
    'Quiz joues en direct avec inscription et classement.',
    'live',
    '#DC2626',
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
    and coalesce(is_active, true) = true
  limit 1
),
live_contest as (
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
    registered_count,
    connected_count,
    current_question_index,
    question_started_at,
    views_count,
    shares_count,
    created_at
  )
  select
    '20260525-0000-4000-c000-000000000901'::uuid,
    null,
    'QL Culture Express',
    'Quiz Live rapide: culture generale, marques et logique. Inscris-toi avant le depart.',
    'https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=1200&q=80',
    null,
    'MegaPromo',
    'quiz',
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
    now() + interval '10 minutes' + interval '100 seconds',
    true,
    array['free']::text[],
    true,
    now() + interval '10 minutes',
    'scheduled',
    0,
    0,
    0,
    null,
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
    is_live = true,
    live_starts_at = excluded.live_starts_at,
    live_status = 'scheduled',
    registered_count = 0,
    connected_count = 0,
    current_question_index = 0,
    question_started_at = null
  returning id
)
insert into public.questions (
  id,
  contest_id,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_answer,
  points,
  time_limit,
  order_index,
  created_at
)
values
  (
    '20260525-0000-4000-c000-000000000911'::uuid,
    '20260525-0000-4000-c000-000000000901'::uuid,
    'Quelle est la capitale politique de la Cote d''Ivoire ?',
    'Yamoussoukro',
    'Abidjan',
    'Bouake',
    'Daloa',
    'A',
    10,
    20,
    1,
    now()
  ),
  (
    '20260525-0000-4000-c000-000000000912'::uuid,
    '20260525-0000-4000-c000-000000000901'::uuid,
    'Quel logo est associe a la marque Nike ?',
    'Le swoosh',
    'Une pomme',
    'Un lion',
    'Une etoile',
    'A',
    10,
    20,
    2,
    now()
  ),
  (
    '20260525-0000-4000-c000-000000000913'::uuid,
    '20260525-0000-4000-c000-000000000901'::uuid,
    'Combien font 8 x 7 ?',
    '56',
    '48',
    '64',
    '72',
    'A',
    10,
    20,
    3,
    now()
  ),
  (
    '20260525-0000-4000-c000-000000000914'::uuid,
    '20260525-0000-4000-c000-000000000901'::uuid,
    'Quel reseau social est connu pour les videos courtes ?',
    'TikTok',
    'LinkedIn',
    'Wikipedia',
    'Dropbox',
    'A',
    10,
    20,
    4,
    now()
  ),
  (
    '20260525-0000-4000-c000-000000000915'::uuid,
    '20260525-0000-4000-c000-000000000901'::uuid,
    'Quelle couleur obtient-on souvent en melangeant bleu et jaune ?',
    'Vert',
    'Rouge',
    'Noir',
    'Rose',
    'A',
    10,
    20,
    5,
    now()
  )
on conflict (id) do update set
  question_text = excluded.question_text,
  option_a = excluded.option_a,
  option_b = excluded.option_b,
  option_c = excluded.option_c,
  option_d = excluded.option_d,
  correct_answer = excluded.correct_answer,
  points = excluded.points,
  time_limit = excluded.time_limit,
  order_index = excluded.order_index;

select
  contests.id,
  contests.title,
  contests.status,
  contests.live_status,
  contests.live_starts_at,
  contests.ends_at,
  contests.prize_description,
  count(questions.id) as questions_count
from public.contests
left join public.questions on questions.contest_id = contests.id
where contests.id = '20260525-0000-4000-c000-000000000901'::uuid
group by contests.id;
