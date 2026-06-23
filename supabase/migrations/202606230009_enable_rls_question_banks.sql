-- MegaPromo - Correctif RLS cible pour question_banks
-- A executer dans Supabase SQL Editor en production.
--
-- Objectif:
-- - corriger l'alerte Supabase Advisor:
--   "RLS Disabled in Public: public.question_banks";
-- - conserver la lecture necessaire a l'app mobile et a la landing;
-- - reserver les modifications aux admins actifs.

create or replace function public.is_active_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
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
  );
$$;

grant execute on function public.is_active_admin()
to authenticated, service_role;

alter table public.question_banks enable row level security;

drop policy if exists "question_banks_public_select_active" on public.question_banks;
create policy "question_banks_public_select_active"
on public.question_banks
for select
to anon, authenticated
using (coalesce(is_active, true) = true);

drop policy if exists "question_banks_admin_insert" on public.question_banks;
create policy "question_banks_admin_insert"
on public.question_banks
for insert
to authenticated
with check (public.is_active_admin());

drop policy if exists "question_banks_admin_update" on public.question_banks;
create policy "question_banks_admin_update"
on public.question_banks
for update
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

drop policy if exists "question_banks_admin_delete" on public.question_banks;
create policy "question_banks_admin_delete"
on public.question_banks
for delete
to authenticated
using (public.is_active_admin());

notify pgrst, 'reload schema';
