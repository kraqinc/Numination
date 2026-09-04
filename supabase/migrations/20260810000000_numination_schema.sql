-- Numination application schema for a fresh Supabase Postgres project.
-- Authentication lives in auth.users. Application profile rows reuse the
-- Supabase UUID as profiles.id, so backend access tokens can address rows
-- without a second user-id mapping table.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  role text not null default 'USER',
  tier text not null default 'FREE',
  "createdAt" timestamptz not null default now()
);

create table if not exists public."Credits" (
  "userId" uuid primary key references public.profiles(id) on delete cascade,
  balance integer not null default 50,
  "updatedAt" timestamptz not null default now()
);

create table if not exists public."CreditLog" (
  id text primary key,
  "userId" uuid not null references public.profiles(id) on delete cascade,
  amount integer not null,
  reason text not null,
  timestamp timestamptz not null default now()
);

create table if not exists public."Project" (
  id text primary key,
  "userId" uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  description text,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public."ProjectFile" (
  id text primary key,
  "projectId" text not null references public."Project"(id) on delete cascade,
  "parentId" text,
  name text not null,
  path text not null,
  "isDirectory" boolean not null default false,
  content text,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public."PendingRecharge" (
  id text primary key,
  "userId" uuid not null references public.profiles(id) on delete cascade,
  "packageId" text not null,
  "creditAmount" integer not null,
  "priceLabel" text not null,
  "referenceCode" text not null unique,
  status text not null default 'PENDING',
  "createdAt" timestamptz not null default now(),
  "resolvedAt" timestamptz,
  "resolvedBy" uuid
);

create table if not exists public."AuditLog" (
  id text primary key,
  "actorId" uuid not null references public.profiles(id) on delete cascade,
  action text not null,
  details text,
  timestamp timestamptz not null default now()
);

create table if not exists public."StorageFile" (
  id text primary key,
  "userId" uuid not null references public.profiles(id) on delete cascade,
  key text not null unique,
  url text not null,
  token text not null,
  "expiresAt" timestamptz not null,
  size integer not null,
  "mimeType" text,
  "createdAt" timestamptz not null default now()
);

create index if not exists "CreditLog_userId_idx" on public."CreditLog" ("userId");
create index if not exists "Project_userId_idx" on public."Project" ("userId");
create index if not exists "ProjectFile_projectId_idx" on public."ProjectFile" ("projectId");
create index if not exists "ProjectFile_parentId_idx" on public."ProjectFile" ("parentId");
create index if not exists "PendingRecharge_userId_idx" on public."PendingRecharge" ("userId");
create index if not exists "PendingRecharge_status_idx" on public."PendingRecharge" (status);
create index if not exists "AuditLog_actorId_idx" on public."AuditLog" ("actorId");
create index if not exists "AuditLog_timestamp_idx" on public."AuditLog" (timestamp);
create index if not exists "StorageFile_userId_idx" on public."StorageFile" ("userId");
create index if not exists "profiles_role_idx" on public.profiles (role);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new."updatedAt" = now();
  return new;
end;
$$;

drop trigger if exists credits_set_updated_at on public."Credits";
create trigger credits_set_updated_at
before update on public."Credits"
for each row execute function public.set_updated_at();

drop trigger if exists project_set_updated_at on public."Project";
create trigger project_set_updated_at
before update on public."Project"
for each row execute function public.set_updated_at();

drop trigger if exists project_file_set_updated_at on public."ProjectFile";
create trigger project_file_set_updated_at
before update on public."ProjectFile"
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, role, tier, "createdAt")
  values (new.id, coalesce(new.email, ''), 'USER', 'FREE', now())
  on conflict (id) do update set email = excluded.email;

  insert into public."Credits" ("userId", balance, "updatedAt")
  values (new.id, 50, now())
  on conflict ("userId") do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Backfill rows for users that already exist in Auth.
insert into public.profiles (id, email, role, tier, "createdAt")
select id, coalesce(email, ''), 'USER', 'FREE', now()
from auth.users
on conflict (id) do update set email = excluded.email;

insert into public."Credits" ("userId", balance, "updatedAt")
select id, 50, now() from auth.users
on conflict ("userId") do nothing;

-- RLS -----------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public."Credits" enable row level security;
alter table public."Project" enable row level security;
alter table public."ProjectFile" enable row level security;
alter table public."PendingRecharge" enable row level security;
alter table public."StorageFile" enable row level security;
alter table public."CreditLog" enable row level security;
alter table public."AuditLog" enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = auth.uid());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists credits_select_own on public."Credits";
create policy credits_select_own on public."Credits"
  for select to authenticated using ("userId" = auth.uid());

drop policy if exists projects_all_own on public."Project";
create policy projects_all_own on public."Project"
  for all to authenticated using ("userId" = auth.uid()) with check ("userId" = auth.uid());

drop policy if exists project_files_all_own on public."ProjectFile";
create policy project_files_all_own on public."ProjectFile"
  for all to authenticated
  using (exists (select 1 from public."Project" p where p.id = "ProjectFile"."projectId" and p."userId" = auth.uid()))
  with check (exists (select 1 from public."Project" p where p.id = "ProjectFile"."projectId" and p."userId" = auth.uid()));

drop policy if exists pending_recharges_select_own on public."PendingRecharge";
create policy pending_recharges_select_own on public."PendingRecharge"
  for select to authenticated using ("userId" = auth.uid());

drop policy if exists pending_recharges_insert_own on public."PendingRecharge";
create policy pending_recharges_insert_own on public."PendingRecharge"
  for insert to authenticated with check ("userId" = auth.uid());

drop policy if exists storage_files_select_own on public."StorageFile";
create policy storage_files_select_own on public."StorageFile"
  for select to authenticated using ("userId" = auth.uid());

-- Authenticated clients may only see rows allowed by the policies above.
grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;
grant select on public."Credits" to authenticated;
grant select, insert, update, delete on public."Project" to authenticated;
grant select, insert, update, delete on public."ProjectFile" to authenticated;
grant select, insert on public."PendingRecharge" to authenticated;
grant select on public."StorageFile" to authenticated;

-- Internal logs intentionally receive no authenticated grants/policies.
