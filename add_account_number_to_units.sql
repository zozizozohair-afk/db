-- إضافة عمود رقم الحساب إلى جدول الوحدات
alter table public.units 
add column if not exists account_number text;
