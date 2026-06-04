create table if not exists public.employee_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  job_title text,
  role text not null default 'admin' check (role in ('admin', 'manager', 'marketing', 'customer_service', 'staff', 'viewer')),
  is_active boolean not null default true
);

alter table public.employee_profiles enable row level security;

alter table public.employee_profiles drop constraint if exists employee_profiles_role_check;
alter table public.employee_profiles
  add constraint employee_profiles_role_check
  check (role in ('admin', 'manager', 'marketing', 'customer_service', 'staff', 'viewer'));

drop policy if exists "Allow all access" on public.employee_profiles;
create policy "Allow all access" on public.employee_profiles for all using (true) with check (true);

create or replace function public.crm_list_employees()
returns table (
  id uuid,
  email text,
  user_created_at timestamp with time zone,
  last_sign_in_at timestamp with time zone,
  job_title text,
  role text,
  is_active boolean
)
language sql
security definer
set search_path = public, auth
as $$
  select
    u.id,
    u.email,
    u.created_at as user_created_at,
    u.last_sign_in_at,
    p.job_title,
    coalesce(p.role, 'admin') as role,
    coalesce(p.is_active, true) as is_active
  from auth.users u
  left join public.employee_profiles p on p.user_id = u.id
  order by u.created_at desc;
$$;

grant execute on function public.crm_list_employees() to anon, authenticated;

create or replace function public.crm_upsert_employee_by_email(
  p_email text,
  p_job_title text,
  p_role text
)
returns table (
  id uuid,
  email text,
  job_title text,
  role text,
  is_active boolean
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
  v_email text;
begin
  if p_email is null or length(trim(p_email)) = 0 then
    raise exception 'email_required';
  end if;

  select u.id, u.email
  into v_user_id, v_email
  from auth.users u
  where lower(u.email) = lower(trim(p_email))
  limit 1;

  if v_user_id is null then
    raise exception 'user_not_found';
  end if;

  insert into public.employee_profiles (user_id, job_title, role, is_active)
  values (v_user_id, nullif(trim(p_job_title), ''), coalesce(nullif(trim(p_role), ''), 'admin'), true)
  on conflict (user_id) do update set
    job_title = excluded.job_title,
    role = excluded.role,
    is_active = true;

  return query
  select
    v_user_id as id,
    v_email as email,
    p.job_title,
    p.role,
    p.is_active
  from public.employee_profiles p
  where p.user_id = v_user_id;
end;
$$;

grant execute on function public.crm_upsert_employee_by_email(text, text, text) to anon, authenticated;

create or replace function public.crm_update_employee_profile(
  p_user_id uuid,
  p_job_title text,
  p_role text,
  p_is_active boolean
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.employee_profiles (user_id, job_title, role, is_active)
  values (
    p_user_id,
    nullif(trim(p_job_title), ''),
    coalesce(nullif(trim(p_role), ''), 'admin'),
    coalesce(p_is_active, true)
  )
  on conflict (user_id) do update set
    job_title = excluded.job_title,
    role = excluded.role,
    is_active = excluded.is_active;
$$;

grant execute on function public.crm_update_employee_profile(uuid, text, text, boolean) to anon, authenticated;
