-- Creates/keeps public.users in sync when Supabase Auth creates a phone user.
-- Run this in Supabase SQL Editor if public.users stays empty after OTP auth.

alter table public.users
add column if not exists fcm_token text;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (
    id,
    phone,
    role,
    is_premium,
    points_total,
    participations_today,
    last_participation_date,
    is_active,
    created_at
  )
  values (
    new.id,
    new.phone,
    'player',
    false,
    0,
    0,
    current_date,
    true,
    now()
  )
  on conflict (id) do update
  set
    phone = coalesce(public.users.phone, excluded.phone),
    role = coalesce(public.users.role, excluded.role),
    is_premium = coalesce(public.users.is_premium, excluded.is_premium),
    points_total = coalesce(public.users.points_total, excluded.points_total),
    participations_today = coalesce(
      public.users.participations_today,
      excluded.participations_today
    ),
    last_participation_date = coalesce(
      public.users.last_participation_date,
      excluded.last_participation_date
    ),
    is_active = coalesce(public.users.is_active, excluded.is_active);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();
