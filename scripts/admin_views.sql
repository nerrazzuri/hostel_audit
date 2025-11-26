-- Create a secure view to allow admins to see user details
-- Note: In a real production app, we would use a Security Definer function or Supabase Admin API.
-- For this MVP, we create a view that joins auth.users with profiles.

create or replace view public.admin_users_view as
select
  au.id,
  au.email,
  au.raw_user_meta_data->>'name' as full_name,
  au.raw_user_meta_data->>'phone' as phone,
  p.role,
  p.hostel_id,
  h.name as hostel_name
from auth.users au
left join public.profiles p on p.id = au.id
left join public.hostels h on h.id = p.hostel_id;

-- Grant access to authenticated users (application logic will filter who can see this page)
grant select on public.admin_users_view to authenticated;

-- Create admin_defects_view
create or replace view public.admin_defects_view as
select
  d.id,
  d.audit_id,
  d.hostel_id,
  h.name as hostel_name,
  d.unit_id,
  hu.name as unit_name,
  d.item_name,
  d.comment,
  d.photos,
  d.status,
  d.created_at,
  d.updated_at,
  d.action_taken,
  d.rectification_photos,
  d.resolved_at,
  a.date as audit_date
from public.defects d
left join public.hostels h on h.id = d.hostel_id
left join public.hostel_units hu on hu.id = d.unit_id
left join public.audits a on a.id = d.audit_id;

grant select on public.admin_defects_view to authenticated;
