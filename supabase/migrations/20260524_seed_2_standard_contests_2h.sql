-- MegaPromo - 2 concours Standard qui finissent dans 2h
-- A executer dans Supabase SQL Editor.
-- Script idempotent : cree/met a jour un quiz et un tirage accessibles aux
-- joueurs Standard, avec fin a now() + interval '2 hours'.

create table if not exists public.contest_draw_settings (
  id uuid primary key default gen_random_uuid(),
  contest_id uuid not null unique references public.contests(id) on delete cascade,
  standard_tickets int4 not null default 1,
  premium_tickets int4 not null default 2,
  confirmation_message text,
  winner_announcement_at timestamptz,
  rules text,
  created_at timestamptz default now()
);

insert into public.contest_types (key, name, description, is_active, order_index)
values
  ('quiz', 'Quiz', 'Concours avec questions, reponses et score.', true, 1),
  ('tirage', 'Tirage', 'Participation simple avec selection de gagnants.', true, 2)
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
    'Standard',
    'Concours rapides ouverts aux joueurs Standard.',
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
    contest_type,
    category_seed.name,
    category_seed.id,
    'active',
    prize_description,
    prize_value,
    winners_count,
    null,
    now(),
    now() + interval '2 hours',
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
        '20260524-0000-4000-9000-000000000941'::uuid,
        'Quiz Standard Express',
        'Un quiz rapide pour les joueurs Standard. Reponds aux questions avant la fin du chrono.',
        'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80',
        'quiz',
        '500F de credit communication pour le meilleur score',
        500,
        1,
        true
      ),
      (
        '20260524-0000-4000-9000-000000000942'::uuid,
        'Tirage Standard 2H',
        'Participe au tirage Standard avant la fin dans 2 heures.',
        'https://images.unsplash.com/photo-1567427017947-545c5f8d16ad?auto=format&fit=crop&w=1200&q=80',
        'tirage',
        '500F de credit communication par tirage',
        500,
        1,
        false
      )
  ) as seed (
    contest_id,
    title,
    description,
    image_url,
    contest_type,
    prize_description,
    prize_value,
    winners_count,
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
  returning id, type
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
      '20260524-0000-4000-9000-000000000951'::uuid,
      '20260524-0000-4000-9000-000000000941'::uuid,
      'Quel est le principe d''un concours quiz ?',
      'Repondre aux questions',
      'Fermer l''application',
      'Attendre sans jouer',
      'Supprimer son compte',
      'A',
      10,
      20,
      1,
      now()
    ),
    (
      '20260524-0000-4000-9000-000000000952'::uuid,
      '20260524-0000-4000-9000-000000000941'::uuid,
      'Que gagne le meilleur score sur ce concours ?',
      'Du credit communication',
      'Une voiture',
      'Un ordinateur',
      'Un voyage',
      'A',
      10,
      20,
      2,
      now()
    ),
    (
      '20260524-0000-4000-9000-000000000953'::uuid,
      '20260524-0000-4000-9000-000000000941'::uuid,
      'Dans combien de temps ces concours se terminent-ils apres execution du script ?',
      '2 heures',
      '2 jours',
      '10 minutes',
      '1 mois',
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
),
draw_settings_seed as (
  insert into public.contest_draw_settings (
    contest_id,
    standard_tickets,
    premium_tickets,
    confirmation_message,
    winner_announcement_at,
    rules,
    created_at
  )
  values (
    '20260524-0000-4000-9000-000000000942'::uuid,
    1,
    1,
    'Ta participation au Tirage Standard 2H est enregistree.',
    now() + interval '2 hours',
    'Une participation par joueur. Tirage automatique a la fin du concours.',
    now()
  )
  on conflict (contest_id) do update set
    standard_tickets = excluded.standard_tickets,
    premium_tickets = excluded.premium_tickets,
    confirmation_message = excluded.confirmation_message,
    winner_announcement_at = excluded.winner_announcement_at,
    rules = excluded.rules
  returning contest_id
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
  '20260524-0000-4000-9000-000000000941'::uuid,
  '20260524-0000-4000-9000-000000000942'::uuid
)
group by contests.id
order by contests.title;
