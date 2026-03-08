
create table if not exists public.unit_contracts (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unit_id uuid references public.units(id) on delete cascade not null,
  type text not null,
  custom_type text,
  file_url text not null,
  file_path text not null
);

alter table public.unit_contracts enable row level security;

drop policy if exists "Allow all access for unit_contracts" on public.unit_contracts;
create policy "Allow all access for unit_contracts" on public.unit_contracts for all using (true) with check (true);
