-- MegaPromo - Suppression admin d'une ligne d'historique d'abonnement joueur
-- A executer dans Supabase SQL Editor.

create or replace function public.admin_delete_player_subscription(
  p_subscription_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  actor_role text;
  actor_admin_role_id uuid;
  subscription_record public.player_subscriptions%rowtype;
  active_paid_expires_at timestamptz;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  select users.role, users.admin_role_id
  into actor_role, actor_admin_role_id
  from public.users
  where users.id = current_user_id
    and coalesce(users.is_active, true) = true
  limit 1;

  if actor_role is null then
    raise exception 'Compte admin introuvable ou inactif.';
  end if;

  if coalesce(actor_role, 'player') not in (
    'super_admin',
    'super-admin',
    'sa'
  )
    and not exists (
      select 1
      from public.admin_role_permissions
      where admin_role_permissions.role_id = actor_admin_role_id
        and admin_role_permissions.permission_key in ('users.write', '*')
    )
  then
    raise exception 'Permission users.write requise pour supprimer un abonnement joueur.';
  end if;

  delete from public.player_subscriptions
  where id = p_subscription_id
  returning *
  into subscription_record;

  if subscription_record.id is null then
    raise exception 'Abonnement joueur introuvable.';
  end if;

  select player_subscriptions.expires_at
  into active_paid_expires_at
  from public.player_subscriptions
  join public.player_plans
    on player_plans.id = player_subscriptions.plan_id
  where player_subscriptions.user_id = subscription_record.user_id
    and player_subscriptions.status = 'active'
    and coalesce(player_plans.price, 0) > 0
    and lower(coalesce(player_plans.key, '')) not in ('free', 'standard')
  order by player_subscriptions.expires_at desc nulls last,
    player_subscriptions.created_at desc
  limit 1;

  update public.users
  set
    is_premium = active_paid_expires_at is not null,
    premium_expires_at = active_paid_expires_at
  where id = subscription_record.user_id;

  return jsonb_build_object(
    'ok', true,
    'subscription', to_jsonb(subscription_record)
  );
end;
$$;

grant execute on function public.admin_delete_player_subscription(uuid)
to authenticated;

notify pgrst, 'reload schema';
