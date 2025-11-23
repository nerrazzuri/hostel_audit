-- Add address and manager_contact to hostels table
alter table public.hostels add column if not exists address text;
alter table public.hostels add column if not exists manager_contact text;

-- Enable RLS if not already enabled (it should be, but good to ensure)
alter table public.hostels enable row level security;

-- Policies for hostels
-- Allow read access to authenticated users
create policy "Enable read access for authenticated users" on public.hostels for select using (auth.role() = 'authenticated');

-- Allow insert/update/delete for authenticated users (for now, can be restricted to admin later)
create policy "Enable insert for authenticated users" on public.hostels for insert with check (auth.role() = 'authenticated');
create policy "Enable update for authenticated users" on public.hostels for update using (auth.role() = 'authenticated');
create policy "Enable delete for authenticated users" on public.hostels for delete using (auth.role() = 'authenticated');
