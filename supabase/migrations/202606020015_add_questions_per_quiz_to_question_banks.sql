-- MegaPromo - Nombre de questions tirees par banque JCQ
-- A executer dans Supabase SQL Editor apres 202606020004.
--
-- Objectif:
-- - permettre au SA de definir combien de questions une banque envoie dans
--   un JCQ;
-- - rendre cette valeur lisible et modifiable depuis le SA;
-- - faire respecter cette valeur cote backend lors du tirage aleatoire;
-- - bloquer le demarrage si la banque n'a pas assez de questions actives.

alter table public.question_banks
add column if not exists questions_per_quiz int not null default 3;

update public.question_banks
set questions_per_quiz = 3
where questions_per_quiz is null
   or questions_per_quiz < 1
   or questions_per_quiz > 50;

alter table public.question_banks
drop constraint if exists question_banks_questions_per_quiz_check;

alter table public.question_banks
add constraint question_banks_questions_per_quiz_check
check (questions_per_quiz between 1 and 50);

drop function if exists public.start_quiz_contest(uuid, int, text);

create or replace function public.start_quiz_contest(
  p_contest_id uuid,
  p_question_count int default null,
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
  requested_question_count int := 0;
  eligible_questions_count int := 0;
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

  select greatest(
    coalesce(max(banks.questions_per_quiz), nullif(p_question_count, 0), 3),
    1
  )::int
  into requested_question_count
  from public.question_banks banks
  join public.question_bank_categories bank_categories
    on bank_categories.question_bank_id = banks.id
  where coalesce(banks.is_active, true) = true
    and bank_categories.category_id = contest_record.category_id;

  select count(*)::int
  into eligible_questions_count
  from public.questions questions
  where coalesce(questions.is_active, true) = true
    and exists (
      select 1
      from public.question_banks banks
      join public.question_bank_categories bank_categories
        on bank_categories.question_bank_id = banks.id
      where banks.id = questions.question_bank_id
        and coalesce(banks.is_active, true) = true
        and bank_categories.category_id = contest_record.category_id
        and questions.contest_id is null
        and (
          questions.category_id is null
          or questions.category_id = contest_record.category_id
        )
        and (
          questions.partner_id is null
          or questions.partner_id = contest_record.partner_id
        )
    );

  if eligible_questions_count <= 0 then
    raise exception 'Aucune question disponible pour ce quiz.';
  end if;

  if eligible_questions_count < requested_question_count then
    raise exception
      'Banque de questions incomplete: % question(s) active(s) disponible(s), % requise(s).',
      eligible_questions_count,
      requested_question_count;
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
      'server_random_question_bank',
      'requested_questions_count',
      requested_question_count,
      'device_history_enabled',
      normalized_device_session_id is not null
    ),
    false
  )
  returning id
  into new_participation_id;

  with eligible_questions as (
    select
      questions.id as question_id,
      case
        when questions.partner_id = contest_record.partner_id then 0
        when questions.category_id = contest_record.category_id then 1
        else 3
      end as source_priority
    from public.questions questions
    where coalesce(questions.is_active, true) = true
      and exists (
        select 1
        from public.question_banks banks
        join public.question_bank_categories bank_categories
          on bank_categories.question_bank_id = banks.id
        where banks.id = questions.question_bank_id
          and coalesce(banks.is_active, true) = true
          and bank_categories.category_id = contest_record.category_id
          and questions.contest_id is null
          and (
            questions.category_id is null
            or questions.category_id = contest_record.category_id
          )
          and (
            questions.partner_id is null
            or questions.partner_id = contest_record.partner_id
          )
      )
  ),
  candidate_questions as (
    select
      eligible_questions.question_id,
      eligible_questions.source_priority,
      exists (
        select 1
        from public.quiz_participation_questions previous_assignment
        join public.questions previous_question
          on previous_question.id = previous_assignment.question_id
        join public.questions candidate_question
          on candidate_question.id = eligible_questions.question_id
        where lower(trim(previous_question.question_text))
          = lower(trim(candidate_question.question_text))
          and (
            previous_assignment.user_id = current_user_id
            or (
              normalized_device_session_id is not null
              and previous_assignment.device_session_id = normalized_device_session_id
            )
          )
      ) as already_seen_by_player_or_device,
      random() as shuffle_rank
    from eligible_questions
  ),
  selected_questions as (
    select
      candidate_questions.question_id,
      row_number() over (
        order by
          candidate_questions.already_seen_by_player_or_device asc,
          candidate_questions.source_priority asc,
          candidate_questions.shuffle_rank asc
      )::int as order_index
    from candidate_questions
    order by
      candidate_questions.already_seen_by_player_or_device asc,
      candidate_questions.source_priority asc,
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
    'requested_questions_count',
    requested_question_count,
    'question_source',
    'question_banks_by_category',
    'device_history_enabled',
    normalized_device_session_id is not null
  );
end;
$$;

grant execute on function public.start_quiz_contest(uuid, int, text)
  to authenticated;

notify pgrst, 'reload schema';
