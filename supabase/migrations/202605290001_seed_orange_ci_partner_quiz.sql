-- MegaPromo - Quiz partenaire Orange CI
-- A executer dans Supabase SQL Editor apres:
-- 1) 20260525_create_manual_reward_fields.sql
-- 2) 202605270004_seed_7_free_brand_quiz_contests.sql (optionnel)
-- Script idempotent: cree/met a jour un partenaire Orange CI, un gain
-- promotionnel et un concours quiz gratuit actif avec 3 questions.

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
    'Quiz promo gratuits',
    'Quiz gratuits proposes par des entreprises partenaires pour faire connaitre leurs activites, produits et services.',
    'campaign',
    '#2563EB',
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
partner_seed as (
  insert into public.partners (
    id,
    company_name,
    email,
    logo_url,
    sector,
    phone,
    subscription_plan,
    subscription_expires_at,
    is_validated,
    is_active,
    created_at
  )
  values (
    '20260529-0000-4000-a000-000000000001'::uuid,
    'Orange Cote d''Ivoire',
    'partenaire.orange-ci@mega-promo.ci',
    'https://www.google.com/s2/favicons?domain=orange.ci&sz=128',
    'Telecommunications',
    '+2250700000000',
    'premium',
    now() + interval '1 year',
    true,
    true,
    now()
  )
  on conflict (id) do update set
    company_name = excluded.company_name,
    email = excluded.email,
    logo_url = excluded.logo_url,
    sector = excluded.sector,
    phone = excluded.phone,
    subscription_plan = excluded.subscription_plan,
    subscription_expires_at = excluded.subscription_expires_at,
    is_validated = true,
    is_active = true
  returning id
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
  select
    '20260529-0000-4000-c000-000000000001'::uuid,
    'Credit communication Orange CI',
    'voucher',
    'Recharge de communication offerte par Orange Cote d''Ivoire au laureat du quiz promotionnel gratuit.',
    'Credit communication 5 000 FCFA',
    5000,
    partner_seed.id,
    'ORANGE-CI-PROMO',
    'Verifier le numero du laureat puis appliquer la recharge de communication offerte par Orange CI.',
    'Quiz gratuit, sans achat requis. Credit non remboursable, non convertible en remboursement et utilisable selon les conditions Orange CI.',
    25,
    0,
    true,
    '{"seed": true, "free_quiz": true, "no_purchase_required": true, "sponsor": "Orange Cote d Ivoire"}'::jsonb,
    now(),
    now()
  from partner_seed
  on conflict (id) do update set
    name = excluded.name,
    reward_type = excluded.reward_type,
    description = excluded.description,
    value_label = excluded.value_label,
    estimated_value = excluded.estimated_value,
    partner_id = excluded.partner_id,
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
    live_starts_at,
    live_status,
    views_count,
    shares_count,
    created_at
  )
  select
    '20260529-0000-4000-b000-000000000001'::uuid,
    partner_seed.id,
    'Quiz gratuit Orange CI - Services mobiles',
    'Orange Cote d''Ivoire propose ce quiz promotionnel gratuit pour faire decouvrir ses services mobiles, internet, assistance client et solutions utiles au quotidien. Aucun achat n''est requis: les joueurs repondent a des questions sur les produits et services Orange CI, puis les meilleurs scores peuvent recevoir une recompense offerte par Orange Cote d''Ivoire.',
    'https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=1200&q=80',
    'https://www.google.com/s2/favicons?domain=orange.ci&sz=128',
    'Orange Cote d''Ivoire',
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
        'free_quiz',
        true,
        'no_purchase_required',
        true,
        'reward_provider',
        'Orange Cote d Ivoire'
      ),
    2,
    null,
    now(),
    now() + interval '5 days',
    true,
    array['free']::text[],
    false,
    null,
    'scheduled',
    0,
    0,
    now()
  from partner_seed
  join category_seed on true
  join reward_seed on true
  on conflict (id) do update set
    partner_id = excluded.partner_id,
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
    live_starts_at = null,
    live_status = 'scheduled'
  returning id
),
questions_seed as (
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
  values
    (
      '20260529-0000-4000-d000-000000000001'::uuid,
      '20260529-0000-4000-b000-000000000001'::uuid,
      'Quel type de service Orange CI met-il en avant dans ce quiz ?',
      'Communication mobile, internet et assistance client',
      'Vente de billets d''avion',
      'Fabrication de voitures',
      'Gestion de pharmacies',
      'A',
      10,
      20,
      1,
      now()
    ),
    (
      '20260529-0000-4000-d000-000000000002'::uuid,
      '20260529-0000-4000-b000-000000000001'::uuid,
      'La participation au quiz Orange CI demande-t-elle un achat ?',
      'Non, la participation est gratuite',
      'Oui, il faut acheter un ticket',
      'Oui, il faut parier',
      'Oui, il faut payer une mise',
      'A',
      10,
      20,
      2,
      now()
    ),
    (
      '20260529-0000-4000-d000-000000000003'::uuid,
      '20260529-0000-4000-b000-000000000001'::uuid,
      'Qui fournit la recompense promotionnelle de ce quiz ?',
      'Orange Cote d''Ivoire',
      'Le joueur participant',
      'Un tirage payant',
      'Un service de pari',
      'A',
      10,
      20,
      3,
      now()
    )
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
)
select
  contests.id,
  contests.title,
  contests.brand_name,
  contests.status,
  contests.ends_at,
  count(questions.id) as questions_count
from public.contests
left join public.questions on questions.contest_id = contests.id
where contests.id = '20260529-0000-4000-b000-000000000001'::uuid
group by contests.id;
