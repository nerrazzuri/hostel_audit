begin;

-- PROFILES: ensure self-only read/update
alter table if exists public.profiles enable row level security;
do $$ begin
  create policy profiles_select_self on public.profiles
    for select to authenticated
    using (id = auth.uid());
exception when duplicate_object then null; end $$;
do $$ begin
  create policy profiles_update_self on public.profiles
    for update to authenticated
    using (id = auth.uid())
    with check (id = auth.uid());
exception when duplicate_object then null; end $$;

-- Allow admins to read/write any profile (needed for updating others' roles)
do $$ begin
  create policy profiles_admin_write on public.profiles
    for all to authenticated
    using (coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin')
    with check (coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin');
exception when duplicate_object then null; end $$;

-- Fallback: allow admins based on their own profile.role = 'admin'
do $$ begin
  create policy profiles_admin_write_by_profile on public.profiles
    for all to authenticated
    using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))
    with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));
exception when duplicate_object then null; end $$;

-- ADMIN-ONLY WRITES: templates
alter table if exists public.template_sections enable row level security;
alter table if exists public.template_items enable row level security;
do $$ begin
  create policy template_sections_read_all on public.template_sections
    for select to authenticated using (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy template_items_read_all on public.template_items
    for select to authenticated using (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy template_sections_admin_write on public.template_sections
    for all to authenticated
    using ((coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'))
    with check ((coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'));
exception when duplicate_object then null; end $$;
do $$ begin
  create policy template_items_admin_write on public.template_items
    for all to authenticated
    using ((coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'))
    with check ((coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'));
exception when duplicate_object then null; end $$;

-- TENANTS: read for authenticated, write admin only
alter table if exists public.tenants enable row level security;
do $$ begin
  create policy tenants_read_all on public.tenants
    for select to authenticated using (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy tenants_admin_write on public.tenants
    for all to authenticated
    using ((coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'))
    with check ((coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'));
exception when duplicate_object then null; end $$;

-- AUDIT DATA: allow admins to read all audits and related tables
alter table if exists public.audits enable row level security;
alter table if exists public.audit_sections enable row level security;
alter table if exists public.audit_items enable row level security;
alter table if exists public.audit_item_photos enable row level security;
alter table if exists public.defects enable row level security;

do $$ begin
  create policy audits_select_admin on public.audits
    for select to authenticated
    using ((coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'));
exception when duplicate_object then null; end $$;

-- Fallback: allow admins based on profile role as well (no JWT needed)
do $$ begin
  create policy audits_select_admin_by_profile on public.audits
    for select to authenticated
    using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy audit_sections_select_admin on public.audit_sections
    for select to authenticated
    using ((coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy audit_sections_select_admin_by_profile on public.audit_sections
    for select to authenticated
    using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy audit_items_select_admin on public.audit_items
    for select to authenticated
    using ((coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy audit_items_select_admin_by_profile on public.audit_items
    for select to authenticated
    using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy audit_item_photos_select_admin on public.audit_item_photos
    for select to authenticated
    using ((coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy audit_item_photos_select_admin_by_profile on public.audit_item_photos
    for select to authenticated
    using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy defects_select_admin on public.defects
    for select to authenticated
    using ((coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy defects_select_admin_by_profile on public.defects
    for select to authenticated
    using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));
exception when duplicate_object then null; end $$;

commit;


-- -------------------------------------------------------------------
-- Admin helper and policy fixes to avoid recursion on profiles
-- -------------------------------------------------------------------
begin;

-- Remove recursive policy variant on profiles
drop policy if exists profiles_admin_write_by_profile on public.profiles;

-- Admin helper: centralized check (JWT role OR profile role)
create or replace function public.is_admin() returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((auth.jwt()->'app_metadata'->>'role'), '') = 'admin'
         or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin');
$$;

grant execute on function public.is_admin() to authenticated;

-- Recreate profiles admin write policy using is_admin()
drop policy if exists profiles_admin_write on public.profiles;
create policy profiles_admin_write on public.profiles
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

commit;

