-- MegaPromo - 1 Quiz Live IA de 5 questions
-- A executer dans Supabase SQL Editor apres:
-- 1) 20260525_create_manual_reward_fields.sql
-- 2) 20260525_seed_reward_catalog_all_types.sql
-- 3) 20260525_process_live_quiz_events_from_question_time.sql
-- Cree/met a jour un QL actif sur l'IA qui commence dans 5 minutes.

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
  and id <> '20260526-0000-4000-c000-000000005101'::uuid
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
    '20260526-0000-4000-c000-000000005101'::uuid,
    null,
    'QL Intelligence Artificielle',
    'Quiz Live sur les bases de l intelligence artificielle, des donnees et des usages IA.',
    'https://images.unsplash.com/photo-1677442136019-21780ecad995?auto=format&fit=crop&w=1200&q=80',
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
    now() + interval '5 minutes' + interval '100 seconds',
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
    '20260526-0000-4000-d000-000000005111'::uuid,
    '20260526-0000-4000-c000-000000005101'::uuid,
    'Que signifie IA ?',
    'Intelligence artificielle',
    'Interface automatique',
    'Information annuelle',
    'Indice analytique',
    'A',
    10,
    20,
    1,
    now()
  ),
  (
    '20260526-0000-4000-d000-000000005112'::uuid,
    '20260526-0000-4000-c000-000000005101'::uuid,
    'Quel element aide souvent une IA a apprendre ?',
    'Des donnees',
    'Une batterie',
    'Un ticket',
    'Une couleur',
    'A',
    10,
    20,
    2,
    now()
  ),
  (
    '20260526-0000-4000-d000-000000005113'::uuid,
    '20260526-0000-4000-c000-000000005101'::uuid,
    'Quel outil peut generer du texte a partir d une demande ?',
    'Un modele de langage',
    'Un chargeur',
    'Un navigateur GPS seul',
    'Une imprimante sans logiciel',
    'A',
    10,
    20,
    3,
    now()
  ),
  (
    '20260526-0000-4000-d000-000000005114'::uuid,
    '20260526-0000-4000-c000-000000005101'::uuid,
    'Pourquoi faut-il verifier une reponse produite par une IA ?',
    'Elle peut se tromper',
    'Elle ne repond jamais',
    'Elle lit toujours dans le futur',
    'Elle supprime les questions',
    'A',
    10,
    20,
    4,
    now()
  ),
  (
    '20260526-0000-4000-d000-000000005115'::uuid,
    '20260526-0000-4000-c000-000000005101'::uuid,
    'Quel usage est courant avec l IA generative ?',
    'Creer du texte ou des images',
    'Remplacer une carte SIM',
    'Augmenter la taille d un ecran',
    'Charger un telephone sans energie',
    'A',
    10,
    20,
    5,
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
where contests.id = '20260526-0000-4000-c000-000000005101'::uuid
group by contests.id;
