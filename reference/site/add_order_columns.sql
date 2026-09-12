-- =====================================================
-- FIX: Add Missing Columns to Orders Table
-- =====================================================

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS commune TEXT,
ADD COLUMN IF NOT EXISTS shipping_type TEXT DEFAULT 'home',
ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS offer_name TEXT,
ADD COLUMN IF NOT EXISTS customer_phone TEXT;

-- Verify
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'orders';
