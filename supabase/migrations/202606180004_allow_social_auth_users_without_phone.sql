-- MegaPromo - Autoriser les comptes sociaux sans telephone
-- A executer dans Supabase SQL Editor.
--
-- Objectif:
-- - Google/Apple Auth ne fournissent pas toujours de numero de telephone;
-- - permettre la creation du profil public.users avant l'onboarding pseudo;
-- - conserver le telephone pour les comptes OTP quand il existe.

alter table public.users
alter column phone drop not null;

notify pgrst, 'reload schema';
