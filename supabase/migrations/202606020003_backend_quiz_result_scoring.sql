-- MegaPromo - Resultat JCQ calcule cote backend
-- A executer dans Supabase SQL Editor apres 202606020001 et 202606020002.
--
-- Objectif:
-- - le mobile envoie seulement les choix du joueur et les temps;
-- - Supabase recalcule les bonnes reponses, les points et la duree;
-- - le classement et les gagnants ne dependent plus d'un score calcule par
--   le client mobile.

create or replace function public.quiz_answer_index_from_letter(
  p_answer text
)
returns int
language sql
immutable
as $$
  select case upper(trim(coalesce(p_answer, '')))
    when 'A' then 0
    when 'B' then 1
    when 'C' then 2
    when 'D' then 3
    else 0
  end;
$$;

create or replace function public.quiz_answer_letter_from_index(
  p_index int
)
returns text
language sql
immutable
as $$
  select case p_index
    when 0 then 'A'
    when 1 then 'B'
    when 2 then 'C'
    when 3 then 'D'
    else null
  end;
$$;

create or replace function public.submit_quiz_result(
  p_participation_id uuid,
  p_answers jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  participation_record public.participations%rowtype;
  computed_score int := 0;
  computed_correct_count int := 0;
  computed_duration_ms int := 0;
  computed_total_questions int := 0;
  computed_items jsonb := '[]'::jsonb;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if p_participation_id is null then
    raise exception 'Participation introuvable.';
  end if;

  select *
  into participation_record
  from public.participations
  where id = p_participation_id
    and user_id = current_user_id
  for update;

  if participation_record.id is null then
    raise exception 'Participation introuvable.';
  end if;

  if coalesce(participation_record.completed, false) = true then
    return jsonb_build_object(
      'participation_id',
      participation_record.id,
      'score',
      coalesce(participation_record.score, 0),
      'correct_count',
      public.participation_correct_count(participation_record.answers),
      'total_questions',
      case
        when coalesce(participation_record.answers ->> 'total_questions', '')
          ~ '^[0-9]+$'
          then (participation_record.answers ->> 'total_questions')::int
        else 0
      end,
      'duration_ms',
      public.participation_duration_ms(participation_record.answers),
      'already_completed',
      true
    );
  end if;

  if coalesce(jsonb_typeof(p_answers), 'null') <> 'array' then
    raise exception 'Format des reponses invalide.';
  end if;

  if not exists (
    select 1
    from public.quiz_participation_questions assigned
    where assigned.participation_id = p_participation_id
      and assigned.user_id = current_user_id
  ) then
    raise exception 'Aucune question assignee a cette participation.';
  end if;

  with raw_answer_rows as (
    select
      answer_item.value as raw_answer,
      answer_item.ordinality::int as answer_order,
      answer_item.value ->> 'question_id' as question_id_text,
      case
        when answer_item.value ? 'selected_index'
          and jsonb_typeof(answer_item.value -> 'selected_index') = 'number'
          then (answer_item.value ->> 'selected_index')::numeric::int
        else null
      end as selected_index,
      greatest(
        least(
          case
            when coalesce(answer_item.value ->> 'elapsed_ms', '') ~ '^[0-9]+$'
              then (answer_item.value ->> 'elapsed_ms')::int
            else 0
          end,
          300000
        ),
        0
      ) as elapsed_ms
    from jsonb_array_elements(p_answers) with ordinality as answer_item(value, ordinality)
    where jsonb_typeof(answer_item.value) = 'object'
  ),
  answer_rows as (
    select distinct on (raw_answer_rows.question_id_text)
      raw_answer_rows.raw_answer,
      raw_answer_rows.answer_order,
      raw_answer_rows.question_id_text,
      raw_answer_rows.selected_index,
      raw_answer_rows.elapsed_ms
    from raw_answer_rows
    where raw_answer_rows.question_id_text is not null
      and raw_answer_rows.question_id_text <> ''
    order by raw_answer_rows.question_id_text, raw_answer_rows.answer_order asc
  ),
  scored_answers as (
    select
      assigned.order_index,
      questions.id as question_id,
      answer_rows.selected_index,
      public.quiz_answer_index_from_letter(questions.correct_answer)
        as correct_index,
      (
        public.quiz_answer_letter_from_index(answer_rows.selected_index)
        = upper(trim(coalesce(questions.correct_answer, 'A')))
      ) as is_correct,
      case
        when public.quiz_answer_letter_from_index(answer_rows.selected_index)
          = upper(trim(coalesce(questions.correct_answer, 'A')))
          then greatest(coalesce(questions.points, 0), 0)
        else 0
      end as points,
      greatest(
        least(
          coalesce(answer_rows.elapsed_ms, 0),
          greatest(coalesce(questions.time_limit, 30), 1) * 1000
        ),
        0
      ) as elapsed_ms
    from public.quiz_participation_questions assigned
    join public.questions on questions.id = assigned.question_id
    left join answer_rows
      on answer_rows.question_id_text = questions.id::text
    where assigned.participation_id = p_participation_id
      and assigned.user_id = current_user_id
  ),
  aggregate_result as (
    select
      coalesce(sum(points), 0)::int as score,
      coalesce(count(*) filter (where is_correct), 0)::int as correct_count,
      coalesce(sum(elapsed_ms), 0)::int as duration_ms,
      count(*)::int as total_questions,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'question_id',
            question_id,
            'selected_index',
            selected_index,
            'correct_index',
            correct_index,
            'is_correct',
            is_correct,
            'points',
            points,
            'elapsed_ms',
            elapsed_ms
          )
          order by order_index asc
        ),
        '[]'::jsonb
      ) as items
    from scored_answers
  )
  select
    score,
    correct_count,
    duration_ms,
    total_questions,
    items
  into
    computed_score,
    computed_correct_count,
    computed_duration_ms,
    computed_total_questions,
    computed_items
  from aggregate_result;

  update public.participations
  set
    score = computed_score,
    answers = jsonb_build_object(
      'type',
      'quiz',
      'status',
      'completed',
      'computed_by',
      'backend',
      'completed_at',
      now(),
      'duration_ms',
      computed_duration_ms,
      'correct_count',
      computed_correct_count,
      'total_questions',
      computed_total_questions,
      'items',
      computed_items
    ),
    completed = true
  where id = p_participation_id
    and user_id = current_user_id;

  update public.users
  set points_total = coalesce(points_total, 0) + computed_score
  where id = current_user_id;

  return jsonb_build_object(
    'participation_id',
    p_participation_id,
    'score',
    computed_score,
    'correct_count',
    computed_correct_count,
    'total_questions',
    computed_total_questions,
    'duration_ms',
    computed_duration_ms,
    'items',
    computed_items,
    'already_completed',
    false
  );
end;
$$;

grant execute on function public.submit_quiz_result(uuid, jsonb)
  to authenticated;

notify pgrst, 'reload schema';
