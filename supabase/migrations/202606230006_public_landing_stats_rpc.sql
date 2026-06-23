-- MegaPromo - Statistiques publiques de la landing page
-- A executer dans Supabase SQL Editor.
--
-- Objectif:
-- - fournir a la landing page des chiffres reels;
-- - ne pas exposer directement la table public.users au public;
-- - retourner uniquement des agregats non personnels.

create or replace function public.get_public_landing_stats()
returns table (
  active_users bigint,
  promo_value numeric,
  campaigns_launched bigint
)
language sql
security definer
set search_path = public
as $$
  select
    (
      select count(*)::bigint
      from public.users
      where coalesce(role, 'player') = 'player'
        and coalesce(is_active, true) = true
        and coalesce(account_status, 'active') = 'active'
    ) as active_users,
    (
      select coalesce(
        sum(
          coalesce(prize_value, 0)
          * greatest(coalesce(winners_count, 1), 1)
        ),
        0
      )::numeric
      from public.contests
      where status = 'active'
    ) as promo_value,
    (
      select count(*)::bigint
      from public.contests
    ) as campaigns_launched;
$$;

grant execute on function public.get_public_landing_stats()
to anon, authenticated, service_role;

notify pgrst, 'reload schema';
