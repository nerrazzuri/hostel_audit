-- Add latest_audit_date to hostels table if not exists
do $$
begin
  if not exists (select 1 from information_schema.columns where table_name = 'hostels' and column_name = 'latest_audit_date') then
    alter table public.hostels add column latest_audit_date timestamp with time zone;
  end if;
end $$;
