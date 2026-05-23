-- MegaPromo - Account deletion lifecycle
-- Adds a 30-day pending deletion state so players can reactivate before
-- permanent anonymization. Historical business rows remain available to admins.

alter table public.users
add column if not exists account_status text not null default 'active',
add column if not exists deletion_requested_at timestamptz,
add column if not exists deletion_scheduled_at timestamptz,
add column if not exists deleted_at timestamptz,
add column if not exists anonymized_ref text,
add column if not exists active_device_session_id text,
add column if not exists active_device_info jsonb default '{}'::jsonb,
add column if not exists active_device_seen_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'users_account_status_check'
  ) then
    alter table public.users
    add constraint users_account_status_check
    check (account_status in ('active', 'pending_deletion', 'deleted'));
  end if;
end $$;

create index if not exists users_account_status_idx
on public.users(account_status, deletion_scheduled_at);

update public.users
set account_status = 'pending_deletion',
    deletion_requested_at = coalesce(deletion_requested_at, now()),
    deletion_scheduled_at = coalesce(
      deletion_scheduled_at,
      now() + interval '30 days'
    )
where is_active = false
  and account_status = 'active';

create or replace function public.process_due_account_deletions()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_count int := 0;
begin
  update public.users
  set account_status = 'deleted',
      is_active = false,
      deleted_at = coalesce(deleted_at, now()),
      anonymized_ref = coalesce(
        anonymized_ref,
        'deleted-player-' || substring(id::text from 1 for 8)
      ),
      phone = null,
      username = 'Joueur supprimé',
      avatar_url = null,
      fcm_token = null,
      active_device_session_id = null,
      active_device_info = '{}'::jsonb,
      active_device_seen_at = null
  where account_status = 'pending_deletion'
    and deletion_scheduled_at is not null
    and deletion_scheduled_at <= now();

  get diagnostics affected_count = row_count;
  return affected_count;
end;
$$;
