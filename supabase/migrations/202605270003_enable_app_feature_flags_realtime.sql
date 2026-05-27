-- MegaPromo - Realtime sur les feature flags app
-- Permet a l'app mobile de recevoir immediatement les changements
-- actives/desactives par le SA.

alter table if exists public.app_feature_flags replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.app_feature_flags;
exception
  when duplicate_object then
    null;
  when others then
    null;
end;
$$;

notify pgrst, 'reload schema';
