-- MegaPromo - JCQ test annonce vainqueur, fin dans 5 minutes
-- A executer dans Supabase SQL Editor apres:
-- 202606080004_seed_cote_ivoire_actuelle_question_bank.sql.
--
-- Objectif:
-- - creer un JCQ de test qui prend fin 5 minutes apres execution;
-- - permettre de verifier l'annonce du vainqueur dans l'application;
-- - tirer 10 questions depuis la Banque Côte d'Ivoire Actuelle.
--
-- Important:
-- - seed de test a executer en DEV ou temporairement en PROD;
-- - relancer ce script remet l'heure de fin a now() + 5 minutes.

alter table public.contests
add column if not exists is_live bool not null default false,
add column if not exists live_status varchar not null default 'scheduled',
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
    questions_per_quiz = excluded.questions_per_quiz,
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
    '20260610-0000-4000-e000-000000000101'::uuid,
    'Credit Test JCQ Vainqueur MegaPromo',
    'voucher',
    'Credit test pour verifier l''annonce du vainqueur JCQ.',
    'Credit test 1 000 FCFA',
    1000,
    null,
    'JCQ-TEST-WIN-1000',
    'Test interne: verifier l''annonce du vainqueur dans l''application.',
    'Concours test, a ne conserver en production que temporairement.',
    5,
    0,
    true,
    '{"seed": true, "test": true, "free_quiz": true, "no_purchase_required": true, "purpose": "winner_announcement_test"}'::jsonb,
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
    '20260610-0000-4000-c000-000000000101'::uuid,
    null,
    'Test Vainqueur - Côte d''Ivoire Actuelle',
    'JCQ test de 10 questions. Il prend fin 5 minutes apres execution du seed pour verifier l''annonce du vainqueur.',
    'https://images.unsplash.com/photo-1526772662000-3f88f10405ff?auto=format&fit=crop&w=1200&q=80',
    'https://www.google.com/s2/favicons?domain=megapromo.app&sz=128',
    'MegaPromo Test',
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
        'question_type',
        'quiz',
        'question_bank_id',
        bank_seed.id::text,
        'question_bank_category',
        category_seed.name,
        'question_source',
        'question_bank_by_category',
        'media_mode',
        'text_only',
        'free_quiz',
        true,
        'no_purchase_required',
        true,
        'test_ends_in_minutes',
        5
      ),
    1,
    null,
    now(),
    now() + interval '5 minutes',
    true,
    array['free']::text[],
    false,
    'scheduled',
    0,
    0,
    now()
  from category_seed
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
    status = 'active',
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
    ends_at = now() + interval '5 minutes',
    is_boosted = excluded.is_boosted,
    allowed_player_plan_keys = excluded.allowed_player_plan_keys,
    is_live = false,
    live_status = 'scheduled',
    views_count = 0,
    shares_count = 0
  returning id, title, starts_at, ends_at
),
question_availability as (
  select
    count(*) filter (
      where coalesce(questions.is_active, true) = true
        and length(trim(coalesce(questions.question_image_url, ''))) = 0
        and length(trim(coalesce(questions.option_a_image_url, ''))) = 0
        and length(trim(coalesce(questions.option_b_image_url, ''))) = 0
        and length(trim(coalesce(questions.option_c_image_url, ''))) = 0
        and length(trim(coalesce(questions.option_d_image_url, ''))) = 0
    ) as text_questions_available
  from public.questions questions
  cross join bank_seed
  where questions.question_bank_id = bank_seed.id
)
select
  (select count(*) from category_seed) as categories_ready,
  (select count(*) from bank_seed) as banks_ready,
  (select count(*) from bank_category_seed) as bank_category_links_inserted,
  (select count(*) from contest_seed) as test_jcq_upserted,
  question_availability.text_questions_available,
  contest_seed.title,
  contest_seed.starts_at,
  contest_seed.ends_at
from contest_seed
cross join question_availability;

notify pgrst, 'reload schema';
