-- MegaPromo - Reparer l'acces aux forfaits depuis les JCQ
-- A executer dans Supabase SQL Editor si "Voir les options" affiche
-- "Offres indisponibles".
--
-- Objectif:
-- - activer la fonctionnalite forfaits joueurs;
-- - desactiver le mode review safe en environnement normal;
-- - garantir les tables et forfaits de base si le catalogue n'existe pas;
-- - permettre aux joueurs bloques par limite journaliere ou forfait requis
--   de voir et souscrire aux offres.

create table if not exists public.app_feature_flags (
  key text primary key,
  name text not null,
  description text,
  is_enabled boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  updated_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.app_feature_flags (
  key,
  name,
  description,
  is_enabled,
  metadata,
  created_at,
  updated_at
)
values
  (
    'player_subscriptions',
    'Forfaits joueurs',
    'Affiche et active la page des forfaits joueurs.',
    true,
    '{"source": "202606050001_enable_player_plans_for_jcq_options"}'::jsonb,
    now(),
    now()
  ),
  (
    'app_review_safe',
    'Mode review safe',
    'Masque les forfaits, montants, tirages et pronostics uniquement pendant les revues stores.',
    false,
    '{"source": "202606050001_enable_player_plans_for_jcq_options", "normal_runtime": true}'::jsonb,
    now(),
    now()
  )
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_enabled = excluded.is_enabled,
  metadata = public.app_feature_flags.metadata || excluded.metadata,
  updated_at = now();

create table if not exists public.player_plans (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text,
  price int not null default 0,
  duration_days int not null default 30,
  daily_participation_limit int not null default 3,
  bonus_tickets int not null default 0,
  badge_multiplier numeric not null default 1,
  is_active boolean not null default true,
  order_index int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.player_plans
add column if not exists key text,
add column if not exists name text,
add column if not exists description text,
add column if not exists price int not null default 0,
add column if not exists duration_days int not null default 30,
add column if not exists daily_participation_limit int not null default 3,
add column if not exists bonus_tickets int not null default 0,
add column if not exists badge_multiplier numeric not null default 1,
add column if not exists is_active boolean not null default true,
add column if not exists order_index int not null default 0,
add column if not exists created_at timestamptz not null default now(),
add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'player_plans_key_key'
      and conrelid = 'public.player_plans'::regclass
  ) then
    alter table public.player_plans
    add constraint player_plans_key_key unique (key);
  end if;
end;
$$;

create table if not exists public.player_plan_benefits (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.player_plans(id) on delete cascade,
  label text not null,
  description text,
  icon text,
  order_index int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.player_plan_benefits
add column if not exists plan_id uuid references public.player_plans(id) on delete cascade,
add column if not exists label text,
add column if not exists description text,
add column if not exists icon text,
add column if not exists order_index int not null default 0,
add column if not exists created_at timestamptz not null default now();

create table if not exists public.player_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  plan_id uuid not null references public.player_plans(id) on delete restrict,
  amount int not null default 0,
  status text not null default 'pending',
  starts_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days'),
  payment_method text,
  payment_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.player_subscriptions
add column if not exists user_id uuid references public.users(id) on delete cascade,
add column if not exists plan_id uuid references public.player_plans(id) on delete restrict,
add column if not exists amount int not null default 0,
add column if not exists status text not null default 'pending',
add column if not exists starts_at timestamptz not null default now(),
add column if not exists expires_at timestamptz not null default (now() + interval '30 days'),
add column if not exists payment_method text,
add column if not exists payment_reference text,
add column if not exists created_at timestamptz not null default now(),
add column if not exists updated_at timestamptz not null default now();

alter table public.player_subscriptions
drop constraint if exists player_subscriptions_status_check;

alter table public.player_subscriptions
add constraint player_subscriptions_status_check
check (status in ('active', 'pending', 'expired', 'cancelled', 'rejected'));

create index if not exists player_subscriptions_user_status_idx
  on public.player_subscriptions(user_id, status, created_at desc);

grant select on public.app_feature_flags to authenticated, anon;
grant select on public.player_plans to authenticated, anon;
grant select on public.player_plan_benefits to authenticated, anon;
grant select, insert on public.player_subscriptions to authenticated;

with plan_rows as (
  select *
  from (
    values
      (
        '20260605-0000-4000-f000-000000000001'::uuid,
        'free',
        'Standard',
        'Forfait gratuit pour commencer a jouer.',
        0,
        30,
        3,
        0,
        1.0::numeric,
        1
      ),
      (
        '20260605-0000-4000-f000-000000000002'::uuid,
        'premium',
        'Premium',
        'Plus de participations quotidiennes et bonus de progression.',
        1000,
        30,
        10,
        3,
        1.5::numeric,
        2
      ),
      (
        '20260605-0000-4000-f000-000000000003'::uuid,
        'vip',
        'VIP',
        'Acces prioritaire aux meilleures campagnes et bonus renforces.',
        2500,
        30,
        25,
        8,
        2.0::numeric,
        3
      )
  ) as rows(
    id,
    key,
    name,
    description,
    price,
    duration_days,
    daily_participation_limit,
    bonus_tickets,
    badge_multiplier,
    order_index
  )
),
plan_seed as (
  insert into public.player_plans (
    id,
    key,
    name,
    description,
    price,
    duration_days,
    daily_participation_limit,
    bonus_tickets,
    badge_multiplier,
    is_active,
    order_index,
    created_at,
    updated_at
  )
  select
    plan_rows.id,
    plan_rows.key,
    plan_rows.name,
    plan_rows.description,
    plan_rows.price,
    plan_rows.duration_days,
    plan_rows.daily_participation_limit,
    plan_rows.bonus_tickets,
    plan_rows.badge_multiplier,
    true,
    plan_rows.order_index,
    now(),
    now()
  from plan_rows
  on conflict (key) do update set
    name = excluded.name,
    description = excluded.description,
    price = excluded.price,
    duration_days = excluded.duration_days,
    daily_participation_limit = excluded.daily_participation_limit,
    bonus_tickets = excluded.bonus_tickets,
    badge_multiplier = excluded.badge_multiplier,
    is_active = true,
    order_index = excluded.order_index,
    updated_at = now()
  returning id, key
),
benefit_rows as (
  select
    plan_seed.id as plan_id,
    benefits.label,
    benefits.description,
    benefits.icon,
    benefits.order_index
  from plan_seed
  join lateral (
    values
      (
        case plan_seed.key
          when 'free' then '3 participations par jour'
          when 'premium' then '10 participations par jour'
          else '25 participations par jour'
        end,
        'Limite quotidienne appliquee aux JCQ et campagnes classiques.',
        'confirmation_number',
        1
      ),
      (
        case plan_seed.key
          when 'free' then 'Acces aux JCQ gratuits'
          when 'premium' then 'Bonus de participations'
          else 'Bonus VIP renforces'
        end,
        'Avantage associe au forfait joueur.',
        'workspace_premium',
        2
      )
  ) as benefits(label, description, icon, order_index) on true
),
benefit_seed as (
  insert into public.player_plan_benefits (
    plan_id,
    label,
    description,
    icon,
    order_index,
    created_at
  )
  select
    benefit_rows.plan_id,
    benefit_rows.label,
    benefit_rows.description,
    benefit_rows.icon,
    benefit_rows.order_index,
    now()
  from benefit_rows
  where not exists (
    select 1
    from public.player_plan_benefits existing_benefits
    where existing_benefits.plan_id = benefit_rows.plan_id
      and existing_benefits.label = benefit_rows.label
  )
  returning id
)
select
  (
    select count(*)
    from public.app_feature_flags
    where key = 'player_subscriptions'
      and is_enabled = true
  ) as player_subscriptions_enabled,
  (
    select count(*)
    from public.app_feature_flags
    where key = 'app_review_safe'
      and is_enabled = false
  ) as app_review_safe_disabled,
  (select count(*) from plan_seed) as player_plans_ready,
  (select count(*) from benefit_seed) as new_plan_benefits_inserted;

notify pgrst, 'reload schema';
