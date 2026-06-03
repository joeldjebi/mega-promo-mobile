-- MegaPromo - 3 JCQ CI alimentes par les banques de questions
-- A executer dans Supabase SQL Editor apres:
-- 202606020010_seed_3_question_bank_categories_only.sql
-- et 202606020011_seed_30_questions_for_3_question_banks.sql.
--
-- Objectif:
-- - creer 1 JCQ Automobile;
-- - creer 1 JCQ Technologie;
-- - creer 1 JCQ Musique;
-- - chaque JCQ demande 3 questions;
-- - les questions sont tirees aleatoirement cote serveur depuis la banque
--   liee a la categorie du JCQ;
-- - aucune question n'est creee directement sur les concours.
--
-- Important:
-- - execute d'abord en DEV;
-- - execute ensuite en PROD uniquement apres validation.

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
      (
        'automobile',
        'Automobile',
        '20260602-0000-4000-b001-000000000001'::uuid
      ),
      (
        'technologie',
        'Technologie',
        '20260602-0000-4000-b002-000000000002'::uuid
      ),
      (
        'musique',
        'Musique',
        '20260602-0000-4000-b003-000000000003'::uuid
      )
  ) as rows(bank_key, category_name, question_bank_id)
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
    'Credit JCQ Marques CI',
    'voucher',
    'Credit promotionnel offert aux gagnants des JCQ par categorie.',
    'Credit 3 000 FCFA',
    3000,
    null,
    'JCQ-CI-BANK-3000',
    'Contacter le gagnant depuis le SA pour confirmer son identite et organiser la remise du credit.',
    'Quiz gratuit, sans achat requis. Credit promotionnel personnel, non remboursable.',
    30,
    0,
    true,
    '{"seed": true, "free_quiz": true, "no_purchase_required": true, "question_source": "question_bank_by_category"}'::jsonb,
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
        'automobile',
        'JCQ Automobile CI',
        'Quiz concours gratuit sur les reflexes auto, la route et la mobilite. Au demarrage, 3 questions sont tirees aleatoirement depuis la Banque Automobile.',
        'CFAO Mobility CI',
        'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=cfao-mobility.ci&sz=128'
      ),
      (
        'technologie',
        'JCQ Technologie CI',
        'Quiz concours gratuit sur le numerique, les applications et les usages tech. Au demarrage, 3 questions sont tirees aleatoirement depuis la Banque Technologie.',
        'Jumia CI',
        'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=jumia.ci&sz=128'
      ),
      (
        'musique',
        'JCQ Musique CI',
        'Quiz concours gratuit sur les bases de la musique, la scene et la culture musicale. Au demarrage, 3 questions sont tirees aleatoirement depuis la Banque Musique.',
        'Trace CI',
        'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=trace.ci&sz=128'
      )
  ) as rows(
    bank_key,
    title,
    description,
    brand_name,
    image_url,
    brand_logo_url
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
      substr(md5('jcq-ci-bank-v2-' || contest_rows.bank_key), 1, 8)
      || '-' ||
      substr(md5('jcq-ci-bank-v2-' || contest_rows.bank_key), 9, 4)
      || '-' ||
      substr(md5('jcq-ci-bank-v2-' || contest_rows.bank_key), 13, 4)
      || '-' ||
      substr(md5('jcq-ci-bank-v2-' || contest_rows.bank_key), 17, 4)
      || '-' ||
      substr(md5('jcq-ci-bank-v2-' || contest_rows.bank_key), 21, 12)
    )::uuid,
    null,
    contest_rows.title,
    contest_rows.description,
    contest_rows.image_url,
    contest_rows.brand_logo_url,
    contest_rows.brand_name,
    'quiz',
    category_rows.name,
    category_rows.id,
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
        'question_bank_id',
        bank_mapping.question_bank_id::text,
        'question_bank_category',
        category_rows.name,
        'question_source',
        'question_bank_by_category',
        'brand_theme',
        contest_rows.brand_name,
        'free_quiz',
        true,
        'no_purchase_required',
        true
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
  join bank_mapping on bank_mapping.bank_key = contest_rows.bank_key
  join category_rows on category_rows.name = bank_mapping.category_name
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
)
select
  (select count(*) from contest_seed) as jcq_upserted,
  (
    select count(*)
    from public.contests
    where id in (
      (
        substr(md5('jcq-ci-bank-v2-automobile'), 1, 8)
        || '-' ||
        substr(md5('jcq-ci-bank-v2-automobile'), 9, 4)
        || '-' ||
        substr(md5('jcq-ci-bank-v2-automobile'), 13, 4)
        || '-' ||
        substr(md5('jcq-ci-bank-v2-automobile'), 17, 4)
        || '-' ||
        substr(md5('jcq-ci-bank-v2-automobile'), 21, 12)
      )::uuid,
      (
        substr(md5('jcq-ci-bank-v2-technologie'), 1, 8)
        || '-' ||
        substr(md5('jcq-ci-bank-v2-technologie'), 9, 4)
        || '-' ||
        substr(md5('jcq-ci-bank-v2-technologie'), 13, 4)
        || '-' ||
        substr(md5('jcq-ci-bank-v2-technologie'), 17, 4)
        || '-' ||
        substr(md5('jcq-ci-bank-v2-technologie'), 21, 12)
      )::uuid,
      (
        substr(md5('jcq-ci-bank-v2-musique'), 1, 8)
        || '-' ||
        substr(md5('jcq-ci-bank-v2-musique'), 9, 4)
        || '-' ||
        substr(md5('jcq-ci-bank-v2-musique'), 13, 4)
        || '-' ||
        substr(md5('jcq-ci-bank-v2-musique'), 17, 4)
        || '-' ||
        substr(md5('jcq-ci-bank-v2-musique'), 21, 12)
      )::uuid
    )
  ) as jcq_total;

notify pgrst, 'reload schema';
