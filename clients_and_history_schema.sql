-- إنشاء جدول العملاء
create table if not exists public.clients (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  name text not null,
  id_number text unique,
  phone text,
  notes text
);

-- إنشاء جدول تاريخ ملكية الوحدات
create table if not exists public.unit_ownership_history (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unit_id uuid references public.units(id) on delete cascade not null,
  client_id uuid references public.clients(id) on delete set null,
  previous_client_id uuid references public.clients(id) on delete set null,
  transaction_type text not null check (transaction_type in ('purchase', 'sale', 'transfer')),
  transaction_date date,
  price numeric,
  notes text
);

-- تمكين Row Level Security
alter table public.clients enable row level security;
alter table public.unit_ownership_history enable row level security;

-- إنشاء سياسات الوصول
drop policy if exists "Allow all access" on public.clients;
drop policy if exists "Allow all access" on public.unit_ownership_history;
create policy "Allow all access" on public.clients for all using (true) with check (true);
create policy "Allow all access" on public.unit_ownership_history for all using (true) with check (true);
