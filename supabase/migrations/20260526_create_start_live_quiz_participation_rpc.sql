-- MegaPromo - Demarrage serveur des Quiz Live
-- A executer dans Supabase SQL Editor.
-- Verrouille le demarrage sur l'heure serveur et interdit de rejouer un QL.

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

  if contest_record.live_starts_at is null then
    raise exception 'La date de debut du Quiz Live est introuvable.';
  end if;

  select
    coalesce(
      nullif(sum(greatest(coalesce(questions.time_limit, 0), 0)), 0),
      greatest(
        extract(
          epoch from (
            coalesce(contest_record.ends_at, now())
            - coalesce(contest_record.live_starts_at, contest_record.starts_at, now())
          )
        )::int,
        0
      )
    )::int
  into duration_seconds
  from public.questions
  where questions.contest_id = p_contest_id;

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
      live_status = 'ended'
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

grant execute on function public.start_live_quiz_participation(uuid)
to authenticated;

notify pgrst, 'reload schema';
