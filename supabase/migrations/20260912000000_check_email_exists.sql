-- Lets the client know, before asking for a password, whether an email
-- already belongs to an account. Reads public.profiles (kept in sync with
-- auth.users via handle_new_user) so we never need direct auth schema access.

create or replace function public.check_email_exists(p_email text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where email = lower(trim(p_email))
  );
$$;

revoke all on function public.check_email_exists(text) from public;
grant execute on function public.check_email_exists(text) to anon, authenticated;
