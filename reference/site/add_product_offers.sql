-- =====================================================
-- FIX: Add Missing Offer Columns to Products Table
-- =====================================================

ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS offer_2_enabled BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS offer_2_price DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS offer_3_enabled BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS offer_3_price DECIMAL(10, 2);

-- Verify
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'products' AND column_name LIKE 'offer_%';
