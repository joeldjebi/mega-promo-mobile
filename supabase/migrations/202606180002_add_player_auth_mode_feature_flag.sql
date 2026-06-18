-- MegaPromo - Mode d'authentification joueur
-- A executer dans Supabase SQL Editor.
--
-- Objectif:
-- - permettre au Super Admin de choisir le mode de connexion joueur;
-- - garder OTP comme mode par defaut tant que Google/Apple ne sont pas
--   configures dans Supabase Auth;
-- - modes supportes:
--   * otp: numero + code OTP;
--   * social: Google + Apple uniquement;
--   * hybrid: Google + Apple + OTP.

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
  'player_auth_mode',
  'Mode authentification joueur',
  'Choisit les moyens de connexion dans l''application mobile: OTP, Google + Apple ou mode hybride.',
  true,
  '{"mode": "otp", "allowed_modes": ["otp", "social", "hybrid"], "redirect_url": "megapromo://login-callback/"}'::jsonb,
  now(),
  now()
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_enabled = true,
  metadata = excluded.metadata || public.app_feature_flags.metadata,
  updated_at = now();

grant select on public.app_feature_flags to authenticated, anon;
grant select on public.app_feature_flags to service_role;

notify pgrst, 'reload schema';
