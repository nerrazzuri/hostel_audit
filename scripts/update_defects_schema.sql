-- Add columns for defect resolution
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'defects' AND column_name = 'action_taken') THEN
        ALTER TABLE public.defects ADD COLUMN action_taken text;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'defects' AND column_name = 'rectification_photos') THEN
        ALTER TABLE public.defects ADD COLUMN rectification_photos text[];
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'defects' AND column_name = 'resolved_at') THEN
        ALTER TABLE public.defects ADD COLUMN resolved_at timestamp with time zone;
    END IF;
END $$;
