-- MegaPromo - File d'attente Quiz Live
-- A executer dans Supabase SQL Editor.
--
-- Objectif:
-- - plusieurs QL peuvent etre programmes a l'avance;
-- - un seul QL peut etre actif/en cours a la fois;
-- - quand le QL actif se termine, le prochain QL programme et arrive a son
--   heure de depart passe automatiquement en "playing";
-- - les autres QL restent visibles mais non jouables.

create or replace function public.live_quiz_duration_seconds(
  p_contest_id uuid,
  p_fallback_starts_at timestamptz default null,
  p_fallback_ends_at timestamptz default null
)
returns integer
language sql
stable
as $$
  select coalesce(
    nullif(
      (
        select sum(greatest(coalesce(questions.time_limit, 0), 0))::int
        from public.questions
        where questions.contest_id = p_contest_id
      ),
      0
    ),
    greatest(
      extract(
        epoch from (
          coalesce(p_fallback_ends_at, now())
          - coalesce(p_fallback_starts_at, now())
        )
      )::int,
      0
    )
  );
$$;

create or replace function public.process_live_quiz_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  ended_count integer := 0;
  activated_count integer := 0;
begin
  perform pg_advisory_xact_lock(hashtext('mega_promo_live_quiz_queue'));

  -- 1) Cloturer uniquement les QL deja actifs/en cours dont la duree est
  -- terminee. Les QL encore "scheduled/waiting" ne sont pas expires ici:
  -- ils restent dans la file jusqu'a leur activation.
  with active_live_quizzes as (
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
        'playing',
        'active',
        'open'
      )
  ),
  ended_live_quizzes as (
    update public.contests
    set
      status = 'ended',
      live_status = 'ended',
      ends_at = least(
        coalesce(public.contests.ends_at, now()),
        now()
      )
    from active_live_quizzes
    where public.contests.id = active_live_quizzes.id
      and active_live_quizzes.duration_seconds > 0
      and (
        active_live_quizzes.live_starts_at
        + make_interval(
          secs => active_live_quizzes.duration_seconds::double precision
        )
      ) <= now()
    returning public.contests.id
  )
  select count(*)::int
  into ended_count
  from ended_live_quizzes;

  -- 2) Si un QL est encore actif, ne rien activer d'autre.
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
    return ended_count;
  end if;

  -- 3) Activer le prochain QL programme dont l'heure est arrivee.
  -- Si l'activation arrive en retard parce qu'un autre QL etait actif,
  -- live_starts_at devient l'heure officielle d'activation serveur.
  with next_live_quiz as (
    select contests.id
    from public.contests
    where coalesce(contests.is_live, false) = true
      and contests.live_starts_at is not null
      and coalesce(contests.status, 'active') = 'active'
      and lower(coalesce(contests.live_status, 'scheduled')) in (
        'scheduled',
        'waiting',
        'queued'
      )
      and contests.live_starts_at <= now()
      and public.live_quiz_duration_seconds(
        contests.id,
        coalesce(contests.live_starts_at, contests.starts_at),
        contests.ends_at
      ) > 0
    order by contests.live_starts_at asc, contests.created_at asc, contests.id asc
    limit 1
  ),
  activated_live_quiz as (
    update public.contests
    set
      live_status = 'playing',
      live_starts_at = greatest(public.contests.live_starts_at, now()),
      starts_at = least(coalesce(public.contests.starts_at, now()), now()),
      ends_at = greatest(
        coalesce(public.contests.ends_at, now()),
        greatest(public.contests.live_starts_at, now())
          + make_interval(
              secs => public.live_quiz_duration_seconds(
                public.contests.id,
                coalesce(public.contests.live_starts_at, public.contests.starts_at),
                public.contests.ends_at
              )::double precision
            )
      )
    from next_live_quiz
    where public.contests.id = next_live_quiz.id
    returning public.contests.id
  )
  select count(*)::int
  into activated_count
  from activated_live_quiz;

  return ended_count + activated_count;
end;
$$;

create or replace function public.start_live_quiz_participation(
  p_contest_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  contest_record public.contests%rowtype;
  waiting_session_id uuid;
  existing_participation_id uuid;
  participation_id uuid;
  duration_seconds integer;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  perform pg_advisory_xact_lock(
    hashtext(current_user_id::text),
    hashtext(p_contest_id::text)
  );

  perform public.process_live_quiz_events();

  select *
  into contest_record
  from public.contests
  where id = p_contest_id
  limit 1;

  if contest_record.id is null then
    raise exception 'Quiz Live introuvable.';
  end if;

  if coalesce(contest_record.is_live, false) = false then
    raise exception 'Ce concours n''est pas un Quiz Live.';
  end if;

  if coalesce(contest_record.status, 'active') <> 'active'
    or coalesce(contest_record.live_status, 'scheduled') in (
      'ended',
      'completed',
      'finished'
    )
  then
    raise exception 'Ce Quiz Live est termine.';
  end if;

  if lower(coalesce(contest_record.live_status, 'scheduled')) not in (
    'playing',
    'active',
    'open'
  ) then
    raise exception 'Ce Quiz Live est dans la file d''attente.';
  end if;

  if contest_record.live_starts_at is null then
    raise exception 'La date de debut du Quiz Live est introuvable.';
  end if;

  select public.live_quiz_duration_seconds(
    p_contest_id,
    coalesce(contest_record.live_starts_at, contest_record.starts_at),
    contest_record.ends_at
  )
  into duration_seconds;

  if coalesce(duration_seconds, 0) <= 0 then
    raise exception 'L''arene du Quiz Live se prepare. Reviens vite.';
  end if;

  if now() < contest_record.live_starts_at then
    raise exception 'Ce Quiz Live n''est pas encore ouvert.';
  end if;

  if now() >= contest_record.live_starts_at
    + make_interval(secs => duration_seconds::double precision)
  then
    update public.contests
    set
      status = 'ended',
      live_status = 'ended',
      ends_at = least(coalesce(ends_at, now()), now())
    where id = p_contest_id;

    raise exception 'Ce Quiz Live est termine.';
  end if;

  select id
  into waiting_session_id
  from public.live_sessions
  where contest_id = p_contest_id
    and user_id = current_user_id
  limit 1;

  if waiting_session_id is null then
    raise exception 'Tu devais entrer en salle d''attente avant le lancement.';
  end if;

  select id
  into existing_participation_id
  from public.participations
  where contest_id = p_contest_id
    and user_id = current_user_id
  limit 1;

  if existing_participation_id is not null then
    raise exception 'Tu as deja lance ce Quiz Live.';
  end if;

  insert into public.participations (
    user_id,
    contest_id,
    score,
    answers,
    completed,
    is_live_session
  )
  values (
    current_user_id,
    p_contest_id,
    0,
    jsonb_build_object(
      'type',
      'quiz_live',
      'status',
      'started',
      'started_at',
      now(),
      'live_starts_at',
      contest_record.live_starts_at
    ),
    false,
    true
  )
  returning id
  into participation_id;

  update public.users
  set
    participations_today = coalesce(participations_today, 0) + 1,
    last_participation_date = now()::date
  where id = current_user_id;

  return jsonb_build_object(
    'participation_id',
    participation_id,
    'server_now',
    now(),
    'live_starts_at',
    contest_record.live_starts_at,
    'duration_seconds',
    duration_seconds
  );
end;
$$;

grant execute on function public.live_quiz_duration_seconds(
  uuid,
  timestamptz,
  timestamptz
) to authenticated;

grant execute on function public.process_live_quiz_events() to authenticated;
grant execute on function public.start_live_quiz_participation(uuid)
  to authenticated;

notify pgrst, 'reload schema';

