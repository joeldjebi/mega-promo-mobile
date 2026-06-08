-- MegaPromo - Durcir l'expiration automatique des Quiz Live
-- A executer dans Supabase SQL Editor apres 202606010005.
--
-- Objectif:
-- - terminer tout QL dont la fenetre de jeu est depassee, meme s'il est
--   reste en scheduled/waiting/queued;
-- - eviter qu'un QL termine reste visible/reservable et bloque le QL suivant;
-- - garder un seul QL reservable/jouable dans la file.

create or replace function public.process_live_quiz_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  changed_count integer := 0;
  expired_count integer := 0;
  normalized_count integer := 0;
  promoted_count integer := 0;
  next_live_quiz_id uuid;
  next_live_quiz_starts_at timestamptz;
begin
  perform pg_advisory_xact_lock(hashtext('mega_promo_live_quiz_queue'));

  -- 1) Terminer tous les QL dont la fenetre est depassee, peu importe leur
  -- statut. C'est le garde-fou principal si un cron/realtime n'a pas bascule
  -- le QL au bon moment.
  with expirable_live_quizzes as (
    select
      contests.id,
      contests.live_starts_at,
      public.live_quiz_duration_seconds(
        contests.id,
        coalesce(contests.live_starts_at, contests.starts_at),
        contests.ends_at
      ) as duration_seconds
    from public.contests
    where coalesce(contests.is_live, false) = true
      and contests.live_starts_at is not null
      and coalesce(contests.status, 'active') = 'active'
      and lower(coalesce(contests.live_status, 'scheduled')) in (
        'scheduled',
        'waiting',
        'queued',
        'playing',
        'active',
        'open'
      )
  ),
  expired_live_quizzes as (
    update public.contests
    set
      status = 'ended',
      live_status = 'ended',
      ends_at = least(coalesce(public.contests.ends_at, now()), now())
    from expirable_live_quizzes
    where public.contests.id = expirable_live_quizzes.id
      and expirable_live_quizzes.duration_seconds > 0
      and (
        expirable_live_quizzes.live_starts_at
        + make_interval(
            secs => expirable_live_quizzes.duration_seconds::double precision
          )
      ) <= now()
    returning public.contests.id
  )
  select count(*)::int
  into expired_count
  from expired_live_quizzes;

  changed_count := changed_count + expired_count;

  -- 2) Si un QL reste en cours, les autres doivent rester programmes.
  if exists (
    select 1
    from public.contests
    where coalesce(is_live, false) = true
      and coalesce(status, 'active') = 'active'
      and lower(coalesce(live_status, 'scheduled')) in (
        'playing',
        'active',
        'open'
      )
  ) then
    update public.contests
    set live_status = 'scheduled'
    where coalesce(is_live, false) = true
      and coalesce(status, 'active') = 'active'
      and lower(coalesce(live_status, 'scheduled')) in ('waiting', 'queued');

    get diagnostics normalized_count = row_count;
    return changed_count + normalized_count;
  end if;

  -- 3) Trouver le prochain QL actif et non expire dans la file.
  select contests.id, contests.live_starts_at
  into next_live_quiz_id, next_live_quiz_starts_at
  from public.contests
  where coalesce(contests.is_live, false) = true
    and contests.live_starts_at is not null
    and coalesce(contests.status, 'active') = 'active'
    and lower(coalesce(contests.live_status, 'scheduled')) in (
      'scheduled',
      'waiting',
      'queued'
    )
    and public.live_quiz_duration_seconds(
      contests.id,
      coalesce(contests.live_starts_at, contests.starts_at),
      contests.ends_at
    ) > 0
    and (
      contests.live_starts_at
      + make_interval(
          secs => public.live_quiz_duration_seconds(
            contests.id,
            coalesce(contests.live_starts_at, contests.starts_at),
            contests.ends_at
          )::double precision
        )
    ) > now()
  order by contests.live_starts_at asc, contests.created_at asc, contests.id asc
  limit 1;

  -- 4) Si aucun QL n'attend, rien a promouvoir.
  if next_live_quiz_id is null then
    return changed_count;
  end if;

  -- 5) Tous les autres restent visibles mais verrouilles.
  update public.contests
  set live_status = 'scheduled'
  where coalesce(is_live, false) = true
    and coalesce(status, 'active') = 'active'
    and id <> next_live_quiz_id
    and lower(coalesce(live_status, 'scheduled')) in ('waiting', 'queued');

  get diagnostics normalized_count = row_count;
  changed_count := changed_count + normalized_count;

  -- 6) Le QL le plus proche est le seul reservable. S'il est temps de jouer,
  -- il passe directement en cours.
  if next_live_quiz_starts_at <= now() then
    update public.contests
    set
      live_status = 'playing',
      starts_at = least(coalesce(public.contests.starts_at, now()), now()),
      ends_at = (
        public.contests.live_starts_at
        + make_interval(
            secs => public.live_quiz_duration_seconds(
              public.contests.id,
              coalesce(
                public.contests.live_starts_at,
                public.contests.starts_at
              ),
              public.contests.ends_at
            )::double precision
          )
      )
    where public.contests.id = next_live_quiz_id
      and lower(coalesce(public.contests.live_status, 'scheduled')) <> 'playing';
  else
    update public.contests
    set live_status = 'waiting'
    where public.contests.id = next_live_quiz_id
      and lower(coalesce(public.contests.live_status, 'scheduled')) <> 'waiting';
  end if;

  get diagnostics promoted_count = row_count;
  changed_count := changed_count + promoted_count;

  return changed_count;
end;
$$;

create or replace function public.assert_live_quiz_access_is_open()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_record public.contests%rowtype;
  duration_seconds integer := 0;
begin
  perform public.process_live_quiz_events();

  select *
  into contest_record
  from public.contests
  where id = new.contest_id
  limit 1;

  if contest_record.id is null then
    return new;
  end if;

  if coalesce(contest_record.is_live, false) = false then
    return new;
  end if;

  duration_seconds := public.live_quiz_duration_seconds(
    contest_record.id,
    coalesce(contest_record.live_starts_at, contest_record.starts_at),
    contest_record.ends_at
  );

  if contest_record.live_starts_at is not null
    and duration_seconds > 0
    and (
      contest_record.live_starts_at
      + make_interval(secs => duration_seconds::double precision)
    ) <= now()
  then
    raise exception 'Ce Quiz Live est termine.';
  end if;

  if coalesce(contest_record.status, 'active') <> 'active'
    or lower(coalesce(contest_record.live_status, 'scheduled')) not in (
      'waiting',
      'playing',
      'active',
      'open'
    )
  then
    raise exception
      'Ce Quiz Live est programme mais pas encore reservable.';
  end if;

  return new;
end;
$$;

grant execute on function public.process_live_quiz_events() to authenticated;

notify pgrst, 'reload schema';
