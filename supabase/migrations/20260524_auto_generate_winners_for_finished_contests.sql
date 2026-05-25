-- MegaPromo - Auto gagnants concours termines
-- A executer dans Supabase SQL Editor.
-- Cree automatiquement des gagnants pending lorsque le concours est termine.

grant usage on schema public to authenticated;
grant select on public.contests to authenticated;
grant select on public.participations to authenticated;
grant select, insert, update on public.winners to authenticated;
grant select, insert, update on public.notifications to authenticated;

do $$
begin
  begin
    alter publication supabase_realtime add table public.winners;
  exception
    when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.notifications;
  exception
    when duplicate_object then null;
  end;
end;
$$;

create or replace function public.participation_duration_ms(p_answers jsonb)
returns integer
language sql
immutable
as $$
  select coalesce(
    case
      when coalesce(p_answers ->> 'duration_ms', '') ~ '^[0-9]+$'
        then (p_answers ->> 'duration_ms')::int
      else null
    end,
    (
      select nullif(
        sum(
          case
            when coalesce(answer_item ->> 'elapsed_ms', '') ~ '^[0-9]+$'
              then (answer_item ->> 'elapsed_ms')::int
            else 0
          end
        ),
        0
      )::int
      from jsonb_array_elements(
        case
          when jsonb_typeof(p_answers -> 'items') = 'array'
            then p_answers -> 'items'
          when jsonb_typeof(p_answers) = 'array'
            then p_answers
          else '[]'::jsonb
        end
      ) answer_item
    ),
    2147483647
  );
$$;

create or replace function public.participation_answer_items(p_answers jsonb)
returns jsonb
language sql
immutable
as $$
  select case
    when jsonb_typeof(p_answers -> 'items') = 'array'
      then p_answers -> 'items'
    when jsonb_typeof(p_answers) = 'array'
      then p_answers
    else '[]'::jsonb
  end;
$$;

create or replace function public.participation_correct_count(p_answers jsonb)
returns integer
language sql
immutable
as $$
  select coalesce(
    case
      when coalesce(p_answers ->> 'correct_count', '') ~ '^[0-9]+$'
        then (p_answers ->> 'correct_count')::int
      else null
    end,
    (
      select count(*)::int
      from jsonb_array_elements(public.participation_answer_items(p_answers))
        answer_item
      where lower(coalesce(answer_item ->> 'is_correct', 'false')) in (
        'true',
        't',
        '1',
        'yes'
      )
        or (
          coalesce(answer_item ->> 'selected_index', '') ~ '^-?[0-9]+$'
          and coalesce(answer_item ->> 'correct_index', '') ~ '^-?[0-9]+$'
          and (answer_item ->> 'selected_index')::int
            = (answer_item ->> 'correct_index')::int
        )
    ),
    0
  );
$$;

create or replace function public.participation_points_from_answers(
  p_answers jsonb
)
returns integer
language sql
immutable
as $$
  select coalesce(
    (
      select nullif(
        sum(
          case
            when coalesce(answer_item ->> 'points', '') ~ '^-?[0-9]+$'
              then (answer_item ->> 'points')::int
            else 0
          end
        ),
        0
      )::int
      from jsonb_array_elements(public.participation_answer_items(p_answers))
        answer_item
    ),
    nullif(public.participation_correct_count(p_answers), 0),
    0
  );
$$;

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
      coalesce(
        nullif(public.participation_duration_ms(participations.answers), 2147483647),
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
    where score > 0
  ),
  best_candidate_by_user as (
    select distinct on (participation_candidates.user_id)
      participation_candidates.user_id,
      participation_candidates.score,
      participation_candidates.duration_ms,
      participation_candidates.participated_at
    from participation_candidates
    order by
      participation_candidates.user_id,
      participation_candidates.score desc,
      participation_candidates.duration_ms asc,
      participation_candidates.participated_at asc nulls last
  ),
  ranked_candidates as (
    select
      best_candidate_by_user.user_id,
      best_candidate_by_user.score,
      best_candidate_by_user.duration_ms,
      best_candidate_by_user.participated_at,
      row_number() over (
        order by
          case
            when lower(coalesce(contest_record.type, '')) in ('tirage', 'raffle', 'draw')
              then random()
            else 0
          end,
          case
            when lower(coalesce(contest_record.type, '')) in ('tirage', 'raffle', 'draw')
              then 0
            else best_candidate_by_user.score
          end desc,
          case
            when lower(coalesce(contest_record.type, '')) in ('tirage', 'raffle', 'draw')
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

create or replace function public.reconcile_winner_limit_for_contest(
  p_contest_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_record public.contests%rowtype;
  winner_limit integer := 1;
  cancelled_count integer := 0;
begin
  select *
  into contest_record
  from public.contests
  where id = p_contest_id
  limit 1;

  if contest_record.id is null then
    return 0;
  end if;

  perform pg_advisory_xact_lock(hashtext(p_contest_id::text));

  winner_limit := greatest(coalesce(contest_record.winners_count, 1), 1);

  with winner_scores as (
    select
      winners.id,
      winners.user_id,
      winners.status,
      winners.created_at,
      best_participation.id as participation_id,
      coalesce(best_participation.score, 0) as score,
      coalesce(best_participation.duration_ms, 2147483647) as duration_ms,
      best_participation.participated_at
    from public.winners
    left join lateral (
      select *
      from (
        select
          participations.id,
          greatest(
            coalesce(participations.score, 0)::int,
            public.participation_points_from_answers(participations.answers)
          ) as score,
          public.participation_duration_ms(participations.answers)
            as duration_ms,
          participations.participated_at
        from public.participations
        where participations.contest_id = winners.contest_id
          and participations.user_id = winners.user_id
          and coalesce(participations.completed, true) = true
      ) scored_participations
      where scored_participations.score > 0
      order by
        scored_participations.score desc,
        scored_participations.duration_ms asc,
        scored_participations.participated_at asc nulls last
      limit 1
    ) best_participation on true
    where winners.contest_id = p_contest_id
      and coalesce(winners.status, 'pending') <> 'cancelled'
  ),
  ranked_winners_by_user as (
    select
      winner_scores.id,
      winner_scores.user_id,
      winner_scores.participation_id,
      row_number() over (
        partition by winner_scores.user_id
        order by
          case
            when lower(coalesce(contest_record.type, '')) in ('tirage', 'raffle', 'draw')
              then winner_scores.created_at
            else null
          end asc nulls last,
          case
            when lower(coalesce(contest_record.type, '')) in ('tirage', 'raffle', 'draw')
              then 0
            else winner_scores.score
          end desc,
          case
            when lower(coalesce(contest_record.type, '')) in ('tirage', 'raffle', 'draw')
              then 0
            else winner_scores.duration_ms
          end asc,
          winner_scores.participated_at asc nulls last,
          winner_scores.created_at asc nulls last,
          winner_scores.user_id asc,
          winner_scores.id asc
      ) as user_rank,
      winner_scores.score,
      winner_scores.duration_ms,
      winner_scores.participated_at,
      winner_scores.created_at
    from winner_scores
  ),
  ranked_unique_winners as (
    select
      ranked_winners_by_user.id,
      row_number() over (
        order by
          case
            when lower(coalesce(contest_record.type, '')) in ('tirage', 'raffle', 'draw')
              then ranked_winners_by_user.created_at
            else null
          end asc nulls last,
          case
            when lower(coalesce(contest_record.type, '')) in ('tirage', 'raffle', 'draw')
              then 0
            else ranked_winners_by_user.score
          end desc,
          case
            when lower(coalesce(contest_record.type, '')) in ('tirage', 'raffle', 'draw')
              then 0
            else ranked_winners_by_user.duration_ms
          end asc,
          ranked_winners_by_user.participated_at asc nulls last,
          ranked_winners_by_user.created_at asc nulls last,
          ranked_winners_by_user.user_id asc,
          ranked_winners_by_user.id asc
      ) as winner_rank
    from ranked_winners_by_user
    where ranked_winners_by_user.user_rank = 1
  ),
  winners_to_cancel as (
    select ranked_winners_by_user.id
    from ranked_winners_by_user
    where ranked_winners_by_user.user_rank > 1
      or ranked_winners_by_user.participation_id is null
      or ranked_winners_by_user.score <= 0

    union

    select ranked_unique_winners.id
    from ranked_unique_winners
    where ranked_unique_winners.winner_rank > winner_limit
  ),
  cancelled_winners as (
    update public.winners
    set
      status = 'cancelled',
      sent_at = null
    where winners.id in (
      select winners_to_cancel.id
      from winners_to_cancel
    )
    returning winners.id
  )
  select count(*)::int
  into cancelled_count
  from cancelled_winners;

  return cancelled_count;
end;
$$;

create or replace function public.generate_pending_winners_when_contest_finishes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.status, 'active') in (
    'inactive',
    'ended',
    'completed',
    'finished'
  )
    or coalesce(new.live_status, 'scheduled') in (
      'ended',
      'completed',
      'finished'
    )
    or coalesce(new.ends_at, now() + interval '1 day') <= now()
  then
    perform public.reconcile_winner_limit_for_contest(new.id);
    perform public.generate_pending_winners_for_contest(new.id);
    perform public.reconcile_winner_limit_for_contest(new.id);
  end if;

  return new;
end;
$$;

drop trigger if exists contests_generate_pending_winners_on_finish on public.contests;
create trigger contests_generate_pending_winners_on_finish
after insert or update of status, live_status, ends_at
on public.contests
for each row
execute function public.generate_pending_winners_when_contest_finishes();

create or replace function public.notify_winner_paid()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_title text := 'un concours MegaPromo';
  prize_label text := 'ton gain MegaPromo';
begin
  if new.user_id is null then
    return new;
  end if;

  if coalesce(new.status, 'pending') not in ('sent', 'paid', 'received', 'recu', 'reçu') then
    return new;
  end if;

  if tg_op = 'UPDATE'
    and coalesce(old.status, 'pending') in ('sent', 'paid', 'received', 'recu', 'reçu')
  then
    return new;
  end if;

  select coalesce(contests.title, contest_title)
  into contest_title
  from public.contests
  where contests.id = new.contest_id
  limit 1;

  prize_label := coalesce(nullif(new.prize_description, ''), prize_label);

  insert into public.notifications (
    id,
    user_id,
    title,
    body,
    type,
    is_read,
    data,
    created_at
  )
  values (
    gen_random_uuid(),
    new.user_id,
    'Gain payé',
    'Ton gain "' || prize_label || '" pour "' || contest_title || '" vient d’être payé.',
    'winner',
    false,
    jsonb_build_object(
      'source', 'winner_paid',
      'winner_id', new.id,
      'contest_id', new.contest_id,
      'status', new.status
    ),
    now()
  );

  return new;
end;
$$;

drop trigger if exists winners_notify_player_on_paid on public.winners;
create trigger winners_notify_player_on_paid
after insert or update of status
on public.winners
for each row
execute function public.notify_winner_paid();

create or replace function public.generate_pending_winners_for_finished_contests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_row record;
  created_count integer := 0;
begin
  for contest_row in
    select id
    from public.contests
    where coalesce(ends_at, now() + interval '1 day') <= now()
      or coalesce(status, 'active') in ('inactive', 'ended', 'completed', 'finished')
      or coalesce(live_status, 'scheduled') in ('ended', 'completed', 'finished')
  loop
    perform public.reconcile_winner_limit_for_contest(contest_row.id);
    created_count := created_count + public.generate_pending_winners_for_contest(contest_row.id);
    perform public.reconcile_winner_limit_for_contest(contest_row.id);
  end loop;

  return created_count;
end;
$$;

grant execute on function public.generate_pending_winners_for_contest(uuid) to authenticated;
grant execute on function public.reconcile_winner_limit_for_contest(uuid) to authenticated;
grant execute on function public.generate_pending_winners_for_finished_contests() to authenticated;

select public.generate_pending_winners_for_finished_contests() as pending_winners_created;

create unique index if not exists winners_one_active_per_user_contest_idx
on public.winners(contest_id, user_id)
where coalesce(status, 'pending') <> 'cancelled';

select
  contests.id,
  contests.title,
  greatest(coalesce(contests.winners_count, 1), 1) as winner_limit,
  count(winners.id)::int as active_winners_count
from public.contests
left join public.winners on winners.contest_id = contests.id
  and coalesce(winners.status, 'pending') <> 'cancelled'
group by contests.id, contests.title, contests.winners_count
having count(winners.id)::int > greatest(coalesce(contests.winners_count, 1), 1);

notify pgrst, 'reload schema';
