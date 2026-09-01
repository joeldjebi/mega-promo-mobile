-- MegaPromo - Blocage nouveaux doublons Mobile Money
-- A executer dans Supabase SQL Editor en production.
--
-- Objectif:
-- - empecher l'ajout d'un numero Mobile Money deja actif sur un autre compte;
-- - couvrir les anciennes apps deja en production via un trigger Supabase;
-- - conserver les doublons existants pour permettre au SA de les traiter.

set lock_timeout = '3s';
set statement_timeout = '30s';

create or replace function public.normalize_payment_phone(p_phone text)
returns text
language sql
immutable
as $$
  select case
    when regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g') like '225__________'
      then right(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'), 10)
    else regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')
  end;
$$;

create or replace function public.prevent_duplicate_player_payment_phone()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_phone text := public.normalize_payment_phone(new.phone);
begin
  if coalesce(new.status, 'active') <> 'active' then
    return new;
  end if;

  if normalized_phone = '' or length(normalized_phone) < 8 then
    raise exception 'Numero Mobile Money invalide.';
  end if;

  if tg_op = 'UPDATE'
    and public.normalize_payment_phone(coalesce(old.phone, '')) = normalized_phone
    and old.user_id = new.user_id
    and coalesce(old.status, 'active') = coalesce(new.status, 'active')
  then
    return new;
  end if;

  if exists (
    select 1
    from public.player_payment_methods
    where player_payment_methods.status = 'active'
      and player_payment_methods.user_id <> new.user_id
      and public.normalize_payment_phone(player_payment_methods.phone) = normalized_phone
      and player_payment_methods.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
  ) then
    raise exception 'Ce numero Mobile Money est deja utilise par un autre compte MegaPromo.';
  end if;

  new.phone := normalized_phone;
  return new;
end;
$$;

drop trigger if exists trg_prevent_duplicate_player_payment_phone
on public.player_payment_methods;

create trigger trg_prevent_duplicate_player_payment_phone
before insert or update of phone, status, user_id
on public.player_payment_methods
for each row
execute function public.prevent_duplicate_player_payment_phone();

grant execute on function public.normalize_payment_phone(text) to authenticated;

notify pgrst, 'reload schema';
