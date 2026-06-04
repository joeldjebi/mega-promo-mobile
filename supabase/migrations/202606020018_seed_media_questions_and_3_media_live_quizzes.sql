-- MegaPromo - Questions multimedia banques + serie de 3 QL media
-- A executer dans Supabase SQL Editor apres:
-- 202606020010_seed_3_question_bank_categories_only.sql
-- 202606020017_add_media_fields_to_quiz_questions.sql
-- et les migrations QL:
-- 202606010001, 202606010003, 202606010004, 202606010005.
--
-- Objectif:
-- - ajouter dans chaque banque Automobile, Technologie, Musique:
--   * 5 questions ou le prompt est une image;
--   * 5 questions ou les propositions sont des images;
-- - creer une serie de 3 Quiz Live:
--   * QL #1: questions en images, reponses texte;
--   * QL #2: questions texte, reponses en images;
--   * QL #3: quiz normal texte;
-- - garder les QL gratuits et programmes en file.

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

alter table public.questions
add column if not exists question_image_url text,
add column if not exists option_a_image_url text,
add column if not exists option_b_image_url text,
add column if not exists option_c_image_url text,
add column if not exists option_d_image_url text;

insert into public.contest_types (key, name, description, is_active, order_index)
values
  ('quiz', 'Quiz', 'Concours avec questions, reponses et score.', true, 1)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = true,
  order_index = excluded.order_index;

with category_rows as (
  select id, name
  from public.categories
  where name in ('Automobile', 'Technologie', 'Musique')
),
bank_mapping as (
  select *
  from (
    values
      ('automobile', 'Automobile', '20260602-0000-4000-b001-000000000001'::uuid),
      ('technologie', 'Technologie', '20260602-0000-4000-b002-000000000002'::uuid),
      ('musique', 'Musique', '20260602-0000-4000-b003-000000000003'::uuid)
  ) as rows(bank_key, category_name, question_bank_id)
),
bank_question_rows as (
  select *
  from (
    values
      ('automobile', 101, 'image_prompt', 'Quel element automobile vois-tu sur cette image ?', 'Un tableau de bord', 'Une guitare', 'Un processeur', 'Un casque audio', 'A', 'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('automobile', 102, 'image_prompt', 'Quelle piece est mise en avant sur cette image ?', 'Un pneu', 'Un microphone', 'Une puce electronique', 'Un clavier musical', 'A', 'https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('automobile', 103, 'image_prompt', 'Quel type de vehicule apparait sur cette image ?', 'Une voiture', 'Un ordinateur', 'Une batterie musicale', 'Un telephone fixe', 'A', 'https://images.unsplash.com/photo-1493238792000-8113da705763?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('automobile', 104, 'image_prompt', 'Quel espace de voiture est visible ici ?', 'L habitacle', 'La scene musicale', 'Le serveur cloud', 'Le studio photo', 'A', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('automobile', 105, 'image_prompt', 'Quel accessoire de conduite est montre ?', 'Le volant', 'Le casque de DJ', 'La souris', 'La guitare basse', 'A', 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('automobile', 106, 'image_answers', 'Quelle image montre une voiture ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=600&q=80'),
      ('automobile', 107, 'image_answers', 'Quelle image represente un pneu ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?auto=format&fit=crop&w=600&q=80'),
      ('automobile', 108, 'image_answers', 'Quelle image montre un volant ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=600&q=80'),
      ('automobile', 109, 'image_answers', 'Quelle image montre un habitacle de voiture ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=600&q=80'),
      ('automobile', 110, 'image_answers', 'Quelle image evoque le secteur automobile ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1493238792000-8113da705763?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=600&q=80'),

      ('technologie', 101, 'image_prompt', 'Quel objet technologique vois-tu sur cette image ?', 'Un ordinateur portable', 'Un volant', 'Une batterie musicale', 'Une roue', 'A', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('technologie', 102, 'image_prompt', 'Quel appareil est visible sur cette image ?', 'Un smartphone', 'Une guitare', 'Un pneu', 'Un micro de scene', 'A', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('technologie', 103, 'image_prompt', 'Quel domaine cette image evoque-t-elle ?', 'Le developpement informatique', 'La conduite auto', 'Le chant', 'La mecanique pure', 'A', 'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('technologie', 104, 'image_prompt', 'Quel type de materiel est montre ?', 'Des composants electroniques', 'Des instruments de musique', 'Des pneus', 'Des sieges auto', 'A', 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('technologie', 105, 'image_prompt', 'Quelle notion cette image illustre le mieux ?', 'Le cloud et les donnees', 'Le freinage', 'Le tempo', 'Le carburant', 'A', 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('technologie', 106, 'image_answers', 'Quelle image montre un smartphone ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&w=600&q=80'),
      ('technologie', 107, 'image_answers', 'Quelle image represente du code informatique ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=600&q=80'),
      ('technologie', 108, 'image_answers', 'Quelle image montre des composants electroniques ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&w=600&q=80'),
      ('technologie', 109, 'image_answers', 'Quelle image evoque le cloud ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=600&q=80'),
      ('technologie', 110, 'image_answers', 'Quelle image montre un ordinateur portable ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?auto=format&fit=crop&w=600&q=80'),

      ('musique', 101, 'image_prompt', 'Quel instrument est visible sur cette image ?', 'Une guitare', 'Un pneu', 'Un routeur', 'Un volant', 'A', 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('musique', 102, 'image_prompt', 'Quel metier musical cette image evoque-t-elle ?', 'DJ', 'Mecanicien', 'Developpeur', 'Chauffeur', 'A', 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('musique', 103, 'image_prompt', 'Quel accessoire est montre sur cette image ?', 'Un microphone', 'Un volant', 'Une carte SIM', 'Un pneu', 'A', 'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('musique', 104, 'image_prompt', 'Quelle scene cette image represente-t-elle ?', 'Un concert', 'Un garage', 'Un bureau de code', 'Une station-service', 'A', 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('musique', 105, 'image_prompt', 'Quel objet audio apparait sur cette image ?', 'Un casque audio', 'Une roue', 'Un clavier ordinateur', 'Un tableau de bord', 'A', 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      ('musique', 106, 'image_answers', 'Quelle image montre une guitare ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=600&q=80'),
      ('musique', 107, 'image_answers', 'Quelle image represente un DJ ou une ambiance musicale ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=600&q=80'),
      ('musique', 108, 'image_answers', 'Quelle image montre un microphone ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&w=600&q=80'),
      ('musique', 109, 'image_answers', 'Quelle image montre un concert ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1493238792000-8113da705763?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=600&q=80'),
      ('musique', 110, 'image_answers', 'Quelle image montre un casque audio ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=600&q=80')
  ) as rows(
    bank_key,
    order_index,
    media_mode,
    question_text,
    option_a,
    option_b,
    option_c,
    option_d,
    correct_answer,
    question_image_url,
    option_a_image_url,
    option_b_image_url,
    option_c_image_url,
    option_d_image_url
  )
),
bank_question_seed as (
  insert into public.questions (
    id,
    contest_id,
    question_bank_id,
    category_id,
    question_scope,
    question_text,
    question_image_url,
    option_a,
    option_a_image_url,
    option_b,
    option_b_image_url,
    option_c,
    option_c_image_url,
    option_d,
    option_d_image_url,
    correct_answer,
    points,
    time_limit,
    order_index,
    difficulty,
    is_active,
    created_at
  )
  select
    (
      substr(md5('bank-media-question-' || bank_question_rows.bank_key || '-' || bank_question_rows.order_index), 1, 8)
      || '-' || substr(md5('bank-media-question-' || bank_question_rows.bank_key || '-' || bank_question_rows.order_index), 9, 4)
      || '-' || substr(md5('bank-media-question-' || bank_question_rows.bank_key || '-' || bank_question_rows.order_index), 13, 4)
      || '-' || substr(md5('bank-media-question-' || bank_question_rows.bank_key || '-' || bank_question_rows.order_index), 17, 4)
      || '-' || substr(md5('bank-media-question-' || bank_question_rows.bank_key || '-' || bank_question_rows.order_index), 21, 12)
    )::uuid,
    null,
    bank_mapping.question_bank_id,
    category_rows.id,
    'bank',
    bank_question_rows.question_text,
    bank_question_rows.question_image_url,
    bank_question_rows.option_a,
    bank_question_rows.option_a_image_url,
    bank_question_rows.option_b,
    bank_question_rows.option_b_image_url,
    bank_question_rows.option_c,
    bank_question_rows.option_c_image_url,
    bank_question_rows.option_d,
    bank_question_rows.option_d_image_url,
    bank_question_rows.correct_answer,
    10,
    20,
    bank_question_rows.order_index,
    case bank_question_rows.media_mode
      when 'image_prompt' then 'image_question'
      else 'image_answers'
    end,
    true,
    now()
  from bank_question_rows
  join bank_mapping on bank_mapping.bank_key = bank_question_rows.bank_key
  join category_rows on category_rows.name = bank_mapping.category_name
  on conflict (id) do update set
    contest_id = null,
    question_bank_id = excluded.question_bank_id,
    category_id = excluded.category_id,
    question_scope = 'bank',
    question_text = excluded.question_text,
    question_image_url = excluded.question_image_url,
    option_a = excluded.option_a,
    option_a_image_url = excluded.option_a_image_url,
    option_b = excluded.option_b,
    option_b_image_url = excluded.option_b_image_url,
    option_c = excluded.option_c,
    option_c_image_url = excluded.option_c_image_url,
    option_d = excluded.option_d,
    option_d_image_url = excluded.option_d_image_url,
    correct_answer = excluded.correct_answer,
    points = excluded.points,
    time_limit = excluded.time_limit,
    order_index = excluded.order_index,
    difficulty = excluded.difficulty,
    is_active = true
  returning id
),
live_category_seed as (
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
    '20260602-0000-4000-e000-000000000701'::uuid,
    'Credit QL Media MegaPromo',
    'voucher',
    'Credit promotionnel offert aux gagnants de la serie de Quiz Live multimedia.',
    'Credit 5 000 FCFA',
    5000,
    null,
    'QL-MEDIA-5000',
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
      substr(md5('ql-media-series-20260602-contest-' || quiz_slots.slot_index), 1, 8)
      || '-' || substr(md5('ql-media-series-20260602-contest-' || quiz_slots.slot_index), 9, 4)
      || '-' || substr(md5('ql-media-series-20260602-contest-' || quiz_slots.slot_index), 13, 4)
      || '-' || substr(md5('ql-media-series-20260602-contest-' || quiz_slots.slot_index), 17, 4)
      || '-' || substr(md5('ql-media-series-20260602-contest-' || quiz_slots.slot_index), 21, 12)
    )::uuid as contest_id,
    case quiz_slots.slot_index
      when 1 then 'QL Media #1 - Questions images'
      when 2 then 'QL Media #2 - Reponses images'
      else 'QL Media #3 - Classique'
    end as title,
    case quiz_slots.slot_index
      when 1 then 'Quiz Live gratuit: observe l''image, puis choisis la bonne reponse texte.'
      when 2 then 'Quiz Live gratuit: lis la question, puis choisis la bonne image.'
      else 'Quiz Live gratuit classique avec questions et reponses texte.'
    end as description
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
    contest_rows.title,
    contest_rows.description,
    case contest_rows.slot_index
      when 1 then 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80'
      when 2 then 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=1200&q=80'
      else 'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1200&q=80'
    end,
    'https://www.google.com/s2/favicons?domain=megapromo.app&sz=128',
    'MegaPromo',
    'quiz',
    live_category_seed.name,
    live_category_seed.id,
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
        'ql-media-series-20260602',
        'series_title',
        'Serie QL Media MegaPromo',
        'series_index',
        contest_rows.slot_index,
        'series_size',
        3,
        'schedule_gap_hours',
        2,
        'media_mode',
        case contest_rows.slot_index
          when 1 then 'image_questions'
          when 2 then 'image_answers'
          else 'text_only'
        end,
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
  cross join live_category_seed
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
ql_question_rows as (
  select *
  from (
    values
      (1, 1, 'Quel objet vois-tu sur cette image ?', 'Un ordinateur', 'Une guitare', 'Un pneu', 'Un micro', 'A', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      (1, 2, 'Quel appareil est montre ?', 'Un smartphone', 'Un volant', 'Un casque audio', 'Une guitare', 'A', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      (1, 3, 'Quel element est visible ?', 'Une guitare', 'Un pneu', 'Un ordinateur', 'Une carte SIM', 'A', 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      (1, 4, 'Quel accessoire apparait sur cette image ?', 'Un volant', 'Un micro', 'Un clavier', 'Un casque', 'A', 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      (1, 5, 'Quel objet audio est montre ?', 'Un casque', 'Un pneu', 'Un smartphone', 'Un volant', 'A', 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=1200&q=80', null, null, null, null),

      (2, 1, 'Quelle image montre une voiture ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=600&q=80'),
      (2, 2, 'Quelle image montre un micro ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=600&q=80'),
      (2, 3, 'Quelle image montre du code ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&w=600&q=80'),
      (2, 4, 'Quelle image montre une guitare ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=600&q=80'),
      (2, 5, 'Quelle image montre un smartphone ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&w=600&q=80', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=600&q=80'),

      (3, 1, 'Dans un QL, quel comportement aide a gagner ?', 'Repondre juste et vite', 'Quitter la salle', 'Attendre la fin', 'Ignorer le chrono', 'A', null, null, null, null, null),
      (3, 2, 'Que signifie une connexion stable pendant un QL ?', 'Moins de risque de coupure', 'Un score automatique', 'Une question en moins', 'Une reponse gratuite', 'A', null, null, null, null, null),
      (3, 3, 'Que departage deux joueurs a score egal ?', 'La rapidite', 'La couleur du profil', 'Le nombre de menus', 'Le type de telephone', 'A', null, null, null, null, null),
      (3, 4, 'Quand faut-il entrer dans l''arene ?', 'Avant le lancement', 'Apres les resultats', 'Le lendemain', 'Jamais', 'A', null, null, null, null, null),
      (3, 5, 'Quel est le bon reflexe apres les questions ?', 'Envoyer le resultat', 'Fermer internet', 'Changer de compte', 'Ignorer la confirmation', 'A', null, null, null, null, null)
  ) as rows(
    slot_index,
    order_index,
    question_text,
    option_a,
    option_b,
    option_c,
    option_d,
    correct_answer,
    question_image_url,
    option_a_image_url,
    option_b_image_url,
    option_c_image_url,
    option_d_image_url
  )
),
ql_question_seed as (
  insert into public.questions (
    id,
    contest_id,
    question_text,
    question_image_url,
    option_a,
    option_a_image_url,
    option_b,
    option_b_image_url,
    option_c,
    option_c_image_url,
    option_d,
    option_d_image_url,
    correct_answer,
    points,
    time_limit,
    order_index,
    created_at
  )
  select
    (
      substr(md5('ql-media-series-20260602-question-' || ql_question_rows.slot_index || '-' || ql_question_rows.order_index), 1, 8)
      || '-' || substr(md5('ql-media-series-20260602-question-' || ql_question_rows.slot_index || '-' || ql_question_rows.order_index), 9, 4)
      || '-' || substr(md5('ql-media-series-20260602-question-' || ql_question_rows.slot_index || '-' || ql_question_rows.order_index), 13, 4)
      || '-' || substr(md5('ql-media-series-20260602-question-' || ql_question_rows.slot_index || '-' || ql_question_rows.order_index), 17, 4)
      || '-' || substr(md5('ql-media-series-20260602-question-' || ql_question_rows.slot_index || '-' || ql_question_rows.order_index), 21, 12)
    )::uuid,
    contest_rows.contest_id,
    ql_question_rows.question_text,
    ql_question_rows.question_image_url,
    ql_question_rows.option_a,
    ql_question_rows.option_a_image_url,
    ql_question_rows.option_b,
    ql_question_rows.option_b_image_url,
    ql_question_rows.option_c,
    ql_question_rows.option_c_image_url,
    ql_question_rows.option_d,
    ql_question_rows.option_d_image_url,
    ql_question_rows.correct_answer,
    10,
    20,
    ql_question_rows.order_index,
    now()
  from ql_question_rows
  join contest_rows on contest_rows.slot_index = ql_question_rows.slot_index
  on conflict (id) do update set
    contest_id = excluded.contest_id,
    question_text = excluded.question_text,
    question_image_url = excluded.question_image_url,
    option_a = excluded.option_a,
    option_a_image_url = excluded.option_a_image_url,
    option_b = excluded.option_b,
    option_b_image_url = excluded.option_b_image_url,
    option_c = excluded.option_c,
    option_c_image_url = excluded.option_c_image_url,
    option_d = excluded.option_d,
    option_d_image_url = excluded.option_d_image_url,
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
  (select count(*) from bank_question_seed) as bank_media_questions_upserted,
  (select count(*) from contest_seed) as live_quizzes_upserted,
  (select count(*) from ql_question_seed) as live_quiz_questions_upserted,
  queue_refresh.changed_count as queue_changes
from queue_refresh;

notify pgrst, 'reload schema';
