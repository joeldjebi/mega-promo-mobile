-- MegaPromo - Reglage canal OTP inscription
-- A executer dans Supabase SQL Editor.
--
-- Objectif:
-- - permettre au Super Admin de choisir le canal OTP inscription;
-- - valeur par defaut: SMS;
-- - WhatsApp est pris en charge par le hook Auth SMS Edge Function
--   auth-sms-mtarget avec le secret WASENDER_API_TOKEN.

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

alter table public.app_feature_flags
add column if not exists metadata jsonb not null default '{}'::jsonb;

insert into public.app_feature_flags (
  key,
  name,
  description,
  is_enabled,
  metadata,
  created_at,
  updated_at
)
values (
  'otp_delivery_channel',
  'Canal OTP inscription',
  'Choisit le canal d''envoi des OTP joueur: SMS ou WhatsApp.',
  true,
  '{"channel": "sms", "resend_schedule_seconds": [180, 300, 1800], "support_url": "https://megapromo.app/#contact"}'::jsonb,
  now(),
  now()
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_enabled = true,
  metadata = excluded.metadata || public.app_feature_flags.metadata,
  updated_at = now();

create table if not exists public.auth_otp_delivery_attempts (
  id uuid primary key default gen_random_uuid(),
  phone_hash text not null,
  channel text not null default 'sms',
  provider_status int,
  delivered boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.auth_otp_delivery_attempts
drop constraint if exists auth_otp_delivery_attempts_channel_check;

alter table public.auth_otp_delivery_attempts
add constraint auth_otp_delivery_attempts_channel_check
check (channel in ('sms', 'whatsapp'));

create index if not exists auth_otp_delivery_attempts_phone_created_idx
  on public.auth_otp_delivery_attempts(phone_hash, created_at desc);

grant select on public.app_feature_flags to authenticated, anon;
grant insert, update on public.app_feature_flags to authenticated;
grant select on public.app_feature_flags to service_role;
grant select, insert, update on public.auth_otp_delivery_attempts to service_role;

notify pgrst, 'reload schema';
