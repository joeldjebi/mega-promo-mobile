-- MegaPromo - Correction ciblage plateforme messages info mobile
-- A executer dans Supabase SQL Editor en production.
--
-- Pourquoi:
-- - apres ajout du ciblage iOS/Android, des messages Android ont pu rester
--   visibles sur iOS si une ancienne policy SELECT permissive existait encore,
--   ou si la plateforme joueur etait inconnue et tombee sur un defaut Android.
--
-- Objectif:
-- - supprimer les policies SELECT precedentes sur mobile_info_messages;
-- - laisser le SA voir tous les messages pour les gerer;
-- - ne laisser les joueurs voir que les messages actifs ciblant leur plateforme;
-- - ne jamais considerer une plateforme inconnue comme Android.

set lock_timeout = '3s';
set statement_timeout = '30s';

alter table public.mobile_info_messages enable row level security;

alter table public.mobile_info_messages
  add column if not exists target_platforms text[] not null
  default array['ios', 'android']::text[];

update public.mobile_info_messages
set target_platforms = array['ios', 'android']::text[]
where target_platforms is null
   or cardinality(target_platforms) = 0;

alter table public.mobile_info_messages
  drop constraint if exists mobile_info_messages_target_platforms_check;

alter table public.mobile_info_messages
  add constraint mobile_info_messages_target_platforms_check
  check (
    cardinality(target_platforms) between 1 and 2
    and target_platforms <@ array['ios', 'android']::text[]
  );

do $$
declare
  policy_record record;
begin
  for policy_record in
    select pg_policies.policyname
    from pg_policies
    where pg_policies.schemaname = 'public'
      and pg_policies.tablename = 'mobile_info_messages'
      and pg_policies.cmd in ('SELECT', 'ALL')
  loop
    execute format(
      'drop policy if exists %I on public.mobile_info_messages',
      policy_record.policyname
    );
  end loop;
end $$;

create policy mobile_info_messages_admin_select_all
on public.mobile_info_messages
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

create policy mobile_info_messages_player_select_targeted
on public.mobile_info_messages
for select
to authenticated
using (
  coalesce(is_active, true) = true
  and exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and coalesce(users.role, 'player') not in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
      and target_platforms @> array[
        lower(
          nullif(
            btrim(
              coalesce(
                users.fcm_token_platform,
                users.device_info ->> 'os',
                users.device_info ->> 'platform',
                ''
              )
            ),
            ''
          )
        )
      ]::text[]
  )
);

notify pgrst, 'reload schema';
