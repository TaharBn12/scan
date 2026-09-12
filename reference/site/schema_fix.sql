-- =====================================================
-- FINAL FIX: Complete Schema Restoration
-- This script creates ALL missing tables to safely restore the database state.
-- Please run this entire script in Supabase SQL Editor.
-- =====================================================

-- 1. Profiles (Must exist first)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    phone TEXT,
    wilaya TEXT,
    is_approved BOOLEAN DEFAULT FALSE,
    package_type TEXT DEFAULT 'basic',
    trial_ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own profile" ON public.profiles USING (auth.uid() = id);


-- 2. Customers (Required for Orders)
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    wilaya TEXT,
    address TEXT,
    total_orders INTEGER DEFAULT 0,
    returned_orders INTEGER DEFAULT 0,
    total_spent DECIMAL(10, 2) DEFAULT 0,
    customer_type TEXT DEFAULT 'regular',
    notes TEXT,
    last_order_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own customers" ON public.customers USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);


-- 3. Products
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    slug TEXT,
    description TEXT,
    price DECIMAL(10, 2) DEFAULT 0,
    compare_at_price DECIMAL(10, 2),
    cost_price DECIMAL(10, 2),
    stock_quantity INTEGER DEFAULT 0,
    sku TEXT,
    main_image_url TEXT,
    images TEXT[], 
    status TEXT DEFAULT 'active',
    category TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own products" ON public.products USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);


-- 4. Store Settings (Pixels)
CREATE TABLE IF NOT EXISTS public.store_settings (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    store_name TEXT,
    logo_url TEXT,
    facebook_pixel_id TEXT,
    tiktok_pixel_id TEXT,
    google_analytics_id TEXT,
    primary_color TEXT DEFAULT '#000000',
    currency TEXT DEFAULT 'DZD',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own store settings" ON public.store_settings USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);


-- 5. Orders (Creating if missing)
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    order_number TEXT,
    product_name TEXT,
    customer_name TEXT,
    selling_price DECIMAL(10, 2) DEFAULT 0,
    purchase_cost DECIMAL(10, 2) DEFAULT 0,
    shipping_cost DECIMAL(10, 2) DEFAULT 0,
    profit DECIMAL(10, 2) DEFAULT 0,
    status TEXT DEFAULT 'pending',
    wilaya TEXT,
    notes TEXT,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL, -- Added directly here
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure product_id exists if table was already there without it
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='product_id') THEN
        ALTER TABLE public.orders ADD COLUMN product_id UUID REFERENCES public.products(id) ON DELETE SET NULL;
    END IF;
END $$;

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own orders" ON public.orders;
CREATE POLICY "Users can manage own orders" ON public.orders USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);


-- 6. Modules Config
CREATE TABLE IF NOT EXISTS public.modules_config (
    module_name TEXT PRIMARY KEY,
    is_premium BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.modules_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Everyone can read modules_config" ON public.modules_config;
CREATE POLICY "Everyone can read modules_config" ON public.modules_config FOR SELECT USING (true);

-- Insert Defaults
INSERT INTO public.modules_config (module_name, is_premium) VALUES 
('finance', true), ('customers', true), ('marketing', false)
ON CONFLICT (module_name) DO NOTHING;

-- End of Fix Script
