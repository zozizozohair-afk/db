create table if not exists public.projects (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  name text not null,
  project_number text,
  deed_number text,
  orientation text,
  floors_count integer default 1,
  units_per_floor integer default 4,
  has_annex boolean default false,
  annex_count integer default 0,
  water_meter text,
  electricity_meter text,
  status text default 'active',
  electricity_meters text[] default array[]::text[],
  hoa_start_date date,
  hoa_end_date date
);

create table if not exists public.units (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  project_id uuid references public.projects(id) on delete cascade not null,
  unit_number integer not null,
  floor_number integer not null,
  floor_label text,
  direction_label text,
  type text check (type in ('apartment', 'annex')),
  electricity_meter text,
  water_meter text,
  client_name text,
  deed_number text,
  status text default 'available'
);

alter table public.projects enable row level security;
alter table public.units enable row level security;

drop policy if exists "Allow all access" on public.projects;
drop policy if exists "Allow all access" on public.units;
create policy "Allow all access" on public.projects for all using (true) with check (true);
create policy "Allow all access" on public.units for all using (true) with check (true);

alter table public.projects 
add column if not exists electricity_meters text[] default array[]::text[],
add column if not exists hoa_start_date date,
add column if not exists hoa_end_date date;

update public.projects 
set electricity_meters = array[electricity_meter] 
where electricity_meter is not null and (electricity_meters is null or electricity_meters = array[]::text[]);

create table if not exists public.project_documents (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  project_id uuid references public.projects(id) on delete cascade not null,
  title text not null,
  type text not null,
  file_url text not null,
  file_path text not null
);

alter table public.project_documents enable row level security;
drop policy if exists "Allow all access" on public.project_documents;
create policy "Allow all access" on public.project_documents for all using (true) with check (true);

create table if not exists public.unit_models (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  project_id uuid references public.projects(id) on delete cascade not null,
  name text not null,
  description text,
  files jsonb not null default '[]'::jsonb
);

alter table public.unit_models enable row level security;
drop policy if exists "Allow all access for unit_models" on public.unit_models;
create policy "Allow all access for unit_models" on public.unit_models for all using (true) with check (true);

alter table public.units 
add column if not exists title_deed_owner text,
add column if not exists client_id_number text,
add column if not exists client_phone text;

alter table public.units 
add column if not exists deed_file_url text;

alter table public.units 
add column if not exists title_deed_owner_id text;

alter table public.units 
add column if not exists title_deed_owner_phone text;

alter table public.units 
add column if not exists sorting_record_file_url text;

alter table public.units 
add column if not exists modifications_file_url text;

alter table public.units 
add column if not exists notes text;

alter table public.units
add column if not exists modification_client_confirmed boolean default false,
add column if not exists modification_engineer_reviewed boolean default false,
add column if not exists modification_completed boolean default false;

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN (
    SELECT constraint_name 
    FROM information_schema.constraint_column_usage 
    WHERE table_name = 'units' AND column_name = 'status'
  ) LOOP 
    EXECUTE 'ALTER TABLE public.units DROP CONSTRAINT ' || quote_ident(r.constraint_name); 
  END LOOP; 
END $$;

ALTER TABLE public.units ADD CONSTRAINT units_status_check 
CHECK (status IN (
  'available', 
  'sold', 
  'rented', 
  'for_resale', 
  'under_construction', 
  'deed_completed', 
  'resold', 
  'transferred_to_other'
));

insert into storage.buckets (id, name, public)
values ('project-files', 'project-files', true)
on conflict (id) do nothing;

drop policy if exists "Public Read Access" on storage.objects;
create policy "Public Read Access"
on storage.objects for select
using ( bucket_id = 'project-files' );

drop policy if exists "Allow Uploads" on storage.objects;
create policy "Allow Uploads"
on storage.objects for insert
with check ( bucket_id = 'project-files' );

drop policy if exists "Allow Updates" on storage.objects;
create policy "Allow Updates"
on storage.objects for update
using ( bucket_id = 'project-files' );

drop policy if exists "Allow Deletes" on storage.objects;
create policy "Allow Deletes"
on storage.objects for delete
using ( bucket_id = 'project-files' );
