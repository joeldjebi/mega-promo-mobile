-- MegaPromo - Historique JCQ joueur + device
-- A executer dans Supabase SQL Editor apres la migration 202606020001.
--
-- Objectif:
-- - eviter de reproposer une question deja vue par le meme joueur;
-- - eviter de reproposer une question deja vue sur le meme device, meme avec
--   un autre compte;
-- - garder un fallback: si la banque ne contient plus assez de nouvelles
--   questions, les anciennes questions restent possibles mais passent en
--   dernier.

alter table public.quiz_participation_questions
add column if not exists device_session_id text;

create index if not exists quiz_participation_questions_device_idx
  on public.quiz_participation_questions(device_session_id)
  where device_session_id is not null;

drop function if exists public.start_quiz_contest(uuid, int);

create or replace function public.start_quiz_contest(
  p_contest_id uuid,
  p_question_count int default 5,
  p_device_session_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  contest_record public.contests%rowtype;
  new_participation_id uuid;
  selected_questions_count int := 0;
  requested_question_count int := greatest(coalesce(p_question_count, 5), 1);
  normalized_device_session_id text := nullif(trim(coalesce(p_device_session_id, '')), '');
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  perform pg_advisory_xact_lock(
    hashtext(current_user_id::text),
    hashtext(p_contest_id::text)
  );

  select *
  into contest_record
  from public.contests
  where id = p_contest_id
  limit 1;

  if contest_record.id is null then
    raise exception 'Concours introuvable.';
  end if;

  if coalesce(contest_record.is_live, false) = true then
    raise exception 'Ce quiz doit etre demarre depuis le flux Quiz Live.';
  end if;

  if lower(coalesce(contest_record.type, '')) <> 'quiz' then
    raise exception 'Ce concours n''est pas un quiz.';
  end if;

  if lower(coalesce(contest_record.status, 'active')) <> 'active'
    or coalesce(contest_record.ends_at, now() - interval '1 second') <= now()
  then
    raise exception 'Ce quiz est termine.';
  end if;

  if exists (
    select 1
    from public.participations
    where contest_id = p_contest_id
      and user_id = current_user_id
  ) then
    raise exception 'Participation deja enregistree pour ce quiz.';
  end if;

  if not exists (
    select 1
    from public.questions
    where contest_id = p_contest_id
  ) then
    raise exception 'Aucune question disponible pour ce quiz.';
  end if;

  insert into public.participations (
    user_id,
    contest_id,
    score,
    answers,
    completed
  )
  values (
    current_user_id,
    p_contest_id,
    0,
    jsonb_build_object(
      'type',
      'quiz',
      'status',
      'started',
      'started_at',
      now(),
      'selection_mode',
      'server_random',
      'device_history_enabled',
      normalized_device_session_id is not null
    ),
    false
  )
  returning id
  into new_participation_id;

  with candidate_questions as (
    select
      questions.id as question_id,
      exists (
        select 1
        from public.quiz_participation_questions previous_assignment
        join public.questions previous_question
          on previous_question.id = previous_assignment.question_id
        where lower(trim(previous_question.question_text))
          = lower(trim(questions.question_text))
          and (
            previous_assignment.user_id = current_user_id
            or (
              normalized_device_session_id is not null
              and previous_assignment.device_session_id = normalized_device_session_id
            )
          )
      ) as already_seen_by_player_or_device,
      random() as shuffle_rank
    from public.questions
    where questions.contest_id = p_contest_id
  ),
  selected_questions as (
    select
      candidate_questions.question_id,
      row_number() over (
        order by
          candidate_questions.already_seen_by_player_or_device asc,
          candidate_questions.shuffle_rank asc
      )::int as order_index
    from candidate_questions
    order by
      candidate_questions.already_seen_by_player_or_device asc,
      candidate_questions.shuffle_rank asc
    limit requested_question_count
  ),
  inserted_questions as (
    insert into public.quiz_participation_questions (
      participation_id,
      contest_id,
      user_id,
      device_session_id,
      question_id,
      order_index
    )
    select
      new_participation_id,
      p_contest_id,
      current_user_id,
      normalized_device_session_id,
      selected_questions.question_id,
      selected_questions.order_index
    from selected_questions
    returning id
  )
  select count(*)::int
  into selected_questions_count
  from inserted_questions;

  if selected_questions_count <= 0 then
    raise exception 'Aucune question tiree pour ce quiz.';
  end if;

  update public.users
  set
    participations_today = coalesce(participations_today, 0) + 1,
    last_participation_date = now()::date
  where id = current_user_id;

  return jsonb_build_object(
    'participation_id',
    new_participation_id,
    'questions_count',
    selected_questions_count,
    'device_history_enabled',
    normalized_device_session_id is not null
  );
end;
$$;

grant execute on function public.start_quiz_contest(uuid, int, text)
  to authenticated;

notify pgrst, 'reload schema';
