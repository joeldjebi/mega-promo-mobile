-- MegaPromo - Correction demarrage replay JCQ
-- A executer dans Supabase SQL Editor en production apres:
-- 202609010008_quiz_replay_paid_requests.sql et
-- 202609010009_allow_multiple_quiz_replay_payments.sql.
--
-- Objectif:
-- - eviter que le demarrage replay soit bloque par le verrouillage de la
--   demande approuvee;
-- - laisser start_quiz_contest consommer le replay approuve disponible;
-- - conserver la verification que le ticket de replay appartient bien au joueur.

set lock_timeout = '3s';
set statement_timeout = '30s';

create or replace function public.start_quiz_contest_replay(
  p_contest_id uuid,
  p_replay_request_id uuid,
  p_device_session_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  replay_request_record public.quiz_replay_requests%rowtype;
  result_payload jsonb;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  select *
  into replay_request_record
  from public.quiz_replay_requests
  where id = p_replay_request_id
    and contest_id = p_contest_id
    and user_id = current_user_id
  limit 1;

  if replay_request_record.id is null then
    raise exception 'Demande de replay introuvable.';
  end if;

  if replay_request_record.status <> 'approved'
    or replay_request_record.used_at is not null
  then
    raise exception 'Ce replay n''est pas encore autorise ou a deja ete utilise.';
  end if;

  result_payload := public.start_quiz_contest(
    p_contest_id,
    null,
    p_device_session_id
  );

  return result_payload || jsonb_build_object(
    'is_replay',
    true,
    'replay_request_id',
    coalesce(result_payload->>'replay_request_id', p_replay_request_id::text)
  );
end;
$$;

grant execute on function public.start_quiz_contest_replay(uuid, uuid, text)
  to authenticated;

notify pgrst, 'reload schema';
