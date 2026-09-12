-- =====================================================
-- FIX: Add Missing Pixel Columns to Products Table
-- =====================================================

-- 1. Add Pixel Columns to Products Table
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS facebook_pixel_id TEXT,
ADD COLUMN IF NOT EXISTS tiktok_pixel_id TEXT,
ADD COLUMN IF NOT EXISTS google_analytics_id TEXT;

-- 2. Ensure RLS is enabled (just in case)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- 3. Verify Columns exist
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'products';
