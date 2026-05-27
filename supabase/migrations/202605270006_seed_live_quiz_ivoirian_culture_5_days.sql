-- MegaPromo - Quiz Live Culture Ivoirienne dans 5 jours
-- A executer dans Supabase SQL Editor apres:
-- 1) 20260525_create_manual_reward_fields.sql
-- 2) 20260525_process_live_quiz_events_from_question_time.sql
-- Cree/met a jour un QL gratuit qui commence dans 5 jours et met en
-- valeur la culture de la Cote d'Ivoire.

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

update public.contests
set
  status = 'ended',
  live_status = 'ended'
where coalesce(is_live, false) = true
  and id <> '20260527-0000-4000-c000-000000000901'::uuid
  and coalesce(status, 'active') not in (
    'inactive',
    'ended',
    'completed',
    'finished'
  )
  and coalesce(live_status, 'scheduled') not in (
    'ended',
    'completed',
    'finished'
  );

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
    '20260527-0000-4000-e000-000000000301'::uuid,
    'Invitation evenement culturel ivoirien',
    'concert_ticket',
    'Invitation offerte au laureat pour participer a un evenement culturel, musical ou artistique mettant en valeur la Cote d''Ivoire.',
    'Invitation culturelle ivoirienne',
    10000,
    null,
    'CULTURE-CI',
    'Contacter le laureat pour confirmer son identite et lui remettre l''invitation numerique.',
    'Quiz gratuit, sans achat requis. Invitation personnelle, non remboursable et utilisable selon les conditions de l''evenement partenaire.',
    10,
    0,
    true,
    '{"seed": true, "apple_review": true, "free_quiz": true, "theme": "culture ivoirienne"}'::jsonb,
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
live_contest as (
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
    '20260527-0000-4000-c000-000000000901'::uuid,
    null,
    'QL Culture Ivoirienne',
    'Quiz Live gratuit dedie a la richesse culturelle de la Cote d''Ivoire: patrimoine, gastronomie, langues, musiques, symboles nationaux et traditions. Les joueurs decouvrent ou revisent des elements forts de l''identite ivoirienne dans une arene synchronisee, conviviale et educative. La recompense est offerte pour valoriser la culture ivoirienne et encourager la connaissance du pays.',
    'https://images.unsplash.com/photo-1516026672322-bc52d61a55d5?auto=format&fit=crop&w=1200&q=80',
    'https://www.google.com/s2/favicons?domain=cotedivoiretourisme.ci&sz=128',
    'Culture Cote d''Ivoire',
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
        'free_quiz', true,
        'no_purchase_required', true,
        'cultural_theme', 'Cote d Ivoire',
        'apple_review_context',
        'Quiz Live culturel gratuit: la recompense est offerte pour valoriser le patrimoine ivoirien.'
      ),
    1,
    null,
    now(),
    now() + interval '5 days' + interval '160 seconds',
    true,
    array['free']::text[],
    true,
    now() + interval '5 days',
    'scheduled',
    0,
    0,
    0,
    null,
    0,
    0,
    now()
  from category_seed
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
  select
    question_rows.id,
    question_rows.contest_id,
    question_rows.question_text,
    question_rows.option_a,
    question_rows.option_b,
    question_rows.option_c,
    question_rows.option_d,
    question_rows.correct_answer,
    question_rows.points,
    question_rows.time_limit,
    question_rows.order_index,
    question_rows.created_at
  from (
    values
      (
        '20260527-0000-4000-d000-000000000911'::uuid,
        '20260527-0000-4000-c000-000000000901'::uuid,
        'Quelle ville est la capitale politique de la Cote d''Ivoire ?',
        'Yamoussoukro',
        'Abidjan',
        'Bouake',
        'Korhogo',
        'A',
        10,
        20,
        1,
        now()
      ),
      (
        '20260527-0000-4000-d000-000000000912'::uuid,
        '20260527-0000-4000-c000-000000000901'::uuid,
        'Quel plat ivoirien est souvent prepare avec de la semoule de manioc ?',
        'Attieke',
        'Garba',
        'Placali',
        'Kedjenou',
        'A',
        10,
        20,
        2,
        now()
      ),
      (
        '20260527-0000-4000-d000-000000000913'::uuid,
        '20260527-0000-4000-c000-000000000901'::uuid,
        'Quel rythme musical populaire est ne en Cote d''Ivoire ?',
        'Coupe-decale',
        'Salsa',
        'Reggae roots',
        'Flamenco',
        'A',
        10,
        20,
        3,
        now()
      ),
      (
        '20260527-0000-4000-d000-000000000914'::uuid,
        '20260527-0000-4000-c000-000000000901'::uuid,
        'Quelle ville du nord est connue pour son artisanat et sa culture senoufo ?',
        'Korhogo',
        'Grand-Bassam',
        'San Pedro',
        'Dabou',
        'A',
        10,
        20,
        4,
        now()
      ),
      (
        '20260527-0000-4000-d000-000000000915'::uuid,
        '20260527-0000-4000-c000-000000000901'::uuid,
        'Quelle ville historique ivoirienne est inscrite au patrimoine mondial de l''UNESCO ?',
        'Grand-Bassam',
        'Man',
        'Daloa',
        'Odienne',
        'A',
        10,
        20,
        5,
        now()
      ),
      (
        '20260527-0000-4000-d000-000000000916'::uuid,
        '20260527-0000-4000-c000-000000000901'::uuid,
        'Que representent les couleurs orange, blanc et vert du drapeau ivoirien ?',
        'Les symboles nationaux de la Cote d''Ivoire',
        'Les couleurs d''une equipe etrangere',
        'Un code produit',
        'Une affiche publicitaire',
        'A',
        10,
        20,
        6,
        now()
      ),
      (
        '20260527-0000-4000-d000-000000000917'::uuid,
        '20260527-0000-4000-c000-000000000901'::uuid,
        'Quel objectif principal porte ce Quiz Live Culture Ivoirienne ?',
        'Valoriser le patrimoine culturel ivoirien',
        'Presenter une fiche technique automobile',
        'Comparer des forfaits internet',
        'Choisir un logo de marque',
        'A',
        10,
        20,
        7,
        now()
      )
  ) as question_rows (
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
  join live_contest on live_contest.id = question_rows.contest_id
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
  contests.is_live,
  contests.live_status,
  contests.live_starts_at,
  contests.ends_at,
  contests.prize_description,
  count(questions.id) as questions_count
from public.contests
left join public.questions on questions.contest_id = contests.id
where contests.id = '20260527-0000-4000-c000-000000000901'::uuid
group by contests.id;
