-- MegaPromo - 2 concours standard + 3 Quiz Live avec gains catalogue
-- A executer dans Supabase SQL Editor apres:
-- 1) 20260525_create_manual_reward_fields.sql
-- 2) 20260525_seed_reward_catalog_all_types.sql
-- Script idempotent: cree/met a jour 2 concours standard actifs et 3 QL
-- prets a activer. Les QL sont crees en inactive car la base interdit
-- plusieurs Quiz Live ouverts en meme temps.

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

alter table public.contests
add column if not exists is_live bool not null default false,
add column if not exists live_starts_at timestamptz,
add column if not exists live_status varchar not null default 'scheduled',
add column if not exists registered_count int4 not null default 0,
add column if not exists connected_count int4 not null default 0,
add column if not exists current_question_index int4 not null default 0,
add column if not exists question_started_at timestamptz,
add column if not exists allowed_player_plan_keys text[] default array[]::text[];

insert into public.contest_types (key, name, description, is_active, order_index)
values
  ('quiz', 'Quiz', 'Concours avec questions, reponses et score.', true, 1),
  ('tirage', 'Tirage', 'Participation simple avec selection de gagnants.', true, 2)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = true,
  order_index = excluded.order_index;

with category_standard as (
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
category_live as (
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
standard_seed as (
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
    seed.contest_id,
    null,
    seed.title,
    seed.description,
    seed.image_url,
    null,
    'MegaPromo',
    seed.contest_type,
    category_standard.name,
    category_standard.id,
    'active',
    reward_catalog.value_label,
    reward_catalog.estimated_value,
    reward_catalog.reward_type,
    reward_catalog.id,
    'manual',
    reward_catalog.default_delivery_instructions,
    reward_catalog.terms,
    seed.winners_count,
    null,
    now(),
    now() + interval '2 hours',
    seed.is_boosted,
    array['free']::text[],
    false,
    null,
    'scheduled',
    0,
    0,
    now()
  from category_standard
  join (
    values
      (
        '20260525-0000-4000-b000-000000000201'::uuid,
        'Quiz Standard Bons Plans',
        'Reponds a quelques questions rapides et tente de gagner un bon de reduction.',
        'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80',
        'quiz',
        '20260525-0000-4000-a000-000000000103'::uuid,
        1,
        true
      ),
      (
        '20260525-0000-4000-b000-000000000202'::uuid,
        'Tirage Lot Surprise 2H',
        'Participe au tirage standard et tente de gagner un lot physique surprise.',
        'https://images.unsplash.com/photo-1513201099705-a9746e1e201f?auto=format&fit=crop&w=1200&q=80',
        'tirage',
        '20260525-0000-4000-a000-000000000105'::uuid,
        1,
        false
      )
  ) as seed (
    contest_id,
    title,
    description,
    image_url,
    contest_type,
    reward_catalog_id,
    winners_count,
    is_boosted
  ) on true
  join public.reward_catalog on reward_catalog.id = seed.reward_catalog_id
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
live_seed as (
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
    seed.contest_id,
    null,
    seed.title,
    seed.description,
    seed.image_url,
    null,
    'MegaPromo',
    'quiz',
    category_live.name,
    category_live.id,
    'inactive',
    reward_catalog.value_label,
    reward_catalog.estimated_value,
    reward_catalog.reward_type,
    reward_catalog.id,
    'manual',
    reward_catalog.default_delivery_instructions,
    reward_catalog.terms,
    1,
    null,
    now(),
    now() + seed.starts_after + interval '7 minutes',
    true,
    array['free']::text[],
    true,
    now() + seed.starts_after,
    'scheduled',
    0,
    0,
    0,
    null,
    0,
    0,
    now()
  from category_live
  join (
    values
      (
        '20260525-0000-4000-b000-000000000301'::uuid,
        'QL Culture Generale',
        'Quiz Live rapide sur la culture generale. Inscris-toi avant le debut.',
        'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?auto=format&fit=crop&w=1200&q=80',
        interval '10 minutes',
        '20260525-0000-4000-a000-000000000101'::uuid
      ),
      (
        '20260525-0000-4000-b000-000000000302'::uuid,
        'QL Marques et Logos',
        'Teste tes connaissances sur les marques, logos et slogans.',
        'https://images.unsplash.com/photo-1556742502-ec7c0e9f34b1?auto=format&fit=crop&w=1200&q=80',
        interval '20 minutes',
        '20260525-0000-4000-a000-000000000102'::uuid
      ),
      (
        '20260525-0000-4000-b000-000000000303'::uuid,
        'QL Musique et Evenements',
        'Un Quiz Live sur la musique, les concerts et les grands evenements.',
        'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=1200&q=80',
        interval '30 minutes',
        '20260525-0000-4000-a000-000000000104'::uuid
      )
  ) as seed (
    contest_id,
    title,
    description,
    image_url,
    starts_after,
    reward_catalog_id
  ) on true
  join public.reward_catalog on reward_catalog.id = seed.reward_catalog_id
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
),
questions_seed as (
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
      '20260525-0000-4000-b000-000000000401'::uuid,
      '20260525-0000-4000-b000-000000000201'::uuid,
      'Que signifie un bon de reduction ?',
      'Une remise sur un achat',
      'Une facture a payer',
      'Une inscription annulee',
      'Un mot de passe',
      'A',
      10,
      20,
      1,
      now()
    ),
    (
      '20260525-0000-4000-b000-000000000402'::uuid,
      '20260525-0000-4000-b000-000000000201'::uuid,
      'Quel est le bon comportement dans un quiz ?',
      'Repondre vite et juste',
      'Quitter la page',
      'Ignorer les questions',
      'Repondre au hasard uniquement',
      'A',
      10,
      20,
      2,
      now()
    ),
    (
      '20260525-0000-4000-b000-000000000411'::uuid,
      '20260525-0000-4000-b000-000000000301'::uuid,
      'Quelle est la capitale de la Cote d''Ivoire ?',
      'Yamoussoukro',
      'Abidjan',
      'Bouake',
      'San Pedro',
      'A',
      10,
      20,
      1,
      now()
    ),
    (
      '20260525-0000-4000-b000-000000000412'::uuid,
      '20260525-0000-4000-b000-000000000301'::uuid,
      'Combien de jours compte une semaine ?',
      '7',
      '5',
      '10',
      '12',
      'A',
      10,
      20,
      2,
      now()
    ),
    (
      '20260525-0000-4000-b000-000000000413'::uuid,
      '20260525-0000-4000-b000-000000000301'::uuid,
      'Quelle couleur obtient-on souvent en melangeant bleu et jaune ?',
      'Vert',
      'Rouge',
      'Noir',
      'Rose',
      'A',
      10,
      20,
      3,
      now()
    ),
    (
      '20260525-0000-4000-b000-000000000421'::uuid,
      '20260525-0000-4000-b000-000000000302'::uuid,
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
      '20260525-0000-4000-b000-000000000422'::uuid,
      '20260525-0000-4000-b000-000000000302'::uuid,
      'Quel logo est associe a Nike ?',
      'Le swoosh',
      'Une etoile',
      'Un crocodile',
      'Une couronne',
      'A',
      10,
      20,
      2,
      now()
    ),
    (
      '20260525-0000-4000-b000-000000000423'::uuid,
      '20260525-0000-4000-b000-000000000302'::uuid,
      'Quel reseau social est connu pour les videos courtes ?',
      'TikTok',
      'LinkedIn',
      'Wikipedia',
      'Dropbox',
      'A',
      10,
      20,
      3,
      now()
    ),
    (
      '20260525-0000-4000-b000-000000000431'::uuid,
      '20260525-0000-4000-b000-000000000303'::uuid,
      'Que permet un ticket de concert ?',
      'Entrer a un evenement',
      'Acheter un telephone',
      'Changer de mot de passe',
      'Supprimer un compte',
      'A',
      10,
      20,
      1,
      now()
    ),
    (
      '20260525-0000-4000-b000-000000000432'::uuid,
      '20260525-0000-4000-b000-000000000303'::uuid,
      'Quel instrument a des touches noires et blanches ?',
      'Piano',
      'Tam-tam',
      'Guitare',
      'Saxophone',
      'A',
      10,
      20,
      2,
      now()
    ),
    (
      '20260525-0000-4000-b000-000000000433'::uuid,
      '20260525-0000-4000-b000-000000000303'::uuid,
      'Dans un concert, qui monte generalement sur scene ?',
      'L artiste',
      'Le serveur DNS',
      'Le navigateur',
      'Le mot de passe',
      'A',
      10,
      20,
      3,
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
    order_index = excluded.order_index
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
    '20260525-0000-4000-b000-000000000202'::uuid,
    1,
    2,
    'Ta participation au Tirage Lot Surprise 2H est enregistree.',
    now() + interval '2 hours',
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
  contests.live_starts_at,
  contests.ends_at,
  contests.prize_description,
  contests.reward_catalog_id,
  count(questions.id) as questions_count
from public.contests
left join public.questions on questions.contest_id = contests.id
where contests.id in (
  '20260525-0000-4000-b000-000000000201'::uuid,
  '20260525-0000-4000-b000-000000000202'::uuid,
  '20260525-0000-4000-b000-000000000301'::uuid,
  '20260525-0000-4000-b000-000000000302'::uuid,
  '20260525-0000-4000-b000-000000000303'::uuid
)
group by contests.id
order by contests.is_live, contests.live_starts_at nulls first, contests.title;
