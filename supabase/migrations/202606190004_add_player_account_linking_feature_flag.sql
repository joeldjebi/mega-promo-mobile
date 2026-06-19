-- MegaPromo - Controle SA pour la liaison des moyens de connexion
-- A executer dans Supabase SQL Editor.
--
-- Objectif:
-- - permettre au Super Admin d'autoriser ou non les joueurs a lier Google,
--   Apple et telephone au meme compte;
-- - laisser l'option active par defaut pour conserver le comportement actuel.

insert into public.app_feature_flags (
  key,
  name,
  description,
  is_enabled,
  metadata,
  created_at,
  updated_at
)
values (
  'player_account_linking',
  'Liaison des comptes joueur',
  'Autorise les joueurs a lier Google, Apple et telephone au meme compte depuis le profil mobile.',
  true,
  '{"scope": "mobile_profile", "default": true}'::jsonb,
  now(),
  now()
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  metadata = excluded.metadata || public.app_feature_flags.metadata,
  updated_at = now();

grant select on public.app_feature_flags to authenticated, anon;
grant select on public.app_feature_flags to service_role;

notify pgrst, 'reload schema';
