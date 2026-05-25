-- MegaPromo - Synchronisation des Quiz Live sur le temps des questions
-- A executer dans Supabase SQL Editor.
-- Cloture les QL quand now() depasse live_starts_at + somme(time_limit).

drop function if exists public.process_live_quiz_events();

create or replace function public.process_live_quiz_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count integer := 0;
begin
  with live_question_durations as (
    select
      contests.id,
      coalesce(
        nullif(sum(greatest(coalesce(questions.time_limit, 0), 0)), 0),
        greatest(
          extract(
            epoch from (
              coalesce(contests.ends_at, now())
              - coalesce(contests.live_starts_at, contests.starts_at, now())
            )
          )::int,
          0
        )
      ) as duration_seconds
    from public.contests
    left join public.questions on questions.contest_id = contests.id
    where coalesce(contests.is_live, false) = true
      and contests.live_starts_at is not null
      and coalesce(contests.status, 'active') not in (
        'inactive',
        'ended',
        'completed',
        'finished'
      )
      and coalesce(contests.live_status, 'scheduled') not in (
        'ended',
        'completed',
        'finished'
      )
    group by contests.id, contests.live_starts_at, contests.starts_at, contests.ends_at
  ),
  ended_live_quizzes as (
    update public.contests
    set
      status = 'ended',
      live_status = 'ended'
    from live_question_durations
    where contests.id = live_question_durations.id
      and (
        contests.live_starts_at
        + make_interval(secs => live_question_durations.duration_seconds::double precision)
      ) <= now()
    returning contests.id
  )
  select count(*)::int
  into updated_count
  from ended_live_quizzes;

  with live_question_durations as (
    select
      contests.id,
      coalesce(
        nullif(sum(greatest(coalesce(questions.time_limit, 0), 0)), 0),
        greatest(
          extract(
            epoch from (
              coalesce(contests.ends_at, now())
              - coalesce(contests.live_starts_at, contests.starts_at, now())
            )
          )::int,
          0
        )
      ) as duration_seconds
    from public.contests
    left join public.questions on questions.contest_id = contests.id
    where coalesce(contests.is_live, false) = true
      and contests.live_starts_at is not null
      and coalesce(contests.status, 'active') = 'active'
      and coalesce(contests.live_status, 'scheduled') in ('scheduled', 'waiting')
    group by contests.id, contests.live_starts_at, contests.starts_at, contests.ends_at
  )
  update public.contests
  set live_status = 'playing'
  from live_question_durations
  where contests.id = live_question_durations.id
    and contests.live_starts_at <= now()
    and (
      contests.live_starts_at
      + make_interval(secs => live_question_durations.duration_seconds::double precision)
    ) > now();

  return updated_count;
end;
$$;

grant execute on function public.process_live_quiz_events() to authenticated;

select public.process_live_quiz_events() as ended_live_quizzes;
