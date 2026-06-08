-- MegaPromo - Serie de 5 QL, 10 questions, depart dans 5 minutes
-- A executer dans Supabase SQL Editor apres les migrations QL:
-- 202606010001, 202606010003, 202606010004 et 202606010005.
--
-- Objectif:
-- - creer une serie de 5 Quiz Live gratuits;
-- - le premier QL commence 5 minutes apres execution;
-- - chaque QL contient 10 questions de 20 secondes;
-- - chaque QL suivant commence 30 minutes apres le depart du precedent;
-- - chaque QL possede ses propres questions;
-- - eviter de modifier les questions si le seed est relance apres ouverture.

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
    '20260608-0000-4000-e000-000000000501'::uuid,
    'Credit QL Sprint 30min MegaPromo',
    'voucher',
    'Credit promotionnel offert aux gagnants de la serie de 5 Quiz Live programmes toutes les 30 minutes.',
    'Credit 5 000 FCFA',
    5000,
    null,
    'QL-SPRINT-5000',
    'Contacter le gagnant depuis le SA pour confirmer son identite et organiser la remise du credit.',
    'Quiz gratuit, sans achat requis. Credit promotionnel personnel, non remboursable.',
    20,
    0,
    true,
    '{"seed": true, "environment": "multi", "free_quiz": true, "schedule": "first_in_5min_then_every_30min"}'::jsonb,
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
      + ((slot_index - 1) * interval '30 minutes') as live_starts_at
  from generate_series(1, 5) as slot_index
),
contest_rows as (
  select
    quiz_slots.slot_index,
    quiz_slots.live_starts_at,
    (
      substr(md5('ql-sprint-30min-20260608-contest-' || quiz_slots.slot_index), 1, 8)
      || '-' ||
      substr(md5('ql-sprint-30min-20260608-contest-' || quiz_slots.slot_index), 9, 4)
      || '-' ||
      substr(md5('ql-sprint-30min-20260608-contest-' || quiz_slots.slot_index), 13, 4)
      || '-' ||
      substr(md5('ql-sprint-30min-20260608-contest-' || quiz_slots.slot_index), 17, 4)
      || '-' ||
      substr(md5('ql-sprint-30min-20260608-contest-' || quiz_slots.slot_index), 21, 12)
    )::uuid as contest_id
  from quiz_slots
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
    contest_rows.contest_id,
    null,
    'QL Sprint 30min #' || contest_rows.slot_index || ' - Arena MegaPromo',
    'Quiz Live gratuit de 10 questions. Reserve ta place, entre dans l''arene au bon moment et vise le meilleur score.',
    case contest_rows.slot_index
      when 1 then 'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1200&q=80'
      when 2 then 'https://images.unsplash.com/photo-1511882150382-421056c89033?auto=format&fit=crop&w=1200&q=80'
      when 3 then 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80'
      when 4 then 'https://images.unsplash.com/photo-1526505262320-81542978f63b?auto=format&fit=crop&w=1200&q=80'
      else 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1200&q=80'
    end,
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
        'series_id',
        'ql-sprint-30min-20260608',
        'series_title',
        'Serie QL Sprint 30min MegaPromo',
        'series_index',
        contest_rows.slot_index,
        'series_size',
        5,
        'question_count',
        10,
        'question_duration_seconds',
        20,
        'duration_seconds',
        200,
        'schedule_gap_minutes',
        30,
        'free_quiz',
        true,
        'no_purchase_required',
        true
      ),
    1,
    null,
    now(),
    contest_rows.live_starts_at + interval '200 seconds',
    true,
    array['free']::text[],
    true,
    contest_rows.live_starts_at,
    'scheduled',
    0,
    0,
    0,
    null,
    0,
    0,
    now()
  from contest_rows
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
  where lower(coalesce(contests.live_status, 'scheduled')) in (
    'scheduled',
    'waiting',
    'queued'
  )
  returning id
),
question_templates as (
  select *
  from (
    values
      (1, 'Quel reflexe donne le meilleur depart en Quiz Live ?', 'Entrer avant le lancement', 'Attendre la fin', 'Fermer l''application', 'Changer de compte', 'A'),
      (2, 'Que faut-il viser pendant un QL ?', 'Justesse et rapidite', 'Lenteur volontaire', 'Reponses au hasard', 'Quitter la salle', 'A'),
      (3, 'Que signifie le compte a rebours avant le QL ?', 'Le temps avant le depart', 'Le nombre de lots caches', 'Le prix du telephone', 'Le volume audio', 'A'),
      (4, 'Quel element aide a envoyer les reponses sans coupure ?', 'Une connexion stable', 'Le mode avion', 'Aucune connexion', 'Le Bluetooth seul', 'A'),
      (5, 'Que departage souvent deux joueurs au meme score ?', 'La rapidite', 'La couleur du profil', 'Le dernier inscrit', 'Le type de telephone', 'A'),
      (6, 'Pourquoi rester dans l''arene pendant tout le QL ?', 'Pour recevoir toutes les questions', 'Pour bloquer les autres', 'Pour changer le lot', 'Pour annuler le quiz', 'A'),
      (7, 'Quel comportement evite de perdre le resultat ?', 'Terminer et envoyer', 'Quitter au milieu', 'Couper internet', 'Ignorer la confirmation', 'A'),
      (8, 'Quel format correspond a un Quiz Live ?', 'Questions en temps limite', 'Discussion libre', 'Photo uniquement', 'Achat obligatoire', 'A'),
      (9, 'Que represente le classement apres un QL ?', 'La performance des joueurs', 'La liste des menus', 'Le stock de tickets', 'Le theme du telephone', 'A'),
      (10, 'Quel joueur est le mieux prepare ?', 'Celui qui arrive avant le depart', 'Celui qui ferme l''app', 'Celui qui ignore le chrono', 'Celui qui coupe le reseau', 'A')
  ) as templates (
    order_index,
    question_text,
    option_a,
    option_b,
    option_c,
    option_d,
    correct_answer
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
      substr(md5('ql-sprint-30min-20260608-question-' || contest_rows.slot_index || '-' || question_templates.order_index), 1, 8)
      || '-' ||
      substr(md5('ql-sprint-30min-20260608-question-' || contest_rows.slot_index || '-' || question_templates.order_index), 9, 4)
      || '-' ||
      substr(md5('ql-sprint-30min-20260608-question-' || contest_rows.slot_index || '-' || question_templates.order_index), 13, 4)
      || '-' ||
      substr(md5('ql-sprint-30min-20260608-question-' || contest_rows.slot_index || '-' || question_templates.order_index), 17, 4)
      || '-' ||
      substr(md5('ql-sprint-30min-20260608-question-' || contest_rows.slot_index || '-' || question_templates.order_index), 21, 12)
    )::uuid,
    contest_rows.contest_id,
    'QL #' || contest_rows.slot_index || ' - ' || question_templates.question_text,
    question_templates.option_a,
    question_templates.option_b,
    question_templates.option_c,
    question_templates.option_d,
    question_templates.correct_answer,
    10,
    20,
    question_templates.order_index,
    now()
  from contest_rows
  cross join question_templates
  on conflict (id) do nothing
  returning id
),
queue_refresh as (
  select public.process_live_quiz_events() as changed_count
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
  queue_refresh.changed_count as queue_changes,
  contests.live_starts_at
    - lag(contests.live_starts_at) over (order by contests.live_starts_at)
    as gap_after_previous_start
from public.contests
cross join queue_refresh
join contest_rows on contest_rows.contest_id = contests.id
left join public.questions on questions.contest_id = contests.id
group by contests.id, queue_refresh.changed_count
order by contests.live_starts_at asc;

notify pgrst, 'reload schema';
