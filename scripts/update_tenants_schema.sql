-- Add unit_id to tenants
alter table public.tenants add column if not exists unit_id uuid references public.hostel_units(id) on delete cascade;

-- We will make unit_id nullable for now to avoid errors with existing data, 
-- but ideally it should be not null if every tenant must be in a unit.
-- If you want to enforce it later, you can update existing records and then alter column.

-- Remove hostel_id constraint if we want to rely solely on unit_id
-- For now, we can keep hostel_id as a denormalized field OR drop it.
-- Let's drop it to avoid confusion and enforce the hierarchy: Hostel -> Unit -> Tenant
-- WARNING: This will delete the link if we don't migrate data. 
-- Since this is dev, we assume it's fine or we can manually migrate if needed.

-- alter table public.tenants drop column if exists hostel_id; 
-- Commented out drop for safety. You can run it manually if you are sure.
-- Ideally, we should migrate data: 
-- UPDATE tenants SET unit_id = (SELECT id FROM hostel_units WHERE hostel_id = tenants.hostel_id LIMIT 1);
-- But we don't have units yet.

-- So the flow is:
-- 1. Create Units.
-- 2. Assign Tenants to Units.
-- 3. (Optional) Drop hostel_id from tenants.
