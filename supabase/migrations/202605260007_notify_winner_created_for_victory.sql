-- MegaPromo - Notification automatique quand un gagnant est designe
-- Cree une notification in-app exploitable par le mobile pour ouvrir
-- directement la page de felicitation /rewards/:winnerId.

grant select, insert, update on public.notifications to authenticated;

create or replace function public.notify_winner_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_title text := 'un concours MegaPromo';
  prize_label text := 'ton gain MegaPromo';
begin
  if new.user_id is null then
    return new;
  end if;

  select coalesce(nullif(contests.title, ''), contest_title)
  into contest_title
  from public.contests
  where contests.id = new.contest_id
  limit 1;

  prize_label := coalesce(nullif(new.prize_description, ''), prize_label);

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
    new.user_id,
    'Felicitations, tu as gagne',
    'Tu es gagnant de "' || contest_title || '". Ton gain: ' || prize_label || '.',
    'winner',
    false,
    jsonb_build_object(
      'source', 'winner_created',
      'winner_id', new.id,
      'contest_id', new.contest_id,
      'status', coalesce(new.status, 'pending')
    ),
    now()
  );

  return new;
end;
$$;

drop trigger if exists winners_notify_player_on_created on public.winners;
create trigger winners_notify_player_on_created
after insert on public.winners
for each row
execute function public.notify_winner_created();

notify pgrst, 'reload schema';
