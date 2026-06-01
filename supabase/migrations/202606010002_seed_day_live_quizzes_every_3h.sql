-- MegaPromo - QL de la journee, toutes les 3h apres la fin du precedent
-- A executer dans Supabase SQL Editor.
--
-- Cree 8 Quiz Live gratuits pour couvrir environ une journee.
-- Le premier commence 5 minutes apres execution.
-- Chaque QL dure 100 secondes: 5 questions x 20 secondes.
-- Le QL suivant commence 3h apres la fin du precedent.
--
-- Important:
-- - ce seed ne termine pas les autres QL;
-- - il est compatible avec la file d'attente QL;
-- - execute d'abord en DEV pour tester, puis en PROD uniquement si tu veux
--   programmer ces QL pour les vrais joueurs.

select public.process_contest_events();

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
    '20260601-0000-4000-e000-000000000701'::uuid,
    'Credit QL Journee MegaPromo',
    'voucher',
    'Credit promotionnel offert aux gagnants des Quiz Live programmes sur la journee.',
    'Credit 5 000 FCFA',
    5000,
    null,
    'QL-DAY-5000',
    'Contacter le gagnant depuis le SA pour confirmer son identite et organiser la remise du credit.',
    'Quiz gratuit, sans achat requis. Credit promotionnel personnel, non remboursable.',
    20,
    0,
    true,
    '{"seed": true, "environment": "multi", "free_quiz": true, "schedule": "every_3h_after_previous_end"}'::jsonb,
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
quiz_slots as (
  select
    slot_index,
    now()
      + interval '5 minutes'
      + ((slot_index - 1) * (interval '3 hours' + interval '100 seconds'))
        as live_starts_at
  from generate_series(1, 8) as slot_index
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
    (
      '20260601-0000-4000-c'
      || lpad(quiz_slots.slot_index::text, 3, '0')
      || '-'
      || lpad((700 + quiz_slots.slot_index)::text, 12, '0')
    )::uuid,
    null,
    'QL Journee #' || quiz_slots.slot_index || ' - Reflexes MegaPromo',
    'Quiz Live gratuit programme automatiquement dans la file QL de la journee. Inscris-toi avant le depart, reponds juste et vite, puis tente de finir en tete du classement.',
    'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80',
    'https://www.google.com/s2/favicons?domain=megapromo.app&sz=128',
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
    coalesce(reward_seed.metadata, '{}'::jsonb)
      || jsonb_build_object(
        'schedule_index',
        quiz_slots.slot_index,
        'free_quiz',
        true,
        'no_purchase_required',
        true
      ),
    1,
    null,
    now(),
    quiz_slots.live_starts_at + interval '100 seconds',
    true,
    array['free']::text[],
    true,
    quiz_slots.live_starts_at,
    'scheduled',
    0,
    0,
    0,
    null,
    0,
    0,
    now()
  from quiz_slots
  cross join category_seed
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
),
question_templates as (
  select *
  from (
    values
      (
        1,
        'Quel est le principal objectif dans un Quiz Live MegaPromo ?',
        'Repondre juste et vite',
        'Attendre la fin sans jouer',
        'Partager son mot de passe',
        'Choisir au hasard uniquement',
        'A',
        10,
        20
      ),
      (
        2,
        'Si deux joueurs ont toutes les bonnes reponses, qui gagne ?',
        'Celui qui a le temps total le plus court',
        'Celui qui a le plus grand avatar',
        'Celui qui arrive le dernier',
        'Celui qui quitte l''application',
        'A',
        10,
        20
      ),
      (
        3,
        'Dans MegaPromo, un QL signifie quoi ?',
        'Quiz Live',
        'Question Lente',
        'Quota Local',
        'Qualite Liste',
        'A',
        10,
        20
      ),
      (
        4,
        'Quel bon reflexe adopter avant le depart d''un QL ?',
        'Entrer en salle d''attente',
        'Fermer internet',
        'Desinstaller l''application',
        'Ignorer le compte a rebours',
        'A',
        10,
        20
      ),
      (
        5,
        'Que mesure le temps dans le classement QL ?',
        'La rapidite totale de reponse',
        'Le nombre de partages seulement',
        'La taille du telephone',
        'La distance du joueur',
        'A',
        10,
        20
      )
  ) as templates (
    order_index,
    question_text,
    option_a,
    option_b,
    option_c,
    option_d,
    correct_answer,
    points,
    time_limit
  )
),
question_seed as (
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
  select
    (
      '20260601-0000-4000-d'
      || lpad(quiz_slots.slot_index::text, 3, '0')
      || '-'
      || lpad(
        (700000 + quiz_slots.slot_index * 10 + question_templates.order_index)::text,
        12,
        '0'
      )
    )::uuid,
    (
      '20260601-0000-4000-c'
      || lpad(quiz_slots.slot_index::text, 3, '0')
      || '-'
      || lpad((700 + quiz_slots.slot_index)::text, 12, '0')
    )::uuid,
    question_templates.question_text,
    question_templates.option_a,
    question_templates.option_b,
    question_templates.option_c,
    question_templates.option_d,
    question_templates.correct_answer,
    question_templates.points,
    question_templates.time_limit,
    question_templates.order_index,
    now()
  from quiz_slots
  cross join question_templates
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
)
select
  contests.id,
  contests.title,
  contests.status,
  contests.live_status,
  contests.live_starts_at,
  contests.ends_at,
  count(questions.id) as questions_count,
  sum(questions.time_limit) as duration_seconds,
  contests.live_starts_at
    - lag(contests.ends_at) over (order by contests.live_starts_at)
    as gap_after_previous_ql
from public.contests
left join public.questions on questions.contest_id = contests.id
where contests.id in (
  select
    (
      '20260601-0000-4000-c'
      || lpad(slot_index::text, 3, '0')
      || '-'
      || lpad((700 + slot_index)::text, 12, '0')
    )::uuid
  from generate_series(1, 8) as slot_index
)
group by contests.id
order by contests.live_starts_at asc;

