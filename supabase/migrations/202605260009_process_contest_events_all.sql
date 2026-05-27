-- MegaPromo - Traitement global des concours termines
-- A executer dans Supabase SQL Editor apres:
-- 1) 20260524_auto_generate_winners_for_finished_contests.sql
-- 2) 20260525_process_live_quiz_events_from_question_time.sql
-- Cette fonction traite les QL expires puis genere les gagnants des concours
-- standard/quiz termines par ends_at.

create or replace function public.process_contest_events()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  ended_live_count integer := 0;
  created_winners_count integer := 0;
begin
  begin
    ended_live_count := coalesce(public.process_live_quiz_events(), 0);
  exception
    when undefined_function then
      ended_live_count := 0;
  end;

  begin
    created_winners_count :=
      coalesce(public.generate_pending_winners_for_finished_contests(), 0);
  exception
    when undefined_function then
      created_winners_count := 0;
  end;

  return jsonb_build_object(
    'ended_live_quizzes', ended_live_count,
    'created_winners', created_winners_count
  );
end;
$$;

grant execute on function public.process_contest_events() to authenticated;

select public.process_contest_events() as processed_contest_events;

notify pgrst, 'reload schema';
