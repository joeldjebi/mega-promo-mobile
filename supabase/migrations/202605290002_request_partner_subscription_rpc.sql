-- MegaPromo - Demande d'abonnement partenaire depuis l'espace AP
-- Permet a un partenaire connecte de choisir ou renouveler un forfait.
-- La demande est creee en pending; le SA garde la validation finale.

create or replace function public.request_partner_subscription(
  p_partner_id uuid,
  p_plan_id uuid,
  p_payment_method text default 'Demande depuis espace partenaire'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  current_email text := lower(
    coalesce(
      nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email',
      ''
    )
  );
  partner_record public.partners%rowtype;
  plan_record public.partner_plans%rowtype;
  subscription_record public.partner_subscriptions%rowtype;
  starts_at_value timestamptz := now();
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecte.';
  end if;

  select *
  into partner_record
  from public.partners
  where id = p_partner_id
  limit 1;

  if partner_record.id is null then
    raise exception 'Partenaire introuvable.';
  end if;

  if coalesce(partner_record.is_active, true) = false then
    raise exception 'Ce compte partenaire est desactive.';
  end if;

  if partner_record.user_id is distinct from current_user_id
    and lower(coalesce(partner_record.email, '')) <> current_email
  then
    raise exception 'Acces non autorise pour ce partenaire.';
  end if;

  select *
  into plan_record
  from public.partner_plans
  where id = p_plan_id
    and coalesce(is_active, true) = true
  limit 1;

  if plan_record.id is null then
    raise exception 'Forfait partenaire indisponible.';
  end if;

  insert into public.partner_subscriptions (
    partner_id,
    plan_id,
    amount,
    status,
    starts_at,
    expires_at,
    payment_method,
    created_at
  )
  values (
    partner_record.id,
    plan_record.id,
    greatest(coalesce(plan_record.price, 0), 0),
    'pending',
    starts_at_value,
    starts_at_value + make_interval(days => greatest(coalesce(plan_record.duration_days, 30), 1)),
    nullif(trim(coalesce(p_payment_method, '')), ''),
    now()
  )
  returning *
  into subscription_record;

  return jsonb_build_object(
    'subscription', to_jsonb(subscription_record),
    'plan', to_jsonb(plan_record),
    'partner', jsonb_build_object(
      'id', partner_record.id,
      'company_name', partner_record.company_name
    )
  );
end;
$$;

grant execute on function public.request_partner_subscription(uuid, uuid, text)
to authenticated;

notify pgrst, 'reload schema';
