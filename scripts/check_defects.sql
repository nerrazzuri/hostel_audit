-- Check count of defects
SELECT count(*) FROM public.defects;

-- View recent defects
SELECT * FROM public.defects ORDER BY created_at DESC LIMIT 5;
