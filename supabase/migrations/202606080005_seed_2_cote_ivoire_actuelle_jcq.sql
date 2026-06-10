-- MegaPromo - 2 JCQ Cote d'Ivoire Actuelle
-- A executer dans Supabase SQL Editor apres:
-- 202606080004_seed_cote_ivoire_actuelle_question_bank.sql.
--
-- Objectif:
-- - creer 2 JCQ gratuits de 10 questions chacun;
-- - les rattacher a la categorie "Côte d'Ivoire Actuelle";
-- - tirer les questions depuis la Banque Côte d'Ivoire Actuelle;
-- - ne pas dupliquer les questions de banque.

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
    '100 questions intermediaires et difficiles sur la Cote d''Ivoire actuelle pour les JCQ et QL.',
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
    '20260608-0000-4000-e000-000000000601'::uuid,
    'Credit JCQ Cote d''Ivoire Actuelle MegaPromo',
    'voucher',
    'Credit promotionnel offert aux gagnants des JCQ Cote d''Ivoire Actuelle.',
    'Credit 3 000 FCFA',
    3000,
    null,
    'JCQ-CI-3000',
    'Contacter le gagnant depuis le SA pour confirmer son identite et organiser la remise du credit.',
    'JCQ gratuit, sans achat requis. Credit promotionnel personnel, non remboursable.',
    20,
    0,
    true,
    '{"seed": true, "free_quiz": true, "no_purchase_required": true, "question_source": "cote_ivoire_actuelle_question_bank"}'::jsonb,
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
        'jcq-ci-actuelle-niveau-1',
        'Connais-tu la Côte d''Ivoire ?',
        'Un JCQ rapide pour tester tes reperes sur la Cote d''Ivoire actuelle: villes, sport, economie et culture.',
        'MegaPromo CI',
        'https://images.unsplash.com/photo-1570129477492-45c003edd2be?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=megapromo.app&sz=128',
        'intermediaire',
        'Session decouverte'
      ),
      (
        'jcq-ci-actuelle-niveau-2',
        'Connais-tu vraiment la Côte d''Ivoire ?',
        'Une session plus relevee pour les joueurs qui suivent l''actualite, les institutions et les grands enjeux du pays.',
        'MegaPromo CI',
        'https://images.unsplash.com/photo-1526772662000-3f88f10405ff?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=megapromo.app&sz=128',
        'difficile',
        'Session expert'
      )
  ) as rows(
    contest_key,
    title,
    description,
    brand_name,
    image_url,
    brand_logo_url,
    difficulty_focus,
    session_label
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
      substr(md5('jcq-cote-ivoire-actuelle-20260608-' || contest_rows.contest_key), 1, 8)
      || '-' ||
      substr(md5('jcq-cote-ivoire-actuelle-20260608-' || contest_rows.contest_key), 9, 4)
      || '-' ||
      substr(md5('jcq-cote-ivoire-actuelle-20260608-' || contest_rows.contest_key), 13, 4)
      || '-' ||
      substr(md5('jcq-cote-ivoire-actuelle-20260608-' || contest_rows.contest_key), 17, 4)
      || '-' ||
      substr(md5('jcq-cote-ivoire-actuelle-20260608-' || contest_rows.contest_key), 21, 12)
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
        10,
        'question_type',
        'quiz',
        'question_bank_id',
        bank_seed.id::text,
        'question_bank_category',
        category_seed.name,
        'question_source',
        'question_bank_by_category',
        'difficulty_focus',
        contest_rows.difficulty_focus,
        'session_label',
        contest_rows.session_label,
        'free_quiz',
        true,
        'no_purchase_required',
        true
      ),
    1,
    null,
    now(),
    now() + interval '30 days',
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
    count(*) as available_questions,
    count(*) filter (where questions.difficulty = 'intermediaire') as intermediate_questions,
    count(*) filter (where questions.difficulty = 'difficile') as difficult_questions
  from public.questions questions
  cross join bank_seed
  where questions.question_bank_id = bank_seed.id
    and coalesce(questions.is_active, true) = true
)
select
  (select count(*) from category_seed) as categories_ready,
  (select count(*) from bank_seed) as banks_ready,
  (select count(*) from bank_category_seed) as bank_category_links_inserted,
  (select count(*) from contest_seed) as jcq_upserted,
  question_availability.available_questions,
  question_availability.intermediate_questions,
  question_availability.difficult_questions
from question_availability;

notify pgrst, 'reload schema';
