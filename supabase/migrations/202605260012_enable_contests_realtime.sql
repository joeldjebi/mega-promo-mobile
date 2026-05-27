-- MegaPromo - Activer le realtime sur les concours
-- Permet a l'app mobile de se mettre a jour quand un jeu concours ou QL
-- est cree/modifie/supprime.

do $$
begin
  alter publication supabase_realtime add table public.contests;
exception
  when duplicate_object then
    null;
  when others then
    null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.questions;
exception
  when duplicate_object then
    null;
  when others then
    null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.categories;
exception
  when duplicate_object then
    null;
  when others then
    null;
end;
$$;

alter table public.contests replica identity full;
alter table public.questions replica identity full;
alter table public.categories replica identity full;
