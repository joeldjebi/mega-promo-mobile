-- MegaPromo - Textes administrables des règles JCQ et QL
-- A exécuter dans Supabase SQL Editor.
--
-- Objectif:
-- - fournir à l'app mobile les règles et objectifs des JCQ et Quiz Live;
-- - permettre au Super Admin de modifier ces textes depuis l'espace web;
-- - conserver les personnalisations existantes lors des prochains passages SQL.

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
  'quiz_rules_content',
  'Règles JCQ et Quiz Live',
  'Textes affichés dans l''app mobile pour expliquer les objectifs et règles des JCQ et QL.',
  true,
  '{
    "jcq": {
      "enabled": true,
      "show_count": 3,
      "title": "Règles du JCQ",
      "objective": "Réponds aux questions, marque le maximum de points et tente de gagner la récompense annoncée.",
      "rules": [
        "Le JCQ se joue à ton rythme, tant que le concours est ouvert.",
        "Chaque question a une seule bonne réponse.",
        "Les bonnes réponses rapportent des points selon la difficulté.",
        "Le classement tient compte du score et du temps de réponse.",
        "Une participation validée ne peut plus être recommencée."
      ]
    },
    "ql": {
      "enabled": true,
      "show_count": 2,
      "title": "Règles du Quiz Live",
      "objective": "Rejoins l’arène à l’heure prévue, réponds en direct et vise la meilleure place au classement.",
      "rules": [
        "Le QL démarre à une heure précise pour tous les joueurs inscrits.",
        "Réserve ta place avant le départ et entre en salle d’attente.",
        "Les questions s’enchaînent en direct avec un temps limité.",
        "Le score dépend des bonnes réponses et de ta rapidité.",
        "Une déconnexion ou un retard peut te faire perdre des points."
      ]
    }
  }'::jsonb,
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
