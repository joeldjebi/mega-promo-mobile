-- Minimal grants/policies for the player app screens.
-- Run in Supabase SQL Editor, then tighten later for production if needed.

grant select, update on public.contests to authenticated;
grant select on public.categories to authenticated;
grant select on public.partners to authenticated;
grant select on public.questions to authenticated;
grant select, insert, update on public.participations to authenticated;
grant select on public.badges to authenticated;
grant select on public.user_badges to authenticated;
grant select on public.winners to authenticated;
grant select, update on public.notifications to authenticated;

alter table public.contests enable row level security;
alter table public.categories enable row level security;
alter table public.partners enable row level security;
alter table public.questions enable row level security;
alter table public.participations enable row level security;
alter table public.badges enable row level security;
alter table public.user_badges enable row level security;
alter table public.winners enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "contests_read_active" on public.contests;
create policy "contests_read_active"
on public.contests
for select
to authenticated
using (status = 'active');

drop policy if exists "contests_update_view_share_counts" on public.contests;
create policy "contests_update_view_share_counts"
on public.contests
for update
to authenticated
using (status = 'active')
with check (status = 'active');

drop policy if exists "categories_read_active" on public.categories;
create policy "categories_read_active"
on public.categories
for select
to authenticated
using (coalesce(is_active, true) = true);

drop policy if exists "partners_read_active" on public.partners;
create policy "partners_read_active"
on public.partners
for select
to authenticated
using (coalesce(is_active, true) = true);

drop policy if exists "questions_read_for_active_contests" on public.questions;
create policy "questions_read_for_active_contests"
on public.questions
for select
to authenticated
using (
  exists (
    select 1
    from public.contests
    where contests.id = questions.contest_id
    and contests.status = 'active'
  )
);

drop policy if exists "participations_select_own_or_contest_counts" on public.participations;
create policy "participations_select_own_or_contest_counts"
on public.participations
for select
to authenticated
using (true);

drop policy if exists "participations_insert_own" on public.participations;
create policy "participations_insert_own"
on public.participations
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "participations_update_own" on public.participations;
create policy "participations_update_own"
on public.participations
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "badges_read_all" on public.badges;
create policy "badges_read_all"
on public.badges
for select
to authenticated
using (true);

drop policy if exists "user_badges_select_own" on public.user_badges;
create policy "user_badges_select_own"
on public.user_badges
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "winners_select_own" on public.winners;
create policy "winners_select_own"
on public.winners
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own"
on public.notifications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own"
on public.notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
