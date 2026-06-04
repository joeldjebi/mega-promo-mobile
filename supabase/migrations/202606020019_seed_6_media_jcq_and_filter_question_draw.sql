-- MegaPromo - 6 JCQ multimedia alimentes par les banques de questions
-- A executer dans Supabase SQL Editor apres:
-- 202606020010_seed_3_question_bank_categories_only.sql
-- 202606020011_seed_30_questions_for_3_question_banks.sql
-- 202606020017_add_media_fields_to_quiz_questions.sql
-- 202606020018_seed_media_questions_and_3_media_live_quizzes.sql
-- et 202606020015_add_questions_per_quiz_to_question_banks.sql.
--
-- Objectif:
-- - creer 2 JCQ ou les questions sont des images;
-- - creer 2 JCQ ou les reponses sont des images;
-- - creer 2 JCQ normaux texte;
-- - garantir cote backend que chaque JCQ tire uniquement le bon type de
--   questions depuis sa banque de categorie.

alter table public.contests
add column if not exists is_live bool not null default false,
add column if not exists live_status varchar not null default 'scheduled',
add column if not exists allowed_player_plan_keys text[] default array[]::text[];

alter table public.questions
add column if not exists question_bank_id uuid references public.question_banks(id) on delete set null,
add column if not exists category_id uuid references public.categories(id) on delete set null,
add column if not exists question_scope text not null default 'contest',
add column if not exists question_image_url text,
add column if not exists option_a_image_url text,
add column if not exists option_b_image_url text,
add column if not exists option_c_image_url text,
add column if not exists option_d_image_url text;

insert into public.contest_types (key, name, description, is_active, order_index)
values
  ('quiz', 'Quiz', 'Concours avec questions, reponses et score.', true, 1)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = true,
  order_index = excluded.order_index;

with category_rows as (
  select id, name
  from public.categories
  where name in ('Automobile', 'Technologie', 'Musique')
),
bank_mapping as (
  select *
  from (
    values
      ('automobile', 'Automobile', '20260602-0000-4000-b001-000000000001'::uuid),
      ('technologie', 'Technologie', '20260602-0000-4000-b002-000000000002'::uuid),
      ('musique', 'Musique', '20260602-0000-4000-b003-000000000003'::uuid)
  ) as rows(bank_key, category_name, question_bank_id)
),
reward_seed as (
  insert into public.reward_catalog (
    id,
    name,
    reward_type,
    description,
    value_label,
    estimated_value,
    partner_id,
    default_code,
    default_delivery_instructions,
    terms,
    stock_quantity,
    used_quantity,
    is_active,
    metadata,
    created_at,
    updated_at
  )
  values (
    '20260602-0000-4000-e000-000000000801'::uuid,
    'Credit JCQ Media MegaPromo',
    'voucher',
    'Credit promotionnel offert aux gagnants des JCQ multimedia.',
    'Credit 3 000 FCFA',
    3000,
    null,
    'JCQ-MEDIA-3000',
    'Contacter le gagnant depuis le SA pour confirmer son identite et organiser la remise du credit.',
    'Quiz gratuit, sans achat requis. Credit promotionnel personnel, non remboursable.',
    60,
    0,
    true,
    '{"seed": true, "free_quiz": true, "no_purchase_required": true, "question_source": "question_bank_by_category"}'::jsonb,
    now(),
    now()
  )
  on conflict (id) do update set
    name = excluded.name,
    reward_type = excluded.reward_type,
    description = excluded.description,
    value_label = excluded.value_label,
    estimated_value = excluded.estimated_value,
    default_code = excluded.default_code,
    default_delivery_instructions = excluded.default_delivery_instructions,
    terms = excluded.terms,
    stock_quantity = excluded.stock_quantity,
    is_active = true,
    metadata = excluded.metadata,
    updated_at = now()
  returning *
),
contest_rows as (
  select *
  from (
    values
      (
        'jcq-media-image-questions-automobile',
        'automobile',
        'JCQ Auto Vision',
        'Observe les images auto et choisis la bonne reponse.',
        'CFAO Mobility CI',
        'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=cfao-mobility.ci&sz=128',
        'image_questions'
      ),
      (
        'jcq-media-image-questions-technologie',
        'technologie',
        'JCQ Tech Vision',
        'Observe les images tech et choisis la bonne reponse.',
        'Jumia CI',
        'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=jumia.ci&sz=128',
        'image_questions'
      ),
      (
        'jcq-media-image-answers-automobile',
        'automobile',
        'JCQ Auto Images',
        'Lis la question, puis selectionne la bonne image.',
        'Toyota CI',
        'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=toyota.ci&sz=128',
        'image_answers'
      ),
      (
        'jcq-media-image-answers-musique',
        'musique',
        'JCQ Music Images',
        'Lis la question, puis selectionne la bonne image musicale.',
        'Trace CI',
        'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=trace.ci&sz=128',
        'image_answers'
      ),
      (
        'jcq-media-text-technologie',
        'technologie',
        'JCQ Tech Classique',
        'Quiz texte sur les usages numeriques et la culture tech.',
        'Orange Digital Center',
        'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=orange.ci&sz=128',
        'text_only'
      ),
      (
        'jcq-media-text-musique',
        'musique',
        'JCQ Music Classique',
        'Quiz texte sur la musique, les instruments et la scene.',
        'Universal Music Africa',
        'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=universalmusic.com&sz=128',
        'text_only'
      )
  ) as rows(
    contest_key,
    bank_key,
    title,
    description,
    brand_name,
    image_url,
    brand_logo_url,
    media_mode
  )
),
contest_seed as (
  insert into public.contests (
    id,
    partner_id,
    title,
    description,
    image_url,
    brand_logo_url,
    brand_name,
    type,
    category,
    category_id,
    status,
    prize_description,
    prize_value,
    reward_type,
    reward_catalog_id,
    reward_delivery_mode,
    reward_delivery_instructions,
    reward_terms,
    reward_metadata,
    winners_count,
    max_participants,
    starts_at,
    ends_at,
    is_boosted,
    allowed_player_plan_keys,
    is_live,
    live_status,
    views_count,
    shares_count,
    created_at
  )
  select
    (
      substr(md5('jcq-media-v1-' || contest_rows.contest_key), 1, 8)
      || '-' || substr(md5('jcq-media-v1-' || contest_rows.contest_key), 9, 4)
      || '-' || substr(md5('jcq-media-v1-' || contest_rows.contest_key), 13, 4)
      || '-' || substr(md5('jcq-media-v1-' || contest_rows.contest_key), 17, 4)
      || '-' || substr(md5('jcq-media-v1-' || contest_rows.contest_key), 21, 12)
    )::uuid,
    null,
    contest_rows.title,
    contest_rows.description,
    contest_rows.image_url,
    contest_rows.brand_logo_url,
    contest_rows.brand_name,
    'quiz',
    category_rows.name,
    category_rows.id,
    'active',
    reward_seed.value_label,
    reward_seed.estimated_value,
    reward_seed.reward_type,
    reward_seed.id,
    'manual',
    reward_seed.default_delivery_instructions,
    reward_seed.terms,
    coalesce(reward_seed.metadata, '{}'::jsonb)
      || jsonb_build_object(
        'question_count',
        3,
        'question_bank_id',
        bank_mapping.question_bank_id::text,
        'question_bank_category',
        category_rows.name,
        'question_source',
        'question_bank_by_category',
        'media_mode',
        contest_rows.media_mode,
        'brand_theme',
        contest_rows.brand_name,
        'free_quiz',
        true,
        'no_purchase_required',
        true
      ),
    1,
    null,
    now(),
    now() + interval '14 days',
    true,
    array['free']::text[],
    false,
    'scheduled',
    0,
    0,
    now()
  from contest_rows
  join bank_mapping on bank_mapping.bank_key = contest_rows.bank_key
  join category_rows on category_rows.name = bank_mapping.category_name
  cross join reward_seed
  on conflict (id) do update set
    title = excluded.title,
    description = excluded.description,
    image_url = excluded.image_url,
    brand_logo_url = excluded.brand_logo_url,
    brand_name = excluded.brand_name,
    type = excluded.type,
    category = excluded.category,
    category_id = excluded.category_id,
    status = excluded.status,
    prize_description = excluded.prize_description,
    prize_value = excluded.prize_value,
    reward_type = excluded.reward_type,
    reward_catalog_id = excluded.reward_catalog_id,
    reward_delivery_mode = excluded.reward_delivery_mode,
    reward_delivery_instructions = excluded.reward_delivery_instructions,
    reward_terms = excluded.reward_terms,
    reward_metadata = excluded.reward_metadata,
    winners_count = excluded.winners_count,
    max_participants = excluded.max_participants,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    is_boosted = excluded.is_boosted,
    allowed_player_plan_keys = excluded.allowed_player_plan_keys,
    is_live = false,
    live_status = 'scheduled'
  returning id
)
select
  (select count(*) from contest_seed) as jcq_media_upserted,
  (
    select count(*)
    from public.contests
    where coalesce(is_live, false) = false
      and reward_metadata->>'media_mode' in (
        'image_questions',
        'image_answers',
        'text_only'
      )
      and reward_metadata->>'question_source' = 'question_bank_by_category'
  ) as jcq_media_total;

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
      'media_mode',
      contest_media_mode,
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
    'media_mode',
    contest_media_mode,
    'device_history_enabled',
    normalized_device_session_id is not null
  );
end;
$$;

grant execute on function public.start_quiz_contest(uuid, int, text)
  to authenticated;

notify pgrst, 'reload schema';
