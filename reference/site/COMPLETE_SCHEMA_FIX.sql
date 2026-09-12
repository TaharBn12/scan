-- =====================================================
-- COMPLETE DATABASE SCHEMA SYNC & FIX
-- This script ensures ALL required columns and RLS policies 
-- for Storefront, Packer, Confirmer, and Tracking are present.
-- =====================================================
-- 1. PROFILES TABLE (Roles and Rates)
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'profiles'
        AND column_name = 'role'
) THEN
ALTER TABLE public.profiles
ADD COLUMN role TEXT DEFAULT 'merchant';
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'profiles'
        AND column_name = 'merchant_id'
) THEN
ALTER TABLE public.profiles
ADD COLUMN merchant_id UUID REFERENCES public.profiles(id) ON DELETE
SET NULL;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'profiles'
        AND column_name = 'email'
) THEN
ALTER TABLE public.profiles
ADD COLUMN email TEXT;
END IF;
-- Confirmer Rates
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'profiles'
        AND column_name = 'confirmation_rate'
) THEN
ALTER TABLE public.profiles
ADD COLUMN confirmation_rate DECIMAL(10, 2) DEFAULT 0;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'profiles'
        AND column_name = 'follow_up_rate'
) THEN
ALTER TABLE public.profiles
ADD COLUMN follow_up_rate DECIMAL(10, 2) DEFAULT 0;
END IF;
-- Packer Rates
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'profiles'
        AND column_name = 'packaging_rate'
) THEN
ALTER TABLE public.profiles
ADD COLUMN packaging_rate DECIMAL(10, 2) DEFAULT 0;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'profiles'
        AND column_name = 'storage_rate'
) THEN
ALTER TABLE public.profiles
ADD COLUMN storage_rate DECIMAL(10, 2) DEFAULT 0;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'profiles'
        AND column_name = 'printing_rate'
) THEN
ALTER TABLE public.profiles
ADD COLUMN printing_rate DECIMAL(10, 2) DEFAULT 0;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'profiles'
        AND column_name = 'extra_commission_rate'
) THEN
ALTER TABLE public.profiles
ADD COLUMN extra_commission_rate DECIMAL(10, 2) DEFAULT 0;
END IF;
END $$;
-- 2. STORE_SETTINGS TABLE (Slug and Tracking)
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'store_settings'
        AND column_name = 'store_slug'
) THEN
ALTER TABLE public.store_settings
ADD COLUMN store_slug TEXT UNIQUE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'store_settings'
        AND column_name = 'facebook_pixel_id'
) THEN
ALTER TABLE public.store_settings
ADD COLUMN facebook_pixel_id TEXT;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'store_settings'
        AND column_name = 'tiktok_pixel_id'
) THEN
ALTER TABLE public.store_settings
ADD COLUMN tiktok_pixel_id TEXT;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'store_settings'
        AND column_name = 'google_analytics_id'
) THEN
ALTER TABLE public.store_settings
ADD COLUMN google_analytics_id TEXT;
END IF;
END $$;
-- 3. PRODUCTS TABLE (Offers and Pixels)
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'products'
        AND column_name = 'facebook_pixel_id'
) THEN
ALTER TABLE public.products
ADD COLUMN facebook_pixel_id TEXT;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'products'
        AND column_name = 'tiktok_pixel_id'
) THEN
ALTER TABLE public.products
ADD COLUMN tiktok_pixel_id TEXT;
END IF;
-- Offers
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'products'
        AND column_name = 'offer_2_enabled'
) THEN
ALTER TABLE public.products
ADD COLUMN offer_2_enabled BOOLEAN DEFAULT FALSE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'products'
        AND column_name = 'offer_2_price'
) THEN
ALTER TABLE public.products
ADD COLUMN offer_2_price DECIMAL(10, 2);
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'products'
        AND column_name = 'offer_3_enabled'
) THEN
ALTER TABLE public.products
ADD COLUMN offer_3_enabled BOOLEAN DEFAULT FALSE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'products'
        AND column_name = 'offer_3_price'
) THEN
ALTER TABLE public.products
ADD COLUMN offer_3_price DECIMAL(10, 2);
END IF;
END $$;
-- 4. ORDERS TABLE (Shipment Details and IDs)
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'orders'
        AND column_name = 'confirmer_id'
) THEN
ALTER TABLE public.orders
ADD COLUMN confirmer_id UUID REFERENCES public.profiles(id) ON DELETE
SET NULL;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'orders'
        AND column_name = 'packer_id'
) THEN
ALTER TABLE public.orders
ADD COLUMN packer_id UUID REFERENCES public.profiles(id) ON DELETE
SET NULL;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'orders'
        AND column_name = 'address'
) THEN
ALTER TABLE public.orders
ADD COLUMN address TEXT;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'orders'
        AND column_name = 'commune'
) THEN
ALTER TABLE public.orders
ADD COLUMN commune TEXT;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'orders'
        AND column_name = 'shipping_type'
) THEN
ALTER TABLE public.orders
ADD COLUMN shipping_type TEXT DEFAULT 'home';
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'orders'
        AND column_name = 'quantity'
) THEN
ALTER TABLE public.orders
ADD COLUMN quantity INTEGER DEFAULT 1;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'orders'
        AND column_name = 'offer_name'
) THEN
ALTER TABLE public.orders
ADD COLUMN offer_name TEXT;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'orders'
        AND column_name = 'customer_phone'
) THEN
ALTER TABLE public.orders
ADD COLUMN customer_phone TEXT;
END IF;
END $$;
-- 5. RLS POLICIES (Public Access)
-- Products
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can view active products" ON public.products;
CREATE POLICY "Public can view active products" ON public.products FOR
SELECT USING (status = 'active');
-- Store Settings
ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can view store settings" ON public.store_settings;
CREATE POLICY "Public can view store settings" ON public.store_settings FOR
SELECT USING (true);
-- Shipping Rates
ALTER TABLE public.shipping_rates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read shipping" ON public.shipping_rates;
CREATE POLICY "Public read shipping" ON public.shipping_rates FOR
SELECT USING (true);
-- Orders (Public Insert)
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can create orders" ON public.orders;
CREATE POLICY "Public can create orders" ON public.orders FOR
INSERT WITH CHECK (true);
-- Final Verification Query
SELECT table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name IN (
        'profiles',
        'store_settings',
        'products',
        'orders'
    )
ORDER BY table_name,
    column_name;