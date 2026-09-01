-- MegaPromo - Replays JCQ illimites par paiements multiples
-- A executer dans Supabase SQL Editor en production apres:
-- 202609010008_quiz_replay_paid_requests.sql.
--
-- Objectif:
-- - permettre a un joueur de payer plusieurs fois pour le meme JCQ;
-- - conserver chaque preuve de paiement dans l'historique;
-- - donner un droit de replay par demande approuvee;
-- - privilegier un replay approuve non utilise dans le statut retourne a l'app.

set lock_timeout = '3s';
set statement_timeout = '30s';

drop index if exists public.quiz_replay_requests_one_pending_or_approved;

create index if not exists quiz_replay_requests_active_status_idx
  on public.quiz_replay_requests(user_id, contest_id, status, created_at desc)
  where status in ('pending', 'approved');

create or replace function public.get_my_quiz_replay_status(p_contest_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  contest_record public.contests%rowtype;
  latest_request public.quiz_replay_requests%rowtype;
  replay_enabled boolean := false;
  replay_amount int := 0;
  payment_target text := '';
  payment_url text := '';
  instructions text := '';
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  select *
  into contest_record
  from public.contests
  where id = p_contest_id
  limit 1;

  if contest_record.id is null then
    raise exception 'JCQ introuvable.';
  end if;

  replay_enabled := coalesce(
    nullif(contest_record.reward_metadata->>'quiz_replay_enabled', '')::boolean,
    false
  );
  replay_amount := coalesce(
    nullif(contest_record.reward_metadata->>'quiz_replay_amount', '')::int,
    0
  );
  payment_target := coalesce(
    nullif(contest_record.reward_metadata->>'quiz_replay_payment_target', ''),
    nullif(contest_record.reward_metadata->>'quiz_replay_payment_number', ''),
    ''
  );
  payment_url := coalesce(
    nullif(contest_record.reward_metadata->>'quiz_replay_payment_url', ''),
    nullif(contest_record.reward_metadata->>'quiz_replay_payment_link', ''),
    ''
  );
  instructions := coalesce(
    nullif(contest_record.reward_metadata->>'quiz_replay_payment_instructions', ''),
    nullif(contest_record.reward_metadata->>'quiz_replay_message', ''),
    'Effectue le paiement, garde une capture claire, puis soumets ta preuve. Validation sous 5 minutes max.'
  );

  select *
  into latest_request
  from public.quiz_replay_requests
  where user_id = current_user_id
    and contest_id = p_contest_id
  order by
    case
      when status = 'approved' and used_at is null then 0
      when status = 'pending' then 1
      when status = 'rejected' then 2
      else 3
    end,
    approved_at asc nulls last,
    created_at asc
  limit 1;

  return jsonb_build_object(
    'replay_enabled', replay_enabled,
    'amount', replay_amount,
    'payment_target', payment_target,
    'payment_url', payment_url,
    'instructions', instructions,
    'status', coalesce(latest_request.status, 'none'),
    'request_id', latest_request.id,
    'rejection_reason', latest_request.rejection_reason,
    'created_at', latest_request.created_at,
    'approved_at', latest_request.approved_at,
    'used_at', latest_request.used_at
  );
end;
$$;

create or replace function public.submit_quiz_replay_request(
  p_contest_id uuid,
  p_proof_image_url text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  contest_record public.contests%rowtype;
  replay_enabled boolean := false;
  replay_amount int := 0;
  payment_target text := '';
  payment_url text := '';
  created_request public.quiz_replay_requests%rowtype;
  player_label text := 'Un joueur';
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  select *
  into contest_record
  from public.contests
  where id = p_contest_id
  limit 1;

  if contest_record.id is null then
    raise exception 'JCQ introuvable.';
  end if;

  if lower(coalesce(contest_record.type, '')) <> 'quiz'
    or coalesce(contest_record.is_live, false) = true
  then
    raise exception 'Le rejeu est reserve aux JCQ.';
  end if;

  if not exists (
    select 1
    from public.participations
    where user_id = current_user_id
      and contest_id = p_contest_id
  ) then
    raise exception 'Tu dois avoir deja joue ce JCQ avant de demander un replay.';
  end if;

  replay_enabled := coalesce(
    nullif(contest_record.reward_metadata->>'quiz_replay_enabled', '')::boolean,
    false
  );
  replay_amount := coalesce(
    nullif(contest_record.reward_metadata->>'quiz_replay_amount', '')::int,
    0
  );
  payment_target := coalesce(
    nullif(contest_record.reward_metadata->>'quiz_replay_payment_target', ''),
    nullif(contest_record.reward_metadata->>'quiz_replay_payment_number', ''),
    ''
  );
  payment_url := coalesce(
    nullif(contest_record.reward_metadata->>'quiz_replay_payment_url', ''),
    nullif(contest_record.reward_metadata->>'quiz_replay_payment_link', ''),
    ''
  );

  if replay_enabled is not true or replay_amount <= 0 then
    raise exception 'Le rejeu n''est pas disponible pour ce JCQ.';
  end if;

  if nullif(trim(coalesce(p_proof_image_url, '')), '') is null then
    raise exception 'La preuve de paiement est obligatoire.';
  end if;

  insert into public.quiz_replay_requests (
    contest_id,
    user_id,
    proof_image_url,
    amount,
    payment_target,
    payment_url,
    status
  )
  values (
    p_contest_id,
    current_user_id,
    trim(p_proof_image_url),
    replay_amount,
    payment_target,
    payment_url,
    'pending'
  )
  returning *
  into created_request;

  select coalesce(nullif(trim(users.username), ''), nullif(trim(users.phone), ''), player_label)
  into player_label
  from public.users
  where users.id = current_user_id
  limit 1;

  insert into public.notifications (
    user_id,
    title,
    body,
    type,
    is_read,
    data,
    created_at
  )
  select
    users.id,
    'Paiement replay a verifier',
    player_label || ' a soumis une preuve de paiement pour rejouer "' ||
      coalesce(nullif(contest_record.title, ''), 'ce JCQ') || '".',
    'admin_quiz_replay_request',
    false,
    jsonb_build_object(
      'source', 'submit_quiz_replay_request',
      'contest_id', p_contest_id,
      'request_id', created_request.id,
      'player_id', current_user_id,
      'amount', replay_amount
    ),
    now()
  from public.users
  where coalesce(users.role, 'player') in (
      'admin',
      'super_admin',
      'super-admin',
      'sa'
    )
    and coalesce(users.is_active, true) = true;

  return public.get_my_quiz_replay_status(p_contest_id);
end;
$$;

grant execute on function public.get_my_quiz_replay_status(uuid) to authenticated;
grant execute on function public.submit_quiz_replay_request(uuid, text) to authenticated;

notify pgrst, 'reload schema';
