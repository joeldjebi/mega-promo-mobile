-- MegaPromo - Banques de questions par famille/categorie
-- A executer dans Supabase SQL Editor apres 202606020001, 202606020002
-- et 202606020003.
--
-- Objectif:
-- - creer une vraie table question_banks;
-- - lier une banque a une ou plusieurs categories de concours;
-- - permettre aux questions d'appartenir a une banque sans etre liees a un
--   concours precis;
-- - tirer les questions JCQ depuis les questions de banque liees a la
--   categorie du JCQ;
--   tout en gardant l'historique joueur/device.

create table if not exists public.question_banks (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  is_active bool not null default true,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.question_bank_categories (
  question_bank_id uuid not null references public.question_banks(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (question_bank_id, category_id)
);

alter table public.questions
alter column contest_id drop not null;

alter table public.questions
add column if not exists question_bank_id uuid references public.question_banks(id) on delete set null,
add column if not exists category_id uuid references public.categories(id) on delete set null,
add column if not exists partner_id uuid references public.partners(id) on delete set null,
add column if not exists question_scope text not null default 'contest',
add column if not exists difficulty text,
add column if not exists is_active bool not null default true;

create index if not exists questions_question_bank_idx
  on public.questions(question_bank_id)
  where question_bank_id is not null;

create index if not exists questions_category_idx
  on public.questions(category_id)
  where category_id is not null;

create index if not exists questions_partner_idx
  on public.questions(partner_id)
  where partner_id is not null;

create index if not exists question_bank_categories_category_idx
  on public.question_bank_categories(category_id);

grant select on public.question_banks to authenticated, anon;
grant insert, update, delete on public.question_banks to authenticated;
grant select on public.question_bank_categories to authenticated, anon;
grant insert, update, delete on public.question_bank_categories to authenticated;

drop function if exists public.start_quiz_contest(uuid, int, text);

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
      )
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
      'server_random_question_bank',
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
