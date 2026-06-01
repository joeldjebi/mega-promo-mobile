-- MegaPromo - Classement gagnants QL par bonnes reponses puis vitesse
-- A executer dans Supabase SQL Editor.
-- Regle:
-- 1) plus grand score / plus grand nombre de bonnes reponses
-- 2) temps global le plus court en millisecondes
-- 3) participation la plus ancienne en dernier departage

create or replace function public.generate_pending_winners_for_contest(
  p_contest_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_record public.contests%rowtype;
  inserted_count integer := 0;
  winner_limit integer := 1;
  existing_winners_count integer := 0;
  remaining_winners_count integer := 0;
begin
  select *
  into contest_record
  from public.contests
  where id = p_contest_id
  limit 1;

  if contest_record.id is null then
    return 0;
  end if;

  if coalesce(contest_record.ends_at, now() + interval '1 day') > now()
    and coalesce(contest_record.status, 'active') not in (
      'inactive',
      'ended',
      'completed',
      'finished'
    )
    and coalesce(contest_record.live_status, 'scheduled') not in (
      'ended',
      'completed',
      'finished'
    )
  then
    return 0;
  end if;

  perform pg_advisory_xact_lock(hashtext(p_contest_id::text));

  winner_limit := greatest(coalesce(contest_record.winners_count, 1), 1);

  select count(*)::int
  into existing_winners_count
  from public.winners
  where contest_id = p_contest_id
    and coalesce(status, 'pending') <> 'cancelled';

  remaining_winners_count := greatest(winner_limit - existing_winners_count, 0);

  if remaining_winners_count <= 0 then
    return 0;
  end if;

  with contest_question_stats as (
    select
      coalesce(
        sum(greatest(coalesce(questions.time_limit, 0), 0)),
        0
      )::int as duration_seconds
    from public.questions
    where questions.contest_id = p_contest_id
  ),
  raw_participation_candidates as (
    select
      participations.user_id,
      greatest(
        coalesce(participations.score, 0)::int,
        public.participation_points_from_answers(participations.answers)
      ) as score,
      public.participation_correct_count(participations.answers)
        as correct_answers,
      coalesce(
        nullif(
          public.participation_duration_ms(participations.answers),
          2147483647
        ),
        nullif(contest_question_stats.duration_seconds, 0) * 1000,
        2147483647
      ) as duration_ms,
      participations.participated_at
    from public.participations
    cross join contest_question_stats
    where participations.contest_id = p_contest_id
      and participations.user_id is not null
      and coalesce(participations.completed, true) = true
      and not exists (
        select 1
        from public.winners existing
        where existing.contest_id = p_contest_id
          and existing.user_id = participations.user_id
          and coalesce(existing.status, 'pending') <> 'cancelled'
      )
  ),
  participation_candidates as (
    select *
    from raw_participation_candidates
    where score > 0 or correct_answers > 0
  ),
  best_candidate_by_user as (
    select distinct on (participation_candidates.user_id)
      participation_candidates.user_id,
      participation_candidates.score,
      participation_candidates.correct_answers,
      participation_candidates.duration_ms,
      participation_candidates.participated_at
    from participation_candidates
    order by
      participation_candidates.user_id,
      participation_candidates.score desc,
      participation_candidates.correct_answers desc,
      participation_candidates.duration_ms asc,
      participation_candidates.participated_at asc nulls last
  ),
  ranked_candidates as (
    select
      best_candidate_by_user.user_id,
      best_candidate_by_user.score,
      best_candidate_by_user.correct_answers,
      best_candidate_by_user.duration_ms,
      best_candidate_by_user.participated_at,
      row_number() over (
        order by
          case
            when lower(coalesce(contest_record.type, '')) in (
              'tirage',
              'raffle',
              'draw'
            )
              then random()
            else 0
          end,
          case
            when lower(coalesce(contest_record.type, '')) in (
              'tirage',
              'raffle',
              'draw'
            )
              then 0
            else best_candidate_by_user.score
          end desc,
          case
            when lower(coalesce(contest_record.type, '')) in (
              'tirage',
              'raffle',
              'draw'
            )
              then 0
            else best_candidate_by_user.correct_answers
          end desc,
          case
            when lower(coalesce(contest_record.type, '')) in (
              'tirage',
              'raffle',
              'draw'
            )
              then 0
            else best_candidate_by_user.duration_ms
          end asc,
          best_candidate_by_user.participated_at asc nulls last,
          best_candidate_by_user.user_id asc
      ) as rank
    from best_candidate_by_user
  ),
  inserted_winners as (
    insert into public.winners (
      user_id,
      contest_id,
      prize_description,
      prize_value,
      payment_method,
      payment_number,
      status,
      sent_at,
      created_at
    )
    select
      ranked_candidates.user_id,
      contest_record.id,
      coalesce(contest_record.prize_description, contest_record.title),
      coalesce(contest_record.prize_value, 0),
      null,
      null,
      'pending',
      null,
      now()
    from ranked_candidates
    where ranked_candidates.rank <= remaining_winners_count
    returning id
  )
  select count(*)
  into inserted_count
  from inserted_winners;

  return inserted_count;
end;
$$;

grant execute on function public.generate_pending_winners_for_contest(uuid)
  to authenticated;

