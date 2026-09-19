-- Adds real chat persistence (Chat + Message) and profile customization
-- fields (displayName, pronouns, avatarUrl) on top of the existing
-- Numination schema. Follows the same conventions as
-- 20260810000000_numination_schema.sql: PascalCase quoted table names,
-- text primary keys (app-generated ids), userId FKs to profiles, RLS
-- scoped to auth.uid().

-- Profile customization ------------------------------------------------------
alter table public.profiles
  add column if not exists "displayName" text,
  add column if not exists pronouns text,
  add column if not exists "avatarUrl" text;

-- Chats ------------------------------------------------------------------
create table if not exists public."Chat" (
  id text primary key,
  "userId" uuid not null references public.profiles(id) on delete cascade,
  title text not null default 'Nuevo chat',
  mode text not null default 'chat', -- 'chat' | 'coder'
  "isGhost" boolean not null default false, -- true = incognito, not persisted long-term / hidden from sidebar list
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public."Message" (
  id text primary key,
  "chatId" text not null references public."Chat"(id) on delete cascade,
  role text not null, -- 'user' | 'assistant'
  content text not null,
  "createdAt" timestamptz not null default now()
);

create index if not exists message_chat_id_idx on public."Message" ("chatId", "createdAt");

-- RLS -----------------------------------------------------------------------
alter table public."Chat" enable row level security;
alter table public."Message" enable row level security;

drop policy if exists chats_all_own on public."Chat";
create policy chats_all_own on public."Chat"
  for all to authenticated using ("userId" = auth.uid()) with check ("userId" = auth.uid());

drop policy if exists messages_all_own on public."Message";
create policy messages_all_own on public."Message"
  for all to authenticated
  using (exists (select 1 from public."Chat" c where c.id = "Message"."chatId" and c."userId" = auth.uid()))
  with check (exists (select 1 from public."Chat" c where c.id = "Message"."chatId" and c."userId" = auth.uid()));

grant select, insert, update, delete on public."Chat" to authenticated;
grant select, insert, update, delete on public."Message" to authenticated;

-- Storage bucket for profile avatars ----------------------------------------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists avatars_read_public on storage.objects;
create policy avatars_read_public on storage.objects
  for select to public using (bucket_id = 'avatars');

drop policy if exists avatars_write_own on storage.objects;
create policy avatars_write_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);   