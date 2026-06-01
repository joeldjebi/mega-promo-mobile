-- MegaPromo - Bloquer l'acces aux QL programmes
-- A executer dans Supabase SQL Editor.
--
-- Objectif:
-- - les QL programmes restent visibles;
-- - aucun joueur ne peut s'inscrire / entrer en salle d'attente tant que le QL
--   n'est pas reellement active par la file d'attente;
-- - etat autorise pour l'acces joueur: live_status in ('playing','active','open').

create or replace function public.assert_live_quiz_access_is_open()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_record public.contests%rowtype;
begin
  select *
  into contest_record
  from public.contests
  where id = new.contest_id
  limit 1;

  if contest_record.id is null then
    return new;
  end if;

  if coalesce(contest_record.is_live, false) = false then
    return new;
  end if;

  if coalesce(contest_record.status, 'active') <> 'active'
    or lower(coalesce(contest_record.live_status, 'scheduled')) not in (
      'playing',
      'active',
      'open'
    )
  then
    raise exception
      'Ce Quiz Live est programme mais pas encore active.';
  end if;

  return new;
end;
$$;

do $$
begin
  if to_regclass('public.live_quiz_registrations') is not null then
    drop trigger if exists live_quiz_registrations_block_until_playing
      on public.live_quiz_registrations;

    create trigger live_quiz_registrations_block_until_playing
    before insert on public.live_quiz_registrations
    for each row
    execute function public.assert_live_quiz_access_is_open();
  end if;

  if to_regclass('public.live_sessions') is not null then
    drop trigger if exists live_sessions_block_until_playing
      on public.live_sessions;

    create trigger live_sessions_block_until_playing
    before insert on public.live_sessions
    for each row
    execute function public.assert_live_quiz_access_is_open();
  end if;
end;
$$;

notify pgrst, 'reload schema';

