-- MegaPromo - Correction droits SA messages info mobile
-- A executer dans Supabase SQL Editor en production.
--
-- Pourquoi:
-- - la correction du ciblage plateforme a resserre les policies SELECT;
-- - elle a aussi supprime d'anciennes policies ALL, ce qui peut bloquer
--   l'ajout, la modification et la suppression des messages par le SA.
--
-- Objectif:
-- - permettre au Super Admin de creer, modifier et supprimer les messages
--   d'information mobile;
-- - conserver le filtrage strict cote joueur.

set lock_timeout = '3s';
set statement_timeout = '30s';

alter table public.mobile_info_messages enable row level security;

drop policy if exists mobile_info_messages_admin_manage_all
  on public.mobile_info_messages;

create policy mobile_info_messages_admin_manage_all
on public.mobile_info_messages
for all
to authenticated
using (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  )
)
with check (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  )
);

grant select, insert, update, delete on public.mobile_info_messages
  to authenticated;

notify pgrst, 'reload schema';
