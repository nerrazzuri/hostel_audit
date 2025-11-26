-- Create hostel_units table
create table if not exists public.hostel_units (
  id uuid default gen_random_uuid() primary key,
  hostel_id uuid references public.hostels(id) on delete cascade not null,
  name text not null, -- e.g., "Unit 101"
  block text,         -- e.g., "Block A"
  floor text,         -- e.g., "Level 2"
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Enable RLS
alter table public.hostel_units enable row level security;

-- Policies
drop policy if exists "Enable read access for authenticated users" on public.hostel_units;
drop policy if exists "Enable insert for authenticated users" on public.hostel_units;
drop policy if exists "Enable update for authenticated users" on public.hostel_units;
drop policy if exists "Enable delete for authenticated users" on public.hostel_units;

create policy "Enable read access for authenticated users" on public.hostel_units for select using (auth.role() = 'authenticated');
create policy "Enable insert for authenticated users" on public.hostel_units for insert with check (auth.role() = 'authenticated');
create policy "Enable update for authenticated users" on public.hostel_units for update using (auth.role() = 'authenticated');
create policy "Enable delete for authenticated users" on public.hostel_units for delete using (auth.role() = 'authenticated');
