-- MegaPromo - 3 JCQ Pronostics depuis la banque de questions
-- A executer dans Supabase SQL Editor apres:
-- 202606020021_seed_pronostic_question_bank.sql.
--
-- Objectif:
-- - creer 3 JCQ Pronostics gratuits;
-- - JCQ #1: tire 3 questions ou le prompt est une image;
-- - JCQ #2: tire 3 questions ou les propositions sont des images;
-- - JCQ #3: tire 3 questions normales texte;
-- - utiliser la Banque Pronostics comme source;
-- - ne pas creer de nouvelles questions.

alter table public.contests
add column if not exists is_live bool not null default false,
add column if not exists live_status varchar not null default 'scheduled',
add column if not exists allowed_player_plan_keys text[] default array[]::text[];

alter table public.questions
add column if not exists question_type text not null default 'quiz',
add column if not exists prediction_type text,
add column if not exists prediction_payload jsonb not null default '{}'::jsonb,
add column if not exists result_payload jsonb not null default '{}'::jsonb,
add column if not exists resolution_status text not null default 'not_required',
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
    'Pronostics',
    'Questions de prediction sportive pour les JCQ et Quiz Live.',
    'sports',
    '#16A34A',
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
    '20260602-0000-4000-b004-000000000004'::uuid,
    'Banque Pronostics',
    'Questions de pronostics sport et football pour les JCQ/QL.',
    3,
    true,
    now(),
    now()
  )
  on conflict (name) do update set
    description = excluded.description,
    questions_per_quiz = 3,
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
    '20260602-0000-4000-e000-000000000901'::uuid,
    'Credit JCQ Pronostics MegaPromo',
    'voucher',
    'Credit promotionnel offert aux gagnants des JCQ Pronostics.',
    'Credit 3 000 FCFA',
    3000,
    null,
    'JCQ-PRONO-3000',
    'Contacter le gagnant depuis le SA pour confirmer son identite et organiser la remise du credit.',
    'Pronostic gratuit, sans achat requis. Credit promotionnel personnel, non remboursable.',
    30,
    0,
    true,
    '{"seed": true, "free_quiz": true, "no_purchase_required": true, "question_source": "pronostic_question_bank"}'::jsonb,
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
contest_rows as (
  select *
  from (
    values
      (
        'jcq-pronostic-image-questions',
        'JCQ Pronostics Vision',
        'Observe l image, choisis ton pronostic et attends la resolution du match.',
        'Pronostics CI',
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=fifciv.com&sz=128',
        'image_questions',
        'Questions images'
      ),
      (
        'jcq-pronostic-image-answers',
        'JCQ Pronostics Drapeaux',
        'Lis le scenario, puis choisis ton pronostic avec les images.',
        'Pronostics CI',
        'https://images.unsplash.com/photo-1522778119026-d647f0596c20?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=cafonline.com&sz=128',
        'image_answers',
        'Reponses images'
      ),
      (
        'jcq-pronostic-text',
        'JCQ Pronostics Classique',
        'Pronostics football en format texte, simples et rapides.',
        'Pronostics CI',
        'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=fifa.com&sz=128',
        'text_only',
        'Questions texte'
      )
  ) as rows(
    contest_key,
    title,
    description,
    brand_name,
    image_url,
    brand_logo_url,
    media_mode,
    media_label
  )
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
    live_status,
    views_count,
    shares_count,
    created_at
  )
  select
    (
      substr(md5('jcq-pronostic-bank-v1-' || contest_rows.contest_key), 1, 8)
      || '-' ||
      substr(md5('jcq-pronostic-bank-v1-' || contest_rows.contest_key), 9, 4)
      || '-' ||
      substr(md5('jcq-pronostic-bank-v1-' || contest_rows.contest_key), 13, 4)
      || '-' ||
      substr(md5('jcq-pronostic-bank-v1-' || contest_rows.contest_key), 17, 4)
      || '-' ||
      substr(md5('jcq-pronostic-bank-v1-' || contest_rows.contest_key), 21, 12)
    )::uuid,
    null,
    contest_rows.title,
    contest_rows.description,
    contest_rows.image_url,
    contest_rows.brand_logo_url,
    contest_rows.brand_name,
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
        3,
        'question_type',
        'pronostic',
        'question_bank_id',
        bank_seed.id::text,
        'question_bank_category',
        category_seed.name,
        'question_source',
        'question_bank_by_category',
        'media_mode',
        contest_rows.media_mode,
        'media_label',
        contest_rows.media_label,
        'brand_theme',
        contest_rows.brand_name,
        'free_quiz',
        true,
        'no_purchase_required',
        true,
        'resolution_status',
        'pending'
      ),
    1,
    null,
    now(),
    now() + interval '14 days',
    true,
    array['free']::text[],
    false,
    'scheduled',
    0,
    0,
    now()
  from contest_rows
  cross join category_seed
  cross join bank_seed
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
    is_live = false,
    live_status = 'scheduled'
  returning id
),
question_availability as (
  select
    count(*) filter (
      where length(trim(coalesce(questions.question_image_url, ''))) > 0
    ) as image_question_available,
    count(*) filter (
      where length(trim(coalesce(questions.option_a_image_url, ''))) > 0
        and length(trim(coalesce(questions.option_b_image_url, ''))) > 0
        and length(trim(coalesce(questions.option_c_image_url, ''))) > 0
        and length(trim(coalesce(questions.option_d_image_url, ''))) > 0
    ) as image_answer_available,
    count(*) filter (
      where length(trim(coalesce(questions.question_image_url, ''))) = 0
        and length(trim(coalesce(questions.option_a_image_url, ''))) = 0
        and length(trim(coalesce(questions.option_b_image_url, ''))) = 0
        and length(trim(coalesce(questions.option_c_image_url, ''))) = 0
        and length(trim(coalesce(questions.option_d_image_url, ''))) = 0
    ) as text_only_available
  from public.questions questions
  cross join bank_seed
  where questions.question_bank_id = bank_seed.id
    and questions.question_type = 'pronostic'
    and coalesce(questions.is_active, true) = true
)
select
  (select count(*) from category_seed) as pronostic_category_ready,
  (select count(*) from bank_seed) as pronostic_bank_ready,
  (select count(*) from bank_category_seed) as bank_category_links_inserted,
  (select count(*) from contest_seed) as pronostic_jcq_upserted,
  question_availability.image_question_available,
  question_availability.image_answer_available,
  question_availability.text_only_available
from question_availability;

notify pgrst, 'reload schema';
