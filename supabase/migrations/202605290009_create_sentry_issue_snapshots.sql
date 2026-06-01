-- MegaPromo - Snapshots Sentry pour le dashboard SA
-- A executer apres les migrations system_logs.
-- Stocke un resume des issues Sentry sans exposer le token Sentry au frontend.

create table if not exists public.sentry_issue_snapshots (
  id uuid primary key default gen_random_uuid(),
  issue_id text not null unique,
  short_id text,
  title text not null,
  culprit text,
  level text,
  status text,
  platform text,
  project_slug text,
  project_name text,
  first_seen timestamptz,
  last_seen timestamptz,
  event_count integer not null default 0,
  user_count integer not null default 0,
  permalink text,
  metadata jsonb not null default '{}'::jsonb,
  raw jsonb not null default '{}'::jsonb,
  is_archived bool not null default false,
  synced_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sentry_issue_snapshots_metadata_object_check
    check (jsonb_typeof(metadata) = 'object'),
  constraint sentry_issue_snapshots_raw_object_check
    check (jsonb_typeof(raw) = 'object')
);

create index if not exists sentry_issue_snapshots_last_seen_idx
on public.sentry_issue_snapshots(last_seen desc nulls last);

create index if not exists sentry_issue_snapshots_status_level_idx
on public.sentry_issue_snapshots(status, level, last_seen desc nulls last);

create index if not exists sentry_issue_snapshots_project_idx
on public.sentry_issue_snapshots(project_slug, last_seen desc nulls last)
where project_slug is not null;

grant select on public.sentry_issue_snapshots to authenticated;
grant select, insert, update, delete on public.sentry_issue_snapshots to service_role;

alter table public.sentry_issue_snapshots enable row level security;

drop policy if exists "sentry_issue_snapshots_admin_select"
on public.sentry_issue_snapshots;
create policy "sentry_issue_snapshots_admin_select"
on public.sentry_issue_snapshots
for select
to authenticated
using (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and coalesce(users.role, 'player') in (
        'admin',
        'super_admin',
        'super-admin',
        'sa'
      )
      and coalesce(users.is_active, true) = true
  )
);

notify pgrst, 'reload schema';
