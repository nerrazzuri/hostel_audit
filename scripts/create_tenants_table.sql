-- Create tenants table
create table if not exists public.tenants (
  id uuid default gen_random_uuid() primary key,
  hostel_id uuid references public.hostels(id) on delete cascade not null,
  name text not null,
  passport_number text,
  permit_number text,
  permit_expiry_date date,
  check_in_date date,
  check_out_date date,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Enable RLS
alter table public.tenants enable row level security;

-- Policies for tenants
drop policy if exists "Enable read access for authenticated users" on public.tenants;
drop policy if exists "Enable insert for authenticated users" on public.tenants;
drop policy if exists "Enable update for authenticated users" on public.tenants;
drop policy if exists "Enable delete for authenticated users" on public.tenants;

create policy "Enable read access for authenticated users" on public.tenants for select using (auth.role() = 'authenticated');
create policy "Enable insert for authenticated users" on public.tenants for insert with check (auth.role() = 'authenticated');
create policy "Enable update for authenticated users" on public.tenants for update using (auth.role() = 'authenticated');
create policy "Enable delete for authenticated users" on public.tenants for delete using (auth.role() = 'authenticated');
