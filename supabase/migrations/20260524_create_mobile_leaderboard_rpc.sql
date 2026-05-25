-- MegaPromo - Mobile leaderboard RPC
-- A executer dans Supabase SQL Editor.
-- Calcule le classement cote serveur pour eviter les resultats incomplets
-- cote client et garder le top 100 coherent.

alter table public.participations
add column if not exists is_live_session bool not null default false;

create or replace function public.get_mobile_leaderboard(
  p_scope text default 'system',
  p_contest_id uuid default null,
  p_limit int default 100
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  requested_limit int := greatest(least(coalesce(p_limit, 100), 100), 1);
  payload jsonb;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  with scoped_participations as (
    select
      participations.user_id,
      greatest(coalesce(participations.score, 0), 0)::int as score
    from public.participations
    left join public.contests on contests.id = participations.contest_id
    where
      case
        when p_scope = 'live_quiz'
          then coalesce(contests.is_live, false) = true
            or coalesce(participations.is_live_session, false) = true
        when p_scope = 'contest'
          then p_contest_id is not null
            and participations.contest_id = p_contest_id
        else true
      end
  ),
  aggregated_scores as (
    select
      scoped_participations.user_id,
      sum(scoped_participations.score)::int as points
    from scoped_participations
    group by scoped_participations.user_id
  ),
  visible_scores as (
    select
      users.id,
      coalesce(users.username, 'Joueur') as username,
      users.avatar_url,
      aggregated_scores.points
    from aggregated_scores
    join public.users on users.id = aggregated_scores.user_id
    where coalesce(users.is_active, true) = true
      and coalesce(users.account_status, 'active') not in (
        'deleted',
        'disabled',
        'banned'
      )
      and coalesce(users.role, 'player') not in (
        'admin',
        'super_admin',
        'sa',
        'support'
      )
      and coalesce(users.username, '') <> 'Joueur supprimé'
  ),
  ranked_scores as (
    select
      visible_scores.*,
      row_number() over (
        order by visible_scores.points desc, visible_scores.id asc
      )::int as rank
    from visible_scores
  ),
  top_scores as (
    select *
    from ranked_scores
    where rank <= requested_limit
    order by rank asc
  ),
  current_score as (
    select *
    from ranked_scores
    where id = current_user_id
    limit 1
  )
  select jsonb_build_object(
    'users',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', top_scores.id,
            'username', top_scores.username,
            'avatar_url', top_scores.avatar_url,
            'points', top_scores.points,
            'rank', top_scores.rank
          )
          order by top_scores.rank asc
        )
        from top_scores
      ),
      '[]'::jsonb
    ),
    'current_user',
    (
      select jsonb_build_object(
        'id', current_score.id,
        'username', current_score.username,
        'avatar_url', current_score.avatar_url,
        'points', current_score.points,
        'rank', current_score.rank
      )
      from current_score
    ),
    'current_user_rank',
    (
      select current_score.rank
      from current_score
    )
  )
  into payload;

  return payload;
end;
$$;

grant execute on function public.get_mobile_leaderboard(text, uuid, int)
to authenticated;

notify pgrst, 'reload schema';
