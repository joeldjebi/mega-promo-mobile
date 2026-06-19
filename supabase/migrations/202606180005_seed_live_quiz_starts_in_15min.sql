-- MegaPromo - QL test, depart dans 15 minutes
-- A executer dans Supabase SQL Editor apres les migrations QL.
--
-- Objectif:
-- - creer un Quiz Live gratuit de 10 questions;
-- - le QL commence 15 minutes apres execution;
-- - chaque question dure 20 secondes;
-- - relancer ce script reprogramme le QL uniquement s'il est encore planifie.

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
    '20260618-0000-4000-e000-000000000501'::uuid,
    'Credit QL 15min MegaPromo',
    'voucher',
    'Credit promotionnel offert au gagnant du Quiz Live de test programme dans 15 minutes.',
    'Credit 2 000 FCFA',
    2000,
    null,
    'QL-15MIN-2000',
    'Contacter le gagnant depuis le SA pour confirmer son identite et organiser la remise du credit.',
    'Quiz gratuit, sans achat requis. Credit promotionnel personnel, non remboursable.',
    10,
    0,
    true,
    '{"seed": true, "free_quiz": true, "schedule": "starts_in_15min"}'::jsonb,
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
contest_row as (
  select
    '20260618-0000-4000-c000-000000000501'::uuid as contest_id,
    now() + interval '15 minutes' as live_starts_at
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
    contest_row.contest_id,
    null,
    'QL Express 15min - Arena MegaPromo',
    'Quiz Live gratuit de 10 questions. Reserve ta place maintenant et entre dans l''arene au depart.',
    'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1200&q=80',
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
        'question_count',
        10,
        'question_duration_seconds',
        20,
        'duration_seconds',
        200,
        'free_quiz',
        true,
        'no_purchase_required',
        true
      ),
    1,
    null,
    now(),
    contest_row.live_starts_at + interval '200 seconds',
    true,
    array['free']::text[],
    true,
    contest_row.live_starts_at,
    'scheduled',
    0,
    0,
    0,
    null,
    0,
    0,
    now()
  from contest_row
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
    starts_at = now(),
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
  returning id, title, live_starts_at, ends_at
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
      substr(md5('ql-express-15min-20260618-question-' || question_templates.order_index), 1, 8)
      || '-' ||
      substr(md5('ql-express-15min-20260618-question-' || question_templates.order_index), 9, 4)
      || '-' ||
      substr(md5('ql-express-15min-20260618-question-' || question_templates.order_index), 13, 4)
      || '-' ||
      substr(md5('ql-express-15min-20260618-question-' || question_templates.order_index), 17, 4)
      || '-' ||
      substr(md5('ql-express-15min-20260618-question-' || question_templates.order_index), 21, 12)
    )::uuid,
    contest_row.contest_id,
    question_templates.question_text,
    question_templates.option_a,
    question_templates.option_b,
    question_templates.option_c,
    question_templates.option_d,
    question_templates.correct_answer,
    10,
    20,
    question_templates.order_index,
    now()
  from contest_row
  cross join question_templates
  on conflict (id) do nothing
  returning id
),
queue_refresh as (
  select public.process_live_quiz_events() as changed_count
)
select
  contest_seed.id,
  contest_seed.title,
  contest_seed.live_starts_at,
  contest_seed.ends_at,
  count(question_seed.id) as new_questions_inserted,
  queue_refresh.changed_count as queue_changes
from contest_seed
cross join question_seed
cross join queue_refresh
group by
  contest_seed.id,
  contest_seed.title,
  contest_seed.live_starts_at,
  contest_seed.ends_at,
  queue_refresh.changed_count;

notify pgrst, 'reload schema';
