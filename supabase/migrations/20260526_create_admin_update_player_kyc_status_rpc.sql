-- MegaPromo - Mise a jour KYC par le SA + notification joueur
-- A executer dans Supabase SQL Editor.
-- Evite les blocages RLS cote client: la fonction verifie le role SA,
-- met a jour la demande KYC et cree une notification in-app pour le joueur.

create or replace function public.admin_update_player_kyc_status(
  p_request_id uuid,
  p_status text,
  p_rejection_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  updated_request public.player_kyc_requests%rowtype;
  notification_title text;
  notification_body text;
  notification_payload jsonb;
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

  if p_status not in ('pending', 'approved', 'rejected') then
    raise exception 'Statut KYC invalide.';
  end if;

  if p_status = 'rejected'
    and nullif(trim(coalesce(p_rejection_reason, '')), '') is null
  then
    raise exception 'Le motif est obligatoire pour rejeter une piece KYC.';
  end if;

  update public.player_kyc_requests
  set
    status = p_status,
    rejection_reason = case
      when p_status = 'rejected' then trim(coalesce(p_rejection_reason, ''))
      else null
    end,
    reviewed_by = current_user_id,
    reviewed_at = case
      when p_status = 'pending' then null
      else now()
    end,
    updated_at = now()
  where id = p_request_id
  returning *
  into updated_request;

  if updated_request.id is null then
    raise exception 'Demande KYC introuvable.';
  end if;

  notification_title := case
    when p_status = 'approved' then 'KYC validée'
    when p_status = 'rejected' then 'KYC rejetée'
    else 'KYC en attente'
  end;

  notification_body := case
    when p_status = 'approved'
      then 'Ta pièce d’identité a été validée. Tu peux maintenant utiliser toutes les fonctionnalités liées à la KYC.'
    when p_status = 'rejected'
      then 'Ta pièce d’identité a été rejetée. Motif : '
        || trim(coalesce(p_rejection_reason, ''))
    else 'Ta vérification d’identité est repassée en attente de traitement.'
  end;

  notification_payload := jsonb_build_object(
    'type', 'kyc',
    'source', 'kyc_status_update',
    'kyc_request_id', updated_request.id,
    'status', p_status
  );

  insert into public.notifications (
    id,
    user_id,
    title,
    body,
    type,
    is_read,
    data,
    created_at
  )
  values (
    gen_random_uuid(),
    updated_request.user_id,
    notification_title,
    notification_body,
    'kyc',
    false,
    notification_payload,
    now()
  );

  return jsonb_build_object(
    'request', to_jsonb(updated_request),
    'notification', jsonb_build_object(
      'user_id', updated_request.user_id,
      'title', notification_title,
      'body', notification_body,
      'type', 'kyc',
      'data', notification_payload
    )
  );
end;
$$;

grant execute on function public.admin_update_player_kyc_status(uuid, text, text)
to authenticated;

notify pgrst, 'reload schema';
