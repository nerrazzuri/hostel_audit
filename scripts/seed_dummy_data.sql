-- Insert a dummy hostel
WITH new_hostel AS (
  INSERT INTO public.hostels (name, address, employer_name, manager_contact)
  VALUES ('Sunshine Dormitory', '123 Sunshine Road, Singapore 123456', 'Acme Construction Co.', '+65 9123 4567')
  RETURNING id
),
-- Insert a dummy unit for the hostel
new_unit AS (
  INSERT INTO public.hostel_units (hostel_id, name, block, floor)
  SELECT id, 'Unit 01-05', 'Block A', 'Level 1'
  FROM new_hostel
  RETURNING id, hostel_id
)
-- Insert a dummy tenant for the unit
INSERT INTO public.tenants (unit_id, hostel_id, name, passport_number, permit_number, permit_expiry_date, check_in_date)
SELECT id, hostel_id, 'John Doe', 'E1234567A', 'WP123456789', '2026-12-31', '2024-01-01'
FROM new_unit;

-- Insert another tenant
WITH target_unit AS (
    SELECT id, hostel_id FROM public.hostel_units WHERE name = 'Unit 01-05' LIMIT 1
)
INSERT INTO public.tenants (unit_id, hostel_id, name, passport_number, permit_number, permit_expiry_date, check_in_date)
SELECT id, hostel_id, 'Jane Smith', 'E9876543B', 'WP987654321', '2025-06-30', '2024-02-15'
FROM target_unit;
