-- MegaPromo - Realtime pour les logs systeme
-- A executer apres 202605290003_create_system_logs.sql.
-- Permet a la page SA "Logs systeme" de recevoir les nouveaux evenements
-- sans rechargement manuel.

do $$
begin
  alter publication supabase_realtime add table public.system_logs;
exception
  when duplicate_object then
    null;
  when others then
    null;
end;
$$;

alter table public.system_logs replica identity full;
