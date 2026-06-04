create table if not exists public.crm_pipeline_stages (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  name text not null unique,
  sort_order integer not null default 0
);

create table if not exists public.crm_client_stage (
  client_id uuid primary key references public.clients(id) on delete cascade,
  stage_id uuid references public.crm_pipeline_stages(id) on delete set null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists public.crm_client_units (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  client_id uuid not null references public.clients(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  relation_type text not null check (relation_type in ('prospect', 'original', 'current')),
  unique (client_id, unit_id, relation_type)
);

create table if not exists public.crm_activities (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  client_id uuid not null references public.clients(id) on delete cascade,
  unit_id uuid references public.units(id) on delete set null,
  channel text not null check (channel in ('note', 'call', 'whatsapp', 'visit', 'email')),
  content text not null,
  created_by uuid,
  next_contact_at timestamp with time zone,
  outcome text,
  appointment_at timestamp with time zone,
  appointment_with text
);

create table if not exists public.crm_tasks (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  client_id uuid not null references public.clients(id) on delete cascade,
  unit_id uuid references public.units(id) on delete set null,
  assigned_to uuid,
  title text not null,
  due_at timestamp with time zone,
  status text not null default 'open' check (status in ('open', 'done')),
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high'))
);

create index if not exists crm_activities_client_id_created_at_idx on public.crm_activities (client_id, created_at desc);
create index if not exists crm_tasks_client_id_status_due_at_idx on public.crm_tasks (client_id, status, due_at);
create index if not exists crm_client_units_client_id_idx on public.crm_client_units (client_id);
create index if not exists crm_client_units_unit_id_idx on public.crm_client_units (unit_id);

alter table if exists public.crm_pipeline_stages enable row level security;
alter table if exists public.crm_client_stage enable row level security;
alter table if exists public.crm_client_units enable row level security;
alter table if exists public.crm_activities enable row level security;
alter table if exists public.crm_tasks enable row level security;

drop policy if exists "Allow all access" on public.crm_pipeline_stages;
drop policy if exists "Allow all access" on public.crm_client_stage;
drop policy if exists "Allow all access" on public.crm_client_units;
drop policy if exists "Allow all access" on public.crm_activities;
drop policy if exists "Allow all access" on public.crm_tasks;

create policy "Allow all access" on public.crm_pipeline_stages for all using (true) with check (true);
create policy "Allow all access" on public.crm_client_stage for all using (true) with check (true);
create policy "Allow all access" on public.crm_client_units for all using (true) with check (true);
create policy "Allow all access" on public.crm_activities for all using (true) with check (true);
create policy "Allow all access" on public.crm_tasks for all using (true) with check (true);

alter table public.crm_tasks add column if not exists assigned_to uuid;
alter table public.crm_tasks add column if not exists updated_at timestamp with time zone default timezone('utc'::text, now()) not null;
alter table public.crm_tasks add column if not exists completed_at timestamp with time zone;

do $$
begin
  alter table public.crm_tasks
    add constraint crm_tasks_assigned_to_fkey
    foreign key (assigned_to) references auth.users(id) on delete set null;
exception
  when duplicate_object then null;
end
$$;

create index if not exists crm_tasks_assigned_to_status_due_at_idx on public.crm_tasks (assigned_to, status, due_at);
create index if not exists crm_tasks_assigned_to_updated_at_idx on public.crm_tasks (assigned_to, updated_at desc);
create index if not exists crm_tasks_completed_at_idx on public.crm_tasks (completed_at desc);

alter table public.crm_activities add column if not exists created_by uuid;
alter table public.crm_activities add column if not exists next_contact_at timestamp with time zone;
alter table public.crm_activities add column if not exists outcome text;
alter table public.crm_activities add column if not exists appointment_at timestamp with time zone;
alter table public.crm_activities add column if not exists appointment_with text;

do $$
begin
  alter table public.crm_activities
    add constraint crm_activities_created_by_fkey
    foreign key (created_by) references auth.users(id) on delete set null;
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  alter table public.crm_activities
    add constraint crm_activities_outcome_check
    check (outcome is null or outcome in ('completed', 'no_answer', 'appointment'));
exception
  when duplicate_object then null;
end
$$;

create index if not exists crm_activities_client_id_created_at_idx on public.crm_activities (client_id, created_at desc);
create index if not exists crm_activities_created_by_created_at_idx on public.crm_activities (created_by, created_at desc);

insert into public.crm_pipeline_stages (name, sort_order)
values
  ('عميل جديد', 10),
  ('مهتم', 20),
  ('زيارة', 30),
  ('تفاوض', 40),
  ('تم الإغلاق', 50),
  ('مرفوض', 60)
on conflict (name) do update set sort_order = excluded.sort_order;
