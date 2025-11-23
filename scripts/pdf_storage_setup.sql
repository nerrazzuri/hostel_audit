-- Add pdf_url column to audits table
alter table audits add column if not exists pdf_url text;

-- Create storage bucket for audit reports
insert into storage.buckets (id, name, public)
values ('audit-reports', 'audit-reports', true)
on conflict (id) do nothing;

-- Policy to allow authenticated users to upload reports
create policy "Allow authenticated uploads reports"
on storage.objects for insert
to authenticated
with check ( bucket_id = 'audit-reports' );

-- Policy to allow authenticated users to view reports
create policy "Allow authenticated view reports"
on storage.objects for select
to authenticated
using ( bucket_id = 'audit-reports' );

-- Policy to allow authenticated users to update their own reports
create policy "Allow authenticated updates reports"
on storage.objects for update
to authenticated
using ( bucket_id = 'audit-reports' );

-- Policy to allow authenticated users to delete their own reports
create policy "Allow authenticated delete reports"
on storage.objects for delete
to authenticated
using ( bucket_id = 'audit-reports' );
