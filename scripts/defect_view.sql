-- Create a view for defects (failed items)
create or replace view public.admin_defects_view as
select
  ai.id as item_id,
  ai.name_en,
  ai.status,
  ai.corrective_action,
  ai.audit_comment,
  a.id as audit_id,
  a.date as audit_date,
  a.hostel_name,
  a.user_id as auditor_id,
  p.hostel_id,
  au.email as auditor_email
from public.audit_items ai
join public.audit_sections s on s.id = ai.section_id
join public.audits a on a.id = s.audit_id
left join auth.users au on au.id = a.user_id
left join public.profiles p on p.id = au.id
where ai.status = 'fail';

grant select on public.admin_defects_view to authenticated;
