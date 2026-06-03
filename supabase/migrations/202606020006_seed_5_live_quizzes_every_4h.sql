-- MegaPromo - Serie de 5 QL, premier depart dans 4h
-- A executer dans Supabase SQL Editor apres les migrations QL:
-- 202606010001, 202606010003, 202606010004 et 202606010005.
--
-- Objectif:
-- - creer une serie de 5 Quiz Live gratuits;
-- - le premier QL commence 4h apres execution;
-- - chaque QL dure 100 secondes: 5 questions x 20 secondes;
-- - chaque QL suivant commence 4h apres la fin du precedent;
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
    '20260602-0000-4000-e000-000000000401'::uuid,
    'Credit QL Serie 4h MegaPromo',
    'voucher',
    'Credit promotionnel offert aux gagnants de la serie de Quiz Live programmes toutes les 4h.',
    'Credit 5 000 FCFA',
    5000,
    null,
    'QL-4H-5000',
    'Contacter le gagnant depuis le SA pour confirmer son identite et organiser la remise du credit.',
    'Quiz gratuit, sans achat requis. Credit promotionnel personnel, non remboursable.',
    20,
    0,
    true,
    '{"seed": true, "environment": "multi", "free_quiz": true, "schedule": "first_in_4h_then_every_4h_after_previous_end"}'::jsonb,
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
      + interval '4 hours'
      + ((slot_index - 1) * (interval '4 hours' + interval '100 seconds'))
        as live_starts_at
  from generate_series(1, 5) as slot_index
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
      '20260602-0000-4000-c'
      || lpad((400 + quiz_slots.slot_index)::text, 3, '0')
      || '-'
      || lpad((900 + quiz_slots.slot_index)::text, 12, '0')
    )::uuid,
    null,
    'QL Serie 4h #' || quiz_slots.slot_index || ' - Reflexes MegaPromo',
    'Quiz Live gratuit de la serie 4h. Inscris-toi au QL le plus proche, entre en salle d''attente, reponds juste et vite, puis tente de finir en tete du classement.',
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
        'series_id',
        'ql-series-4h-20260602',
        'series_title',
        'Serie QL 4h MegaPromo',
        'series_index',
        quiz_slots.slot_index,
        'series_size',
        5,
        'schedule_gap_hours',
        4,
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
      (1, 1, 'Dans un QL, quel comportement donne le plus de chance de gagner ?', 'Repondre juste et rapidement', 'Attendre la derniere seconde', 'Quitter la salle', 'Ignorer le chrono', 'A', 10, 20),
      (1, 2, 'Quand faut-il entrer en salle d''attente ?', 'Avant le lancement du QL', 'Apres la fin du QL', 'Uniquement le lendemain', 'Jamais', 'A', 10, 20),
      (1, 3, 'Que departage deux joueurs qui ont le meme score ?', 'Le temps total le plus court', 'La couleur du telephone', 'Le nombre de clics menu', 'La date de naissance', 'A', 10, 20),
      (1, 4, 'Combien de QL peut etre jouable a la fois dans la file ?', 'Un seul', 'Deux', 'Cinq', 'Tous', 'A', 10, 20),
      (1, 5, 'Quel est le bon reflexe quand le compte a rebours commence ?', 'Rester connecte et pret', 'Fermer l''application', 'Changer de compte', 'Couper internet', 'A', 10, 20),

      (2, 1, 'Que signifie le mot score dans un quiz ?', 'Le total des points gagnes', 'La taille de l''image', 'Le nombre de menus', 'Le niveau de batterie', 'A', 10, 20),
      (2, 2, 'Quel element mesure la rapidite du joueur ?', 'La duree totale de reponse', 'La luminosite', 'Le volume sonore', 'Le pseudo', 'A', 10, 20),
      (2, 3, 'Dans MegaPromo, un QL est principalement...', 'Un quiz joue en direct', 'Une page de profil', 'Un mode sombre', 'Une facture', 'A', 10, 20),
      (2, 4, 'Pourquoi faut-il eviter de quitter pendant un QL ?', 'Pour ne pas perdre le rythme du jeu', 'Pour changer le lot', 'Pour supprimer les questions', 'Pour bloquer les autres', 'A', 10, 20),
      (2, 5, 'Que doit faire un joueur pour valider son resultat ?', 'Terminer et envoyer ses reponses', 'Fermer son telephone', 'Supprimer son compte', 'Ignorer toutes les questions', 'A', 10, 20),

      (3, 1, 'Quel type de reponse est attendue dans un quiz a choix multiples ?', 'Choisir une option proposee', 'Envoyer une photo', 'Appeler le support', 'Changer de categorie', 'A', 10, 20),
      (3, 2, 'Que represente le classement apres un QL ?', 'La position des joueurs selon leurs resultats', 'La liste des menus', 'Les couleurs de l''application', 'Les parametres du telephone', 'A', 10, 20),
      (3, 3, 'Quel joueur gagne si deux joueurs ont toutes les bonnes reponses ?', 'Le plus rapide', 'Le dernier connecte', 'Celui qui a ferme l''app', 'Celui qui a le plus long nom', 'A', 10, 20),
      (3, 4, 'Quelle information est utile avant le depart d''un QL ?', 'L''heure de lancement', 'La marque du chargeur', 'La taille de police systeme', 'La couleur du fond d''ecran', 'A', 10, 20),
      (3, 5, 'Pourquoi les QL programmes restent verrouilles ?', 'Pour respecter l''ordre de la file', 'Pour cacher les lots', 'Pour supprimer les joueurs', 'Pour changer la langue', 'A', 10, 20),

      (4, 1, 'Quel est le meilleur etat reseau pour jouer un QL ?', 'Une connexion stable', 'Aucune connexion', 'Mode avion', 'Bluetooth seulement', 'A', 10, 20),
      (4, 2, 'Que se passe-t-il quand un QL est termine ?', 'Il sort de la file active', 'Il recommence toujours', 'Il devient un profil', 'Il supprime les points', 'A', 10, 20),
      (4, 3, 'Quel objectif MegaPromo met en avant dans un QL ?', 'Jouer juste et vite', 'Attendre sans participer', 'Ouvrir tous les menus', 'Changer de pseudo', 'A', 10, 20),
      (4, 4, 'Que signifie une question avec 20 secondes ?', 'Le temps maximal pour repondre', 'Le prix du lot', 'Le nombre de joueurs', 'Le nombre de categories', 'A', 10, 20),
      (4, 5, 'Quel etat indique qu''un QL est pret mais pas encore lance ?', 'En attente', 'Supprime', 'Archive', 'Bloque definitivement', 'A', 10, 20),

      (5, 1, 'Quel est le meilleur moment pour verifier sa connexion ?', 'Avant d''entrer dans le QL', 'Apres le resultat', 'Pendant la remise du lot', 'Jamais', 'A', 10, 20),
      (5, 2, 'Dans une serie QL, pourquoi les horaires sont importants ?', 'Ils organisent le passage des QL', 'Ils changent les avatars', 'Ils effacent les scores', 'Ils masquent le classement', 'A', 10, 20),
      (5, 3, 'Quel joueur est avantage si le score est identique ?', 'Celui qui repond plus vite', 'Celui qui ouvre le profil', 'Celui qui attend le plus', 'Celui qui partage le moins', 'A', 10, 20),
      (5, 4, 'Quel bouton doit etre utilise pour entrer dans un QL ouvert ?', 'Le bouton de participation ou salle d''attente', 'Le bouton de deconnexion', 'Le bouton retour systeme', 'Le bouton theme', 'A', 10, 20),
      (5, 5, 'Que faut-il faire apres avoir repondu aux questions ?', 'Envoyer le resultat', 'Couper internet immediatement', 'Changer de compte', 'Ignorer la confirmation', 'A', 10, 20)
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
      '20260602-0000-4000-d'
      || lpad((400 + question_templates.slot_index)::text, 3, '0')
      || '-'
      || lpad(
        (
          900000
          + question_templates.slot_index * 10
          + question_templates.order_index
        )::text,
        12,
        '0'
      )
    )::uuid,
    (
      '20260602-0000-4000-c'
      || lpad((400 + question_templates.slot_index)::text, 3, '0')
      || '-'
      || lpad((900 + question_templates.slot_index)::text, 12, '0')
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
  from question_templates
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
left join public.questions on questions.contest_id = contests.id
where contests.id in (
  select
    (
      '20260602-0000-4000-c'
      || lpad((400 + slot_index)::text, 3, '0')
      || '-'
      || lpad((900 + slot_index)::text, 12, '0')
    )::uuid
  from generate_series(1, 5) as slot_index
)
group by contests.id, queue_refresh.changed_count
order by contests.live_starts_at asc;
