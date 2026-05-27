-- MegaPromo - Planifier le traitement automatique des concours
-- A executer dans Supabase SQL Editor apres:
-- 202605260009_process_contest_events_all.sql
--
-- Necessite l'extension pg_cron activee sur le projet Supabase.
-- Le job passe chaque minute pour:
-- - cloturer les QL expires
-- - designer les gagnants des jeux concours/quiz termines
-- - creer les notifications winner qui ouvrent la page de felicitation.

create extension if not exists pg_cron with schema extensions;

do $$
begin
  perform cron.unschedule('megapromo-process-contest-events');
exception
  when others then
    null;
end;
$$;

select cron.schedule(
  'megapromo-process-contest-events',
  '* * * * *',
  'select public.process_contest_events();'
);

select public.process_contest_events() as processed_contest_events_now;
