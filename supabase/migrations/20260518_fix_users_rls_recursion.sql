-- Fixes "infinite recursion detected in policy for relation users".
-- Run this in Supabase SQL editor if an existing users policy queries users
-- from inside a users policy, for example with EXISTS (select ... from users).

drop policy if exists "users_select_own_profile" on public.users;
drop policy if exists "users_insert_own_profile" on public.users;
drop policy if exists "users_update_own_profile" on public.users;

create policy "users_select_own_profile"
on public.users
for select
to authenticated
using (id = auth.uid());

create policy "users_insert_own_profile"
on public.users
for insert
to authenticated
with check (id = auth.uid());

create policy "users_update_own_profile"
on public.users
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());
