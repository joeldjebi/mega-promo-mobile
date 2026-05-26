-- MegaPromo - Autoriser le SA a creer des notifications joueur
-- A executer dans Supabase SQL Editor.
-- Necessaire pour notifier le joueur apres validation/rejet KYC depuis le SA.

grant select, insert, update on public.notifications to authenticated;

drop policy if exists "notifications_admin_insert"
on public.notifications;

create policy "notifications_admin_insert"
on public.notifications
for insert
to authenticated
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

notify pgrst, 'reload schema';
