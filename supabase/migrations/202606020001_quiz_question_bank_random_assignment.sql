-- MegaPromo - Banque de questions JCQ + tirage aleatoire serveur
-- A executer dans Supabase SQL Editor.
--
-- Objectif:
-- - au demarrage d'un JCQ, le serveur cree la participation;
-- - le serveur tire aleatoirement les questions depuis la banque du concours;
-- - les questions assignees sont figees par participation;
-- - le mobile ne choisit plus lui-meme les questions d'un JCQ.

create table if not exists public.quiz_participation_questions (
  id uuid primary key default gen_random_uuid(),
  participation_id uuid not null references public.participations(id) on delete cascade,
  contest_id uuid not null references public.contests(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  order_index int not null,
  created_at timestamptz not null default now(),
  unique (participation_id, question_id),
  unique (participation_id, order_index)
);

create index if not exists quiz_participation_questions_participation_idx
  on public.quiz_participation_questions(participation_id, order_index);

create index if not exists quiz_participation_questions_user_contest_idx
  on public.quiz_participation_questions(user_id, contest_id);

alter table public.quiz_participation_questions enable row level security;

drop policy if exists quiz_participation_questions_select_own
  on public.quiz_participation_questions;

create policy quiz_participation_questions_select_own
on public.quiz_participation_questions
for select
to authenticated
using (user_id = auth.uid());

grant select on public.quiz_participation_questions to authenticated;

create or replace function public.start_quiz_contest(
  p_contest_id uuid,
  p_question_count int default 5
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
      'server_random'
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
        where previous_assignment.user_id = current_user_id
          and lower(trim(previous_question.question_text))
            = lower(trim(questions.question_text))
      ) as already_seen
    from public.questions
    where questions.contest_id = p_contest_id
  ),
  selected_questions as (
    select
      candidate_questions.question_id,
      row_number() over (
        order by candidate_questions.already_seen asc, random()
    )::int as order_index
    from candidate_questions
    order by candidate_questions.already_seen asc, random()
    limit requested_question_count
  ),
  inserted_questions as (
    insert into public.quiz_participation_questions (
      participation_id,
      contest_id,
      user_id,
      question_id,
      order_index
    )
    select
      new_participation_id,
      p_contest_id,
      current_user_id,
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
    selected_questions_count
  );
end;
$$;

create or replace function public.get_quiz_participation_questions(
  p_participation_id uuid
)
returns setof public.questions
language sql
security definer
set search_path = public
as $$
  select questions.*
  from public.quiz_participation_questions assigned
  join public.questions on questions.id = assigned.question_id
  where assigned.participation_id = p_participation_id
    and assigned.user_id = auth.uid()
  order by assigned.order_index asc;
$$;

grant execute on function public.start_quiz_contest(uuid, int)
  to authenticated;

grant execute on function public.get_quiz_participation_questions(uuid)
  to authenticated;

notify pgrst, 'reload schema';
