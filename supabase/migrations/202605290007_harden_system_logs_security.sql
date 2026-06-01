-- MegaPromo - Nettoyage securite des logs systeme
-- A executer apres 202605290006_system_logs_retention_rpc.sql.
-- Renforce la suppression des donnees sensibles dans les metadata,
-- y compris dans les objets imbriques et les tableaux.

create or replace function public.sanitize_system_log_metadata(
  p_metadata jsonb
)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  value_type text := jsonb_typeof(coalesce(p_metadata, '{}'::jsonb));
  item record;
  array_item jsonb;
  sanitized jsonb := '{}'::jsonb;
  sanitized_array jsonb := '[]'::jsonb;
  normalized_key text;
  text_value text;
begin
  if p_metadata is null then
    return '{}'::jsonb;
  end if;

  if value_type = 'object' then
    for item in
      select key, value
      from jsonb_each(p_metadata)
    loop
      normalized_key := lower(
        regexp_replace(item.key, '[^a-z0-9]+', '_', 'g')
      );

      if normalized_key in (
        'otp',
        'password',
        'passcode',
        'pin',
        'token',
        'access_token',
        'refresh_token',
        'authorization',
        'auth',
        'secret',
        'api_key',
        'apikey',
        'service_role_key',
        'fcm_token',
        'identity_document',
        'document_url',
        'document',
        'kyc_document',
        'phone',
        'email',
        'msisdn',
        'mobile_money',
        'mobile_money_number',
        'mm_number',
        'payment_number',
        'account_number',
        'iban'
      )
        or normalized_key like '%token%'
        or normalized_key like '%password%'
        or normalized_key like '%secret%'
        or normalized_key like '%authorization%'
        or normalized_key like '%otp%'
        or normalized_key like '%fcm%'
        or normalized_key like '%document%'
        or normalized_key like '%identity%'
        or normalized_key like '%phone%'
        or normalized_key like '%email%'
        or normalized_key like '%msisdn%'
        or normalized_key like '%mobile_money%'
        or normalized_key like '%payment_number%'
        or normalized_key like '%account_number%'
      then
        continue;
      end if;

      sanitized := sanitized || jsonb_build_object(
        item.key,
        public.sanitize_system_log_metadata(item.value)
      );
    end loop;

    return sanitized;
  end if;

  if value_type = 'array' then
    for array_item in
      select value
      from jsonb_array_elements(p_metadata)
      limit 30
    loop
      sanitized_array := sanitized_array
        || jsonb_build_array(public.sanitize_system_log_metadata(array_item));
    end loop;

    return sanitized_array;
  end if;

  if value_type = 'string' then
    text_value := p_metadata #>> '{}';

    if text_value ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'
      or regexp_replace(text_value, '\s+', '', 'g') ~ '^\+?[0-9]{8,16}$'
    then
      return to_jsonb('[redacted]'::text);
    end if;

    if length(text_value) > 500 then
      return to_jsonb(substring(text_value from 1 for 500));
    end if;
  end if;

  return p_metadata;
end;
$$;

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

  cleaned_metadata := public.sanitize_system_log_metadata(cleaned_metadata);

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

update public.system_logs
set metadata = public.sanitize_system_log_metadata(metadata)
where metadata <> public.sanitize_system_log_metadata(metadata);

revoke insert, update, delete on public.system_logs from authenticated;
grant execute on function public.sanitize_system_log_metadata(jsonb)
to service_role;

notify pgrst, 'reload schema';
