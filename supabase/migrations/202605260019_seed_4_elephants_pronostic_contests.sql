-- MegaPromo - 4 jeux concours pronostic sur les Elephants de Cote d'Ivoire
-- A executer dans Supabase SQL Editor apres:
-- 1) 20260525_create_manual_reward_fields.sql
-- 2) 20260525_seed_reward_catalog_all_types.sql
-- Script idempotent: cree/met a jour 4 pronostics actifs:
-- titulaires, score, premier buteur et passeur decisif.

create table if not exists public.contest_predictions (
  id uuid primary key default gen_random_uuid(),
  contest_id uuid not null unique references public.contests(id) on delete cascade,
  home_team text not null default 'Equipe 1',
  away_team text not null default 'Equipe 2',
  match_label text not null default 'Pronostic du match',
  match_date timestamptz,
  home_score int4,
  away_score int4,
  status text not null default 'open',
  prediction_type text not null default 'score_exact',
  points_exact_score int4 not null default 50,
  points_correct_result int4 not null default 20,
  options jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.contest_predictions
add column if not exists home_team text not null default 'Equipe 1',
add column if not exists away_team text not null default 'Equipe 2',
add column if not exists match_label text not null default 'Pronostic du match',
add column if not exists match_date timestamptz,
add column if not exists home_score int4,
add column if not exists away_score int4,
add column if not exists status text not null default 'open',
add column if not exists prediction_type text not null default 'score_exact',
add column if not exists points_exact_score int4 not null default 50,
add column if not exists points_correct_result int4 not null default 20,
add column if not exists options jsonb not null default '{}'::jsonb,
add column if not exists metadata jsonb not null default '{}'::jsonb,
add column if not exists created_at timestamptz not null default now(),
add column if not exists updated_at timestamptz not null default now();

create unique index if not exists contest_predictions_contest_id_key
on public.contest_predictions(contest_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'contest_predictions_status_check'
  ) then
    alter table public.contest_predictions
    add constraint contest_predictions_status_check
    check (status in ('open', 'closed', 'resolved', 'cancelled'));
  end if;
end;
$$;

grant select, insert, update on public.contest_predictions to authenticated;

insert into public.contest_types (key, name, description, is_active, order_index)
values
  (
    'pronostic',
    'Pronostic',
    'Jeu concours de prediction sportive.',
    true,
    3
  )
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
    'Jeux concours de prediction sportive.',
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
seed_rows as (
  select *
  from (
    values
      (
        '20260526-0000-4000-e000-000000000101'::uuid,
        'Pronostic Elephants - XI titulaire',
        'Devine le scenario du match des Elephants et valide ton pronostic avant le coup d envoi.',
        'https://images.unsplash.com/photo-1517466787929-bc90951d0974?auto=format&fit=crop&w=1200&q=80',
        '20260525-0000-4000-a000-000000000101'::uuid,
        'Elephants de Cote d Ivoire',
        'Adversaire du jour',
        'Composition titulaire des Elephants',
        'starting_eleven',
        '{"prompt": "Selectionne les 11 titulaires des Elephants.", "action_label": "Valider mon XI", "min_selections": 11, "max_selections": 11, "players": ["Yahia Fofana", "Serge Aurier", "Wilfried Singo", "Evan Ndicka", "Ghislain Konan", "Seko Fofana", "Franck Kessie", "Ibrahim Sangare", "Simon Adingra", "Nicolas Pepe", "Sebastien Haller", "Oumar Diakite", "Karim Konate", "Jean-Philippe Krasso", "Max-Alain Gradel", "Jeremie Boga", "Odilon Kossounou", "Willy Boly"]}'::jsonb,
        '{"theme": "starting_lineup", "hint": "Qui sera dans le XI titulaire ?", "expected": "selection_11_joueurs"}'::jsonb,
        true
      ),
      (
        '20260526-0000-4000-e000-000000000102'::uuid,
        'Pronostic Elephants - Score exact',
        'Trouve le score du match des Elephants. Le score exact rapporte le plus de points.',
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
        '20260525-0000-4000-a000-000000000103'::uuid,
        'Elephants de Cote d Ivoire',
        'Adversaire du jour',
        'Score exact du match',
        'score_exact',
        '{"prompt": "Quel sera le score final ?", "action_label": "Valider mon score"}'::jsonb,
        '{"theme": "exact_score", "hint": "Quel sera le score final ?", "expected": "home_score_away_score"}'::jsonb,
        true
      ),
      (
        '20260526-0000-4000-e000-000000000103'::uuid,
        'Pronostic Elephants - Premier but',
        'Pronostique le scenario du premier but des Elephants et tente de gagner.',
        'https://images.unsplash.com/photo-1522778119026-d647f0596c20?auto=format&fit=crop&w=1200&q=80',
        '20260525-0000-4000-a000-000000000102'::uuid,
        'Elephants de Cote d Ivoire',
        'Adversaire du jour',
        'Premier buteur du match',
        'first_scorer',
        '{"prompt": "Qui marquera le premier but ?", "action_label": "Valider mon buteur", "allow_none": true, "allow_other": true, "players": ["Sebastien Haller", "Simon Adingra", "Nicolas Pepe", "Oumar Diakite", "Karim Konate", "Jean-Philippe Krasso", "Max-Alain Gradel", "Seko Fofana", "Franck Kessie", "Jeremie Boga"]}'::jsonb,
        '{"theme": "first_goal", "hint": "Qui marque en premier ?", "expected": "joueur_unique"}'::jsonb,
        false
      ),
      (
        '20260526-0000-4000-e000-000000000104'::uuid,
        'Pronostic Elephants - Passeur decisif',
        'Anticipe le joueur qui fera la passe decisive et le resultat du match.',
        'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?auto=format&fit=crop&w=1200&q=80',
        '20260525-0000-4000-a000-000000000105'::uuid,
        'Elephants de Cote d Ivoire',
        'Adversaire du jour',
        'Premier passeur decisif',
        'assist_provider',
        '{"prompt": "Qui fera la premiere passe decisive ?", "action_label": "Valider mon passeur", "allow_none": true, "allow_other": true, "players": ["Simon Adingra", "Nicolas Pepe", "Jeremie Boga", "Max-Alain Gradel", "Seko Fofana", "Franck Kessie", "Serge Aurier", "Ghislain Konan", "Oumar Diakite", "Karim Konate"]}'::jsonb,
        '{"theme": "assist_provider", "hint": "Qui fera la passe decisive ?", "expected": "joueur_unique"}'::jsonb,
        false
      )
  ) as seed (
    contest_id,
    title,
    description,
    image_url,
    reward_catalog_id,
    home_team,
    away_team,
    match_label,
    prediction_type,
    options,
    metadata,
    is_boosted
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
    seed_rows.contest_id,
    null,
    seed_rows.title,
    seed_rows.description,
    seed_rows.image_url,
    null,
    'Elephants CI',
    'pronostic',
    category_seed.name,
    category_seed.id,
    'active',
    reward_catalog.value_label,
    reward_catalog.estimated_value,
    reward_catalog.reward_type,
    reward_catalog.id,
    'manual',
    reward_catalog.default_delivery_instructions,
    reward_catalog.terms,
    2,
    null,
    now(),
    now() + interval '24 hours',
    seed_rows.is_boosted,
    array['free']::text[],
    false,
    null,
    'scheduled',
    0,
    0,
    now()
  from seed_rows
  cross join category_seed
  join public.reward_catalog
    on reward_catalog.id = seed_rows.reward_catalog_id
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
prediction_seed as (
  insert into public.contest_predictions (
    contest_id,
    home_team,
    away_team,
    match_label,
    match_date,
    home_score,
    away_score,
    status,
    prediction_type,
    points_exact_score,
    points_correct_result,
    options,
    metadata,
    created_at,
    updated_at
  )
  select
    seed_rows.contest_id,
    seed_rows.home_team,
    seed_rows.away_team,
    seed_rows.match_label,
    now() + interval '24 hours',
    null,
    null,
    'open',
    seed_rows.prediction_type,
    50,
    20,
    seed_rows.options,
    seed_rows.metadata,
    now(),
    now()
  from seed_rows
  on conflict (contest_id) do update set
    home_team = excluded.home_team,
    away_team = excluded.away_team,
    match_label = excluded.match_label,
    match_date = excluded.match_date,
    status = 'open',
    prediction_type = excluded.prediction_type,
    points_exact_score = excluded.points_exact_score,
    points_correct_result = excluded.points_correct_result,
    options = excluded.options,
    metadata = excluded.metadata,
    updated_at = now()
  returning contest_id
)
select
  contests.id,
  contests.title,
  contests.type,
  contests.status,
  contests.ends_at,
  contest_predictions.match_label,
  contests.prize_description
from public.contests
join public.contest_predictions
  on contest_predictions.contest_id = contests.id
where contests.id in (
  '20260526-0000-4000-e000-000000000101'::uuid,
  '20260526-0000-4000-e000-000000000102'::uuid,
  '20260526-0000-4000-e000-000000000103'::uuid,
  '20260526-0000-4000-e000-000000000104'::uuid
)
order by contests.title;
