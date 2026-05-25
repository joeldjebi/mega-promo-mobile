-- MegaPromo - Rattrapage gagnant Quiz Crédit Communication 500F
-- A executer dans Supabase SQL Editor.
-- Cree le gagnant pending manquant pour le concours termine, sans doublon.

with target_contest as (
  select *
  from public.contests
  where id = '20260521-0000-4000-8000-000000000501'::uuid
     or title in (
       'Quiz Crédit Communication 500F',
       'Quiz Credit Communication 500F'
     )
  order by created_at desc
  limit 1
),
winner_capacity as (
  select
    target_contest.id as contest_id,
    greatest(coalesce(target_contest.winners_count, 1), 1) as winner_limit,
    (
      select count(*)::int
      from public.winners
      where winners.contest_id = target_contest.id
        and coalesce(winners.status, 'pending') <> 'cancelled'
    ) as existing_winners_count
  from target_contest
),
participation_candidates as (
  select
    participations.user_id,
    greatest(
      coalesce(participations.score, 0)::int,
      public.participation_points_from_answers(participations.answers)
    ) as score,
    public.participation_duration_ms(participations.answers) as duration_ms,
    participations.participated_at
  from public.participations
  join target_contest on target_contest.id = participations.contest_id
  where participations.user_id is not null
    and coalesce(participations.completed, true) = true
    and not exists (
      select 1
      from public.winners existing
      where existing.contest_id = target_contest.id
        and existing.user_id = participations.user_id
        and coalesce(existing.status, 'pending') <> 'cancelled'
    )
    and greatest(
      coalesce(participations.score, 0)::int,
      public.participation_points_from_answers(participations.answers)
    ) > 0
),
best_candidate_by_user as (
  select distinct on (participation_candidates.user_id)
    participation_candidates.user_id,
    participation_candidates.score,
    participation_candidates.duration_ms,
    participation_candidates.participated_at
  from participation_candidates
  order by
    participation_candidates.user_id,
    participation_candidates.score desc,
    participation_candidates.duration_ms asc,
    participation_candidates.participated_at asc nulls last
),
ranked_candidates as (
  select
    best_candidate_by_user.user_id,
    best_candidate_by_user.score,
    best_candidate_by_user.duration_ms,
    best_candidate_by_user.participated_at,
    row_number() over (
      order by
        best_candidate_by_user.score desc,
        best_candidate_by_user.duration_ms asc,
        best_candidate_by_user.participated_at asc nulls last,
        best_candidate_by_user.user_id asc
    ) as rank
  from best_candidate_by_user
),
inserted_winner as (
  insert into public.winners (
    user_id,
    contest_id,
    prize_description,
    prize_value,
    payment_method,
    payment_number,
    status,
    sent_at,
    created_at
  )
  select
    ranked_candidates.user_id,
    target_contest.id,
    coalesce(
      target_contest.prize_description,
      '500F de crédit communication'
    ),
    coalesce(target_contest.prize_value, 500),
    null,
    null,
    'pending',
    null,
    now()
  from target_contest
  join winner_capacity on winner_capacity.contest_id = target_contest.id
  join ranked_candidates on ranked_candidates.rank <= greatest(
    winner_capacity.winner_limit - winner_capacity.existing_winners_count,
    0
  )
  returning id, user_id, contest_id, prize_description, prize_value, status
)
select
  target_contest.id as contest_id,
  target_contest.title,
  target_contest.status,
  target_contest.ends_at,
  (
    select count(*)::int
    from public.participations
    where participations.contest_id = target_contest.id
  ) as participations_count,
  (
    select count(*)::int
    from public.winners
    where winners.contest_id = target_contest.id
      and coalesce(winners.status, 'pending') <> 'cancelled'
  ) as winners_count,
  coalesce(
    (
      select jsonb_agg(to_jsonb(inserted_winner))
      from inserted_winner
    ),
    '[]'::jsonb
  ) as inserted_winners
from target_contest;
