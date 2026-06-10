-- MegaPromo - Resultat detaille participation + notification gagnant robuste
-- A executer dans Supabase SQL Editor apres les migrations participations,
-- questions, winners et notifications.
--
-- Objectif:
-- - notifier automatiquement le gagnant au moment de sa declaration;
-- - eviter les notifications gagnant en double;
-- - permettre a tout participant de consulter son resultat, ses reponses
--   et le classement top 10 du JCQ/QL.

grant select, insert, update on public.notifications to authenticated;

create or replace function public.notify_winner_created()
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

  select coalesce(nullif(contests.title, ''), contest_title)
  into contest_title
  from public.contests
  where contests.id = new.contest_id
  limit 1;

  prize_label := coalesce(nullif(new.prize_description, ''), prize_label);

  if exists (
    select 1
    from public.notifications
    where notifications.user_id = new.user_id
      and notifications.type = 'winner'
      and notifications.data ->> 'winner_id' = new.id::text
  ) then
    return new;
  end if;

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
    'Felicitations, tu as gagne',
    'Tu es gagnant de "' || contest_title || '". Ton gain: ' || prize_label || '.',
    'winner',
    false,
    jsonb_build_object(
      'source', 'winner_created',
      'winner_id', new.id,
      'contest_id', new.contest_id,
      'status', coalesce(new.status, 'pending')
    ),
    now()
  );

  return new;
end;
$$;

drop trigger if exists winners_notify_player_on_created on public.winners;
create trigger winners_notify_player_on_created
after insert on public.winners
for each row
execute function public.notify_winner_created();

create or replace function public.get_participation_result_detail(
  p_participation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  participation_record public.participations%rowtype;
  contest_record public.contests%rowtype;
  payload jsonb;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  select *
  into participation_record
  from public.participations
  where id = p_participation_id
    and user_id = current_user_id
  limit 1;

  if participation_record.id is null then
    raise exception 'Participation introuvable.';
  end if;

  select *
  into contest_record
  from public.contests
  where id = participation_record.contest_id
  limit 1;

  if contest_record.id is null then
    raise exception 'Concours introuvable.';
  end if;

  with contest_question_stats as (
    select
      coalesce(
        nullif(public.participation_answer_count(participation_record.answers), 0),
        count(questions.id)::int,
        0
      ) as question_count,
      coalesce(
        sum(greatest(coalesce(questions.time_limit, 0), 0)),
        0
      )::int as duration_seconds
    from public.questions
    where questions.contest_id = participation_record.contest_id
      or questions.id in (
        select
          case
            when coalesce(answer_item ->> 'question_id', '') ~
              '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
              then (answer_item ->> 'question_id')::uuid
            else null
          end
        from jsonb_array_elements(
          public.participation_answer_items(participation_record.answers)
        ) answer_item
      )
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
      participations.participated_at
    from public.participations
    cross join contest_question_stats
    where participations.contest_id = participation_record.contest_id
      and participations.user_id is not null
      and coalesce(participations.completed, true) = true
  ),
  best_participation_by_user as (
    select distinct on (raw_participation_candidates.user_id)
      raw_participation_candidates.*
    from raw_participation_candidates
    order by
      raw_participation_candidates.user_id,
      raw_participation_candidates.score desc,
      raw_participation_candidates.duration_ms asc,
      raw_participation_candidates.participated_at asc nulls last
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
  leaderboard_rows as (
    select
      ranked_participations.rank,
      ranked_participations.user_id,
      ranked_participations.score,
      ranked_participations.duration_ms,
      ranked_participations.correct_answers,
      ranked_participations.total_answers,
      ranked_participations.participated_at,
      users.username,
      users.avatar_url
    from ranked_participations
    left join public.users on users.id = ranked_participations.user_id
    where ranked_participations.rank <= 10
      or ranked_participations.id = participation_record.id
    order by ranked_participations.rank asc
  ),
  current_participation as (
    select *
    from ranked_participations
    where id = participation_record.id
    limit 1
  ),
  answer_items as (
    select
      answer_item,
      ordinality::int as order_index,
      case
        when coalesce(answer_item ->> 'question_id', '') ~
          '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
          then (answer_item ->> 'question_id')::uuid
        else null
      end as question_id
    from jsonb_array_elements(
      public.participation_answer_items(participation_record.answers)
    ) with ordinality as answer_rows(answer_item, ordinality)
  ),
  answer_details as (
    select
      answer_items.order_index,
      answer_items.answer_item,
      questions.id as question_id,
      questions.question_text,
      questions.question_image_url,
      questions.option_a,
      questions.option_a_image_url,
      questions.option_b,
      questions.option_b_image_url,
      questions.option_c,
      questions.option_c_image_url,
      questions.option_d,
      questions.option_d_image_url,
      questions.correct_answer,
      coalesce(questions.points, 0)::int as question_points
    from answer_items
    left join public.questions on questions.id = answer_items.question_id
    order by answer_items.order_index asc
  )
  select jsonb_build_object(
    'participation',
    jsonb_build_object(
      'id', participation_record.id,
      'contest_id', participation_record.contest_id,
      'score', coalesce(
        (select current_participation.score from current_participation),
        participation_record.score,
        0
      ),
      'duration_ms', coalesce(
        (select current_participation.duration_ms from current_participation),
        public.participation_duration_ms(participation_record.answers)
      ),
      'correct_answers', coalesce(
        (select current_participation.correct_answers from current_participation),
        public.participation_correct_count(participation_record.answers)
      ),
      'total_answers', coalesce(
        (select current_participation.total_answers from current_participation),
        public.participation_answer_count(participation_record.answers)
      ),
      'rank', coalesce(
        (select current_participation.rank from current_participation),
        0
      ),
      'participants_count',
        (select count(*)::int from ranked_participations),
      'participated_at', participation_record.participated_at,
      'completed', coalesce(participation_record.completed, true)
    ),
    'contest',
    jsonb_build_object(
      'id', contest_record.id,
      'title', contest_record.title,
      'image_url', contest_record.image_url,
      'is_live', coalesce(contest_record.is_live, false),
      'type', contest_record.type,
      'category', contest_record.category,
      'ends_at', contest_record.ends_at
    ),
    'leaderboard',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'rank', leaderboard_rows.rank,
            'user_id', leaderboard_rows.user_id,
            'username', coalesce(leaderboard_rows.username, 'Joueur'),
            'avatar_url', leaderboard_rows.avatar_url,
            'score', leaderboard_rows.score,
            'duration_ms', leaderboard_rows.duration_ms,
            'correct_answers', leaderboard_rows.correct_answers,
            'total_answers', leaderboard_rows.total_answers,
            'participated_at', leaderboard_rows.participated_at,
            'is_current_user', leaderboard_rows.user_id = current_user_id
          )
          order by leaderboard_rows.rank asc
        )
        from leaderboard_rows
      ),
      '[]'::jsonb
    ),
    'answers',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'order_index', answer_details.order_index,
            'question_id', answer_details.question_id,
            'question_text', coalesce(answer_details.question_text, ''),
            'question_image_url', answer_details.question_image_url,
            'options', jsonb_build_array(
              jsonb_build_object(
                'label', 'A',
                'text', coalesce(answer_details.option_a, ''),
                'image_url', answer_details.option_a_image_url
              ),
              jsonb_build_object(
                'label', 'B',
                'text', coalesce(answer_details.option_b, ''),
                'image_url', answer_details.option_b_image_url
              ),
              jsonb_build_object(
                'label', 'C',
                'text', coalesce(answer_details.option_c, ''),
                'image_url', answer_details.option_c_image_url
              ),
              jsonb_build_object(
                'label', 'D',
                'text', coalesce(answer_details.option_d, ''),
                'image_url', answer_details.option_d_image_url
              )
            ),
            'selected_index',
              case
                when coalesce(answer_details.answer_item ->> 'selected_index', '') ~ '^-?[0-9]+$'
                  then (answer_details.answer_item ->> 'selected_index')::int
                else null
              end,
            'correct_index',
              case
                when coalesce(answer_details.answer_item ->> 'correct_index', '') ~ '^-?[0-9]+$'
                  then (answer_details.answer_item ->> 'correct_index')::int
                when coalesce(answer_details.correct_answer, 'A') = 'B' then 1
                when coalesce(answer_details.correct_answer, 'A') = 'C' then 2
                when coalesce(answer_details.correct_answer, 'A') = 'D' then 3
                else 0
              end,
            'is_correct',
              lower(coalesce(answer_details.answer_item ->> 'is_correct', 'false'))
                in ('true', 't', '1', 'yes'),
            'points',
              case
                when coalesce(answer_details.answer_item ->> 'points', '') ~ '^-?[0-9]+$'
                  then (answer_details.answer_item ->> 'points')::int
                else 0
              end,
            'elapsed_ms',
              case
                when coalesce(answer_details.answer_item ->> 'elapsed_ms', '') ~ '^[0-9]+$'
                  then (answer_details.answer_item ->> 'elapsed_ms')::int
                else 0
              end,
            'question_points', answer_details.question_points
          )
          order by answer_details.order_index asc
        )
        from answer_details
      ),
      '[]'::jsonb
    )
  )
  into payload;

  return payload;
end;
$$;

grant execute on function public.get_participation_result_detail(uuid)
to authenticated;

notify pgrst, 'reload schema';
