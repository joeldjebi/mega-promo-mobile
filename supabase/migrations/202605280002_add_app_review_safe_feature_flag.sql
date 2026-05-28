-- MegaPromo - Mode review safe App Store / Play Store
-- Permet au SA d'activer/desactiver en realtime la presentation de conformite:
-- montants masques, forfaits masques, tirages/pronostics masques.

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
  'app_review_safe',
  'Mode review safe',
  'Active la presentation de conformite pour les stores: montants masques, forfaits masques, tirages et pronostics masques.',
  true,
  jsonb_build_object(
    'scope',
    'mobile',
    'managed_from',
    'dashboard',
    'realtime',
    true,
    'store_review',
    true
  ),
  now(),
  now()
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  metadata = public.app_feature_flags.metadata || excluded.metadata,
  updated_at = now();

notify pgrst, 'reload schema';
