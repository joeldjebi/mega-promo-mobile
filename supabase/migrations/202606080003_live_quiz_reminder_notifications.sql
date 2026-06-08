-- MegaPromo - Rappels automatiques Quiz Live
-- A executer dans Supabase SQL Editor apres 202606080002.
--
-- Objectif:
-- - a T-5 min: inviter les joueurs non inscrits a reserver leur place;
-- - a T-2 min: rappeler aux joueurs inscrits que le QL commence bientot;
-- - eviter les doublons meme si le cron tourne plusieurs fois;
-- - brancher le traitement sur le cron de production.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  title text not null,
  body text not null default '',
  type text not null default 'info',
  is_read boolean not null default false,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.notifications
add column if not exists user_id uuid references public.users(id) on delete cascade,
add column if not exists title text,
add column if not exists body text not null default '',
add column if not exists type text not null default 'info',
add column if not exists is_read boolean not null default false,
add column if not exists data jsonb not null default '{}'::jsonb,
add column if not exists created_at timestamptz not null default now();

create table if not exists public.live_quiz_notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  contest_id uuid not null references public.contests(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  reminder_key text not null,
  created_at timestamptz not null default now(),
  unique (contest_id, user_id, reminder_key)
);

alter table public.live_quiz_notification_deliveries
drop constraint if exists live_quiz_notification_deliveries_reminder_key_check;

alter table public.live_quiz_notification_deliveries
add constraint live_quiz_notification_deliveries_reminder_key_check
check (reminder_key in ('open_t_minus_5', 'registered_t_minus_2'));

create index if not exists live_quiz_notification_deliveries_contest_idx
  on public.live_quiz_notification_deliveries(contest_id, reminder_key);

grant select, update on public.notifications to authenticated;

create or replace function public.dispatch_live_quiz_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer := 0;
begin
  -- Garder la file QL a jour avant de calculer les fenetres de rappel.
  begin
    perform public.process_live_quiz_events();
  exception
    when undefined_function then
      null;
  end;

  with reminder_candidates as (
    -- T-5: joueurs actifs pas encore inscrits.
    select
      contests.id as contest_id,
      users.id as user_id,
      'open_t_minus_5'::text as reminder_key
    from public.contests contests
    join public.users users
      on coalesce(users.is_active, true) = true
     and lower(coalesce(users.role, 'player')) = 'player'
    where coalesce(contests.is_live, false) = true
      and coalesce(contests.status, 'active') = 'active'
      and contests.live_starts_at is not null
      and contests.live_starts_at > now()
      and contests.live_starts_at - interval '5 minutes' <= now()
      and contests.live_starts_at - interval '2 minutes' > now()
      and lower(coalesce(contests.live_status, 'scheduled')) in (
        'scheduled',
        'waiting',
        'queued'
      )
      and not exists (
        select 1
        from public.live_quiz_registrations registrations
        where registrations.contest_id = contests.id
          and registrations.user_id = users.id
          and lower(coalesce(registrations.status, 'registered')) = 'registered'
      )
      and not exists (
        select 1
        from public.participations participations
        where participations.contest_id = contests.id
          and participations.user_id = users.id
      )

    union all

    -- T-2: joueurs deja inscrits.
    select
      contests.id as contest_id,
      registrations.user_id,
      'registered_t_minus_2'::text as reminder_key
    from public.contests contests
    join public.live_quiz_registrations registrations
      on registrations.contest_id = contests.id
     and lower(coalesce(registrations.status, 'registered')) = 'registered'
    where coalesce(contests.is_live, false) = true
      and coalesce(contests.status, 'active') = 'active'
      and contests.live_starts_at is not null
      and contests.live_starts_at > now()
      and contests.live_starts_at - interval '2 minutes' <= now()
      and lower(coalesce(contests.live_status, 'scheduled')) in (
        'scheduled',
        'waiting',
        'queued'
      )
  ),
  inserted_deliveries as (
    insert into public.live_quiz_notification_deliveries (
      contest_id,
      user_id,
      reminder_key,
      created_at
    )
    select
      reminder_candidates.contest_id,
      reminder_candidates.user_id,
      reminder_candidates.reminder_key,
      now()
    from reminder_candidates
    on conflict (contest_id, user_id, reminder_key) do nothing
    returning contest_id, user_id, reminder_key
  ),
  inserted_notifications as (
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
    select
      gen_random_uuid(),
      inserted_deliveries.user_id,
      case inserted_deliveries.reminder_key
        when 'registered_t_minus_2' then 'QL dans 2 minutes'
        else 'Quiz Live imminent'
      end,
      case inserted_deliveries.reminder_key
        when 'registered_t_minus_2' then
          '"' || contests.title || '" commence dans 2 minutes. Entre dans l''arene.'
        else
          '"' || contests.title || '" commence dans environ 5 minutes. Reserve ta place maintenant.'
      end,
      'live_quiz_reminder',
      false,
      jsonb_build_object(
        'source',
        'live_quiz_reminder',
        'contest_id',
        contests.id,
        'live_starts_at',
        contests.live_starts_at,
        'reminder_key',
        inserted_deliveries.reminder_key,
        'target',
        'live_waiting'
      ),
      now()
    from inserted_deliveries
    join public.contests contests
      on contests.id = inserted_deliveries.contest_id
    returning id
  )
  select count(*)::int
  into inserted_count
  from inserted_notifications;

  return inserted_count;
end;
$$;

grant execute on function public.dispatch_live_quiz_reminders() to authenticated;

create or replace function public.process_contest_events()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  ended_live_count integer := 0;
  live_reminders_count integer := 0;
  created_winners_count integer := 0;
  result jsonb;
begin
  begin
    ended_live_count := coalesce(public.process_live_quiz_events(), 0);
  exception
    when undefined_function then
      ended_live_count := 0;
  end;

  begin
    live_reminders_count := coalesce(public.dispatch_live_quiz_reminders(), 0);
  exception
    when undefined_function then
      live_reminders_count := 0;
  end;

  begin
    created_winners_count :=
      coalesce(public.generate_pending_winners_for_finished_contests(), 0);
  exception
    when undefined_function then
      created_winners_count := 0;
  end;

  result := jsonb_build_object(
    'ended_live_quizzes',
    ended_live_count,
    'live_quiz_reminders',
    live_reminders_count,
    'created_winners',
    created_winners_count
  );

  if ended_live_count > 0
    or live_reminders_count > 0
    or created_winners_count > 0
  then
    perform public.log_system_event(
      'info',
      'database',
      'contests',
      'process_events',
      'Traitement automatique des concours execute.',
      null,
      null,
      null,
      'contest_event_batch',
      null,
      result,
      null,
      'postgres/process_contest_events'
    );
  end if;

  return result;
exception
  when others then
    perform public.log_system_event(
      'error',
      'database',
      'contests',
      'process_events_failed',
      'Echec traitement automatique des concours.',
      null,
      null,
      null,
      null,
      null,
      jsonb_build_object('error', sqlerrm, 'sqlstate', sqlstate),
      null,
      'postgres/process_contest_events'
    );
    raise;
end;
$$;

grant execute on function public.process_contest_events() to authenticated;

do $$
begin
  create extension if not exists pg_cron with schema extensions;
exception
  when others then
    null;
end;
$$;

do $$
begin
  perform cron.unschedule('megapromo-live-quiz-reminders');
exception
  when others then
    null;
end;
$$;

do $$
begin
  perform cron.schedule(
    'megapromo-live-quiz-reminders',
    '* * * * *',
    'select public.dispatch_live_quiz_reminders();'
  );
exception
  when others then
    null;
end;
$$;

select public.dispatch_live_quiz_reminders() as live_quiz_reminders_now;

notify pgrst, 'reload schema';
