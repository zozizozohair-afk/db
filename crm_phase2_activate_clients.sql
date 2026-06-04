alter table public.clients
add column if not exists is_active boolean not null default true;

alter table public.clients
add column if not exists activated_at timestamp with time zone default timezone('utc'::text, now());

alter table public.clients
add column if not exists source text;

alter table public.units
add column if not exists original_client_id uuid references public.clients(id) on delete set null;

alter table public.units
add column if not exists current_client_id uuid references public.clients(id) on delete set null;

update public.clients
set
  is_active = true,
  activated_at = coalesce(activated_at, timezone('utc'::text, now())),
  source = coalesce(source, 'existing')
where is_active is distinct from true or activated_at is null or source is null;

insert into public.clients (name, id_number, phone, source, is_active, activated_at)
select distinct
  u.client_name as name,
  u.client_id_number as id_number,
  u.client_phone as phone,
  'imported_from_units_original' as source,
  true as is_active,
  timezone('utc'::text, now()) as activated_at
from public.units u
where u.client_name is not null and u.client_name != '' and u.client_id_number is not null and u.client_id_number != ''
on conflict (id_number) do update set
  name = excluded.name,
  phone = coalesce(public.clients.phone, excluded.phone),
  source = coalesce(public.clients.source, excluded.source),
  is_active = true,
  activated_at = coalesce(public.clients.activated_at, excluded.activated_at);

insert into public.clients (name, id_number, phone, source, is_active, activated_at)
select distinct
  u.title_deed_owner as name,
  u.title_deed_owner_id as id_number,
  u.title_deed_owner_phone as phone,
  'imported_from_units_current' as source,
  true as is_active,
  timezone('utc'::text, now()) as activated_at
from public.units u
where u.title_deed_owner is not null and u.title_deed_owner != '' and u.title_deed_owner_id is not null and u.title_deed_owner_id != ''
on conflict (id_number) do update set
  name = excluded.name,
  phone = coalesce(public.clients.phone, excluded.phone),
  source = coalesce(public.clients.source, excluded.source),
  is_active = true,
  activated_at = coalesce(public.clients.activated_at, excluded.activated_at);

insert into public.clients (name, phone, source, is_active, activated_at)
select distinct
  u.client_name as name,
  u.client_phone as phone,
  'imported_from_units_original_no_id' as source,
  true as is_active,
  timezone('utc'::text, now()) as activated_at
from public.units u
where
  u.client_name is not null and u.client_name != ''
  and (u.client_id_number is null or u.client_id_number = '')
  and u.client_phone is not null and u.client_phone != ''
  and not exists (
    select 1 from public.clients c
    where c.id_number is null and c.name = u.client_name and coalesce(c.phone, '') = u.client_phone
  );

insert into public.clients (name, phone, source, is_active, activated_at)
select distinct
  u.title_deed_owner as name,
  u.title_deed_owner_phone as phone,
  'imported_from_units_current_no_id' as source,
  true as is_active,
  timezone('utc'::text, now()) as activated_at
from public.units u
where
  u.title_deed_owner is not null and u.title_deed_owner != ''
  and (u.title_deed_owner_id is null or u.title_deed_owner_id = '')
  and u.title_deed_owner_phone is not null and u.title_deed_owner_phone != ''
  and not exists (
    select 1 from public.clients c
    where c.id_number is null and c.name = u.title_deed_owner and coalesce(c.phone, '') = u.title_deed_owner_phone
  );

update public.units u
set original_client_id = c.id
from public.clients c
where u.client_id_number is not null and u.client_id_number != '' and c.id_number = u.client_id_number;

update public.units u
set current_client_id = c.id
from public.clients c
where u.title_deed_owner_id is not null and u.title_deed_owner_id != '' and c.id_number = u.title_deed_owner_id;

update public.clients c
set
  is_active = true,
  activated_at = coalesce(c.activated_at, timezone('utc'::text, now())),
  source = coalesce(c.source, 'linked_from_units')
where exists (
  select 1 from public.units u
  where u.original_client_id = c.id or u.current_client_id = c.id
);
