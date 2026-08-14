-- Activity, memory, notifications, and schema hardening for Numination.
-- Adds the tables referenced by backend API routes that were missing from
-- the initial migration, plus security and index improvements.

-- ---------------------------------------------------------------------------
-- AppVersion (Prisma had this model but the first migration omitted it)
-- ---------------------------------------------------------------------------
create table if not exists public."AppVersion" (
  id text primary key,
  platform text not null,
  version text not null,
  mandatory boolean not null default false,
  "downloadUrl" text not null,
  notes text,
  "createdAt" timestamptz not null default now()
);

create index if not exists "AppVersion_platform_idx"
  on public."AppVersion" (platform);

-- ---------------------------------------------------------------------------
-- Project: recent-projects support
-- ---------------------------------------------------------------------------
alter table public."Project"
  add column if not exists "lastOpenedAt" timestamptz;

create index if not exists "Project_userId_updatedAt_idx"
  on public."Project" ("userId", "updatedAt" desc);

-- ---------------------------------------------------------------------------
-- CreditLog: faster history queries
-- ---------------------------------------------------------------------------
create index if not exists "CreditLog_userId_timestamp_idx"
  on public."CreditLog" ("userId", timestamp desc);

-- ---------------------------------------------------------------------------
-- Unified activity feed
-- ---------------------------------------------------------------------------
create table if not exists public."UserActivity" (
  id text primary key,
  "userId" uuid not null references public.profiles(id) on delete cascade,
  "projectId" text references public."Project"(id) on delete set null,
  "fileId" text,
  type text not null,
  title text,
  description text,
  metadata jsonb,
  "createdAt" timestamptz not null default now()
);

create index if not exists "UserActivity_userId_createdAt_idx"
  on public."UserActivity" ("userId", "createdAt" desc);

create index if not exists "UserActivity_projectId_createdAt_idx"
  on public."UserActivity" ("projectId", "createdAt" desc);

-- ---------------------------------------------------------------------------
-- Persistent notifications
-- ---------------------------------------------------------------------------
create table if not exists public."Notification" (
  id text primary key,
  "userId" uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  message text not null,
  read boolean not null default false,
  metadata jsonb,
  "createdAt" timestamptz not null default now()
);

create index if not exists "Notification_userId_createdAt_idx"
  on public."Notification" ("userId", "createdAt" desc);

create index if not exists "Notification_userId_read_idx"
  on public."Notification" ("userId", read);

-- ---------------------------------------------------------------------------
-- AI memory store
-- ---------------------------------------------------------------------------
create table if not exists public."Memory" (
  id text primary key,
  "userId" uuid not null references public.profiles(id) on delete cascade,
  "projectId" text references public."Project"(id) on delete set null,
  title text not null,
  content text not null,
  type text not null default 'PROJECT',
  path text,
  extension text,
  pinned boolean not null default false,
  metadata jsonb,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create index if not exists "Memory_userId_updatedAt_idx"
  on public."Memory" ("userId", "updatedAt" desc);

create index if not exists "Memory_userId_projectId_idx"
  on public."Memory" ("userId", "projectId");

drop trigger if exists memory_set_updated_at on public."Memory";
create trigger memory_set_updated_at
before update on public."Memory"
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public."UserActivity" enable row level security;
alter table public."Notification" enable row level security;
alter table public."Memory" enable row level security;
alter table public."AppVersion" enable row level security;

drop policy if exists user_activity_select_own on public."UserActivity";
create policy user_activity_select_own on public."UserActivity"
  for select to authenticated using ("userId" = auth.uid());

drop policy if exists user_activity_insert_own on public."UserActivity";
create policy user_activity_insert_own on public."UserActivity"
  for insert to authenticated with check ("userId" = auth.uid());

drop policy if exists notifications_select_own on public."Notification";
create policy notifications_select_own on public."Notification"
  for select to authenticated using ("userId" = auth.uid());

drop policy if exists notifications_update_own on public."Notification";
create policy notifications_update_own on public."Notification"
  for update to authenticated
  using ("userId" = auth.uid())
  with check ("userId" = auth.uid());

drop policy if exists memory_all_own on public."Memory";
create policy memory_all_own on public."Memory"
  for all to authenticated
  using ("userId" = auth.uid())
  with check ("userId" = auth.uid());

-- AppVersion is public read-only metadata for clients.
drop policy if exists app_version_select_all on public."AppVersion";
create policy app_version_select_all on public."AppVersion"
  for select to authenticated using (true);

grant select on public."UserActivity" to authenticated;
grant insert on public."UserActivity" to authenticated;
grant select, update on public."Notification" to authenticated;
grant select, insert, update, delete on public."Memory" to authenticated;
grant select on public."AppVersion" to authenticated;

-- ---------------------------------------------------------------------------
-- Security: prevent self-promotion to OWNER via direct Supabase client
-- ---------------------------------------------------------------------------
create or replace function public.protect_profile_privileged_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.role is distinct from old.role then
    raise exception 'role changes are not allowed';
  end if;

  if new.tier is distinct from old.tier then
    raise exception 'tier changes are not allowed';
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_protect_privileged_columns on public.profiles;
create trigger profiles_protect_privileged_columns
before update on public.profiles
for each row execute function public.protect_profile_privileged_columns();
