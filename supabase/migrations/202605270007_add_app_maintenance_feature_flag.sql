-- MegaPromo - Mode maintenance global
-- A executer apres 202605270002_create_app_feature_flags.sql.
-- Le SA peut activer ce flag pour rediriger les joueurs vers la page maintenance.

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
  'app_maintenance',
  'Mode maintenance',
  'Bloque temporairement l''acces joueur a l''application mobile et affiche une page maintenance.',
  false,
  jsonb_build_object(
    'scope',
    'mobile',
    'blocks_players',
    true,
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
