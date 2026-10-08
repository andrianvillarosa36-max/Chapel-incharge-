-- Chapel In-Charge: accounts, admin panel and user limit.
-- Paste this whole file into Supabase > SQL Editor > Run. Safe to run again.

create extension if not exists pgcrypto with schema extensions;

-- Tables --------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  name text not null default '',
  is_admin boolean not null default false
);
alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists name text not null default '';
alter table public.profiles add column if not exists is_admin boolean not null default false;
alter table public.profiles add column if not exists course text;
alter table public.profiles add column if not exists section text;
alter table public.profiles add column if not exists year text;
create unique index if not exists profiles_username_key on public.profiles (lower(username));

create table if not exists public.pending_users (
  username text primary key,
  name text, course text, section text, year text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.app_settings (
  id int primary key default 1 check (id = 1),
  user_limit int not null default 50 check (user_limit >= 1)
);
insert into public.app_settings (id, user_limit) values (1, 50) on conflict do nothing;

create table if not exists public.messages (
  id bigint generated always as identity primary key,
  user_id uuid default auth.uid(),
  name text,
  text text,
  created_at timestamptz not null default now()
);
alter table public.messages add column if not exists user_id uuid default auth.uid();

-- Helper: is the current user an admin? ------------------------------
create or replace function public.am_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false)
$$;

-- New accounts: only allowed if an admin pre-approved the username ----
-- (the very first account ever created becomes the admin).
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  uname text := lower(split_part(new.email, '@', 1));
  p public.pending_users%rowtype;
  lim int; n int; first_user boolean;
begin
  select not exists (select 1 from public.profiles) into first_user;
  select * into p from public.pending_users where username = uname;
  if not found then
    if first_user then
      p.name := uname; p.is_admin := true;
    else
      raise exception 'Sign-ups are closed. Ask an admin to create your account.';
    end if;
  end if;
  if not coalesce(p.is_admin, false) then
    select user_limit into lim from public.app_settings where id = 1;
    select count(*) into n from public.profiles where not is_admin;
    if n >= coalesce(lim, 50) then
      raise exception 'User limit reached.';
    end if;
  end if;
  insert into public.profiles (id, username, name, is_admin, course, section, year)
  values (new.id, uname, coalesce(nullif(p.name, ''), uname), coalesce(p.is_admin, false), p.course, p.section, p.year);
  delete from public.pending_users where username = uname;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Users cannot make themselves admin or rename themselves ------------
create or replace function public.protect_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.am_admin() then
    if new.id <> old.id or new.username <> old.username or new.is_admin <> old.is_admin then
      raise exception 'Not allowed.';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists protect_profile_trg on public.profiles;
create trigger protect_profile_trg before update on public.profiles
  for each row execute function public.protect_profile();

-- Admin-only actions ---------------------------------------------------
create or replace function public.admin_delete_user(uid uuid) returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if not public.am_admin() then raise exception 'Admins only.'; end if;
  if uid = auth.uid() then raise exception 'You cannot delete your own account.'; end if;
  delete from public.messages where user_id = uid;
  delete from auth.users where id = uid;
end $$;

create or replace function public.admin_set_password(uid uuid, pw text) returns void
language plpgsql security definer set search_path = public, auth, extensions as $$
begin
  if not public.am_admin() then raise exception 'Admins only.'; end if;
  if length(pw) < 6 then raise exception 'Password too short.'; end if;
  update auth.users set encrypted_password = crypt(pw, gen_salt('bf')), updated_at = now() where id = uid;
end $$;

revoke execute on function public.admin_delete_user(uuid), public.admin_set_password(uuid, text) from public, anon;
grant execute on function public.admin_delete_user(uuid), public.admin_set_password(uuid, text) to authenticated;

-- Row level security (drops old policies on these tables first) ------
do $$ declare r record; begin
  for r in select policyname, tablename from pg_policies
           where schemaname = 'public' and tablename in ('profiles','pending_users','app_settings','messages')
  loop execute format('drop policy %I on public.%I', r.policyname, r.tablename); end loop;
end $$;

alter table public.profiles enable row level security;
alter table public.pending_users enable row level security;
alter table public.app_settings enable row level security;
alter table public.messages enable row level security;

create policy "profiles read own or admin" on public.profiles for select to authenticated
  using (id = auth.uid() or public.am_admin());
create policy "profiles update own" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy "profiles update admin" on public.profiles for update to authenticated
  using (public.am_admin()) with check (public.am_admin());

create policy "pending admin all" on public.pending_users for all to authenticated
  using (public.am_admin()) with check (public.am_admin());

create policy "settings admin read" on public.app_settings for select to authenticated using (public.am_admin());
create policy "settings admin update" on public.app_settings for update to authenticated
  using (public.am_admin()) with check (public.am_admin());

create policy "messages read" on public.messages for select to authenticated using (true);
create policy "messages insert own" on public.messages for insert to authenticated
  with check (user_id = auth.uid());
create policy "messages delete own or admin" on public.messages for delete to authenticated
  using (user_id = auth.uid() or public.am_admin());

-- Live chat updates (ignore the error if already enabled) -------------
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when others then null;
end $$;
