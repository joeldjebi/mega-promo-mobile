-- MegaPromo - Lecture publique des feature flags necessaires au login
-- A executer dans Supabase SQL Editor.
--
-- Objectif:
-- - permettre a l'app mobile non connectee de lire player_auth_mode,
--   otp_delivery_channel et les flags publics;
-- - corriger le cas ou GRANT SELECT existe mais RLS bloque encore le role anon.

grant select on public.app_feature_flags to authenticated, anon;
grant select on public.app_feature_flags to service_role;

drop policy if exists "app_feature_flags_public_select"
on public.app_feature_flags;

create policy "app_feature_flags_public_select"
on public.app_feature_flags
for select
to anon, authenticated
using (true);

notify pgrst, 'reload schema';
