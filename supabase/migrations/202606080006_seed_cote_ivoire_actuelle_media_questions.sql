-- MegaPromo - Questions media Cote d'Ivoire Actuelle
-- A executer dans Supabase SQL Editor apres:
-- 202606080004_seed_cote_ivoire_actuelle_question_bank.sql
-- 202606020017_add_media_fields_to_quiz_questions.sql.
--
-- Objectif:
-- - ajouter 50 questions ou le prompt est une image;
-- - ajouter 50 questions ou les propositions de reponse sont des images;
-- - rattacher toutes les questions a la Banque Côte d'Ivoire Actuelle;
-- - garder le format QCM classique sans impacter les questions texte.

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
    'Questions sur la Cote d''Ivoire contemporaine: institutions, economie, sport, culture et infrastructures.',
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
    'Questions texte et media sur la Cote d''Ivoire actuelle pour les JCQ et QL.',
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
media_prompt_themes as (
  select *
  from (
    values
      (1, 'Abidjan et ses infrastructures', 'Quel theme de la Cote d''Ivoire actuelle cette image illustre-t-elle le mieux ?', 'Urbanisation et infrastructures', 'Patrimoine colonial uniquement', 'Agriculture vivriere', 'Equipe nationale', 'https://images.unsplash.com/photo-1570129477492-45c003edd2be?auto=format&fit=crop&w=1200&q=80'),
      (2, 'Football et CAN', 'Quel evenement recent cette image peut-elle evoquer pour la Cote d''Ivoire ?', 'Organisation et victoire a la CAN', 'Election municipale', 'Salon agricole', 'Sommet monetaire', 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80'),
      (3, 'Cacao et agriculture', 'Quel pilier economique ivoirien cette image represente-t-elle le mieux ?', 'Cacao et agriculture', 'Tourisme spatial', 'Industrie automobile', 'Peche polaire', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1200&q=80'),
      (4, 'Port et commerce', 'Quel role economique cette image peut-elle illustrer ?', 'Commerce maritime et exportations', 'Justice constitutionnelle', 'Musique urbaine', 'Transport aerien uniquement', 'https://images.unsplash.com/photo-1494412519320-aa613dfb7738?auto=format&fit=crop&w=1200&q=80'),
      (5, 'Culture urbaine', 'Quel aspect de la vie ivoirienne actuelle est le plus proche de cette image ?', 'Culture urbaine et loisirs', 'Exploitation miniere', 'Parlement', 'Reserve forestiere', 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1200&q=80'),
      (6, 'Transport et mobilite', 'Quel enjeu d''Abidjan cette image suggere-t-elle ?', 'Mobilite urbaine', 'Cacao durable', 'Patrimoine UNESCO', 'Football international', 'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=1200&q=80'),
      (7, 'Numerique et services', 'Quel secteur actuel cette image peut-elle representer ?', 'Services numeriques', 'Culture vivriere', 'Stade de football', 'Port autonome', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80'),
      (8, 'Institutions et gouvernance', 'Quel domaine de la vie publique cette image evoque-t-elle ?', 'Institutions et gouvernance', 'Cuisine populaire', 'Foret tropicale', 'Musique live', 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=1200&q=80'),
      (9, 'Patrimoine et tourisme', 'Quel axe de developpement cette image met-elle en avant ?', 'Tourisme et patrimoine', 'Bourse regionale', 'Filiere cafe-cacao', 'Transport ferroviaire', 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80'),
      (10, 'Gastronomie et quotidien', 'Quel element du quotidien ivoirien cette image peut-elle illustrer ?', 'Cuisine et consommation locale', 'Election presidentielle', 'Finance regionale', 'Export de cacao', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80')
  ) as rows(
    theme_index,
    theme_label,
    base_question,
    option_a,
    option_b,
    option_c,
    option_d,
    question_image_url
  )
),
image_prompt_rows as (
  select
    200 + ((variant_index - 1) * 10) + media_prompt_themes.theme_index as order_index,
    case
      when variant_index <= 3 then 'intermediaire'
      else 'difficile'
    end as difficulty,
    'image_prompt' as media_mode,
    case variant_index
      when 1 then media_prompt_themes.base_question
      when 2 then 'Observe l''image: quel sujet ivoirien actuel correspond le mieux ?'
      when 3 then 'Cette image renvoie surtout a quel theme de la Cote d''Ivoire actuelle ?'
      when 4 then 'Quel enjeu public ivoirien peut etre associe a cette image ?'
      else 'Dans un quiz sur la Cote d''Ivoire actuelle, que faut-il reconnaitre ici ?'
    end as question_text,
    media_prompt_themes.option_a,
    media_prompt_themes.option_b,
    media_prompt_themes.option_c,
    media_prompt_themes.option_d,
    'A' as correct_answer,
    media_prompt_themes.question_image_url,
    null::text as option_a_image_url,
    null::text as option_b_image_url,
    null::text as option_c_image_url,
    null::text as option_d_image_url
  from media_prompt_themes
  cross join generate_series(1, 5) as variant_index
),
media_answer_themes as (
  select *
  from (
    values
      (1, 'Quelle image evoque le mieux Abidjan et ses infrastructures ?', 'https://images.unsplash.com/photo-1570129477492-45c003edd2be?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=700&q=80'),
      (2, 'Quelle image correspond le mieux au football et a la CAN ?', 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1494412519320-aa613dfb7738?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=700&q=80'),
      (3, 'Quelle image illustre le mieux l''agriculture et le cacao ?', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=700&q=80'),
      (4, 'Quelle image represente le commerce maritime ?', 'https://images.unsplash.com/photo-1494412519320-aa613dfb7738?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=700&q=80'),
      (5, 'Quelle image evoque la culture urbaine et les evenements ?', 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=700&q=80'),
      (6, 'Quelle image illustre le mieux la mobilite urbaine ?', 'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=700&q=80'),
      (7, 'Quelle image represente les services numeriques ?', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1494412519320-aa613dfb7738?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=700&q=80'),
      (8, 'Quelle image evoque les institutions et les grandes rencontres ?', 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=700&q=80'),
      (9, 'Quelle image correspond le mieux au tourisme et au patrimoine ?', 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1494412519320-aa613dfb7738?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=700&q=80'),
      (10, 'Quelle image illustre le mieux la gastronomie et le quotidien ?', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1494412519320-aa613dfb7738?auto=format&fit=crop&w=700&q=80', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=700&q=80')
  ) as rows(
    theme_index,
    base_question,
    option_a_image_url,
    option_b_image_url,
    option_c_image_url,
    option_d_image_url
  )
),
image_answer_rows as (
  select
    300 + ((variant_index - 1) * 10) + media_answer_themes.theme_index as order_index,
    case
      when variant_index <= 3 then 'intermediaire'
      else 'difficile'
    end as difficulty,
    'image_answers' as media_mode,
    case variant_index
      when 1 then media_answer_themes.base_question
      when 2 then replace(media_answer_themes.base_question, 'Quelle image', 'Parmi ces images, laquelle')
      when 3 then 'Choisis l''image qui correspond le mieux: ' || lower(media_answer_themes.base_question)
      when 4 then 'Dans le contexte ivoirien actuel: ' || lower(media_answer_themes.base_question)
      else 'Quelle proposition visuelle repond correctement a ce theme: ' || lower(media_answer_themes.base_question)
    end as question_text,
    '' as option_a,
    '' as option_b,
    '' as option_c,
    '' as option_d,
    'A' as correct_answer,
    null::text as question_image_url,
    media_answer_themes.option_a_image_url,
    media_answer_themes.option_b_image_url,
    media_answer_themes.option_c_image_url,
    media_answer_themes.option_d_image_url
  from media_answer_themes
  cross join generate_series(1, 5) as variant_index
),
bank_question_rows as (
  select
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
  from image_prompt_rows

  union all

  select
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
  from image_answer_rows
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
      substr(md5('cote-ivoire-actuelle-media-20260608-question-' || bank_question_rows.order_index), 1, 8)
      || '-' ||
      substr(md5('cote-ivoire-actuelle-media-20260608-question-' || bank_question_rows.order_index), 9, 4)
      || '-' ||
      substr(md5('cote-ivoire-actuelle-media-20260608-question-' || bank_question_rows.order_index), 13, 4)
      || '-' ||
      substr(md5('cote-ivoire-actuelle-media-20260608-question-' || bank_question_rows.order_index), 17, 4)
      || '-' ||
      substr(md5('cote-ivoire-actuelle-media-20260608-question-' || bank_question_rows.order_index), 21, 12)
    )::uuid,
    null,
    bank_seed.id,
    category_seed.id,
    'bank',
    'quiz',
    bank_question_rows.question_text,
    nullif(trim(coalesce(bank_question_rows.question_image_url, '')), ''),
    bank_question_rows.option_a,
    nullif(trim(coalesce(bank_question_rows.option_a_image_url, '')), ''),
    bank_question_rows.option_b,
    nullif(trim(coalesce(bank_question_rows.option_b_image_url, '')), ''),
    bank_question_rows.option_c,
    nullif(trim(coalesce(bank_question_rows.option_c_image_url, '')), ''),
    bank_question_rows.option_d,
    nullif(trim(coalesce(bank_question_rows.option_d_image_url, '')), ''),
    bank_question_rows.correct_answer,
    case bank_question_rows.difficulty
      when 'difficile' then 15
      else 10
    end,
    case bank_question_rows.difficulty
      when 'difficile' then 25
      else 20
    end,
    bank_question_rows.order_index,
    bank_question_rows.difficulty,
    true,
    now()
  from bank_question_rows
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
  count(*) filter (where bank_question_rows.media_mode = 'image_prompt') as image_prompt_questions_ready,
  count(*) filter (where bank_question_rows.media_mode = 'image_answers') as image_answer_questions_ready,
  (select count(*) from question_seed) as questions_upserted
from bank_question_rows;

notify pgrst, 'reload schema';
