-- Add latest_audit_date to hostel_units
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'hostel_units' AND column_name = 'latest_audit_date') THEN
        ALTER TABLE public.hostel_units ADD COLUMN latest_audit_date timestamp with time zone;
    END IF;
END $$;
