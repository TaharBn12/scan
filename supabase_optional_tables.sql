-- =====================================================
-- OPTIONAL tables for the Flutter app (billing_app)
--
-- The storefront (products / orders / customers / profiles / store_settings /
-- shipping_rates) already exists and is left untouched. These extra tables
-- back the features the site has no table for: coupons, banners, reviews,
-- saved addresses, wishlist, multi-line order items and staff payouts.
--
-- Run this in the Supabase SQL editor of the SAME project
-- (https://cazwkhcbkzhnsluuafwz.supabase.co). Nothing here is required for the
-- catalogue, the orders board or the checkout — until it is run the app
-- reports those screens as unavailable instead of failing.
--
-- Every table is scoped by user_id, exactly like the site's own tables.
-- =====================================================

CREATE TABLE IF NOT EXISTS public.store_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    name_ar TEXT,
    name_fr TEXT,
    slug TEXT,
    image_url TEXT,
    position INTEGER DEFAULT 0,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.store_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    name TEXT,
    image TEXT,
    unit_price DECIMAL(10, 2) DEFAULT 0,
    quantity DECIMAL(10, 2) DEFAULT 1,
    unit TEXT DEFAULT 'piece'
);

CREATE TABLE IF NOT EXISTS public.store_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    label TEXT,
    full_name TEXT,
    phone TEXT,
    address TEXT,
    city TEXT,
    wilaya TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.store_coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    type TEXT DEFAULT 'percent',          -- percent | fixed
    value DECIMAL(10, 2) DEFAULT 0,
    min_spend DECIMAL(10, 2) DEFAULT 0,
    max_discount DECIMAL(10, 2),
    usage_limit INTEGER DEFAULT 0,
    used_count INTEGER DEFAULT 0,
    expires_at TIMESTAMPTZ,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.store_banners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT,
    subtitle TEXT,
    image_url TEXT,
    link TEXT,
    position INTEGER DEFAULT 0,
    active BOOLEAN DEFAULT TRUE,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.store_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    order_id UUID,
    customer_id UUID,
    customer_name TEXT,
    rating INTEGER DEFAULT 5,
    comment TEXT,
    approved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.store_wishlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, product_id)
);

CREATE TABLE IF NOT EXISTS public.store_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    role TEXT,                            -- confirmer | packer
    period_start DATE,
    period_end DATE,
    orders_count INTEGER DEFAULT 0,
    amount DECIMAL(10, 2) DEFAULT 0,
    status TEXT DEFAULT 'pending',        -- pending | paid
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- RLS: same shape as the site's own policies.
-- =====================================================
DO $$
DECLARE t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'store_categories','store_order_items','store_addresses','store_coupons',
        'store_banners','store_reviews','store_wishlist','store_payouts'
    ] LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    END LOOP;
END $$;

CREATE POLICY "Users manage own categories" ON public.store_categories
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users manage own addresses" ON public.store_addresses
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users manage own coupons" ON public.store_coupons
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users manage own banners" ON public.store_banners
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users manage own reviews" ON public.store_reviews
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users manage own wishlist" ON public.store_wishlist
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users manage own payouts" ON public.store_payouts
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Shoppers read the catalogue extras without signing in.
CREATE POLICY "Public read banners" ON public.store_banners FOR SELECT USING (active = TRUE);
CREATE POLICY "Public read reviews" ON public.store_reviews FOR SELECT USING (approved = TRUE);
CREATE POLICY "Public read categories" ON public.store_categories FOR SELECT USING (active = TRUE);

-- Order items follow their order's visibility.
CREATE POLICY "Owners manage order items" ON public.store_order_items
    USING (EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id AND o.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id AND o.user_id = auth.uid()));
