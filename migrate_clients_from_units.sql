-- ====================================================
-- سكربت ترحيل العملاء من جدول الوحدات إلى جدول العملاء الجديد
-- ====================================================

-- 1. إنشاء الجداول الجديدة إذا لم تكن موجودة
create table if not exists public.clients (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  name text not null,
  id_number text unique,
  phone text,
  notes text
);

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
alter table if exists public.clients enable row level security;
alter table if exists public.unit_ownership_history enable row level security;

-- إنشاء سياسات الوصول
drop policy if exists "Allow all access" on public.clients;
drop policy if exists "Allow all access" on public.unit_ownership_history;
create policy "Allow all access" on public.clients for all using (true) with check (true);
create policy "Allow all access" on public.unit_ownership_history for all using (true) with check (true);

-- ====================================================
-- 2. إضافة حقول client_id إلى جدول units إذا لم تكن موجودة
-- ====================================================

alter table public.units 
add column if not exists original_client_id uuid references public.clients(id) on delete set null;

alter table public.units 
add column if not exists current_client_id uuid references public.clients(id) on delete set null;

-- ====================================================
-- 3. ترحيل العملاء الأصليين (من حقول client_)
-- ====================================================

insert into public.clients (name, id_number, phone)
select distinct
  client_name as name,
  client_id_number as id_number,
  client_phone as phone
from public.units
where client_name is not null and client_name != ''
on conflict (id_number) do nothing;

-- ====================================================
-- 4. ترحيل المالكين الحاليين (من حقول title_deed_owner_)
-- ====================================================

insert into public.clients (name, id_number, phone)
select distinct
  title_deed_owner as name,
  title_deed_owner_id as id_number,
  title_deed_owner_phone as phone
from public.units
where title_deed_owner is not null and title_deed_owner != ''
on conflict (id_number) do nothing;

-- ====================================================
-- 5. تحديث جدول units مع client_id الأصلي
-- ====================================================

update public.units u
set original_client_id = c.id
from public.clients c
where (u.client_id_number is not null and u.client_id_number = c.id_number)
   or (u.client_name = c.name and u.client_id_number is null);

-- ====================================================
-- 6. تحديث جدول units مع client_id الحالي
-- ====================================================

update public.units u
set current_client_id = c.id
from public.clients c
where (u.title_deed_owner_id is not null and u.title_deed_owner_id = c.id_number)
   or (u.title_deed_owner = c.name and u.title_deed_owner_id is null);

-- ====================================================
-- 7. إنشاء سجل تاريخي للملكية الحالية
-- ====================================================

insert into public.unit_ownership_history (unit_id, client_id, transaction_type, notes)
select 
  id as unit_id,
  current_client_id as client_id,
  'purchase' as transaction_type,
  'تم ترحيله من البيانات القديمة' as notes
from public.units
where current_client_id is not null;
