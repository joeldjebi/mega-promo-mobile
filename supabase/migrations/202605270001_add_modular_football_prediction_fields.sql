-- MegaPromo - Champs modulables pour pronostics football
-- A executer dans Supabase SQL Editor.
-- Ajoute le type de pronostic et les options de formulaire:
-- score_exact, first_scorer, assist_provider, starting_eleven, custom_text.

create table if not exists public.contest_predictions (
  id uuid primary key default gen_random_uuid(),
  contest_id uuid not null references public.contests(id) on delete cascade,
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
add column if not exists prediction_type text not null default 'score_exact',
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
    where conname = 'contest_predictions_prediction_type_check'
  ) then
    alter table public.contest_predictions
    add constraint contest_predictions_prediction_type_check
    check (
      prediction_type in (
        'score_exact',
        'first_scorer',
        'assist_provider',
        'starting_eleven',
        'custom_text'
      )
    );
  end if;
end;
$$;

grant select, insert, update on public.contest_predictions to authenticated;

notify pgrst, 'reload schema';
