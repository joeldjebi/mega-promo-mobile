-- MegaPromo - Ciblage notifications JCQ
-- A executer dans Supabase SQL Editor.
--
-- Objectif:
-- - permettre au SA de cibler les joueurs selon leur avancement JCQ;
-- - ne retourner que des user_id;
-- - eviter les gros calculs cote navigateur.

create or replace function public.get_jcq_notification_target_users(
  p_target text,
  p_contest_id uuid default null
)
returns table (user_id uuid)
language sql
security definer
set search_path = public
as $$
  with active_players as (
    select users.id
    from public.users
    where coalesce(users.role, 'player') = 'player'
      and coalesce(users.is_active, true) = true
      and coalesce(users.account_status, 'active') = 'active'
  ),
  active_jcq as (
    select contests.id
    from public.contests
    where contests.type = 'quiz'
      and coalesce(contests.is_live, false) = false
      and contests.status = 'active'
      and (contests.ends_at is null or contests.ends_at > now())
  ),
  active_jcq_count as (
    select count(*)::int as total
    from active_jcq
  ),
  played_active_jcq as (
    select
      participations.user_id,
      count(distinct participations.contest_id)::int as played_count
    from public.participations
    join active_jcq on active_jcq.id = participations.contest_id
    group by participations.user_id
  )
  select active_players.id as user_id
  from active_players
  where
    (
      p_target = 'jcq_not_played_this'
      and p_contest_id is not null
      and not exists (
        select 1
        from public.participations
        where participations.user_id = active_players.id
          and participations.contest_id = p_contest_id
      )
    )
    or
    (
      p_target = 'jcq_started_not_finished_this'
      and p_contest_id is not null
      and exists (
        select 1
        from public.participations
        where participations.user_id = active_players.id
          and participations.contest_id = p_contest_id
          and coalesce(participations.completed, false) = false
      )
    )
    or
    (
      p_target = 'jcq_not_played_all_active'
      and (select total from active_jcq_count) > 0
      and exists (
        select 1
        from played_active_jcq
        where played_active_jcq.user_id = active_players.id
          and played_active_jcq.played_count > 0
          and played_active_jcq.played_count < (select total from active_jcq_count)
      )
    )
    or
    (
      p_target = 'jcq_not_played_any_active'
      and (select total from active_jcq_count) > 0
      and not exists (
        select 1
        from played_active_jcq
        where played_active_jcq.user_id = active_players.id
      )
    );
$$;

grant execute on function public.get_jcq_notification_target_users(text, uuid)
to authenticated, service_role;

notify pgrst, 'reload schema';
