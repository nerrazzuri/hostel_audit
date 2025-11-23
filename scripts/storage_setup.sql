-- Create storage bucket for audit photos if it doesn't exist
insert into storage.buckets (id, name, public)
values ('audit-photos', 'audit-photos', true)
on conflict (id) do nothing;

-- Policy to allow authenticated users to upload photos
create policy "Allow authenticated uploads"
on storage.objects for insert
to authenticated
with check ( bucket_id = 'audit-photos' );

-- Policy to allow authenticated users to view photos
create policy "Allow authenticated view"
on storage.objects for select
to authenticated
using ( bucket_id = 'audit-photos' );

-- Policy to allow authenticated users to update their own photos (optional, but good for re-uploads)
create policy "Allow authenticated updates"
on storage.objects for update
to authenticated
using ( bucket_id = 'audit-photos' );

-- Policy to allow authenticated users to delete their own photos
create policy "Allow authenticated delete"
on storage.objects for delete
to authenticated
using ( bucket_id = 'audit-photos' );
