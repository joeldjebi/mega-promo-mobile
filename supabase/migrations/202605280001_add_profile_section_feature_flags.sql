-- MegaPromo - Flags sections profil joueur
-- Permet au SA de masquer/afficher les coordonnees et recompenses
-- dans la page profil de l'application mobile, en realtime.

insert into public.app_feature_flags (
  key,
  name,
  description,
  is_enabled,
  metadata,
  created_at,
  updated_at
)
values
  (
    'player_profile_coordinates',
    'Coordonnees profil joueur',
    'Affiche ou masque le bouton Coordonnees dans le profil joueur mobile.',
    true,
    jsonb_build_object(
      'scope',
      'mobile_profile',
      'section',
      'coordinates',
      'managed_from',
      'players',
      'realtime',
      true
    ),
    now(),
    now()
  ),
  (
    'player_profile_rewards',
    'Recompenses profil joueur',
    'Affiche ou masque le bouton Recompenses dans le profil joueur mobile.',
    true,
    jsonb_build_object(
      'scope',
      'mobile_profile',
      'section',
      'rewards',
      'managed_from',
      'winners',
      'realtime',
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
