-- Add hostel_id and unit_id to audits table if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'audits' AND column_name = 'hostel_id') THEN
        ALTER TABLE public.audits ADD COLUMN hostel_id uuid REFERENCES public.hostels(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'audits' AND column_name = 'unit_id') THEN
        ALTER TABLE public.audits ADD COLUMN unit_id uuid REFERENCES public.hostel_units(id);
    END IF;
END $$;
