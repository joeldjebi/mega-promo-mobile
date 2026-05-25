-- MegaPromo - Moyens de paiement joueur + KYC
-- A executer dans Supabase SQL Editor.
-- Permet 1 numero Mobile Money sans KYC. Le 2e numero et les modifications
-- necessitent une KYC approuvee.

create table if not exists public.player_kyc_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  document_type text not null check (
    document_type in ('national_id', 'passport', 'driver_license')
  ),
  document_front_url text,
  document_back_url text,
  status text not null default 'pending' check (
    status in ('pending', 'approved', 'rejected')
  ),
  rejection_reason text,
  reviewed_by uuid references public.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.player_payment_methods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  operator_key text not null,
  operator_name text not null,
  phone text not null,
  label text,
  is_primary bool not null default false,
  is_whatsapp bool not null default false,
  status text not null default 'active' check (
    status in ('active', 'disabled')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  operator_key text not null,
  country text not null default 'Côte d’Ivoire',
  payment_url text,
  instructions text,
  proof_phone text,
  is_active bool not null default true,
  order_index integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists player_payment_methods_user_phone_idx
on public.player_payment_methods(user_id, phone)
where status = 'active';

create unique index if not exists payment_methods_operator_key_idx
on public.payment_methods(lower(operator_key));

create index if not exists payment_methods_active_order_idx
on public.payment_methods(is_active, order_index, name);

create index if not exists player_payment_methods_user_idx
on public.player_payment_methods(user_id, status, created_at);

create index if not exists player_kyc_requests_user_status_idx
on public.player_kyc_requests(user_id, status, created_at desc);

alter table public.player_payment_methods
add column if not exists is_whatsapp bool not null default false;

alter table public.payment_methods
add column if not exists country text not null default 'Côte d’Ivoire';

alter table public.payment_methods
add column if not exists payment_url text;

alter table public.payment_methods
add column if not exists instructions text;

alter table public.payment_methods
add column if not exists proof_phone text;

alter table public.payment_methods
add column if not exists is_active bool not null default true;

alter table public.payment_methods
add column if not exists order_index integer not null default 0;

alter table public.payment_methods
add column if not exists created_at timestamptz not null default now();

alter table public.payment_methods
add column if not exists updated_at timestamptz not null default now();

insert into public.payment_methods (
  name,
  operator_key,
  country,
  is_active,
  order_index,
  created_at,
  updated_at
)
values
  ('Orange Money', 'orange_money', 'Côte d’Ivoire', true, 1, now(), now()),
  ('MTN Money', 'mtn_money', 'Côte d’Ivoire', true, 2, now(), now()),
  ('Moov Money', 'moov_money', 'Côte d’Ivoire', true, 3, now(), now()),
  ('Wave', 'wave', 'Côte d’Ivoire', true, 4, now(), now())
on conflict ((lower(operator_key))) do nothing;

insert into storage.buckets (id, name, public)
values ('kyc-documents', 'kyc-documents', true)
on conflict (id) do update
set public = excluded.public;

alter table public.player_payment_methods enable row level security;
alter table public.player_kyc_requests enable row level security;

drop policy if exists "player_payment_methods_select_own" on public.player_payment_methods;
create policy "player_payment_methods_select_own"
on public.player_payment_methods
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "player_payment_methods_admin_select" on public.player_payment_methods;
create policy "player_payment_methods_admin_select"
on public.player_payment_methods
for select
to authenticated
using (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role = 'admin'
      and coalesce(users.is_active, true) = true
  )
);

drop policy if exists "player_kyc_requests_select_own" on public.player_kyc_requests;
create policy "player_kyc_requests_select_own"
on public.player_kyc_requests
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "player_kyc_requests_admin_select" on public.player_kyc_requests;
create policy "player_kyc_requests_admin_select"
on public.player_kyc_requests
for select
to authenticated
using (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role = 'admin'
      and coalesce(users.is_active, true) = true
  )
);

drop policy if exists "player_kyc_requests_admin_update" on public.player_kyc_requests;
create policy "player_kyc_requests_admin_update"
on public.player_kyc_requests
for update
to authenticated
using (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role = 'admin'
      and coalesce(users.is_active, true) = true
  )
)
with check (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role = 'admin'
      and coalesce(users.is_active, true) = true
  )
);

grant select on public.player_payment_methods to authenticated;
grant select, update on public.player_kyc_requests to authenticated;
grant select on public.countries to authenticated;
grant select on public.payment_methods to authenticated;

drop policy if exists "kyc_documents_insert_own" on storage.objects;
create policy "kyc_documents_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'kyc-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "kyc_documents_select_own_or_admin" on storage.objects;
create policy "kyc_documents_select_own_or_admin"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'kyc-documents'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists (
      select 1
      from public.users
      where users.id = auth.uid()
        and users.role = 'admin'
        and coalesce(users.is_active, true) = true
    )
  )
);

create or replace function public.player_has_approved_kyc(p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.player_kyc_requests
    where user_id = p_user_id
      and status = 'approved'
  );
$$;

create or replace function public.submit_player_kyc_request(
  p_document_type text,
  p_document_front_url text default null,
  p_document_back_url text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  latest_request public.player_kyc_requests%rowtype;
  request_record public.player_kyc_requests%rowtype;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if p_document_type not in ('national_id', 'passport', 'driver_license') then
    raise exception 'Type de piece invalide.';
  end if;

  if nullif(trim(coalesce(p_document_front_url, '')), '') is null then
    raise exception 'Le fichier de la piece est obligatoire.';
  end if;

  if p_document_type = 'national_id'
    and nullif(trim(coalesce(p_document_back_url, '')), '') is null
  then
    raise exception 'Le verso de la CNI est obligatoire.';
  end if;

  select *
  into latest_request
  from public.player_kyc_requests
  where user_id = current_user_id
  order by created_at desc
  limit 1;

  if latest_request.id is not null
    and latest_request.status = 'pending'
  then
    raise exception 'Ta verification d''identite est deja en cours.';
  end if;

  if latest_request.id is not null
    and latest_request.status = 'approved'
  then
    raise exception 'Ton identite est deja verifiee.';
  end if;

  if latest_request.id is not null
    and latest_request.status = 'rejected'
    and nullif(trim(coalesce(latest_request.rejection_reason, '')), '') is null
  then
    raise exception 'La verification ne peut pas etre modifiee pour le moment.';
  end if;

  insert into public.player_kyc_requests (
    user_id,
    document_type,
    document_front_url,
    document_back_url,
    status,
    created_at,
    updated_at
  )
  values (
    current_user_id,
    p_document_type,
    nullif(trim(coalesce(p_document_front_url, '')), ''),
    nullif(trim(coalesce(p_document_back_url, '')), ''),
    'pending',
    now(),
    now()
  )
  returning *
  into request_record;

  return to_jsonb(request_record);
end;
$$;

drop function if exists public.upsert_player_payment_method(uuid, text, text, text, text);

create or replace function public.upsert_player_payment_method(
  p_method_id uuid default null,
  p_operator_key text default 'mobile_money',
  p_operator_name text default 'Mobile Money',
  p_phone text default '',
  p_is_whatsapp boolean default false,
  p_label text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_phone text := regexp_replace(coalesce(p_phone, ''), '[^0-9+]', '', 'g');
  normalized_operator_key text := lower(trim(coalesce(p_operator_key, 'mobile_money')));
  active_operator_name text;
  active_methods_count integer := 0;
  has_kyc boolean := false;
  payment_record public.player_payment_methods%rowtype;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  if length(regexp_replace(normalized_phone, '[^0-9]', '', 'g')) < 8 then
    raise exception 'Numero Mobile Money invalide.';
  end if;

  select payment_methods.name
  into active_operator_name
  from public.payment_methods
  where lower(payment_methods.operator_key) = normalized_operator_key
    and coalesce(payment_methods.is_active, true) = true
  order by payment_methods.order_index asc nulls last, payment_methods.name asc
  limit 1;

  if active_operator_name is null then
    raise exception 'Operateur Mobile Money indisponible.';
  end if;

  has_kyc := public.player_has_approved_kyc(current_user_id);

  if p_method_id is not null then
    if not has_kyc then
      raise exception 'KYC requise pour modifier un numero Mobile Money.';
    end if;

    update public.player_payment_methods
    set
      operator_key = normalized_operator_key,
      operator_name = active_operator_name,
      phone = normalized_phone,
      is_whatsapp = coalesce(p_is_whatsapp, false),
      label = nullif(trim(coalesce(p_label, '')), ''),
      updated_at = now()
    where id = p_method_id
      and user_id = current_user_id
      and status = 'active'
    returning *
    into payment_record;

    if payment_record.id is null then
      raise exception 'Moyen de paiement introuvable.';
    end if;

    return to_jsonb(payment_record);
  end if;

  select count(*)::int
  into active_methods_count
  from public.player_payment_methods
  where user_id = current_user_id
    and status = 'active';

  if active_methods_count >= 2 then
    raise exception 'Tu peux enregistrer deux numeros Mobile Money maximum.';
  end if;

  if active_methods_count >= 1 and not has_kyc then
    raise exception 'KYC requise pour ajouter un deuxieme numero Mobile Money.';
  end if;

  insert into public.player_payment_methods (
    user_id,
    operator_key,
    operator_name,
    phone,
    label,
    is_primary,
    is_whatsapp,
    status,
    created_at,
    updated_at
  )
  values (
    current_user_id,
    normalized_operator_key,
    active_operator_name,
    normalized_phone,
    nullif(trim(coalesce(p_label, '')), ''),
    active_methods_count = 0,
    coalesce(p_is_whatsapp, false),
    'active',
    now(),
    now()
  )
  returning *
  into payment_record;

  return to_jsonb(payment_record);
end;
$$;

grant execute on function public.player_has_approved_kyc(uuid) to authenticated;
grant execute on function public.submit_player_kyc_request(text, text, text) to authenticated;
grant execute on function public.upsert_player_payment_method(uuid, text, text, text, boolean, text) to authenticated;

notify pgrst, 'reload schema';
