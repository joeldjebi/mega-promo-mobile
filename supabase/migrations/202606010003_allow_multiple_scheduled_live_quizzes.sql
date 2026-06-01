-- MegaPromo - Autoriser plusieurs QL programmes
-- A executer dans Supabase SQL Editor.
--
-- Corrige l'ancien trigger prevent_multiple_open_live_quizzes() qui bloquait
-- plusieurs QL avec status='active', meme quand ils etaient seulement
-- programmes en live_status='scheduled'.
--
-- Nouvelle regle:
-- - plusieurs QL peuvent etre en live_status='scheduled' / 'waiting' / 'queued';
-- - un seul QL peut etre reellement ouvert/en cours:
--   live_status in ('playing', 'active', 'open').

create or replace function public.prevent_multiple_open_live_quizzes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.is_live, false) = false then
    return new;
  end if;

  if coalesce(new.status, 'active') <> 'active' then
    return new;
  end if;

  if lower(coalesce(new.live_status, 'scheduled')) not in (
    'playing',
    'active',
    'open'
  ) then
    return new;
  end if;

  if exists (
    select 1
    from public.contests existing
    where existing.id <> new.id
      and coalesce(existing.is_live, false) = true
      and coalesce(existing.status, 'active') = 'active'
      and lower(coalesce(existing.live_status, 'scheduled')) in (
        'playing',
        'active',
        'open'
      )
  ) then
    raise exception
      'Un Quiz Live est deja ouvert. Termine le Quiz Live actuel avant d''en activer un nouveau.';
  end if;

  return new;
end;
$$;

notify pgrst, 'reload schema';

