-- MegaPromo - Recompenses manuelles
-- A executer dans Supabase SQL Editor.
-- Ajoute une premiere gestion manuelle des lots: code de reduction, bon,
-- ticket, mobile money ou autre lot traite par le SA.

create table if not exists public.reward_types (
  key text primary key,
  name text not null,
  description text,
  icon text,
  color text,
  is_active bool not null default true,
  order_index integer not null default 0,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.reward_types (
  key,
  name,
  description,
  icon,
  color,
  is_active,
  order_index,
  created_at,
  updated_at
)
values
  (
    'mobile_money',
    'Mobile Money',
    'Gain payé par Mobile Money.',
    'wallet',
    '#16A34A',
    true,
    1,
    now(),
    now()
  ),
  (
    'discount_code',
    'Code réduction',
    'Code promotionnel à utiliser chez un partenaire.',
    'ticket',
    '#7C3AED',
    true,
    2,
    now(),
    now()
  ),
  (
    'voucher',
    'Bon de réduction',
    'Bon ou coupon de réduction remis au gagnant.',
    'tag',
    '#2563EB',
    true,
    3,
    now(),
    now()
  ),
  (
    'concert_ticket',
    'Ticket de concert',
    'Billet ou invitation à un évènement.',
    'event',
    '#DB2777',
    true,
    4,
    now(),
    now()
  ),
  (
    'physical_item',
    'Lot physique',
    'Produit ou lot à remettre physiquement.',
    'gift',
    '#EA580C',
    true,
    5,
    now(),
    now()
  ),
  (
    'manual',
    'Manuel',
    'Gain traité manuellement par le SA.',
    'gift',
    '#475569',
    true,
    6,
    now(),
    now()
  )
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  icon = excluded.icon,
  color = excluded.color,
  is_active = true,
  order_index = excluded.order_index,
  updated_at = now();

create table if not exists public.reward_catalog (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  reward_type text not null default 'manual',
  description text,
  value_label text,
  estimated_value numeric not null default 0,
  partner_id uuid references public.partners(id) on delete set null,
  default_code text,
  default_delivery_instructions text,
  terms text,
  stock_quantity integer,
  used_quantity integer not null default 0,
  is_active bool not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.contests
add column if not exists reward_type text default 'mobile_money';

alter table public.contests
add column if not exists reward_catalog_id uuid
references public.reward_catalog(id) on delete set null;

alter table public.contests
add column if not exists reward_delivery_mode text not null default 'manual';

alter table public.contests
add column if not exists reward_delivery_instructions text;

alter table public.contests
add column if not exists reward_terms text;

alter table public.contests
add column if not exists reward_metadata jsonb not null default '{}'::jsonb;

alter table public.winners
add column if not exists reward_type text;

alter table public.winners
add column if not exists reward_catalog_id uuid
references public.reward_catalog(id) on delete set null;

alter table public.winners
add column if not exists reward_code text;

alter table public.winners
add column if not exists reward_claim_status text not null default 'pending';

alter table public.winners
add column if not exists reward_delivery_instructions text;

alter table public.winners
add column if not exists reward_notes text;

alter table public.winners
add column if not exists reward_metadata jsonb not null default '{}'::jsonb;

do $$
begin
  alter table public.reward_catalog
  drop constraint if exists reward_catalog_type_check;

  alter table public.contests
  drop constraint if exists contests_reward_type_check;

  alter table public.winners
  drop constraint if exists winners_reward_type_check;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'reward_catalog_stock_quantity_check'
  ) then
    alter table public.reward_catalog
    add constraint reward_catalog_stock_quantity_check
    check (stock_quantity is null or stock_quantity >= 0);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'reward_catalog_used_quantity_check'
  ) then
    alter table public.reward_catalog
    add constraint reward_catalog_used_quantity_check
    check (used_quantity >= 0);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'contests_reward_delivery_mode_check'
  ) then
    alter table public.contests
    add constraint contests_reward_delivery_mode_check
    check (reward_delivery_mode in ('manual', 'automatic', 'claim_required'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'winners_reward_claim_status_check'
  ) then
    alter table public.winners
    add constraint winners_reward_claim_status_check
    check (
      reward_claim_status in (
        'pending',
        'ready',
        'sent',
        'claimed',
        'used',
        'expired',
        'cancelled'
      )
    );
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reward_catalog_reward_type_fkey'
  ) then
    alter table public.reward_catalog
    add constraint reward_catalog_reward_type_fkey
    foreign key (reward_type)
    references public.reward_types(key)
    on update cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'contests_reward_type_fkey'
  ) then
    alter table public.contests
    add constraint contests_reward_type_fkey
    foreign key (reward_type)
    references public.reward_types(key)
    on update cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'winners_reward_type_fkey'
  ) then
    alter table public.winners
    add constraint winners_reward_type_fkey
    foreign key (reward_type)
    references public.reward_types(key)
    on update cascade;
  end if;
end;
$$;

create index if not exists winners_reward_claim_status_idx
on public.winners(reward_claim_status, created_at desc);

create index if not exists reward_types_active_order_idx
on public.reward_types(is_active, order_index, name);

create index if not exists reward_catalog_active_type_idx
on public.reward_catalog(is_active, reward_type, name);

create index if not exists reward_catalog_partner_idx
on public.reward_catalog(partner_id, is_active);

grant select, insert, update on public.reward_types to authenticated;
grant select, insert, update on public.reward_catalog to authenticated;
grant select, update on public.winners to authenticated;
grant select, update on public.contests to authenticated;

alter table public.reward_types enable row level security;
alter table public.reward_catalog enable row level security;

drop policy if exists "reward_types_admin_select" on public.reward_types;
create policy "reward_types_admin_select"
on public.reward_types
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

drop policy if exists "reward_types_admin_insert" on public.reward_types;
create policy "reward_types_admin_insert"
on public.reward_types
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

drop policy if exists "reward_types_admin_update" on public.reward_types;
create policy "reward_types_admin_update"
on public.reward_types
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

drop policy if exists "reward_catalog_admin_select" on public.reward_catalog;
create policy "reward_catalog_admin_select"
on public.reward_catalog
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

drop policy if exists "reward_catalog_admin_insert" on public.reward_catalog;
create policy "reward_catalog_admin_insert"
on public.reward_catalog
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

drop policy if exists "reward_catalog_admin_update" on public.reward_catalog;
create policy "reward_catalog_admin_update"
on public.reward_catalog
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

create or replace function public.apply_manual_reward_defaults()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  catalog_record public.reward_catalog%rowtype;
  contest_reward_type text;
  contest_reward_catalog_id uuid;
  contest_reward_delivery_instructions text;
  contest_reward_metadata jsonb;
begin
  select
    contests.reward_type,
    contests.reward_catalog_id,
    contests.reward_delivery_instructions,
    contests.reward_metadata
  into
    contest_reward_type,
    contest_reward_catalog_id,
    contest_reward_delivery_instructions,
    contest_reward_metadata
  from public.contests
  where contests.id = new.contest_id
  limit 1;

  if contest_reward_catalog_id is not null then
    select *
    into catalog_record
    from public.reward_catalog
    where id = contest_reward_catalog_id
      and coalesce(is_active, true) = true
    limit 1;
  end if;

  new.reward_catalog_id := coalesce(new.reward_catalog_id, catalog_record.id);
  new.reward_type := coalesce(
    nullif(new.reward_type, ''),
    nullif(catalog_record.reward_type, ''),
    nullif(contest_reward_type, ''),
    case
      when coalesce(new.prize_value, 0) > 0 then 'mobile_money'
      else 'manual'
    end
  );
  new.reward_claim_status := coalesce(
    nullif(new.reward_claim_status, ''),
    'pending'
  );
  new.reward_delivery_instructions := coalesce(
    nullif(new.reward_delivery_instructions, ''),
    nullif(catalog_record.default_delivery_instructions, ''),
    nullif(contest_reward_delivery_instructions, '')
  );
  new.reward_code := coalesce(
    nullif(new.reward_code, ''),
    nullif(catalog_record.default_code, '')
  );
  new.reward_metadata := coalesce(new.reward_metadata, '{}'::jsonb)
    || coalesce(catalog_record.metadata, '{}'::jsonb)
    || coalesce(contest_reward_metadata, '{}'::jsonb);

  return new;
end;
$$;

drop trigger if exists winners_apply_manual_reward_defaults on public.winners;
create trigger winners_apply_manual_reward_defaults
before insert on public.winners
for each row
execute function public.apply_manual_reward_defaults();

update public.winners
set
  reward_type = coalesce(
    reward_type,
    case
      when coalesce(prize_value, 0) > 0 then 'mobile_money'
      else 'manual'
    end
  ),
  reward_claim_status = coalesce(reward_claim_status, 'pending'),
  reward_metadata = coalesce(reward_metadata, '{}'::jsonb)
where reward_type is null
  or reward_claim_status is null
  or reward_metadata is null;

drop policy if exists "winners_admin_select" on public.winners;
create policy "winners_admin_select"
on public.winners
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

drop policy if exists "winners_admin_update_rewards" on public.winners;
create policy "winners_admin_update_rewards"
on public.winners
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

drop policy if exists "contests_admin_update_rewards" on public.contests;
create policy "contests_admin_update_rewards"
on public.contests
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

create or replace function public.upsert_reward_catalog_item(
  p_item_id uuid default null,
  p_name text default '',
  p_reward_type text default 'manual',
  p_description text default null,
  p_value_label text default null,
  p_estimated_value numeric default 0,
  p_partner_id uuid default null,
  p_default_code text default null,
  p_default_delivery_instructions text default null,
  p_terms text default null,
  p_stock_quantity integer default null,
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  reward_record public.reward_catalog%rowtype;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if not exists (
    select 1
    from public.users
    where users.id = current_user_id
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  ) then
    raise exception 'Acces reserve au super admin.';
  end if;

  if nullif(trim(coalesce(p_name, '')), '') is null then
    raise exception 'Le nom du gain est obligatoire.';
  end if;

  if not exists (
    select 1
    from public.reward_types
    where reward_types.key = p_reward_type
      and coalesce(reward_types.is_active, true) = true
  ) then
    raise exception 'Type de recompense invalide.';
  end if;

  if p_stock_quantity is not null and p_stock_quantity < 0 then
    raise exception 'Le stock ne peut pas etre negatif.';
  end if;

  if p_item_id is null then
    insert into public.reward_catalog (
      name,
      reward_type,
      description,
      value_label,
      estimated_value,
      partner_id,
      default_code,
      default_delivery_instructions,
      terms,
      stock_quantity,
      is_active,
      created_by,
      created_at,
      updated_at
    )
    values (
      trim(p_name),
      p_reward_type,
      nullif(trim(coalesce(p_description, '')), ''),
      nullif(trim(coalesce(p_value_label, '')), ''),
      greatest(coalesce(p_estimated_value, 0), 0),
      p_partner_id,
      nullif(trim(coalesce(p_default_code, '')), ''),
      nullif(trim(coalesce(p_default_delivery_instructions, '')), ''),
      nullif(trim(coalesce(p_terms, '')), ''),
      p_stock_quantity,
      coalesce(p_is_active, true),
      current_user_id,
      now(),
      now()
    )
    returning *
    into reward_record;
  else
    update public.reward_catalog
    set
      name = trim(p_name),
      reward_type = p_reward_type,
      description = nullif(trim(coalesce(p_description, '')), ''),
      value_label = nullif(trim(coalesce(p_value_label, '')), ''),
      estimated_value = greatest(coalesce(p_estimated_value, 0), 0),
      partner_id = p_partner_id,
      default_code = nullif(trim(coalesce(p_default_code, '')), ''),
      default_delivery_instructions =
        nullif(trim(coalesce(p_default_delivery_instructions, '')), ''),
      terms = nullif(trim(coalesce(p_terms, '')), ''),
      stock_quantity = p_stock_quantity,
      is_active = coalesce(p_is_active, true),
      updated_at = now()
    where id = p_item_id
    returning *
    into reward_record;

    if reward_record.id is null then
      raise exception 'Gain introuvable dans le catalogue.';
    end if;
  end if;

  return to_jsonb(reward_record);
end;
$$;

create or replace function public.upsert_reward_type(
  p_key text default '',
  p_name text default '',
  p_description text default null,
  p_icon text default null,
  p_color text default null,
  p_is_active boolean default true,
  p_order_index integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_key text := lower(
    regexp_replace(trim(coalesce(p_key, '')), '[^a-z0-9_]+', '_', 'g')
  );
  reward_type_record public.reward_types%rowtype;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if not exists (
    select 1
    from public.users
    where users.id = current_user_id
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  ) then
    raise exception 'Acces reserve au super admin.';
  end if;

  if nullif(normalized_key, '') is null then
    raise exception 'La cle du type est obligatoire.';
  end if;

  if nullif(trim(coalesce(p_name, '')), '') is null then
    raise exception 'Le nom du type est obligatoire.';
  end if;

  insert into public.reward_types (
    key,
    name,
    description,
    icon,
    color,
    is_active,
    order_index,
    created_by,
    created_at,
    updated_at
  )
  values (
    normalized_key,
    trim(p_name),
    nullif(trim(coalesce(p_description, '')), ''),
    nullif(trim(coalesce(p_icon, '')), ''),
    nullif(trim(coalesce(p_color, '')), ''),
    coalesce(p_is_active, true),
    coalesce(p_order_index, 0),
    current_user_id,
    now(),
    now()
  )
  on conflict (key) do update set
    name = excluded.name,
    description = excluded.description,
    icon = excluded.icon,
    color = excluded.color,
    is_active = excluded.is_active,
    order_index = excluded.order_index,
    updated_at = now()
  returning *
  into reward_type_record;

  return to_jsonb(reward_type_record);
end;
$$;

create or replace function public.disable_reward_type(
  p_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  reward_type_record public.reward_types%rowtype;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if not exists (
    select 1
    from public.users
    where users.id = current_user_id
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  ) then
    raise exception 'Acces reserve au super admin.';
  end if;

  if exists (
    select 1
    from public.reward_catalog
    where reward_catalog.reward_type = p_key
      and coalesce(reward_catalog.is_active, true) = true
  ) then
    raise exception 'Ce type est utilise par des gains actifs.';
  end if;

  update public.reward_types
  set
    is_active = false,
    updated_at = now()
  where key = p_key
  returning *
  into reward_type_record;

  if reward_type_record.key is null then
    raise exception 'Type de gain introuvable.';
  end if;

  return to_jsonb(reward_type_record);
end;
$$;

create or replace function public.delete_reward_type(
  p_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  reward_type_record public.reward_types%rowtype;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if not exists (
    select 1
    from public.users
    where users.id = current_user_id
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  ) then
    raise exception 'Acces reserve au super admin.';
  end if;

  if exists (
    select 1
    from public.reward_catalog
    where reward_catalog.reward_type = p_key
  )
    or exists (
      select 1
      from public.contests
      where contests.reward_type = p_key
    )
    or exists (
      select 1
      from public.winners
      where winners.reward_type = p_key
    )
  then
    raise exception 'Ce type est deja utilise. Desactive-le au lieu de le supprimer.';
  end if;

  delete from public.reward_types
  where key = p_key
  returning *
  into reward_type_record;

  if reward_type_record.key is null then
    raise exception 'Type de gain introuvable.';
  end if;

  return to_jsonb(reward_type_record);
end;
$$;

create or replace function public.attach_reward_catalog_to_contest(
  p_contest_id uuid,
  p_reward_catalog_id uuid,
  p_reward_delivery_instructions text default null,
  p_reward_terms text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  catalog_record public.reward_catalog%rowtype;
  contest_record public.contests%rowtype;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if not exists (
    select 1
    from public.users
    where users.id = current_user_id
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  ) then
    raise exception 'Acces reserve au super admin.';
  end if;

  select *
  into catalog_record
  from public.reward_catalog
  where id = p_reward_catalog_id
    and coalesce(is_active, true) = true
  limit 1;

  if catalog_record.id is null then
    raise exception 'Gain introuvable dans le catalogue.';
  end if;

  update public.contests
  set
    reward_catalog_id = catalog_record.id,
    reward_type = catalog_record.reward_type,
    prize_description = coalesce(
      nullif(catalog_record.value_label, ''),
      catalog_record.name,
      prize_description
    ),
    prize_value = coalesce(catalog_record.estimated_value, prize_value),
    reward_delivery_instructions = coalesce(
      nullif(trim(coalesce(p_reward_delivery_instructions, '')), ''),
      catalog_record.default_delivery_instructions,
      reward_delivery_instructions
    ),
    reward_terms = coalesce(
      nullif(trim(coalesce(p_reward_terms, '')), ''),
      catalog_record.terms,
      reward_terms
    ),
    reward_metadata = coalesce(reward_metadata, '{}'::jsonb)
      || coalesce(catalog_record.metadata, '{}'::jsonb)
  where id = p_contest_id
  returning *
  into contest_record;

  if contest_record.id is null then
    raise exception 'Concours introuvable.';
  end if;

  return to_jsonb(contest_record);
end;
$$;

create or replace function public.create_reward_catalog_item(
  p_name text,
  p_reward_type text default 'manual',
  p_description text default null,
  p_value_label text default null,
  p_estimated_value numeric default 0,
  p_partner_id uuid default null,
  p_default_code text default null,
  p_default_delivery_instructions text default null,
  p_terms text default null,
  p_stock_quantity integer default null,
  p_is_active boolean default true
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.upsert_reward_catalog_item(
    null,
    p_name,
    p_reward_type,
    p_description,
    p_value_label,
    p_estimated_value,
    p_partner_id,
    p_default_code,
    p_default_delivery_instructions,
    p_terms,
    p_stock_quantity,
    p_is_active
  );
$$;

create or replace function public.update_reward_catalog_item(
  p_item_id uuid,
  p_name text,
  p_reward_type text default 'manual',
  p_description text default null,
  p_value_label text default null,
  p_estimated_value numeric default 0,
  p_partner_id uuid default null,
  p_default_code text default null,
  p_default_delivery_instructions text default null,
  p_terms text default null,
  p_stock_quantity integer default null,
  p_is_active boolean default true
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.upsert_reward_catalog_item(
    p_item_id,
    p_name,
    p_reward_type,
    p_description,
    p_value_label,
    p_estimated_value,
    p_partner_id,
    p_default_code,
    p_default_delivery_instructions,
    p_terms,
    p_stock_quantity,
    p_is_active
  );
$$;

create or replace function public.disable_reward_catalog_item(
  p_item_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  reward_record public.reward_catalog%rowtype;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if not exists (
    select 1
    from public.users
    where users.id = current_user_id
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  ) then
    raise exception 'Acces reserve au super admin.';
  end if;

  update public.reward_catalog
  set
    is_active = false,
    updated_at = now()
  where id = p_item_id
  returning *
  into reward_record;

  if reward_record.id is null then
    raise exception 'Gain introuvable dans le catalogue.';
  end if;

  return to_jsonb(reward_record);
end;
$$;

create or replace function public.delete_reward_catalog_item(
  p_item_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  reward_record public.reward_catalog%rowtype;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if not exists (
    select 1
    from public.users
    where users.id = current_user_id
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  ) then
    raise exception 'Acces reserve au super admin.';
  end if;

  select *
  into reward_record
  from public.reward_catalog
  where id = p_item_id
  limit 1;

  if reward_record.id is null then
    raise exception 'Gain introuvable dans le catalogue.';
  end if;

  if coalesce(reward_record.used_quantity, 0) > 0 then
    raise exception 'Ce gain a deja ete utilise. Desactive-le au lieu de le supprimer.';
  end if;

  if exists (
    select 1
    from public.contests
    where contests.reward_catalog_id = p_item_id
  )
    or exists (
      select 1
      from public.winners
      where winners.reward_catalog_id = p_item_id
    )
  then
    raise exception 'Ce gain est deja lie a un concours ou un gagnant. Desactive-le au lieu de le supprimer.';
  end if;

  delete from public.reward_catalog
  where id = p_item_id
  returning *
  into reward_record;

  return to_jsonb(reward_record);
end;
$$;

create or replace function public.set_winner_manual_reward(
  p_winner_id uuid,
  p_reward_type text default 'manual',
  p_reward_catalog_id uuid default null,
  p_reward_code text default null,
  p_reward_delivery_instructions text default null,
  p_reward_claim_status text default 'ready',
  p_reward_notes text default null,
  p_status text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  catalog_record public.reward_catalog%rowtype;
  updated_winner public.winners%rowtype;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if not exists (
    select 1
    from public.users
    where users.id = current_user_id
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  ) then
    raise exception 'Acces reserve au super admin.';
  end if;

  if not exists (
    select 1
    from public.reward_types
    where reward_types.key = p_reward_type
      and coalesce(reward_types.is_active, true) = true
  ) then
    raise exception 'Type de recompense invalide.';
  end if;

  if p_reward_claim_status not in (
    'pending',
    'ready',
    'sent',
    'claimed',
    'used',
    'expired',
    'cancelled'
  ) then
    raise exception 'Statut de recompense invalide.';
  end if;

  if p_reward_catalog_id is not null then
    select *
    into catalog_record
    from public.reward_catalog
    where id = p_reward_catalog_id
      and coalesce(is_active, true) = true
    limit 1;

    if catalog_record.id is null then
      raise exception 'Gain introuvable dans le catalogue.';
    end if;
  end if;

  update public.winners
  set
    reward_catalog_id = coalesce(catalog_record.id, reward_catalog_id),
    reward_type = coalesce(nullif(catalog_record.reward_type, ''), p_reward_type),
    reward_code = coalesce(
      nullif(trim(coalesce(p_reward_code, '')), ''),
      nullif(catalog_record.default_code, '')
    ),
    reward_delivery_instructions =
      coalesce(
        nullif(trim(coalesce(p_reward_delivery_instructions, '')), ''),
        nullif(catalog_record.default_delivery_instructions, '')
      ),
    reward_claim_status = p_reward_claim_status,
    reward_notes = nullif(trim(coalesce(p_reward_notes, '')), ''),
    prize_description = coalesce(
      nullif(catalog_record.value_label, ''),
      nullif(catalog_record.name, ''),
      prize_description
    ),
    prize_value = coalesce(catalog_record.estimated_value, prize_value),
    reward_metadata = coalesce(reward_metadata, '{}'::jsonb)
      || coalesce(catalog_record.metadata, '{}'::jsonb),
    status = coalesce(nullif(trim(coalesce(p_status, '')), ''), status),
    sent_at = case
      when p_reward_claim_status in ('sent', 'claimed', 'used')
        or coalesce(nullif(trim(coalesce(p_status, '')), ''), status)
          in ('sent', 'paid', 'received')
        then coalesce(sent_at, now())
      else sent_at
    end
  where id = p_winner_id
  returning *
  into updated_winner;

  if updated_winner.id is null then
    raise exception 'Gain introuvable.';
  end if;

  return to_jsonb(updated_winner);
end;
$$;

grant execute on function public.set_winner_manual_reward(
  uuid,
  text,
  uuid,
  text,
  text,
  text,
  text,
  text
) to authenticated;

grant execute on function public.upsert_reward_catalog_item(
  uuid,
  text,
  text,
  text,
  text,
  numeric,
  uuid,
  text,
  text,
  text,
  integer,
  boolean
) to authenticated;

grant execute on function public.upsert_reward_type(
  text,
  text,
  text,
  text,
  text,
  boolean,
  integer
) to authenticated;

grant execute on function public.disable_reward_type(text)
to authenticated;

grant execute on function public.delete_reward_type(text)
to authenticated;

grant execute on function public.create_reward_catalog_item(
  text,
  text,
  text,
  text,
  numeric,
  uuid,
  text,
  text,
  text,
  integer,
  boolean
) to authenticated;

grant execute on function public.update_reward_catalog_item(
  uuid,
  text,
  text,
  text,
  text,
  numeric,
  uuid,
  text,
  text,
  text,
  integer,
  boolean
) to authenticated;

grant execute on function public.disable_reward_catalog_item(uuid)
to authenticated;

grant execute on function public.delete_reward_catalog_item(uuid)
to authenticated;

grant execute on function public.attach_reward_catalog_to_contest(
  uuid,
  uuid,
  text,
  text
) to authenticated;

notify pgrst, 'reload schema';
