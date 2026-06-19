-- MegaPromo - 20 questions média Côte d'Ivoire Actuelle
-- A exécuter dans Supabase SQL Editor après:
-- 202606080004_seed_cote_ivoire_actuelle_question_bank.sql
-- et les migrations ajoutant les champs média sur public.questions.
--
-- Objectif:
-- - ajouter 10 questions où l'énoncé est une image et les réponses sont du texte;
-- - ajouter 10 questions où les réponses sont des images;
-- - rattacher toutes les questions à la Banque Côte d'Ivoire Actuelle;
-- - varier la bonne réponse entre A, B, C et D.

alter table public.questions
add column if not exists question_type text not null default 'quiz',
add column if not exists question_bank_id uuid,
add column if not exists category_id uuid,
add column if not exists question_scope text,
add column if not exists difficulty text,
add column if not exists is_active boolean not null default true,
add column if not exists question_image_url text,
add column if not exists option_a_image_url text,
add column if not exists option_b_image_url text,
add column if not exists option_c_image_url text,
add column if not exists option_d_image_url text;

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
    'Côte d''Ivoire Actuelle',
    'Questions sur la Côte d''Ivoire: histoire, régions, culture, peuples, gastronomie, musique et société.',
    'flag',
    '#F59E0B',
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
bank_seed as (
  insert into public.question_banks (
    id,
    name,
    description,
    questions_per_quiz,
    is_active,
    created_at,
    updated_at
  )
  values (
    '20260608-0000-4000-b005-000000000005'::uuid,
    'Banque Côte d''Ivoire Actuelle',
    'Questions texte et média sur la Côte d''Ivoire actuelle, son histoire, ses régions, ses cultures et sa société.',
    10,
    true,
    now(),
    now()
  )
  on conflict (name) do update set
    description = excluded.description,
    questions_per_quiz = 10,
    is_active = true,
    updated_at = now()
  returning id, name
),
bank_category_seed as (
  insert into public.question_bank_categories (
    question_bank_id,
    category_id
  )
  select
    bank_seed.id,
    category_seed.id
  from bank_seed
  cross join category_seed
  on conflict (question_bank_id, category_id) do nothing
  returning question_bank_id, category_id
),
media_question_templates as (
  select *
  from (
    values
      (501, 'intermediaire', 'question_image', 'Observe l''image: quel thème ivoirien correspond le mieux ?', 'Culture urbaine et événements', 'Agriculture du cacao', 'Patrimoine colonial', 'Transport aérien', 'A', 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      (502, 'intermediaire', 'question_image', 'Cette image évoque surtout quel pilier économique ivoirien ?', 'Tourisme balnéaire', 'Cacao et agriculture', 'Football', 'Vie parlementaire', 'B', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      (503, 'intermediaire', 'question_image', 'Quel sujet de la Côte d''Ivoire actuelle cette image peut-elle illustrer ?', 'Maquis et gastronomie', 'Régions du nord', 'Port et commerce maritime', 'Masques traditionnels', 'C', 'https://images.unsplash.com/photo-1494412519320-aa613dfb7738?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      (504, 'intermediaire', 'question_image', 'Quel thème ivoirien est le plus proche de cette image ?', 'Forêt classée', 'Cacao durable', 'Zouglou', 'Football et CAN', 'D', 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      (505, 'intermediaire', 'question_image', 'Cette image renvoie surtout à quel aspect du quotidien ivoirien ?', 'Cuisine populaire', 'Bourse régionale', 'Pouvoir judiciaire', 'Exploitation spatiale', 'A', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      (506, 'difficile', 'question_image', 'Dans un quiz sur la Côte d''Ivoire, cette image peut représenter quel enjeu ?', 'Royaumes traditionnels', 'Mobilité urbaine', 'Musique reggae', 'Régions frontalières', 'B', 'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      (507, 'difficile', 'question_image', 'Quel domaine public ivoirien cette image évoque-t-elle le mieux ?', 'Gastronomie', 'Culture mandé', 'Institutions et grandes rencontres', 'Pêche artisanale', 'C', 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      (508, 'difficile', 'question_image', 'Quel axe de développement ivoirien cette image suggère-t-elle ?', 'Élevage sahélien', 'Café-cacao', 'Ports secs', 'Tourisme et patrimoine', 'D', 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      (509, 'difficile', 'question_image', 'Quel secteur actuel cette image peut-elle représenter ?', 'Services numériques', 'Traditions du Poro', 'Exportation d''anacarde', 'Fête de l''indépendance', 'A', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80', null, null, null, null),
      (510, 'difficile', 'question_image', 'Quel thème ivoirien cette image peut-elle illustrer dans un JCQ ?', 'Lagune Ébrié uniquement', 'Urbanisation et infrastructures', 'Reine Abla Pokou', 'Cuisine de rue', 'B', 'https://images.unsplash.com/photo-1570129477492-45c003edd2be?auto=format&fit=crop&w=1200&q=80', null, null, null, null),

      (511, 'intermediaire', 'answer_images', 'Quelle image correspond le mieux au football et à la CAN ?', '', '', '', '', 'C', null, 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=700&q=80'),
      (512, 'intermediaire', 'answer_images', 'Quelle image illustre le mieux le port et le commerce maritime ?', '', '', '', '', 'D', null, 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1494412519320-aa613dfb7738?auto=format&fit=crop&w=700&q=80'),
      (513, 'intermediaire', 'answer_images', 'Quelle image évoque le mieux la gastronomie et le quotidien ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=700&q=80'),
      (514, 'intermediaire', 'answer_images', 'Quelle image représente le mieux les services numériques ?', '', '', '', '', 'B', null, 'https://images.unsplash.com/photo-1494412519320-aa613dfb7738?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=700&q=80'),
      (515, 'intermediaire', 'answer_images', 'Quelle image correspond le mieux à la culture urbaine et aux événements ?', '', '', '', '', 'C', null, 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=700&q=80'),
      (516, 'difficile', 'answer_images', 'Quelle image illustre le mieux le cacao et l''agriculture ?', '', '', '', '', 'D', null, 'https://images.unsplash.com/photo-1570129477492-45c003edd2be?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=700&q=80'),
      (517, 'difficile', 'answer_images', 'Quelle image évoque le mieux les institutions et les grandes rencontres ?', '', '', '', '', 'A', null, 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1494412519320-aa613dfb7738?auto=format&fit=crop&w=700&q=80'),
      (518, 'difficile', 'answer_images', 'Quelle image représente le mieux la mobilité urbaine ?', '', '', '', '', 'B', null, 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=700&q=80'),
      (519, 'difficile', 'answer_images', 'Quelle image correspond le mieux au tourisme et au patrimoine ?', '', '', '', '', 'C', null, 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=700&q=80'),
      (520, 'difficile', 'answer_images', 'Quelle image évoque le mieux Abidjan et ses infrastructures ?', '', '', '', '', 'D', null, 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1570129477492-45c003edd2be?auto=format&fit=crop&w=700&q=80')
  ) as rows (
    order_index,
    difficulty,
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
question_seed as (
  insert into public.questions (
    id,
    contest_id,
    question_bank_id,
    category_id,
    question_scope,
    question_type,
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
      substr(md5('cote-ivoire-actuelle-extra-media-20260619-question-' || media_question_templates.order_index), 1, 8)
      || '-' ||
      substr(md5('cote-ivoire-actuelle-extra-media-20260619-question-' || media_question_templates.order_index), 9, 4)
      || '-' ||
      substr(md5('cote-ivoire-actuelle-extra-media-20260619-question-' || media_question_templates.order_index), 13, 4)
      || '-' ||
      substr(md5('cote-ivoire-actuelle-extra-media-20260619-question-' || media_question_templates.order_index), 17, 4)
      || '-' ||
      substr(md5('cote-ivoire-actuelle-extra-media-20260619-question-' || media_question_templates.order_index), 21, 12)
    )::uuid,
    null,
    bank_seed.id,
    category_seed.id,
    'bank',
    'quiz',
    media_question_templates.question_text,
    nullif(trim(coalesce(media_question_templates.question_image_url, '')), ''),
    media_question_templates.option_a,
    nullif(trim(coalesce(media_question_templates.option_a_image_url, '')), ''),
    media_question_templates.option_b,
    nullif(trim(coalesce(media_question_templates.option_b_image_url, '')), ''),
    media_question_templates.option_c,
    nullif(trim(coalesce(media_question_templates.option_c_image_url, '')), ''),
    media_question_templates.option_d,
    nullif(trim(coalesce(media_question_templates.option_d_image_url, '')), ''),
    media_question_templates.correct_answer,
    case media_question_templates.difficulty
      when 'difficile' then 15
      else 10
    end,
    case media_question_templates.difficulty
      when 'difficile' then 25
      else 20
    end,
    media_question_templates.order_index,
    media_question_templates.difficulty,
    true,
    now()
  from media_question_templates
  cross join bank_seed
  cross join category_seed
  on conflict (id) do update set
    contest_id = null,
    question_bank_id = excluded.question_bank_id,
    category_id = excluded.category_id,
    question_scope = 'bank',
    question_type = 'quiz',
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
)
select
  (select count(*) from category_seed) as categories_ready,
  (select count(*) from bank_seed) as banks_ready,
  (select count(*) from bank_category_seed) as bank_category_links_inserted,
  count(*) filter (where media_question_templates.media_mode = 'question_image') as image_prompt_questions_ready,
  count(*) filter (where media_question_templates.media_mode = 'answer_images') as image_answer_questions_ready,
  (select count(*) from question_seed) as questions_upserted,
  count(*) filter (where correct_answer = 'A') as correct_a,
  count(*) filter (where correct_answer = 'B') as correct_b,
  count(*) filter (where correct_answer = 'C') as correct_c,
  count(*) filter (where correct_answer = 'D') as correct_d
from media_question_templates;

notify pgrst, 'reload schema';
