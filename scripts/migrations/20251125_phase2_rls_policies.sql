-- Phase 2: Enable RLS and add policies for core tables
-- Run this after Phase 1 and the RPC script.

begin;

-- AUDITS
alter table if exists public.audits enable row level security;
do $$ begin
  create policy audits_select_own on public.audits
    for select
    to authenticated
    using (user_id::text = auth.uid()::text);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy audits_modify_own on public.audits
    for all
    to authenticated
    using (user_id::text = auth.uid()::text)
    with check (user_id::text = auth.uid()::text);
exception when duplicate_object then null; end $$;

-- AUDIT SECTIONS
alter table if exists public.audit_sections enable row level security;
do $$ begin
  create policy audit_sections_select_own on public.audit_sections
    for select
    to authenticated
    using (exists (
      select 1 from public.audits a
      where a.id = audit_sections.audit_id
        and a.user_id::text = auth.uid()::text
    ));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy audit_sections_modify_own on public.audit_sections
    for all
    to authenticated
    using (exists (
      select 1 from public.audits a
      where a.id = audit_sections.audit_id
        and a.user_id::text = auth.uid()::text
    ))
    with check (exists (
      select 1 from public.audits a
      where a.id = audit_sections.audit_id
        and a.user_id::text = auth.uid()::text
    ));
exception when duplicate_object then null; end $$;

-- AUDIT ITEMS
alter table if exists public.audit_items enable row level security;
do $$ begin
  create policy audit_items_select_own on public.audit_items
    for select
    to authenticated
    using (exists (
      select 1
      from public.audit_sections s
      join public.audits a on a.id = s.audit_id
      where s.id = audit_items.section_id
        and a.user_id::text = auth.uid()::text
    ));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy audit_items_modify_own on public.audit_items
    for all
    to authenticated
    using (exists (
      select 1
      from public.audit_sections s
      join public.audits a on a.id = s.audit_id
      where s.id = audit_items.section_id
        and a.user_id::text = auth.uid()::text
    ))
    with check (exists (
      select 1
      from public.audit_items i
      join public.audit_sections s on s.id = i.section_id
      join public.audits a on a.id = s.audit_id
      where s.id = audit_items.section_id
        and a.user_id::text = auth.uid()::text
    ));
exception when duplicate_object then null; end $$;

-- AUDIT ITEM PHOTOS
alter table if exists public.audit_item_photos enable row level security;
do $$ begin
  create policy audit_item_photos_select_own on public.audit_item_photos
    for select
    to authenticated
    using (exists (
      select 1
      from public.audit_items i
      join public.audit_sections s on s.id = i.section_id
      join public.audits a on a.id = s.audit_id
      where i.id = audit_item_photos.item_id
        and a.user_id::text = auth.uid()::text
    ));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy audit_item_photos_modify_own on public.audit_item_photos
    for all
    to authenticated
    using (exists (
      select 1
      from public.audit_items i
      join public.audit_sections s on s.id = i.section_id
      join public.audits a on a.id = s.audit_id
      where i.id = audit_item_photos.item_id
        and a.user_id::text = auth.uid()::text
    ))
    with check (exists (
      select 1
      from public.audit_items i
      join public.audit_sections s on s.id = i.section_id
      join public.audits a on a.id = s.audit_id
      where i.id = audit_item_photos.item_id
        and a.user_id::text = auth.uid()::text
    ));
exception when duplicate_object then null; end $$;

-- DEFECTS
alter table if exists public.defects enable row level security;
do $$ begin
  create policy defects_select_own on public.defects
    for select
    to authenticated
    using (exists (
      select 1 from public.audits a
      where a.id = defects.audit_id
        and a.user_id::text = auth.uid()::text
    ));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy defects_modify_own on public.defects
    for all
    to authenticated
    using (exists (
      select 1 from public.audits a
      where a.id = defects.audit_id
        and a.user_id::text = auth.uid()::text
    ))
    with check (exists (
      select 1 from public.audits a
      where a.id = defects.audit_id
        and a.user_id::text = auth.uid()::text
    ));
exception when duplicate_object then null; end $$;

-- HOSTELS
alter table if exists public.hostels enable row level security;
do $$ begin
  create policy hostels_select_all on public.hostels
    for select
    to authenticated
    using (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy hostels_modify_admin_or_creator on public.hostels
    for all
    to authenticated
    using (
      (coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin')
      or (created_by::text = auth.uid()::text)
    )
    with check (
      (coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin')
      or (created_by::text = auth.uid()::text)
    );
exception when duplicate_object then null; end $$;

-- HOSTEL UNITS (if present)
alter table if exists public.hostel_units enable row level security;
do $$ begin
  create policy hostel_units_select_all on public.hostel_units
    for select
    to authenticated
    using (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy hostel_units_modify_admin_or_creator on public.hostel_units
    for all
    to authenticated
    using ((coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'))
    with check ((coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'));
exception when duplicate_object then null; end $$;

commit;


