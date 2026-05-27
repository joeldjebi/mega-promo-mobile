-- MegaPromo - Feature flags applicatifs
-- Permet au SA de masquer/afficher certaines fonctionnalites joueur
-- sans redeployer les apps.

create table if not exists public.app_feature_flags (
  key text primary key,
  name text not null,
  description text,
  is_enabled boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  updated_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.app_feature_flags (
  key,
  name,
  description,
  is_enabled,
  created_at,
  updated_at
)
values (
  'player_subscriptions',
  'Bouton forfait joueur',
  'Affiche ou masque l''acces aux forfaits dans le profil joueur.',
  true,
  now(),
  now()
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  updated_at = now();

grant select on public.app_feature_flags to authenticated;
grant insert, update on public.app_feature_flags to authenticated;

alter table public.app_feature_flags enable row level security;
alter table public.app_feature_flags replica identity full;

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

drop policy if exists "app_feature_flags_authenticated_select"
on public.app_feature_flags;
create policy "app_feature_flags_authenticated_select"
on public.app_feature_flags
for select
to authenticated
using (true);

drop policy if exists "app_feature_flags_admin_insert"
on public.app_feature_flags;
create policy "app_feature_flags_admin_insert"
on public.app_feature_flags
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

drop policy if exists "app_feature_flags_admin_update"
on public.app_feature_flags;
create policy "app_feature_flags_admin_update"
on public.app_feature_flags
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
