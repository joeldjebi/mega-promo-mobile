-- MegaPromo - Metadata plateformes pour les tokens push
-- A executer dans Supabase SQL Editor.
-- Permet de differencier les tokens iOS/Android/Web et de diagnostiquer
-- les echecs FCM sans confondre les tests du SA avec l'app mobile.

alter table public.users
add column if not exists fcm_token_platform text,
add column if not exists fcm_token_updated_at timestamptz,
add column if not exists fcm_token_last_error text,
add column if not exists fcm_token_last_error_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'users_fcm_token_platform_check'
  ) then
    alter table public.users
    add constraint users_fcm_token_platform_check
    check (
      fcm_token_platform is null
      or fcm_token_platform in ('ios', 'android', 'web', 'unknown')
    );
  end if;
end;
$$;

create index if not exists users_fcm_token_platform_idx
on public.users(fcm_token_platform)
where fcm_token is not null;
