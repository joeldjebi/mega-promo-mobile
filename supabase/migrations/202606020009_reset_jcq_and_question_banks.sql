-- MegaPromo - Reset propre JCQ + banques de questions
-- A executer dans Supabase SQL Editor uniquement si tu veux repartir de zero.
-- Necessite que 202606020004_create_question_banks_and_category_draw.sql
-- ait deja ete execute, car le reset utilise les tables de banques.
--
-- Objectif:
-- - supprimer les JCQ non-live;
-- - supprimer leurs questions, participations et gagnants;
-- - supprimer toutes les questions de banque et questions orphelines;
-- - supprimer les liens categorie/banque et les banques de questions;
-- - ne pas toucher aux Quiz Live (QL).
--
-- Important:
-- - DEV: OK pour repartir proprement.
-- - PROD: destructif. A executer uniquement si tu acceptes de supprimer les
--   JCQ publies, leurs participations, resultats et gagnants associes.

create temp table if not exists tmp_reset_jcq_ids (
  id uuid primary key
) on commit drop;

create temp table if not exists tmp_reset_jcq_summary (
  item text primary key,
  count_value int not null
) on commit drop;

truncate table tmp_reset_jcq_ids;
truncate table tmp_reset_jcq_summary;

insert into tmp_reset_jcq_ids (id)
select contests.id
from public.contests
where lower(coalesce(contests.type, '')) = 'quiz'
  and coalesce(contests.is_live, false) = false;

do $$
declare
  affected_count int := 0;
begin
  with user_scores_to_remove as (
    select
      participations.user_id,
      coalesce(sum(greatest(coalesce(participations.score, 0), 0)), 0)::int
        as score_to_remove
    from public.participations
    join tmp_reset_jcq_ids target_jcq
      on target_jcq.id = participations.contest_id
    where participations.user_id is not null
    group by participations.user_id
  )
  update public.users
  set points_total = greatest(
    coalesce(public.users.points_total, 0) - user_scores_to_remove.score_to_remove,
    0
  )
  from user_scores_to_remove
  where public.users.id = user_scores_to_remove.user_id;

  get diagnostics affected_count = row_count;
  insert into tmp_reset_jcq_summary values ('users_points_repaired', affected_count);

  delete from public.quiz_participation_questions assigned
  using tmp_reset_jcq_ids target_jcq
  where assigned.contest_id = target_jcq.id;

  get diagnostics affected_count = row_count;
  insert into tmp_reset_jcq_summary values ('assigned_questions_deleted', affected_count);

  delete from public.winners winners
  using tmp_reset_jcq_ids target_jcq
  where winners.contest_id = target_jcq.id;

  get diagnostics affected_count = row_count;
  insert into tmp_reset_jcq_summary values ('winners_deleted', affected_count);

  delete from public.participations participations
  using tmp_reset_jcq_ids target_jcq
  where participations.contest_id = target_jcq.id;

  get diagnostics affected_count = row_count;
  insert into tmp_reset_jcq_summary values ('participations_deleted', affected_count);

  delete from public.questions questions
  using tmp_reset_jcq_ids target_jcq
  where questions.contest_id = target_jcq.id;

  get diagnostics affected_count = row_count;
  insert into tmp_reset_jcq_summary values ('contest_questions_deleted', affected_count);

  delete from public.questions questions
  where questions.contest_id is null
    or questions.question_bank_id is not null
    or lower(coalesce(questions.question_scope, '')) = 'bank';

  get diagnostics affected_count = row_count;
  insert into tmp_reset_jcq_summary values ('bank_questions_deleted', affected_count);

  delete from public.contests contests
  using tmp_reset_jcq_ids target_jcq
  where contests.id = target_jcq.id;

  get diagnostics affected_count = row_count;
  insert into tmp_reset_jcq_summary values ('jcq_deleted', affected_count);

  delete from public.question_bank_categories;

  get diagnostics affected_count = row_count;
  insert into tmp_reset_jcq_summary values ('bank_category_links_deleted', affected_count);

  delete from public.question_banks;

  get diagnostics affected_count = row_count;
  insert into tmp_reset_jcq_summary values ('banks_deleted', affected_count);
end;
$$;

notify pgrst, 'reload schema';

select *
from tmp_reset_jcq_summary
order by item asc;
