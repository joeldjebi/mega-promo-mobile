-- MegaPromo - Pseudos joueurs uniques sans tenir compte de la casse
-- A exécuter dans Supabase SQL Editor.
--
-- Objectif:
-- - considérer "Chris", "chris" et "CHRIS" comme le même pseudo;
-- - empêcher les doublons au niveau base de données;
-- - exposer une fonction de vérification utilisée par l'app mobile.

with ranked_usernames as (
  select
    id,
    row_number() over (
      partition by lower(btrim(username))
      order by created_at asc nulls last, id asc
    ) as duplicate_rank
  from public.users
  where username is not null
    and btrim(username) <> ''
    and coalesce(account_status, 'active') <> 'deleted'
),
duplicates as (
  select id
  from ranked_usernames
  where duplicate_rank > 1
)
update public.users
set username = 'joueur_' || substr(replace(id::text, '-', ''), 1, 12)
where id in (select id from duplicates);

create unique index if not exists users_username_lower_unique_idx
on public.users (lower(btrim(username)))
where username is not null
  and btrim(username) <> ''
  and coalesce(account_status, 'active') <> 'deleted';

create or replace function public.is_username_available(
  p_username text,
  p_exclude_user_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.users
    where username is not null
      and btrim(username) <> ''
      and coalesce(account_status, 'active') <> 'deleted'
      and lower(btrim(username)) = lower(btrim(coalesce(p_username, '')))
      and (p_exclude_user_id is null or id <> p_exclude_user_id)
  );
$$;

grant execute on function public.is_username_available(text, uuid)
to anon, authenticated, service_role;

notify pgrst, 'reload schema';
