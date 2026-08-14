-- Numination Pro is activated only after a server-side owner approval.
-- Android may request a plan, but it cannot write a profile tier or expiry.

alter table public.profiles
  add column if not exists "proExpiresAt" timestamptz;

alter table public."PendingRecharge"
  add column if not exists "planTier" text,
  add column if not exists "tierDurationDays" integer;

create index if not exists "profiles_tier_proExpiresAt_idx"
  on public.profiles (tier, "proExpiresAt");

-- Extend the earlier profile hardening trigger: a client must not grant itself
-- Pro access by changing an expiry timestamp directly through Supabase.
create or replace function public.protect_profile_privileged_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- Requests through Supabase's authenticated API carry auth.uid(); the
  -- server's Prisma connection does not and is the only path allowed to
  -- approve billing changes.
  if auth.uid() is not null and new.role is distinct from old.role then
    raise exception 'role changes are not allowed';
  end if;

  if auth.uid() is not null and new.tier is distinct from old.tier then
    raise exception 'tier changes are not allowed';
  end if;

  if auth.uid() is not null and new."proExpiresAt" is distinct from old."proExpiresAt" then
    raise exception 'Pro expiry changes are not allowed';
  end if;

  return new;
end;
$$;
