-- MegaPromo - Observabilite systeme, phase 1
-- Cree le journal metier centralise exploitable par le SA.
-- Les erreurs techniques restent dans Crashlytics/Sentry/Supabase Logs,
-- tandis que cette table garde les evenements metier importants.

create table if not exists public.system_logs (
  id uuid primary key default gen_random_uuid(),
  level text not null default 'info',
  source text not null,
  feature text not null,
  action text not null,
  message text not null,
  user_id uuid references public.users(id) on delete set null,
  admin_id uuid references public.users(id) on delete set null,
  partner_id uuid references public.partners(id) on delete set null,
  entity_type text,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now(),
  constraint system_logs_level_check check (
    level in ('debug', 'info', 'warning', 'error')
  ),
  constraint system_logs_source_check check (
    source in (
      'mobile',
      'web_admin',
      'web_partner',
      'landing',
      'edge_function',
      'database'
    )
  ),
  constraint system_logs_metadata_object_check check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index if not exists system_logs_created_at_idx
on public.system_logs(created_at desc);

create index if not exists system_logs_level_created_at_idx
on public.system_logs(level, created_at desc);

create index if not exists system_logs_source_created_at_idx
on public.system_logs(source, created_at desc);

create index if not exists system_logs_feature_action_idx
on public.system_logs(feature, action, created_at desc);

create index if not exists system_logs_user_idx
on public.system_logs(user_id, created_at desc)
where user_id is not null;

create index if not exists system_logs_admin_idx
on public.system_logs(admin_id, created_at desc)
where admin_id is not null;

create index if not exists system_logs_partner_idx
on public.system_logs(partner_id, created_at desc)
where partner_id is not null;

create index if not exists system_logs_entity_idx
on public.system_logs(entity_type, entity_id, created_at desc)
where entity_type is not null;

grant select on public.system_logs to authenticated;
grant select, insert, update, delete on public.system_logs to service_role;

alter table public.system_logs enable row level security;

drop policy if exists "system_logs_admin_select" on public.system_logs;
create policy "system_logs_admin_select"
on public.system_logs
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

create or replace function public.log_system_event(
  p_level text default 'info',
  p_source text default 'database',
  p_feature text default 'system',
  p_action text default 'event',
  p_message text default '',
  p_user_id uuid default null,
  p_admin_id uuid default null,
  p_partner_id uuid default null,
  p_entity_type text default null,
  p_entity_id text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_ip_address text default null,
  p_user_agent text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_level text := lower(trim(coalesce(p_level, 'info')));
  normalized_source text := lower(trim(coalesce(p_source, 'database')));
  cleaned_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
  inserted_log public.system_logs%rowtype;
begin
  if normalized_level not in ('debug', 'info', 'warning', 'error') then
    raise exception 'Niveau de log invalide.';
  end if;

  if normalized_source not in (
    'mobile',
    'web_admin',
    'web_partner',
    'landing',
    'edge_function',
    'database'
  ) then
    raise exception 'Source de log invalide.';
  end if;

  if nullif(trim(coalesce(p_feature, '')), '') is null then
    raise exception 'La feature du log est obligatoire.';
  end if;

  if nullif(trim(coalesce(p_action, '')), '') is null then
    raise exception 'L action du log est obligatoire.';
  end if;

  if nullif(trim(coalesce(p_message, '')), '') is null then
    raise exception 'Le message du log est obligatoire.';
  end if;

  if jsonb_typeof(cleaned_metadata) <> 'object' then
    raise exception 'Les metadata du log doivent etre un objet JSON.';
  end if;

  cleaned_metadata := cleaned_metadata
    - array[
      'otp',
      'password',
      'pin',
      'token',
      'access_token',
      'refresh_token',
      'authorization',
      'fcm_token',
      'service_role_key',
      'identity_document',
      'document_url'
    ];

  insert into public.system_logs (
    level,
    source,
    feature,
    action,
    message,
    user_id,
    admin_id,
    partner_id,
    entity_type,
    entity_id,
    metadata,
    ip_address,
    user_agent,
    created_at
  )
  values (
    normalized_level,
    normalized_source,
    trim(p_feature),
    trim(p_action),
    trim(p_message),
    coalesce(
      p_user_id,
      case when normalized_source = 'mobile' then current_user_id else null end
    ),
    coalesce(
      p_admin_id,
      case
        when normalized_source in ('web_admin', 'web_partner')
          then current_user_id
        else null
      end
    ),
    p_partner_id,
    nullif(trim(coalesce(p_entity_type, '')), ''),
    nullif(trim(coalesce(p_entity_id, '')), ''),
    cleaned_metadata,
    nullif(trim(coalesce(p_ip_address, '')), '')::inet,
    nullif(trim(coalesce(p_user_agent, '')), ''),
    now()
  )
  returning *
  into inserted_log;

  return to_jsonb(inserted_log);
end;
$$;

grant execute on function public.log_system_event(
  text,
  text,
  text,
  text,
  text,
  uuid,
  uuid,
  uuid,
  text,
  text,
  jsonb,
  text,
  text
) to authenticated;

grant execute on function public.log_system_event(
  text,
  text,
  text,
  text,
  text,
  uuid,
  uuid,
  uuid,
  text,
  text,
  jsonb,
  text,
  text
) to service_role;

notify pgrst, 'reload schema';
