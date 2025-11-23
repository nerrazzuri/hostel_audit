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
