-- MegaPromo - QL PROD dans 5 minutes
-- A executer dans Supabase PROD SQL Editor.
-- Cree un Quiz Live gratuit, actif, qui commence 5 minutes apres execution.

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
  and id <> '20260530-0000-4000-c000-000000000501'::uuid
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
  insert into public.reward_catalog (
    id,
    name,
    reward_type,
    description,
    value_label,
    estimated_value,
    partner_id,
    default_code,
    default_delivery_instructions,
    terms,
    stock_quantity,
    used_quantity,
    is_active,
    metadata,
    created_at,
    updated_at
  )
  values (
    '20260530-0000-4000-e000-000000000501'::uuid,
    'Credit de communication QL Express',
    'mobile_money',
    'Credit ou equivalent promotionnel offert au gagnant du Quiz Live Express.',
    'Credit communication 5 000 FCFA',
    5000,
    null,
    'QL-PROD-5MIN',
    'Verifier le gagnant puis traiter la remise du credit depuis le SA.',
    'Quiz gratuit, sans achat requis. Une seule participation par joueur.',
    5,
    0,
    true,
    '{"seed": true, "environment": "prod", "free_quiz": true, "no_purchase_required": true}'::jsonb,
    now(),
    now()
  )
  on conflict (id) do update set
    name = excluded.name,
    reward_type = excluded.reward_type,
    description = excluded.description,
    value_label = excluded.value_label,
    estimated_value = excluded.estimated_value,
    default_code = excluded.default_code,
    default_delivery_instructions = excluded.default_delivery_instructions,
    terms = excluded.terms,
    stock_quantity = excluded.stock_quantity,
    is_active = true,
    metadata = excluded.metadata,
    updated_at = now()
  returning *
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
    reward_metadata,
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
    '20260530-0000-4000-c000-000000000501'::uuid,
    null,
    'QL Express MegaPromo',
    'Quiz Live gratuit de 5 questions pour tester tes connaissances sur MegaPromo, la culture digitale et les marques. Inscris-toi avant le depart, reponds vite et tente de finir en tete du classement.',
    'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80',
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
    coalesce(reward_seed.metadata, '{}'::jsonb),
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
    brand_logo_url = excluded.brand_logo_url,
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
    reward_metadata = excluded.reward_metadata,
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
    '20260530-0000-4000-d000-000000000511'::uuid,
    '20260530-0000-4000-c000-000000000501'::uuid,
    'Que permet MegaPromo aux utilisateurs ?',
    'Decouvrir des marques via des quiz gratuits',
    'Acheter des tickets de pari',
    'Vendre des comptes',
    'Remplacer une banque',
    'A',
    10,
    20,
    1,
    now()
  ),
  (
    '20260530-0000-4000-d000-000000000512'::uuid,
    '20260530-0000-4000-c000-000000000501'::uuid,
    'Quel est le bon reflexe dans un Quiz Live ?',
    'Repondre vite et juste',
    'Quitter la salle',
    'Ignorer le chrono',
    'Partager son code OTP',
    'A',
    10,
    20,
    2,
    now()
  ),
  (
    '20260530-0000-4000-d000-000000000513'::uuid,
    '20260530-0000-4000-c000-000000000501'::uuid,
    'Quel pays MegaPromo met principalement en avant ?',
    'La Cote d''Ivoire',
    'Le Canada',
    'Le Japon',
    'Le Bresil',
    'A',
    10,
    20,
    3,
    now()
  ),
  (
    '20260530-0000-4000-d000-000000000514'::uuid,
    '20260530-0000-4000-c000-000000000501'::uuid,
    'Que represente une recompense partenaire ?',
    'Un avantage offert par une marque',
    'Une dette du joueur',
    'Une mise obligatoire',
    'Un abonnement cache',
    'A',
    10,
    20,
    4,
    now()
  ),
  (
    '20260530-0000-4000-d000-000000000515'::uuid,
    '20260530-0000-4000-c000-000000000501'::uuid,
    'Combien de questions contient ce QL Express ?',
    '5',
    '2',
    '10',
    '20',
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
  contests.is_live,
  contests.live_status,
  contests.starts_at,
  contests.live_starts_at,
  contests.ends_at,
  contests.prize_description,
  count(questions.id) as questions_count,
  sum(questions.time_limit) as live_duration_seconds
from public.contests
left join public.questions on questions.contest_id = contests.id
where contests.id = '20260530-0000-4000-c000-000000000501'::uuid
group by contests.id;
