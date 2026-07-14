begin;

do $$
declare
  v_projects_schema text;
  v_units_schema text;
  v_unit_models_schema text;
  v_unit_model_assets_schema text;
begin
  select schemaname
    into v_projects_schema
  from pg_tables
  where tablename = 'projects'
    and schemaname not in ('pg_catalog', 'information_schema')
  order by case when schemaname = 'public' then 0 else 1 end, schemaname
  limit 1;

  select schemaname
    into v_units_schema
  from pg_tables
  where tablename = 'units'
    and schemaname not in ('pg_catalog', 'information_schema')
  order by case when schemaname = 'public' then 0 else 1 end, schemaname
  limit 1;

  select schemaname
    into v_unit_models_schema
  from pg_tables
  where tablename = 'unit_models'
    and schemaname not in ('pg_catalog', 'information_schema')
  order by case when schemaname = 'public' then 0 else 1 end, schemaname
  limit 1;

  select schemaname
    into v_unit_model_assets_schema
  from pg_tables
  where tablename = 'unit_model_assets'
    and schemaname not in ('pg_catalog', 'information_schema')
  order by case when schemaname = 'public' then 0 else 1 end, schemaname
  limit 1;

  if v_projects_schema is null then
    raise exception 'Table "projects" not found. تأكد أنك على مشروع Supabase الصحيح.';
  end if;

  if v_units_schema is null then
    raise exception 'Table "units" not found. تأكد أنك على مشروع Supabase الصحيح.';
  end if;

  if v_unit_models_schema is null then
    raise exception 'Table "unit_models" not found. تأكد أنك على مشروع Supabase الصحيح.';
  end if;

  if v_unit_model_assets_schema is null then
    raise exception 'Table "unit_model_assets" not found. تأكد أنك على مشروع Supabase الصحيح.';
  end if;

  raise notice 'Detected schemas => projects: %, units: %, unit_models: %, unit_model_assets: %',
    v_projects_schema, v_units_schema, v_unit_models_schema, v_unit_model_assets_schema;

  execute format('alter table %I.projects add column if not exists public_enabled boolean not null default false', v_projects_schema);
  execute format('alter table %I.projects add column if not exists location_text text', v_projects_schema);

  execute format('alter table %I.unit_models add column if not exists public_enabled boolean not null default false', v_unit_models_schema);
  execute format('alter table %I.unit_models add column if not exists area_sqm numeric', v_unit_models_schema);

  execute format(
    'alter table %I.unit_model_assets add column if not exists display_role text check (display_role in (''cover'', ''facade''))',
    v_unit_model_assets_schema
  );

  execute format('alter table %I.unit_model_assets enable row level security', v_unit_model_assets_schema);

  execute format('drop policy if exists "auth can insert unit model assets" on %I.unit_model_assets', v_unit_model_assets_schema);
  execute format('drop policy if exists "auth can read unit model assets" on %I.unit_model_assets', v_unit_model_assets_schema);
  execute format('drop policy if exists "auth can update unit model assets" on %I.unit_model_assets', v_unit_model_assets_schema);
  execute format('drop policy if exists "auth can delete unit model assets" on %I.unit_model_assets', v_unit_model_assets_schema);

  execute format($policy$
    create policy "auth can insert unit model assets"
    on %I.unit_model_assets
    for insert
    to authenticated
    with check (true)
  $policy$, v_unit_model_assets_schema);

  execute format($policy$
    create policy "auth can read unit model assets"
    on %I.unit_model_assets
    for select
    to authenticated
    using (true)
  $policy$, v_unit_model_assets_schema);

  execute format($policy$
    create policy "auth can update unit model assets"
    on %I.unit_model_assets
    for update
    to authenticated
    using (true)
    with check (true)
  $policy$, v_unit_model_assets_schema);

  execute format($policy$
    create policy "auth can delete unit model assets"
    on %I.unit_model_assets
    for delete
    to authenticated
    using (true)
  $policy$, v_unit_model_assets_schema);

  execute 'drop view if exists public.public_units_view';
  execute 'drop view if exists public.public_unit_model_view';
  execute 'drop view if exists public.public_model_assets_view';

  execute format($view$
    create view public.public_units_view as
    select
      u.id as unit_id,
      u.project_id,
      p.name as project_name,
      p.project_number,
      u.unit_number,
      u.floor_number,
      u.floor_label,
      u.direction_label,
      u.type as unit_type,
      case
        when u.status in ('resale', 'for_resale') then u.resale_agreed_amount
        when u.status = 'pending_sale' then u.resale_agreed_amount
        else null
      end as public_price,
      case
        when u.status in ('resale', 'for_resale') then 'available'
        when u.status = 'pending_sale' then 'reserved'
        else 'sold'
      end as public_status,
      u.status as internal_status,
      p.location_text as project_location_text,
      p.location_lat as project_location_lat,
      p.location_lng as project_location_lng,
      p.location_url as project_location_url,
      (
        select a.file_url
        from %I.unit_model_assets a
        where a.model_id = m.id
          and a.kind = 'image'
          and a.display_role = 'cover'
        order by a.created_at asc
        limit 1
      ) as model_cover_url
    from %I.units u
    join %I.projects p
      on p.id = u.project_id
    join lateral (
      select um.id, um.name
      from %I.unit_models um
      where um.project_id = u.project_id
        and um.name = u.direction_label
        and coalesce(um.public_enabled, false) = true
      limit 1
    ) m on true
    where
      coalesce(p.public_enabled, false) = true
      and u.status in ('resale', 'for_resale', 'pending_sale')
  $view$, v_unit_model_assets_schema, v_units_schema, v_projects_schema, v_unit_models_schema);

  execute format($view$
    create view public.public_unit_model_view as
    select
      u.id as unit_id,
      u.project_id,
      m.id as model_id,
      m.name as model_name,
      m.description as model_description,
      coalesce(m.location_url, p.location_url) as model_location_url,
      m.area_sqm as model_area_sqm,
      p.location_text as project_location_text,
      p.location_lat as project_location_lat,
      p.location_lng as project_location_lng,
      (
        select a.file_url
        from %I.unit_model_assets a
        where a.model_id = m.id
          and a.kind = 'image'
          and a.display_role = 'cover'
        order by a.created_at asc
        limit 1
      ) as model_cover_url,
      (
        select a.file_url
        from %I.unit_model_assets a
        where a.model_id = m.id
          and a.kind = 'image'
          and a.display_role = 'facade'
        order by a.created_at asc
        limit 1
      ) as model_facade_url
    from %I.units u
    join %I.projects p
      on p.id = u.project_id
    join lateral (
      select um.id, um.name, um.description, um.location_url, um.area_sqm
      from %I.unit_models um
      where um.project_id = u.project_id
        and um.name = u.direction_label
        and coalesce(um.public_enabled, false) = true
      limit 1
    ) m on true
    where
      coalesce(p.public_enabled, false) = true
      and u.status in ('resale', 'for_resale', 'pending_sale')
  $view$, v_unit_model_assets_schema, v_unit_model_assets_schema, v_units_schema, v_projects_schema, v_unit_models_schema);

  execute format($view$
    create view public.public_model_assets_view as
    select
      a.id,
      a.project_id,
      a.model_id,
      a.kind,
      a.title,
      a.file_url,
      a.display_role
    from %I.unit_model_assets a
    join %I.unit_models m
      on m.id = a.model_id
    join %I.projects p
      on p.id = a.project_id
    where
      coalesce(p.public_enabled, false) = true
      and coalesce(m.public_enabled, false) = true
  $view$, v_unit_model_assets_schema, v_unit_models_schema, v_projects_schema);
end $$;

grant select on public.public_units_view to anon;
grant select on public.public_units_view to authenticated;

grant select on public.public_unit_model_view to anon;
grant select on public.public_unit_model_view to authenticated;

grant select on public.public_model_assets_view to anon;
grant select on public.public_model_assets_view to authenticated;

insert into storage.buckets (id, name, public)
values ('public-media', 'public-media', true)
on conflict (id) do nothing;

drop policy if exists "auth can upload public media" on storage.objects;
drop policy if exists "public can read public media" on storage.objects;
drop policy if exists "auth can delete public media" on storage.objects;
drop policy if exists "auth can update public media" on storage.objects;

create policy "auth can upload public media"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'public-media');

create policy "public can read public media"
on storage.objects
for select
to public
using (bucket_id = 'public-media');

create policy "auth can delete public media"
on storage.objects
for delete
to authenticated
using (bucket_id = 'public-media');

create policy "auth can update public media"
on storage.objects
for update
to authenticated
using (bucket_id = 'public-media')
with check (bucket_id = 'public-media');

commit;