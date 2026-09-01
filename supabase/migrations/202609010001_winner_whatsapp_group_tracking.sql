-- MegaPromo - Suivi groupe WhatsApp des gagnants
-- A executer dans Supabase SQL Editor en production.
--
-- Objectif:
-- - permettre au SA de marquer un joueur comme ajoute au groupe WhatsApp
--   des gagnants;
-- - afficher ce statut depuis la liste des gagnants et la liste des joueurs;
-- - ne pas modifier les gains existants.

set lock_timeout = '3s';
set statement_timeout = '30s';

alter table public.users
  add column if not exists whatsapp_group_added_at timestamptz;

comment on column public.users.whatsapp_group_added_at is
  'Date a laquelle le SA a marque le joueur comme ajoute au groupe WhatsApp des gagnants.';

notify pgrst, 'reload schema';
