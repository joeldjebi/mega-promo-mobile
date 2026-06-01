-- MegaPromo - Retention des logs systeme
-- A executer apres 202605290003_create_system_logs.sql.
-- Permet au SA de purger les logs anciens sans acces direct en delete.

create or replace function public.admin_purge_system_logs(
  p_retention_days integer default 90
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_retention_days integer := greatest(coalesce(p_retention_days, 90), 7);
  cutoff_at timestamptz := now() - make_interval(days => normalized_retention_days);
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
  where created_at < cutoff_at;

  get diagnostics deleted_count = row_count;

  perform public.log_system_event(
    'warning',
    'database',
    'system_logs',
    'purge_old_logs',
    'Logs systeme anciens purges par le SA.',
    null,
    current_user_id,
    null,
    'system_logs',
    null,
    jsonb_build_object(
      'retention_days', normalized_retention_days,
      'cutoff_at', cutoff_at,
      'deleted_count', deleted_count
    ),
    null,
    null
  );

  return jsonb_build_object(
    'retention_days', normalized_retention_days,
    'cutoff_at', cutoff_at,
    'deleted_count', deleted_count
  );
end;
$$;

grant execute on function public.admin_purge_system_logs(integer)
to authenticated;

notify pgrst, 'reload schema';
