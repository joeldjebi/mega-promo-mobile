-- MegaPromo - Suppression complete des logs et snapshots Sentry
-- A executer apres 202605290009_create_sentry_issue_snapshots.sql.
-- Donne au SA des actions controlees pour nettoyer tout l'historique.

create or replace function public.admin_delete_all_system_logs()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  deleted_count integer := 0;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if not exists (
    select 1
    from public.users
    where users.id = current_user_id
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  ) then
    raise exception 'Acces reserve au super admin.';
  end if;

  delete from public.system_logs
  where id is not null;
  get diagnostics deleted_count = row_count;

  return jsonb_build_object(
    'deleted_count', deleted_count,
    'deleted_at', now()
  );
end;
$$;

create or replace function public.admin_delete_all_sentry_issue_snapshots()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  deleted_count integer := 0;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if not exists (
    select 1
    from public.users
    where users.id = current_user_id
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  ) then
    raise exception 'Acces reserve au super admin.';
  end if;

  delete from public.sentry_issue_snapshots
  where id is not null;
  get diagnostics deleted_count = row_count;

  perform public.log_system_event(
    'warning',
    'database',
    'sentry',
    'delete_all_snapshots',
    'Snapshots Sentry supprimes par le SA.',
    null,
    current_user_id,
    null,
    'sentry_issue_snapshots',
    null,
    jsonb_build_object(
      'deleted_count', deleted_count
    ),
    null,
    null
  );

  return jsonb_build_object(
    'deleted_count', deleted_count,
    'deleted_at', now()
  );
end;
$$;

grant execute on function public.admin_delete_all_system_logs()
to authenticated;

grant execute on function public.admin_delete_all_sentry_issue_snapshots()
to authenticated;

notify pgrst, 'reload schema';
