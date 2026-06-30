-- MegaPromo - Ciblage plateforme des messages d'information mobile
-- A executer dans Supabase SQL Editor en production.
--
-- Objectif:
-- - permettre au SA de cibler un message d'information sur iOS, Android,
--   ou iOS/Android;
-- - conserver le comportement actuel par defaut: tous les messages existants
--   restent visibles sur iOS et Android;
-- - eviter une mise a jour obligatoire de l'app mobile deja en production:
--   le filtrage se fait cote Supabase via RLS.

set lock_timeout = '3s';
set statement_timeout = '30s';

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

drop policy if exists mobile_info_messages_select_active
  on public.mobile_info_messages;

create policy mobile_info_messages_select_active
on public.mobile_info_messages
for select
to authenticated
using (
  coalesce(is_active, true) = true
  and (
    target_platforms @> array[
      coalesce(
        (
          select lower(nullif(btrim(users.fcm_token_platform), ''))
          from public.users
          where users.id = auth.uid()
          limit 1
        ),
        'android'
      )
    ]::text[]
  )
);

notify pgrst, 'reload schema';
