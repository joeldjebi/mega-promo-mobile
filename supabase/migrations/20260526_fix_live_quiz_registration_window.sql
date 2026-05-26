-- MegaPromo - Correction fenetre inscription Quiz Live
-- A executer dans Supabase SQL Editor si les joueurs ne peuvent plus
-- s'inscrire/entrer en salle d'attente avant le depart du QL.
-- starts_at ouvre l'inscription; live_starts_at reste le vrai depart du jeu.

update public.contests
set starts_at = now()
where coalesce(is_live, false) = true
  and coalesce(status, 'active') = 'active'
  and live_starts_at is not null
  and live_starts_at > now()
  and (
    starts_at is null
    or starts_at > now()
  );

notify pgrst, 'reload schema';
