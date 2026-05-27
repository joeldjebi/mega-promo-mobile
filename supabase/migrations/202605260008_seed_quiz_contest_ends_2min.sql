-- MegaPromo - Jeu concours quiz qui se termine dans 2 minutes
-- A executer dans Supabase SQL Editor apres:
-- 1) 20260525_create_manual_reward_fields.sql
-- 2) 20260525_seed_reward_catalog_all_types.sql
-- Script idempotent: cree/met a jour un quiz standard actif, non-live,
-- qui se termine 2 minutes apres execution.

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
    'Jeux concours',
    'Concours standard ouverts aux joueurs.',
    'game',
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
reward_seed as (
  select *
  from public.reward_catalog
  where id = '20260525-0000-4000-a000-000000000101'::uuid
  limit 1
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
    '20260526-0000-4000-9000-000000000201'::uuid,
    null,
    'Quiz Flash 2 Minutes',
    'Un jeu concours quiz ultra rapide. Le meilleur score gagne apres la fin du chrono.',
    'https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=1200&q=80',
    null,
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
    1,
    null,
    now(),
    now() + interval '2 minutes',
    true,
    array['free']::text[],
    false,
    null,
    'scheduled',
    0,
    0,
    now()
  from category_seed
  cross join reward_seed
  on conflict (id) do update set
    title = excluded.title,
    description = excluded.description,
    image_url = excluded.image_url,
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
      '20260526-0000-4000-9000-000000000211'::uuid,
      '20260526-0000-4000-9000-000000000201'::uuid,
      'Que doit faire un joueur pour gagner un quiz MegaPromo ?',
      'Repondre vite et juste',
      'Quitter le jeu',
      'Ignorer les questions',
      'Changer de pseudo',
      'A',
      10,
      20,
      1,
      now()
    ),
    (
      '20260526-0000-4000-9000-000000000212'::uuid,
      '20260526-0000-4000-9000-000000000201'::uuid,
      'Combien de secondes compte une minute ?',
      '30',
      '45',
      '60',
      '90',
      'C',
      10,
      20,
      2,
      now()
    ),
    (
      '20260526-0000-4000-9000-000000000213'::uuid,
      '20260526-0000-4000-9000-000000000201'::uuid,
      'Quel type de gain est utilise pour ce quiz ?',
      'Mobile Money',
      'Ticket avion',
      'Mot de passe',
      'Abonnement internet illimite',
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
  contests.type,
  contests.is_live,
  contests.starts_at,
  contests.ends_at,
  contests.prize_description,
  contests.reward_catalog_id,
  count(questions.id) as questions_count
from public.contests
left join public.questions on questions.contest_id = contests.id
where contests.id = '20260526-0000-4000-9000-000000000201'::uuid
group by contests.id;
