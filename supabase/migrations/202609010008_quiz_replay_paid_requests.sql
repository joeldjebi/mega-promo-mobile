-- MegaPromo - Rejeu payant des JCQ avec validation admin
-- A executer dans Supabase SQL Editor en production.
--
-- Objectif:
-- - permettre au SA d'activer le rejeu par JCQ depuis reward_metadata;
-- - permettre au joueur deja participant de soumettre une preuve de paiement;
-- - permettre au SA d'approuver/refuser une demande;
-- - notifier le joueur quand il est autorise a rejouer;
-- - autoriser une nouvelle participation JCQ uniquement apres approbation.

set lock_timeout = '3s';
set statement_timeout = '30s';

create table if not exists public.quiz_replay_requests (
  id uuid primary key default gen_random_uuid(),
  contest_id uuid not null references public.contests(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  proof_image_url text not null,
  amount int not null default 0,
  payment_target text not null default '',
  payment_url text not null default '',
  status text not null default 'pending',
  rejection_reason text,
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,
  approved_at timestamptz,
  used_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint quiz_replay_requests_status_check
    check (status in ('pending', 'approved', 'rejected', 'used'))
);

create index if not exists quiz_replay_requests_user_contest_idx
  on public.quiz_replay_requests(user_id, contest_id, created_at desc);

drop index if exists public.quiz_replay_requests_one_pending_or_approved;

create index if not exists quiz_replay_requests_active_status_idx
  on public.quiz_replay_requests(user_id, contest_id, status, created_at desc)
  where status in ('pending', 'approved');

alter table public.quiz_replay_requests enable row level security;

drop policy if exists quiz_replay_requests_select_own_or_admin
  on public.quiz_replay_requests;
create policy quiz_replay_requests_select_own_or_admin
on public.quiz_replay_requests
for select
using (
  auth.uid() = user_id
  or public.is_active_admin()
);

drop policy if exists quiz_replay_requests_insert_own
  on public.quiz_replay_requests;
create policy quiz_replay_requests_insert_own
on public.quiz_replay_requests
for insert
with check (auth.uid() = user_id);

drop policy if exists quiz_replay_requests_admin_update
  on public.quiz_replay_requests;
create policy quiz_replay_requests_admin_update
on public.quiz_replay_requests
for update
using (public.is_active_admin())
with check (public.is_active_admin());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment-proofs',
  'payment-proofs',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  public = true,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists payment_proofs_insert_own_folder on storage.objects;
create policy payment_proofs_insert_own_folder
on storage.objects
for insert
with check (
  bucket_id = 'payment-proofs'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists payment_proofs_select_own_or_admin on storage.objects;
create policy payment_proofs_select_own_or_admin
on storage.objects
for select
using (
  bucket_id = 'payment-proofs'
  and (
    auth.uid()::text = (storage.foldername(name))[1]
    or public.is_active_admin()
  )
);

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

create or replace function public.admin_update_quiz_replay_config(
  p_contest_id uuid,
  p_enabled boolean,
  p_amount int,
  p_payment_target text,
  p_payment_url text default '',
  p_instructions text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_record public.contests%rowtype;
begin
  if not public.is_active_admin() then
    raise exception 'Acces reserve au super admin.';
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

  update public.contests
  set reward_metadata = coalesce(reward_metadata, '{}'::jsonb)
    || jsonb_build_object(
      'quiz_replay_enabled', coalesce(p_enabled, false),
      'quiz_replay_amount', greatest(coalesce(p_amount, 0), 0),
      'quiz_replay_payment_target', coalesce(p_payment_target, ''),
      'quiz_replay_payment_url', coalesce(p_payment_url, ''),
      'quiz_replay_payment_instructions', coalesce(p_instructions, '')
    )
  where id = p_contest_id;

  return jsonb_build_object('success', true, 'contest_id', p_contest_id);
end;
$$;

create or replace function public.admin_approve_quiz_replay_request(
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_id uuid := auth.uid();
  request_record public.quiz_replay_requests%rowtype;
  contest_title text := 'ce JCQ';
begin
  if not public.is_active_admin() then
    raise exception 'Acces reserve au super admin.';
  end if;

  select *
  into request_record
  from public.quiz_replay_requests
  where id = p_request_id
  for update;

  if request_record.id is null then
    raise exception 'Demande introuvable.';
  end if;

  update public.quiz_replay_requests
  set
    status = 'approved',
    rejection_reason = null,
    reviewed_by = admin_id,
    reviewed_at = now(),
    approved_at = now(),
    updated_at = now()
  where id = p_request_id
  returning *
  into request_record;

  select coalesce(nullif(title, ''), contest_title)
  into contest_title
  from public.contests
  where id = request_record.contest_id
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
  values (
    request_record.user_id,
    'Replay autorise',
    'Ta demande est validee. Tu peux rejouer "' || contest_title || '" maintenant.',
    'quiz_replay_approved',
    false,
    jsonb_build_object(
      'source', 'admin_approve_quiz_replay_request',
      'contest_id', request_record.contest_id,
      'request_id', request_record.id
    ),
    now()
  );

  return jsonb_build_object('success', true, 'request_id', request_record.id);
end;
$$;

create or replace function public.admin_reject_quiz_replay_request(
  p_request_id uuid,
  p_rejection_reason text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_id uuid := auth.uid();
begin
  if not public.is_active_admin() then
    raise exception 'Acces reserve au super admin.';
  end if;

  update public.quiz_replay_requests
  set
    status = 'rejected',
    rejection_reason = nullif(trim(coalesce(p_rejection_reason, '')), ''),
    reviewed_by = admin_id,
    reviewed_at = now(),
    updated_at = now()
  where id = p_request_id;

  return jsonb_build_object('success', true, 'request_id', p_request_id);
end;
$$;

drop function if exists public.start_quiz_contest(uuid, int);
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
  contest_media_mode text := null;
  source_question_bank_ids uuid[] := null;
  existing_participations_count int := 0;
  approved_replay_request_id uuid := null;
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

  contest_media_mode := nullif(trim(coalesce(contest_record.reward_metadata->>'media_mode', '')), '');

  select coalesce(array_agg(value::uuid), null)
  into source_question_bank_ids
  from jsonb_array_elements_text(
    case
      when jsonb_typeof(contest_record.reward_metadata->'source_question_bank_ids') = 'array'
        then contest_record.reward_metadata->'source_question_bank_ids'
      else '[]'::jsonb
    end
  ) as source_ids(value);

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

  select count(*)::int
  into existing_participations_count
  from public.participations
  where contest_id = p_contest_id
    and user_id = current_user_id;

  if existing_participations_count > 0 then
    select quiz_replay_requests.id
    into approved_replay_request_id
    from public.quiz_replay_requests
    where quiz_replay_requests.contest_id = p_contest_id
      and quiz_replay_requests.user_id = current_user_id
      and quiz_replay_requests.status = 'approved'
      and quiz_replay_requests.used_at is null
    order by quiz_replay_requests.approved_at asc nulls last,
      quiz_replay_requests.created_at asc
    limit 1
    for update skip locked;

    if approved_replay_request_id is null then
      raise exception 'Participation deja enregistree pour ce quiz.';
    end if;
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
    and bank_categories.category_id = contest_record.category_id
    and (
      source_question_bank_ids is null
      or banks.id = any(source_question_bank_ids)
    );

  select count(*)::int
  into eligible_questions_count
  from public.questions questions
  where coalesce(questions.is_active, true) = true
    and (
      contest_media_mode is null
      or contest_media_mode not in ('image_questions', 'image_answers', 'text_only')
      or (
        contest_media_mode = 'image_questions'
        and length(trim(coalesce(questions.question_image_url, ''))) > 0
      )
      or (
        contest_media_mode = 'image_answers'
        and length(trim(coalesce(questions.option_a_image_url, ''))) > 0
        and length(trim(coalesce(questions.option_b_image_url, ''))) > 0
        and length(trim(coalesce(questions.option_c_image_url, ''))) > 0
        and length(trim(coalesce(questions.option_d_image_url, ''))) > 0
      )
      or (
        contest_media_mode = 'text_only'
        and length(trim(coalesce(questions.question_image_url, ''))) = 0
        and length(trim(coalesce(questions.option_a_image_url, ''))) = 0
        and length(trim(coalesce(questions.option_b_image_url, ''))) = 0
        and length(trim(coalesce(questions.option_c_image_url, ''))) = 0
        and length(trim(coalesce(questions.option_d_image_url, ''))) = 0
      )
    )
    and exists (
      select 1
      from public.question_banks banks
      join public.question_bank_categories bank_categories
        on bank_categories.question_bank_id = banks.id
      where banks.id = questions.question_bank_id
        and coalesce(banks.is_active, true) = true
        and bank_categories.category_id = contest_record.category_id
        and (
          source_question_bank_ids is null
          or banks.id = any(source_question_bank_ids)
        )
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
      case
        when source_question_bank_ids is null then 'server_random_question_bank'
        else 'server_random_question_bank_list'
      end,
      'requested_questions_count',
      requested_question_count,
      'media_mode',
      contest_media_mode,
      'device_history_enabled',
      normalized_device_session_id is not null,
      'is_replay',
      approved_replay_request_id is not null,
      'replay_request_id',
      approved_replay_request_id
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
      and (
        contest_media_mode is null
        or contest_media_mode not in ('image_questions', 'image_answers', 'text_only')
        or (
          contest_media_mode = 'image_questions'
          and length(trim(coalesce(questions.question_image_url, ''))) > 0
        )
        or (
          contest_media_mode = 'image_answers'
          and length(trim(coalesce(questions.option_a_image_url, ''))) > 0
          and length(trim(coalesce(questions.option_b_image_url, ''))) > 0
          and length(trim(coalesce(questions.option_c_image_url, ''))) > 0
          and length(trim(coalesce(questions.option_d_image_url, ''))) > 0
        )
        or (
          contest_media_mode = 'text_only'
          and length(trim(coalesce(questions.question_image_url, ''))) = 0
          and length(trim(coalesce(questions.option_a_image_url, ''))) = 0
          and length(trim(coalesce(questions.option_b_image_url, ''))) = 0
          and length(trim(coalesce(questions.option_c_image_url, ''))) = 0
          and length(trim(coalesce(questions.option_d_image_url, ''))) = 0
        )
      )
      and exists (
        select 1
        from public.question_banks banks
        join public.question_bank_categories bank_categories
          on bank_categories.question_bank_id = banks.id
        where banks.id = questions.question_bank_id
          and coalesce(banks.is_active, true) = true
          and bank_categories.category_id = contest_record.category_id
          and (
            source_question_bank_ids is null
            or banks.id = any(source_question_bank_ids)
          )
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

  if approved_replay_request_id is not null then
    update public.quiz_replay_requests
    set
      status = 'used',
      used_at = now(),
      updated_at = now()
    where id = approved_replay_request_id;
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
    case
      when source_question_bank_ids is null then 'question_banks_by_category'
      else 'question_bank_list'
    end,
    'media_mode',
    contest_media_mode,
    'device_history_enabled',
    normalized_device_session_id is not null,
    'is_replay',
    approved_replay_request_id is not null,
    'replay_request_id',
    approved_replay_request_id
  );
end;
$$;

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

  perform pg_advisory_xact_lock(
    hashtext(current_user_id::text),
    hashtext(p_contest_id::text)
  );

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
    p_replay_request_id
  );
end;
$$;

grant select, insert, update on public.quiz_replay_requests to authenticated;
grant execute on function public.get_my_quiz_replay_status(uuid) to authenticated;
grant execute on function public.submit_quiz_replay_request(uuid, text) to authenticated;
grant execute on function public.admin_update_quiz_replay_config(uuid, boolean, int, text, text, text) to authenticated;
grant execute on function public.admin_approve_quiz_replay_request(uuid) to authenticated;
grant execute on function public.admin_reject_quiz_replay_request(uuid, text) to authenticated;
grant execute on function public.start_quiz_contest(uuid, int, text) to authenticated;
grant execute on function public.start_quiz_contest_replay(uuid, uuid, text) to authenticated;

notify pgrst, 'reload schema';
