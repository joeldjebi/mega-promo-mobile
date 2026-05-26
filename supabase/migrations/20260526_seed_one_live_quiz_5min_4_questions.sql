-- MegaPromo - 1 Quiz Live de 4 questions dans 5 minutes
-- A executer dans Supabase SQL Editor apres:
-- 1) 20260525_create_manual_reward_fields.sql
-- 2) 20260525_seed_reward_catalog_all_types.sql
-- 3) 20260525_process_live_quiz_events_from_question_time.sql
-- Script idempotent: synchronise les QL, cloture les QL ouverts puis
-- cree/met a jour un QL actif de 4 questions qui commence dans 5 minutes.

select public.process_live_quiz_events();

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
  and id <> '20260526-0000-4000-c000-000000004101'::uuid
  and coalesce(status, 'active') not in (
    'inactive',
    'ended',
    'completed',
    'finished'
  )
  and coalesce(live_status, 'scheduled') not in (
    'ended',
    'completed',
    'finished'
  );

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
  where id = '20260525-0000-4000-a000-000000000102'::uuid
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
    '20260526-0000-4000-c000-000000004101'::uuid,
    null,
    'QL Sprint 4 Questions',
    'Quiz Live court de 4 questions. Inscris-toi avant le depart.',
    'https://images.unsplash.com/photo-1551817958-d9d86fb29431?auto=format&fit=crop&w=1200&q=80',
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
    now() + interval '5 minutes' + interval '80 seconds',
    true,
    array['free']::text[],
    true,
    now() + interval '5 minutes',
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
    '20260526-0000-4000-d000-000000004111'::uuid,
    '20260526-0000-4000-c000-000000004101'::uuid,
    'Quelle marque utilise une pomme comme logo ?',
    'Apple',
    'Samsung',
    'Nike',
    'Toyota',
    'A',
    10,
    20,
    1,
    now()
  ),
  (
    '20260526-0000-4000-d000-000000004112'::uuid,
    '20260526-0000-4000-c000-000000004101'::uuid,
    'Combien de secondes y a-t-il dans une minute ?',
    '60',
    '30',
    '90',
    '100',
    'A',
    10,
    20,
    2,
    now()
  ),
  (
    '20260526-0000-4000-d000-000000004113'::uuid,
    '20260526-0000-4000-c000-000000004101'::uuid,
    'Quelle est la capitale politique de la Cote d''Ivoire ?',
    'Yamoussoukro',
    'Abidjan',
    'Bouake',
    'Korhogo',
    'A',
    10,
    20,
    3,
    now()
  ),
  (
    '20260526-0000-4000-d000-000000004114'::uuid,
    '20260526-0000-4000-c000-000000004101'::uuid,
    'Quelle couleur obtient-on souvent en melangeant bleu et jaune ?',
    'Vert',
    'Rouge',
    'Noir',
    'Rose',
    'A',
    10,
    20,
    4,
    now()
  )
on conflict (id) do nothing;

select
  contests.id,
  contests.title,
  contests.status,
  contests.is_live,
  contests.live_status,
  contests.live_starts_at,
  contests.ends_at,
  contests.prize_description,
  count(questions.id) as questions_count,
  sum(questions.time_limit) as live_duration_seconds
from public.contests
left join public.questions on questions.contest_id = contests.id
where contests.id = '20260526-0000-4000-c000-000000004101'::uuid
group by contests.id;
