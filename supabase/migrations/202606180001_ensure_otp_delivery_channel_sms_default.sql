-- MegaPromo - Garantir le canal OTP par defaut
-- A executer dans Supabase SQL Editor si le hook OTP ne lit pas le choix SA.
--
-- Objectif:
-- - garantir l'existence du flag otp_delivery_channel;
-- - conserver le choix existant s'il est deja defini;
-- - remettre SMS comme canal par defaut fiable.

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

grant select on public.app_feature_flags to authenticated, anon;
grant select on public.app_feature_flags to service_role;

notify pgrst, 'reload schema';
