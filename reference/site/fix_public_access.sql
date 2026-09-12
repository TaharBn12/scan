-- =====================================================
-- FIX PUBLIC ACCESS (Products, Store Settings, Shipping)
-- =====================================================

-- 1. Products (Public Read)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view active products" ON public.products;
CREATE POLICY "Public can view active products" ON public.products
FOR SELECT
USING (status = 'active'); -- Only show active products to public

-- Ensure owners can still manage (if not covered)
-- (Existing policy "Users can manage own products" covers this)


-- 2. Store Settings (Public Read - for branding)
ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view store settings" ON public.store_settings;
CREATE POLICY "Public can view store settings" ON public.store_settings
FOR SELECT
USING (true);


-- 3. Shipping Rates (Public Read - for checkout)
ALTER TABLE public.shipping_rates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read shipping" ON public.shipping_rates;
CREATE POLICY "Public read shipping" ON public.shipping_rates 
FOR SELECT 
USING (true);

-- 4. Modules Config (Public Read - if needed)
ALTER TABLE public.modules_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Everyone can read modules_config" ON public.modules_config;
CREATE POLICY "Everyone can read modules_config" ON public.modules_config 
FOR SELECT 
USING (true);