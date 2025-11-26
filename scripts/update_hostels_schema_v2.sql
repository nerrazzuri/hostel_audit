-- Add employer_name, address, and manager_contact to hostels table
alter table public.hostels add column if not exists employer_name text;
alter table public.hostels add column if not exists address text;
alter table public.hostels add column if not exists manager_contact text;

-- Ensure RLS is enabled
alter table public.hostels enable row level security;

-- Policies (re-applying or ensuring they exist)
drop policy if exists "Enable read access for authenticated users" on public.hostels;
drop policy if exists "Enable insert for authenticated users" on public.hostels;
drop policy if exists "Enable update for authenticated users" on public.hostels;
drop policy if exists "Enable delete for authenticated users" on public.hostels;

create policy "Enable read access for authenticated users" on public.hostels for select using (auth.role() = 'authenticated');
create policy "Enable insert for authenticated users" on public.hostels for insert with check (auth.role() = 'authenticated');
create policy "Enable update for authenticated users" on public.hostels for update using (auth.role() = 'authenticated');
create policy "Enable delete for authenticated users" on public.hostels for delete using (auth.role() = 'authenticated');
