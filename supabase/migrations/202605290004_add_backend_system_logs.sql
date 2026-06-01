-- MegaPromo - Observabilite backend, phase 5
-- Ajoute des logs metier dans les traitements automatiques SQL.

create or replace function public.process_live_quiz_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count integer := 0;
  playing_count integer := 0;
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
  ),
  playing_live_quizzes as (
    update public.contests
    set live_status = 'playing'
    from live_question_durations
    where contests.id = live_question_durations.id
      and contests.live_starts_at <= now()
      and (
        contests.live_starts_at
        + make_interval(secs => live_question_durations.duration_seconds::double precision)
      ) > now()
    returning contests.id
  )
  select count(*)::int
  into playing_count
  from playing_live_quizzes;

  if updated_count > 0 then
    perform public.log_system_event(
      'info',
      'database',
      'live_quiz',
      'auto_end',
      'Quiz Live expires automatiquement.',
      null,
      null,
      null,
      'live_quiz_batch',
      null,
      jsonb_build_object('ended_count', updated_count),
      null,
      'postgres/process_live_quiz_events'
    );
  end if;

  if playing_count > 0 then
    perform public.log_system_event(
      'info',
      'database',
      'live_quiz',
      'auto_start',
      'Quiz Live passes automatiquement en cours.',
      null,
      null,
      null,
      'live_quiz_batch',
      null,
      jsonb_build_object('playing_count', playing_count),
      null,
      'postgres/process_live_quiz_events'
    );
  end if;

  return updated_count;
exception
  when others then
    perform public.log_system_event(
      'error',
      'database',
      'live_quiz',
      'process_events_failed',
      'Echec traitement automatique des Quiz Live.',
      null,
      null,
      null,
      null,
      null,
      jsonb_build_object('error', sqlerrm, 'sqlstate', sqlstate),
      null,
      'postgres/process_live_quiz_events'
    );
    raise;
end;
$$;

create or replace function public.generate_pending_winners_for_finished_contests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_row record;
  created_count integer := 0;
  contest_created_count integer := 0;
begin
  for contest_row in
    select id, title, type, is_live
    from public.contests
    where coalesce(ends_at, now() + interval '1 day') <= now()
      or coalesce(status, 'active') in ('inactive', 'ended', 'completed', 'finished')
      or coalesce(live_status, 'scheduled') in ('ended', 'completed', 'finished')
  loop
    perform public.reconcile_winner_limit_for_contest(contest_row.id);
    contest_created_count := public.generate_pending_winners_for_contest(contest_row.id);
    created_count := created_count + contest_created_count;
    perform public.reconcile_winner_limit_for_contest(contest_row.id);

    if contest_created_count > 0 then
      perform public.log_system_event(
        'info',
        'database',
        'winners',
        'auto_generate_for_contest',
        'Gagnants generes automatiquement pour un concours termine.',
        null,
        null,
        null,
        'contest',
        contest_row.id::text,
        jsonb_build_object(
          'contest_title', contest_row.title,
          'contest_type', contest_row.type,
          'is_live', coalesce(contest_row.is_live, false),
          'created_count', contest_created_count
        ),
        null,
        'postgres/generate_pending_winners_for_finished_contests'
      );
    end if;
  end loop;

  if created_count > 0 then
    perform public.log_system_event(
      'info',
      'database',
      'winners',
      'auto_generate_batch',
      'Generation automatique des gagnants terminee.',
      null,
      null,
      null,
      'winner_batch',
      null,
      jsonb_build_object('created_count', created_count),
      null,
      'postgres/generate_pending_winners_for_finished_contests'
    );
  end if;

  return created_count;
exception
  when others then
    perform public.log_system_event(
      'error',
      'database',
      'winners',
      'auto_generate_batch_failed',
      'Echec generation automatique des gagnants.',
      null,
      null,
      null,
      null,
      null,
      jsonb_build_object('error', sqlerrm, 'sqlstate', sqlstate),
      null,
      'postgres/generate_pending_winners_for_finished_contests'
    );
    raise;
end;
$$;

create or replace function public.process_contest_events()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  ended_live_count integer := 0;
  created_winners_count integer := 0;
  result jsonb;
begin
  begin
    ended_live_count := coalesce(public.process_live_quiz_events(), 0);
  exception
    when undefined_function then
      ended_live_count := 0;
  end;

  begin
    created_winners_count :=
      coalesce(public.generate_pending_winners_for_finished_contests(), 0);
  exception
    when undefined_function then
      created_winners_count := 0;
  end;

  result := jsonb_build_object(
    'ended_live_quizzes', ended_live_count,
    'created_winners', created_winners_count
  );

  if ended_live_count > 0 or created_winners_count > 0 then
    perform public.log_system_event(
      'info',
      'database',
      'contests',
      'process_events',
      'Traitement automatique des concours execute.',
      null,
      null,
      null,
      'contest_event_batch',
      null,
      result,
      null,
      'postgres/process_contest_events'
    );
  end if;

  return result;
exception
  when others then
    perform public.log_system_event(
      'error',
      'database',
      'contests',
      'process_events_failed',
      'Echec traitement automatique des concours.',
      null,
      null,
      null,
      null,
      null,
      jsonb_build_object('error', sqlerrm, 'sqlstate', sqlstate),
      null,
      'postgres/process_contest_events'
    );
    raise;
end;
$$;

grant execute on function public.process_live_quiz_events() to authenticated;
grant execute on function public.generate_pending_winners_for_finished_contests()
to authenticated;
grant execute on function public.process_contest_events() to authenticated;

notify pgrst, 'reload schema';
