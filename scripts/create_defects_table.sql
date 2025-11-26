-- Create defects table
create table if not exists public.defects (
  id uuid default gen_random_uuid() primary key,
  audit_id text references public.audits(id) on delete cascade,
  hostel_id uuid references public.hostels(id) on delete cascade,
  unit_id uuid references public.hostel_units(id) on delete cascade,
  item_name text not null,
  comment text,
  photos text[],
  status text check (status in ('open', 'fixed', 'verified')) default 'open',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.defects enable row level security;

-- Policies
create policy "Enable read access for authenticated users" on public.defects for select using (auth.role() = 'authenticated');
create policy "Enable insert for authenticated users" on public.defects for insert with check (auth.role() = 'authenticated');
create policy "Enable update for authenticated users" on public.defects for update using (auth.role() = 'authenticated');
create policy "Enable delete for authenticated users" on public.defects for delete using (auth.role() = 'authenticated');
