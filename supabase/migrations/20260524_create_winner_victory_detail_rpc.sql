-- MegaPromo - Detail victoire mobile
-- A executer dans Supabase SQL Editor.
-- Retourne le gain, la performance du joueur et le top 3 du concours/QL.

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

create or replace function public.participation_answer_count(
  p_answers jsonb,
  p_fallback integer default 0
)
returns integer
language sql
immutable
as $$
  select coalesce(
    case
      when jsonb_array_length(public.participation_answer_items(p_answers)) > 0
        then jsonb_array_length(public.participation_answer_items(p_answers))
      else null
    end,
    case
      when coalesce(p_answers ->> 'total_questions', '') ~ '^[0-9]+$'
        then (p_answers ->> 'total_questions')::int
      else null
    end,
    (
      select nullif(count(*)::int, 0)
      from jsonb_object_keys(
        case
          when jsonb_typeof(p_answers) = 'object' then p_answers
          else '{}'::jsonb
        end
      ) as answer_keys(answer_key)
      where answer_key not in (
        'type',
        'status',
        'started_at',
        'completed_at',
        'duration_ms',
        'correct_count',
        'total_questions',
        'items',
        'live_starts_at'
      )
    ),
    p_fallback,
    0
  );
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

create or replace function public.get_winner_victory_detail(
  p_winner_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  winner_record public.winners%rowtype;
  contest_record public.contests%rowtype;
  payload jsonb;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  select *
  into winner_record
  from public.winners
  where id = p_winner_id
    and user_id = current_user_id
  limit 1;

  if winner_record.id is null then
    raise exception 'Gain introuvable.';
  end if;

  select *
  into contest_record
  from public.contests
  where id = winner_record.contest_id
  limit 1;

  if contest_record.id is null then
    raise exception 'Concours introuvable.';
  end if;

  with contest_question_stats as (
    select
      count(questions.id)::int as question_count,
      coalesce(
        sum(greatest(coalesce(questions.time_limit, 0), 0)),
        0
      )::int as duration_seconds
    from public.questions
    where questions.contest_id = winner_record.contest_id
  ),
  raw_participation_candidates as (
    select
      participations.id,
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
      public.participation_correct_count(participations.answers)
        as correct_answers,
      public.participation_answer_count(
        participations.answers,
        contest_question_stats.question_count
      ) as total_answers,
      participations.answers,
      participations.participated_at
    from public.participations
    cross join contest_question_stats
    where participations.contest_id = winner_record.contest_id
      and participations.user_id is not null
      and coalesce(participations.completed, true) = true
  ),
  participation_candidates as (
    select *
    from raw_participation_candidates
    where score > 0
  ),
  best_participation_by_user as (
    select distinct on (participation_candidates.user_id)
      participation_candidates.*
    from participation_candidates
    order by
      participation_candidates.user_id,
      participation_candidates.score desc,
      participation_candidates.duration_ms asc,
      participation_candidates.participated_at asc nulls last
  ),
  ranked_participations as (
    select
      best_participation_by_user.*,
      row_number() over (
        order by
          best_participation_by_user.score desc,
          best_participation_by_user.duration_ms asc,
          best_participation_by_user.participated_at asc nulls last,
          best_participation_by_user.user_id asc
      )::int as rank
    from best_participation_by_user
  ),
  top_three as (
    select
      ranked_participations.rank,
      ranked_participations.user_id,
      ranked_participations.score,
      ranked_participations.duration_ms,
      ranked_participations.participated_at,
      users.username,
      users.avatar_url
    from ranked_participations
    left join public.users on users.id = ranked_participations.user_id
    where ranked_participations.rank <= 3
      or ranked_participations.user_id = winner_record.user_id
    order by ranked_participations.rank asc
  ),
  current_participation as (
    select *
    from ranked_participations
    where user_id = winner_record.user_id
    limit 1
  )
  select jsonb_build_object(
    'winner',
    jsonb_build_object(
      'id', winner_record.id,
      'status', winner_record.status,
      'prize_description', winner_record.prize_description,
      'prize_value', winner_record.prize_value,
      'payment_method', winner_record.payment_method,
      'payment_number', winner_record.payment_number,
      'sent_at', winner_record.sent_at,
      'created_at', winner_record.created_at
    ),
    'contest',
    jsonb_build_object(
      'id', contest_record.id,
      'title', contest_record.title,
      'image_url', contest_record.image_url,
      'is_live', coalesce(contest_record.is_live, false),
      'type', contest_record.type
    ),
    'performance',
    (
      select jsonb_build_object(
        'rank', current_participation.rank,
        'score', current_participation.score,
        'duration_ms', current_participation.duration_ms,
        'participated_at', current_participation.participated_at,
        'correct_answers', coalesce(current_participation.correct_answers, 0),
        'total_answers', coalesce(current_participation.total_answers, 0)
      )
      from current_participation
    ),
    'top_three',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'rank', top_three.rank,
            'user_id', top_three.user_id,
            'username', coalesce(top_three.username, 'Joueur'),
            'avatar_url', top_three.avatar_url,
            'score', top_three.score,
            'duration_ms', top_three.duration_ms,
            'participated_at', top_three.participated_at,
            'is_current_user', top_three.user_id = winner_record.user_id
          )
          order by top_three.rank asc
        )
        from top_three
      ),
      '[]'::jsonb
    )
  )
  into payload;

  return payload;
end;
$$;

grant execute on function public.get_winner_victory_detail(uuid) to authenticated;

notify pgrst, 'reload schema';
