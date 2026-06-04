-- MegaPromo - Serie de 3 QL, premier depart dans 2h
-- A executer dans Supabase SQL Editor apres les migrations QL:
-- 202606010001, 202606010003, 202606010004 et 202606010005.
--
-- Objectif:
-- - creer une serie de 3 Quiz Live gratuits;
-- - le premier QL commence 2h apres execution;
-- - chaque QL dure 100 secondes: 5 questions x 20 secondes;
-- - chaque QL suivant commence 2h apres la fin du precedent;
-- - chaque QL possede ses propres questions;
-- - la file QL garde un seul QL reservable/jouable a la fois.
--
-- Important:
-- - execute d'abord en DEV pour tester;
-- - execute en PROD uniquement si tu veux programmer ces QL pour les vrais
--   joueurs.

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
    '20260602-0000-4000-e000-000000000601'::uuid,
    'Credit QL Serie 2h MegaPromo',
    'voucher',
    'Credit promotionnel offert aux gagnants de la serie de Quiz Live programmes toutes les 2h.',
    'Credit 5 000 FCFA',
    5000,
    null,
    'QL-2H-5000',
    'Contacter le gagnant depuis le SA pour confirmer son identite et organiser la remise du credit.',
    'Quiz gratuit, sans achat requis. Credit promotionnel personnel, non remboursable.',
    12,
    0,
    true,
    '{"seed": true, "environment": "multi", "free_quiz": true, "schedule": "first_in_2h_then_every_2h_after_previous_end"}'::jsonb,
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
      + interval '2 hours'
      + ((slot_index - 1) * (interval '2 hours' + interval '100 seconds'))
        as live_starts_at
  from generate_series(1, 3) as slot_index
),
contest_rows as (
  select
    quiz_slots.slot_index,
    quiz_slots.live_starts_at,
    (
      substr(md5('ql-series-2h-20260602-contest-' || quiz_slots.slot_index), 1, 8)
      || '-' ||
      substr(md5('ql-series-2h-20260602-contest-' || quiz_slots.slot_index), 9, 4)
      || '-' ||
      substr(md5('ql-series-2h-20260602-contest-' || quiz_slots.slot_index), 13, 4)
      || '-' ||
      substr(md5('ql-series-2h-20260602-contest-' || quiz_slots.slot_index), 17, 4)
      || '-' ||
      substr(md5('ql-series-2h-20260602-contest-' || quiz_slots.slot_index), 21, 12)
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
    'QL Serie 2h #' || contest_rows.slot_index || ' - Arena MegaPromo',
    'Quiz Live gratuit de la serie 2h. Reserve ta place, entre dans l''arene au bon moment, reponds juste et vite, puis vise le haut du classement.',
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
        'series_id',
        'ql-series-2h-20260602',
        'series_title',
        'Serie QL 2h MegaPromo',
        'series_index',
        contest_rows.slot_index,
        'series_size',
        3,
        'schedule_gap_hours',
        2,
        'free_quiz',
        true,
        'no_purchase_required',
        true
      ),
    1,
    null,
    now(),
    contest_rows.live_starts_at + interval '100 seconds',
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
  returning id
),
question_templates as (
  select *
  from (
    values
      (1, 1, 'Quel reflexe aide a bien demarrer un QL ?', 'Entrer avant le lancement', 'Fermer l''application', 'Couper internet', 'Changer de compte', 'A', 10, 20),
      (1, 2, 'Dans un Quiz Live, que faut-il privilegier ?', 'Justesse et rapidite', 'Lenteur volontaire', 'Reponses au hasard', 'Quitter la salle', 'A', 10, 20),
      (1, 3, 'Que represente le compte a rebours du QL ?', 'Le temps avant le depart', 'Le prix du telephone', 'Le nombre de menus', 'La couleur du profil', 'A', 10, 20),
      (1, 4, 'Quel element valide la performance du joueur ?', 'Les reponses envoyees', 'La luminosite', 'Le fond d''ecran', 'Le volume audio', 'A', 10, 20),
      (1, 5, 'Pourquoi rester connecte pendant un QL ?', 'Pour recevoir et envoyer les questions', 'Pour bloquer les autres', 'Pour changer le lot', 'Pour annuler le quiz', 'A', 10, 20),

      (2, 1, 'Que signifie etre inscrit a un QL ?', 'Avoir reserve sa place', 'Avoir gagne automatiquement', 'Avoir termine le quiz', 'Avoir supprime son compte', 'A', 10, 20),
      (2, 2, 'Quel joueur est avantage en cas de score identique ?', 'Le plus rapide', 'Le plus lent', 'Le dernier inscrit', 'Celui qui quitte', 'A', 10, 20),
      (2, 3, 'Que doit faire le joueur quand le QL est ouvert ?', 'Entrer dans l''arene', 'Attendre la fin', 'Ignorer la notification', 'Fermer l''app', 'A', 10, 20),
      (2, 4, 'A quoi sert le classement apres un QL ?', 'Comparer les performances', 'Changer les questions', 'Supprimer les lots', 'Masquer les joueurs', 'A', 10, 20),
      (2, 5, 'Quel est le bon etat reseau pour jouer ?', 'Connexion stable', 'Mode avion', 'Aucune connexion', 'Bluetooth seul', 'A', 10, 20),

      (3, 1, 'Que gagne le joueur en participant souvent ?', 'Plus d''experience de jeu', 'Moins de questions', 'Un blocage automatique', 'Une perte de profil', 'A', 10, 20),
      (3, 2, 'Quel format correspond au Quiz Live ?', 'Questions en temps limite', 'Discussion libre', 'Photo uniquement', 'Achat obligatoire', 'A', 10, 20),
      (3, 3, 'Pourquoi les QL sont programmes dans une file ?', 'Pour garder un ordre clair', 'Pour lancer tous les QL ensemble', 'Pour cacher les horaires', 'Pour supprimer les scores', 'A', 10, 20),
      (3, 4, 'Quel indicateur est important avant le depart ?', 'L''heure de lancement', 'La taille du clavier', 'La marque du chargeur', 'La couleur du cable', 'A', 10, 20),
      (3, 5, 'Quel comportement evite les pertes de resultat ?', 'Terminer et envoyer les reponses', 'Quitter au milieu', 'Couper internet', 'Ignorer la confirmation', 'A', 10, 20)
  ) as templates (
    slot_index,
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
      substr(md5('ql-series-2h-20260602-question-' || question_templates.slot_index || '-' || question_templates.order_index), 1, 8)
      || '-' ||
      substr(md5('ql-series-2h-20260602-question-' || question_templates.slot_index || '-' || question_templates.order_index), 9, 4)
      || '-' ||
      substr(md5('ql-series-2h-20260602-question-' || question_templates.slot_index || '-' || question_templates.order_index), 13, 4)
      || '-' ||
      substr(md5('ql-series-2h-20260602-question-' || question_templates.slot_index || '-' || question_templates.order_index), 17, 4)
      || '-' ||
      substr(md5('ql-series-2h-20260602-question-' || question_templates.slot_index || '-' || question_templates.order_index), 21, 12)
    )::uuid,
    contest_rows.contest_id,
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
  from question_templates
  join contest_rows on contest_rows.slot_index = question_templates.slot_index
  on conflict (id) do update set
    contest_id = excluded.contest_id,
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
    - lag(contests.ends_at) over (order by contests.live_starts_at)
    as gap_after_previous_ql
from public.contests
cross join queue_refresh
join contest_rows on contest_rows.contest_id = contests.id
left join public.questions on questions.contest_id = contests.id
group by contests.id, queue_refresh.changed_count
order by contests.live_starts_at asc;
