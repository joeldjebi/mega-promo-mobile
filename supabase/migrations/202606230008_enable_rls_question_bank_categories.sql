-- MegaPromo - Correctif RLS cible pour question_bank_categories
-- A executer dans Supabase SQL Editor en production.
--
-- Objectif:
-- - corriger l'alerte Supabase Advisor:
--   "RLS Disabled in Public: public.question_bank_categories";
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

alter table public.question_bank_categories enable row level security;

drop policy if exists "question_bank_categories_public_select_active" on public.question_bank_categories;
create policy "question_bank_categories_public_select_active"
on public.question_bank_categories
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.question_banks
    where question_banks.id = question_bank_categories.question_bank_id
      and coalesce(question_banks.is_active, true) = true
  )
  and exists (
    select 1
    from public.categories
    where categories.id = question_bank_categories.category_id
      and coalesce(categories.is_active, true) = true
  )
);

drop policy if exists "question_bank_categories_admin_insert" on public.question_bank_categories;
create policy "question_bank_categories_admin_insert"
on public.question_bank_categories
for insert
to authenticated
with check (public.is_active_admin());

drop policy if exists "question_bank_categories_admin_update" on public.question_bank_categories;
create policy "question_bank_categories_admin_update"
on public.question_bank_categories
for update
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

drop policy if exists "question_bank_categories_admin_delete" on public.question_bank_categories;
create policy "question_bank_categories_admin_delete"
on public.question_bank_categories
for delete
to authenticated
using (public.is_active_admin());

notify pgrst, 'reload schema';
