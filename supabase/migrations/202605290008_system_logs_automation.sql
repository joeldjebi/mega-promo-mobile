-- MegaPromo - Automatisation et maintenance des logs systeme
-- A executer apres 202605290007_harden_system_logs_security.sql.
-- Ajoute une configuration de maintenance, un runner securise et une
-- planification automatique si pg_cron est disponible sur le projet Supabase.

create table if not exists public.system_maintenance_settings (
  key text primary key,
  name text not null,
  description text,
  is_enabled bool not null default true,
  retention_days integer not null default 90,
  run_hour_utc integer not null default 2,
  last_run_at timestamptz,
  last_deleted_count integer not null default 0,
  last_error text,
  next_run_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  updated_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint system_maintenance_retention_days_check
    check (retention_days >= 7),
  constraint system_maintenance_run_hour_utc_check
    check (run_hour_utc between 0 and 23),
  constraint system_maintenance_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

alter table public.system_maintenance_settings enable row level security;

grant select on public.system_maintenance_settings to authenticated;
grant select, insert, update, delete on public.system_maintenance_settings
to service_role;

drop policy if exists "system_maintenance_admin_select"
on public.system_maintenance_settings;
create policy "system_maintenance_admin_select"
on public.system_maintenance_settings
for select
to authenticated
using (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  )
);

create or replace function public.calculate_next_system_log_maintenance_run(
  p_run_hour_utc integer default 2,
  p_from timestamptz default now()
)
returns timestamptz
language plpgsql
stable
set search_path = public
as $$
declare
  normalized_hour integer := least(greatest(coalesce(p_run_hour_utc, 2), 0), 23);
  candidate timestamptz;
begin
  candidate := (
    date_trunc('day', p_from at time zone 'UTC')
    + make_interval(hours => normalized_hour)
  ) at time zone 'UTC';

  if candidate <= p_from then
    candidate := candidate + interval '1 day';
  end if;

  return candidate;
end;
$$;

insert into public.system_maintenance_settings (
  key,
  name,
  description,
  is_enabled,
  retention_days,
  run_hour_utc,
  next_run_at,
  metadata,
  created_at,
  updated_at
)
values (
  'system_logs_retention',
  'Retention des logs systeme',
  'Purge automatiquement les logs systeme plus anciens que la duree configuree.',
  true,
  90,
  2,
  public.calculate_next_system_log_maintenance_run(2, now()),
  jsonb_build_object('schedule', 'daily', 'cron_probe', 'hourly'),
  now(),
  now()
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  next_run_at = coalesce(
    public.system_maintenance_settings.next_run_at,
    excluded.next_run_at
  ),
  metadata = public.system_maintenance_settings.metadata
    || jsonb_build_object('schedule', 'daily', 'cron_probe', 'hourly'),
  updated_at = now();

create or replace function public.is_current_user_system_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  );
$$;

create or replace function public.admin_upsert_system_logs_maintenance(
  p_is_enabled boolean default true,
  p_retention_days integer default 90,
  p_run_hour_utc integer default 2
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_retention_days integer := greatest(coalesce(p_retention_days, 90), 7);
  normalized_run_hour integer := least(greatest(coalesce(p_run_hour_utc, 2), 0), 23);
  setting_record public.system_maintenance_settings%rowtype;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if not public.is_current_user_system_admin() then
    raise exception 'Acces reserve au super admin.';
  end if;

  insert into public.system_maintenance_settings (
    key,
    name,
    description,
    is_enabled,
    retention_days,
    run_hour_utc,
    next_run_at,
    updated_by,
    updated_at
  )
  values (
    'system_logs_retention',
    'Retention des logs systeme',
    'Purge automatiquement les logs systeme plus anciens que la duree configuree.',
    coalesce(p_is_enabled, true),
    normalized_retention_days,
    normalized_run_hour,
    public.calculate_next_system_log_maintenance_run(normalized_run_hour, now()),
    current_user_id,
    now()
  )
  on conflict (key) do update set
    is_enabled = excluded.is_enabled,
    retention_days = excluded.retention_days,
    run_hour_utc = excluded.run_hour_utc,
    next_run_at = public.calculate_next_system_log_maintenance_run(
      excluded.run_hour_utc,
      now()
    ),
    last_error = null,
    updated_by = excluded.updated_by,
    updated_at = now()
  returning *
  into setting_record;

  perform public.log_system_event(
    'info',
    'database',
    'system_logs',
    'update_maintenance_settings',
    'Configuration de maintenance des logs mise a jour.',
    null,
    current_user_id,
    null,
    'system_maintenance_settings',
    setting_record.key,
    jsonb_build_object(
      'is_enabled', setting_record.is_enabled,
      'retention_days', setting_record.retention_days,
      'run_hour_utc', setting_record.run_hour_utc,
      'next_run_at', setting_record.next_run_at
    ),
    null,
    null
  );

  return to_jsonb(setting_record);
end;
$$;

create or replace function public.run_system_logs_maintenance(
  p_force boolean default false,
  p_dry_run boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  setting_record public.system_maintenance_settings%rowtype;
  cutoff_at timestamptz;
  deleted_count integer := 0;
  candidate_count integer := 0;
  should_run boolean := false;
  result jsonb;
begin
  if current_user_id is not null and not public.is_current_user_system_admin() then
    raise exception 'Acces reserve au super admin.';
  end if;

  select *
  into setting_record
  from public.system_maintenance_settings
  where key = 'system_logs_retention'
  for update;

  if setting_record.key is null then
    insert into public.system_maintenance_settings (
      key,
      name,
      description,
      is_enabled,
      retention_days,
      run_hour_utc,
      next_run_at,
      created_at,
      updated_at
    )
    values (
      'system_logs_retention',
      'Retention des logs systeme',
      'Purge automatiquement les logs systeme plus anciens que la duree configuree.',
      true,
      90,
      2,
      public.calculate_next_system_log_maintenance_run(2, now()),
      now(),
      now()
    )
    returning *
    into setting_record;
  end if;

  should_run := coalesce(p_force, false)
    or (
      coalesce(setting_record.is_enabled, true)
      and coalesce(setting_record.next_run_at, now()) <= now()
    );

  cutoff_at := now() - make_interval(days => setting_record.retention_days);

  select count(*)
  into candidate_count
  from public.system_logs
  where created_at < cutoff_at;

  if not should_run then
    return jsonb_build_object(
      'status', 'skipped',
      'reason', case
        when not coalesce(setting_record.is_enabled, true)
          then 'disabled'
        else 'not_due'
      end,
      'is_enabled', setting_record.is_enabled,
      'retention_days', setting_record.retention_days,
      'run_hour_utc', setting_record.run_hour_utc,
      'next_run_at', setting_record.next_run_at,
      'candidate_count', candidate_count,
      'deleted_count', 0,
      'dry_run', coalesce(p_dry_run, false)
    );
  end if;

  if coalesce(p_dry_run, false) then
    deleted_count := 0;
  else
    delete from public.system_logs
    where created_at < cutoff_at;

    get diagnostics deleted_count = row_count;
  end if;

  update public.system_maintenance_settings
  set
    last_run_at = now(),
    last_deleted_count = case
      when coalesce(p_dry_run, false) then last_deleted_count
      else deleted_count
    end,
    last_error = null,
    next_run_at = public.calculate_next_system_log_maintenance_run(
      run_hour_utc,
      now()
    ),
    metadata = coalesce(metadata, '{}'::jsonb)
      || jsonb_build_object(
        'last_candidate_count', candidate_count,
        'last_dry_run', coalesce(p_dry_run, false),
        'last_force', coalesce(p_force, false)
      ),
    updated_by = coalesce(current_user_id, updated_by),
    updated_at = now()
  where key = setting_record.key
  returning *
  into setting_record;

  result := jsonb_build_object(
    'status', case when coalesce(p_dry_run, false) then 'dry_run' else 'completed' end,
    'is_enabled', setting_record.is_enabled,
    'retention_days', setting_record.retention_days,
    'run_hour_utc', setting_record.run_hour_utc,
    'cutoff_at', cutoff_at,
    'last_run_at', setting_record.last_run_at,
    'next_run_at', setting_record.next_run_at,
    'candidate_count', candidate_count,
    'deleted_count', deleted_count,
    'dry_run', coalesce(p_dry_run, false)
  );

  perform public.log_system_event(
    case when deleted_count > 0 then 'warning' else 'info' end,
    'database',
    'system_logs',
    'automated_maintenance_run',
    'Maintenance automatique des logs systeme executee.',
    null,
    current_user_id,
    null,
    'system_maintenance_settings',
    setting_record.key,
    result,
    null,
    null
  );

  return result;
exception
  when others then
    update public.system_maintenance_settings
    set
      last_error = sqlerrm,
      updated_at = now()
    where key = 'system_logs_retention';

    perform public.log_system_event(
      'error',
      'database',
      'system_logs',
      'automated_maintenance_failed',
      'Echec de la maintenance automatique des logs systeme.',
      null,
      current_user_id,
      null,
      'system_maintenance_settings',
      'system_logs_retention',
      jsonb_build_object('error', sqlerrm),
      null,
      null
    );

    raise;
end;
$$;

create or replace function public.admin_run_system_logs_maintenance(
  p_force boolean default true,
  p_dry_run boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if not public.is_current_user_system_admin() then
    raise exception 'Acces reserve au super admin.';
  end if;

  return public.run_system_logs_maintenance(
    coalesce(p_force, true),
    coalesce(p_dry_run, false)
  );
end;
$$;

create or replace function public.get_system_logs_maintenance_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  setting_record public.system_maintenance_settings%rowtype;
  cutoff_at timestamptz;
  candidate_count integer := 0;
  total_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if not public.is_current_user_system_admin() then
    raise exception 'Acces reserve au super admin.';
  end if;

  select *
  into setting_record
  from public.system_maintenance_settings
  where key = 'system_logs_retention';

  if setting_record.key is null then
    perform public.run_system_logs_maintenance(false, true);

    select *
    into setting_record
    from public.system_maintenance_settings
    where key = 'system_logs_retention';
  end if;

  cutoff_at := now() - make_interval(days => setting_record.retention_days);

  select count(*)
  into candidate_count
  from public.system_logs
  where created_at < cutoff_at;

  select count(*)
  into total_count
  from public.system_logs;

  return jsonb_build_object(
    'key', setting_record.key,
    'name', setting_record.name,
    'is_enabled', setting_record.is_enabled,
    'retention_days', setting_record.retention_days,
    'run_hour_utc', setting_record.run_hour_utc,
    'last_run_at', setting_record.last_run_at,
    'last_deleted_count', setting_record.last_deleted_count,
    'last_error', setting_record.last_error,
    'next_run_at', setting_record.next_run_at,
    'candidate_count', candidate_count,
    'total_count', total_count,
    'updated_at', setting_record.updated_at
  );
end;
$$;

grant execute on function public.admin_upsert_system_logs_maintenance(
  boolean,
  integer,
  integer
) to authenticated;

grant execute on function public.admin_run_system_logs_maintenance(
  boolean,
  boolean
) to authenticated;

grant execute on function public.get_system_logs_maintenance_status()
to authenticated;

grant execute on function public.run_system_logs_maintenance(boolean, boolean)
to service_role;

do $$
begin
  if exists (
    select 1
    from pg_namespace
    where nspname = 'cron'
  ) then
    begin
      execute $cron$
        select cron.unschedule('megapromo-system-logs-retention')
      $cron$;
    exception
      when others then
        null;
    end;

    begin
      execute $cron$
        select cron.schedule(
          'megapromo-system-logs-retention',
          '15 * * * *',
          $job$select public.run_system_logs_maintenance(false, false);$job$
        )
      $cron$;
    exception
      when others then
        update public.system_maintenance_settings
        set
          last_error = 'Planification pg_cron indisponible: ' || sqlerrm,
          updated_at = now()
        where key = 'system_logs_retention';
    end;
  end if;
end;
$$;

notify pgrst, 'reload schema';
