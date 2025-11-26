-- Recreate RPC with transactional defect handling
-- Behavior:
-- - Sections/items are rewritten on each save (simple and safe). If you prefer minimal changes,
--   replace the delete+insert with diff-based updates.
-- - Defects are upserted based on (audit_id, item_name). Requires unique index:
--     create unique index if not exists defects_audit_item_unique
--       on public.defects (audit_id, item_name);
-- - Photos are expected to be pre-uploaded by the client; pass public URLs only.
-- Version: save_audit_transaction_v2

create or replace function public.save_audit_transaction_v2(
  p_audit_id uuid,
  p_user_id uuid,
  p_hostel_id uuid,
  p_unit_id uuid,
  p_hostel_name text,
  p_unit_name text,
  p_employer_name text,
  p_headcount int,
  p_date timestamptz,
  p_pdf_url text,
  p_sections jsonb,
  p_defects jsonb default '[]'::jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_audit_id uuid := p_audit_id;
  v_section jsonb;
  v_item jsonb;
  v_defect jsonb;
  v_section_id int;
  v_item_id int;
begin
  -- Enforce that callers can only operate on their own user_id
  if p_user_id is null or p_user_id <> auth.uid() then
    raise exception 'Unauthorized: user mismatch';
  end if;

  -- Wrap all changes in a single transaction (functions run in caller txn).
  -- Upsert audits (note: audits table has no unit_name column; we only store unit_id)
  insert into public.audits (id, user_id, hostel_id, unit_id, hostel_name, employer_name, headcount, date, pdf_url)
  values (v_audit_id, p_user_id, p_hostel_id, p_unit_id, p_hostel_name, p_employer_name, p_headcount, p_date, p_pdf_url)
  on conflict (id) do update
    set user_id = excluded.user_id,
        hostel_id = excluded.hostel_id,
        unit_id = excluded.unit_id,
        hostel_name = excluded.hostel_name,
        employer_name = excluded.employer_name,
        headcount = excluded.headcount,
        date = excluded.date,
        pdf_url = excluded.pdf_url;

  -- Example: upsert sections/items (adjust to your schema as needed)
  -- Delete existing sections/items for a clean rewrite (or implement diffing per your needs)
  delete from public.audit_items where section_id in (select id from public.audit_sections where audit_id::text = v_audit_id::text);
  delete from public.audit_sections where audit_id::text = v_audit_id::text;

  for v_section in select * from jsonb_array_elements(p_sections)
  loop
    insert into public.audit_sections (audit_id, name_en, name_ms, position)
    values (v_audit_id, v_section->>'name_en', v_section->>'name_ms', coalesce((v_section->>'position')::int, 0))
    returning id into v_section_id;

    for v_item in select * from jsonb_array_elements(coalesce(v_section->'items', '[]'::jsonb))
    loop
      insert into public.audit_items (section_id, name_en, name_ms, status, corrective_action, audit_comment, position)
      values (
        v_section_id,
        v_item->>'name_en',
        v_item->>'name_ms',
        (v_item->>'status')::audit_item_status,
        coalesce(v_item->>'corrective_action',''),
        coalesce(v_item->>'audit_comment',''),
        coalesce((v_item->>'position')::int, 0)
      )
      returning id into v_item_id;

      -- Handle image paths (pre-uploaded URLs) into audit_item_photos
      if (v_item ? 'image_paths') then
        insert into public.audit_item_photos (item_id, storage_path)
        select v_item_id, p
        from jsonb_array_elements_text(coalesce(v_item->'image_paths','[]'::jsonb)) as p;
      end if;
    end loop;
  end loop;

  -- Defects: transactional upsert based on (audit_id, item_name)
  if p_defects is not null then
    for v_defect in select * from jsonb_array_elements(p_defects)
    loop
      insert into public.defects (audit_id, hostel_id, unit_id, item_name, comment, photos, status)
      values (
        v_audit_id,
        nullif(v_defect->>'hostel_id','')::uuid,
        nullif(v_defect->>'unit_id','')::uuid,
        v_defect->>'item_name',
        coalesce(v_defect->>'comment',''),
        coalesce(
          (select array_agg(p)
             from jsonb_array_elements_text(coalesce(v_defect->'photos','[]'::jsonb)) as p),
          ARRAY[]::text[]
        ),
        coalesce(v_defect->>'status','open')
      )
      on conflict (audit_id, item_name) do update
        set comment = excluded.comment,
            photos = excluded.photos,
            status = excluded.status,
            updated_at = now();
    end loop;
  end if;

  -- Optionally update hostels.latest_audit_date
  if p_hostel_id is not null then
    update public.hostels
      set latest_audit_date = p_date,
          employer_name = p_employer_name,
          headcount = p_headcount
      where id::text = p_hostel_id::text;
  end if;

  -- Optionally update hostel_units.latest_audit_date
  if p_unit_id is not null then
    update public.hostel_units
      set latest_audit_date = p_date
      where id::text = p_unit_id::text;
  end if;
end;
$$;

revoke all on function public.save_audit_transaction_v2(uuid, uuid, uuid, uuid, text, text, text, int, timestamptz, text, jsonb, jsonb) from public;
grant execute on function public.save_audit_transaction_v2(uuid, uuid, uuid, uuid, text, text, text, int, timestamptz, text, jsonb, jsonb) to authenticated;
grant execute on function public.save_audit_transaction_v2(uuid, uuid, uuid, uuid, text, text, text, int, timestamptz, text, jsonb, jsonb) to service_role;

-- Drop function if exists to allow updates
DROP FUNCTION IF EXISTS save_audit_transaction;

CREATE OR REPLACE FUNCTION save_audit_transaction(
  p_audit_id UUID,
  p_user_id UUID,
  p_hostel_id UUID,
  p_unit_id UUID,
  p_hostel_name TEXT,
  p_unit_name TEXT,
  p_employer_name TEXT,
  p_headcount INTEGER,
  p_date TIMESTAMP WITH TIME ZONE,
  p_pdf_url TEXT,
  p_sections JSONB
) RETURNS VOID AS $$
DECLARE
  section_record JSONB;
  item_record JSONB;
  new_section_id BIGINT;
  new_item_id BIGINT;
BEGIN
  -- 1. Upsert Audit
  INSERT INTO audits (
    id, user_id, hostel_id, unit_id, hostel_name, unit_name, 
    employer_name, headcount, date, pdf_url, updated_at
  ) VALUES (
    p_audit_id, p_user_id, p_hostel_id, p_unit_id, p_hostel_name, p_unit_name,
    p_employer_name, p_headcount, p_date, p_pdf_url, NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    hostel_id = EXCLUDED.hostel_id,
    unit_id = EXCLUDED.unit_id,
    hostel_name = EXCLUDED.hostel_name,
    unit_name = EXCLUDED.unit_name,
    employer_name = EXCLUDED.employer_name,
    headcount = EXCLUDED.headcount,
    date = EXCLUDED.date,
    pdf_url = EXCLUDED.pdf_url,
    updated_at = NOW();

  -- 2. Process Sections and Items
  -- Strategy:
  -- A. Upsert all sections/items provided.
  -- B. Delete any sections/items belonging to this audit that were NOT in the provided list.
  
  -- Create temp tables to track processed IDs
  CREATE TEMPORARY TABLE IF NOT EXISTS processed_sections (id BIGINT) ON COMMIT DROP;
  CREATE TEMPORARY TABLE IF NOT EXISTS processed_items (id BIGINT) ON COMMIT DROP;
  
  -- Clear tables in case they persist in session (though ON COMMIT DROP handles it usually)
  DELETE FROM processed_sections;
  DELETE FROM processed_items;

  FOR section_record IN SELECT * FROM jsonb_array_elements(p_sections)
  LOOP
    -- Upsert Section
    IF (section_record->>'id') IS NOT NULL THEN
      UPDATE audit_sections SET
        name_en = section_record->>'name_en',
        name_ms = section_record->>'name_ms',
        position = (section_record->>'position')::INTEGER
      WHERE id = (section_record->>'id')::BIGINT
      RETURNING id INTO new_section_id;
      
      INSERT INTO processed_sections (id) VALUES (new_section_id);
    ELSE
      INSERT INTO audit_sections (audit_id, name_en, name_ms, position)
      VALUES (
        p_audit_id,
        section_record->>'name_en',
        section_record->>'name_ms',
        (section_record->>'position')::INTEGER
      )
      RETURNING id INTO new_section_id;
      
      INSERT INTO processed_sections (id) VALUES (new_section_id);
    END IF;

    -- Process Items
    FOR item_record IN SELECT * FROM jsonb_array_elements(section_record->'items')
    LOOP
      IF (item_record->>'id') IS NOT NULL THEN
        UPDATE audit_items SET
          section_id = new_section_id, -- Ensure it belongs to correct section
          name_en = item_record->>'name_en',
          name_ms = item_record->>'name_ms',
          status = (item_record->>'status')::audit_item_status,
          corrective_action = item_record->>'corrective_action',
          audit_comment = item_record->>'audit_comment',
          image_paths = (item_record->'image_paths'),
          position = (item_record->>'position')::INTEGER
        WHERE id = (item_record->>'id')::BIGINT;
        
        INSERT INTO processed_items (id) VALUES ((item_record->>'id')::BIGINT);
      ELSE
        INSERT INTO audit_items (
          section_id, name_en, name_ms, status, 
          corrective_action, audit_comment, image_paths, position
        )
        VALUES (
          new_section_id,
          item_record->>'name_en',
          item_record->>'name_ms',
          (item_record->>'status')::audit_item_status,
          item_record->>'corrective_action',
          item_record->>'audit_comment',
          (item_record->'image_paths'),
          (item_record->>'position')::INTEGER
        )
        RETURNING id INTO new_item_id;
        
        INSERT INTO processed_items (id) VALUES (new_item_id);
      END IF;
    END LOOP;
  END LOOP;

  -- 3. Garbage Collection
  -- Delete items that belong to this audit's sections but were not updated (and thus not in payload)
  -- We only delete items where id IS NOT NULL (meaning they existed) AND id NOT IN (processed_items).
  
  DELETE FROM audit_items 
  WHERE section_id IN (SELECT id FROM audit_sections WHERE audit_id = p_audit_id)
  AND id NOT IN (SELECT id FROM processed_items);

  -- Delete sections that belong to this audit but were not updated
  DELETE FROM audit_sections
  WHERE audit_id = p_audit_id
  AND id NOT IN (SELECT id FROM processed_sections);

END;
$$ LANGUAGE plpgsql;
