-- MegaPromo - Acces SA aux moyens de paiement joueur et KYC
-- A executer dans Supabase SQL Editor apres 20260524_create_player_payment_methods_and_kyc.sql.
-- Corrige les policies trop strictes qui limitaient l'acces au role "admin".

drop policy if exists "player_payment_methods_admin_select"
on public.player_payment_methods;

create policy "player_payment_methods_admin_select"
on public.player_payment_methods
for select
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
);

drop policy if exists "player_kyc_requests_admin_select"
on public.player_kyc_requests;

create policy "player_kyc_requests_admin_select"
on public.player_kyc_requests
for select
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
);

drop policy if exists "player_kyc_requests_admin_update"
on public.player_kyc_requests;

create policy "player_kyc_requests_admin_update"
on public.player_kyc_requests
for update
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

notify pgrst, 'reload schema';
