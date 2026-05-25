-- MegaPromo - 2 jeux concours Quiz qui finissent dans 1h
-- A executer dans Supabase SQL Editor.
-- Script idempotent : cree/met a jour deux concours quiz accessibles aux
-- joueurs Standard, avec fin a now() + interval '1 hour'.

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
    'Quiz',
    'Jeux concours avec questions rapides.',
    'quiz',
    '#7C3AED',
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
seed_contests as (
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
    winners_count,
    max_participants,
    starts_at,
    ends_at,
    is_boosted,
    allowed_player_plan_keys,
    is_live,
    views_count,
    shares_count,
    created_at
  )
  select
    contest_id,
    null,
    title,
    description,
    image_url,
    null,
    'MegaPromo',
    'quiz',
    category_seed.name,
    category_seed.id,
    'active',
    prize_description,
    prize_value,
    1,
    null,
    now(),
    now() + interval '1 hour',
    is_boosted,
    array['free']::text[],
    false,
    0,
    0,
    now()
  from category_seed
  cross join (
    values
      (
        '20260525-0000-4000-9000-000000001001'::uuid,
        'Quiz Culture Express 1H',
        'Reponds a ces questions de culture generale avant la fin du chrono.',
        'https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=1200&q=80',
        '500F de credit communication pour le meilleur score',
        500,
        true
      ),
      (
        '20260525-0000-4000-9000-000000001002'::uuid,
        'Quiz MegaPromo Reflexe 1H',
        'Un jeu concours quiz rapide pour tester tes reflexes et gagner.',
        'https://images.unsplash.com/photo-1523240795612-9a054b0db644?auto=format&fit=crop&w=1200&q=80',
        '500F de credit communication pour le meilleur score',
        500,
        false
      )
  ) as seed (
    contest_id,
    title,
    description,
    image_url,
    prize_description,
    prize_value,
    is_boosted
  )
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
    winners_count = excluded.winners_count,
    max_participants = excluded.max_participants,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    is_boosted = excluded.is_boosted,
    allowed_player_plan_keys = excluded.allowed_player_plan_keys,
    is_live = false
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
      '20260525-0000-4000-9000-000000001011'::uuid,
      '20260525-0000-4000-9000-000000001001'::uuid,
      'Quelle planete est surnommee la planete rouge ?',
      'Mars',
      'Venus',
      'Jupiter',
      'Mercure',
      'A',
      10,
      20,
      1,
      now()
    ),
    (
      '20260525-0000-4000-9000-000000001012'::uuid,
      '20260525-0000-4000-9000-000000001001'::uuid,
      'Combien de minutes y a-t-il dans une heure ?',
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
      '20260525-0000-4000-9000-000000001013'::uuid,
      '20260525-0000-4000-9000-000000001001'::uuid,
      'Quel continent abrite la Cote d''Ivoire ?',
      'Europe',
      'Afrique',
      'Asie',
      'Amerique',
      'B',
      10,
      20,
      3,
      now()
    ),
    (
      '20260525-0000-4000-9000-000000001021'::uuid,
      '20260525-0000-4000-9000-000000001002'::uuid,
      'Que faut-il faire pour marquer des points dans un quiz ?',
      'Repondre correctement',
      'Quitter la page',
      'Attendre la fin',
      'Partager seulement',
      'A',
      10,
      20,
      1,
      now()
    ),
    (
      '20260525-0000-4000-9000-000000001022'::uuid,
      '20260525-0000-4000-9000-000000001002'::uuid,
      'Dans combien de temps ces concours se terminent-ils apres execution du script ?',
      '10 minutes',
      '1 heure',
      '2 heures',
      '24 heures',
      'B',
      10,
      20,
      2,
      now()
    ),
    (
      '20260525-0000-4000-9000-000000001023'::uuid,
      '20260525-0000-4000-9000-000000001002'::uuid,
      'Quel type de concours est cree par ce script ?',
      'Tirage',
      'Pronostic',
      'Quiz',
      'Sondage',
      'C',
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
  contests.starts_at,
  contests.ends_at,
  contests.allowed_player_plan_keys,
  count(questions.id) as questions_count
from public.contests
left join public.questions on questions.contest_id = contests.id
where contests.id in (
  '20260525-0000-4000-9000-000000001001'::uuid,
  '20260525-0000-4000-9000-000000001002'::uuid
)
group by contests.id
order by contests.title;
