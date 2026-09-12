-- =====================================================
-- MASTER DATABASE SETUP SCRIPT
-- DZ Commerce Ultra - All Tables
-- تشغيل هذا الملف سيقوم بإنشاء جميع جداول قاعدة البيانات دفعة واحدة
-- =====================================================

-- 1. جدول الملفات الشخصية (Users/Profiles)
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

-- 2. جدول المدراء (Admins)
CREATE TABLE IF NOT EXISTS public.platform_admins (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    role TEXT DEFAULT 'super_admin',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. جدول إعدادات المتجر (Pixels & Settings)
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

-- 4. جدول إعدادات الأدوات (Modules)
CREATE TABLE IF NOT EXISTS public.modules_config (
    module_name TEXT PRIMARY KEY,
    is_premium BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- بيانات افتراضية للأدوات
INSERT INTO public.modules_config (module_name, is_premium) VALUES 
('finance', true), ('customers', true), ('marketing', false)
ON CONFLICT (module_name) DO NOTHING;

-- 5. جدول العملاء (CRM)
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

-- 6. جدول المنتجات (Products)
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

-- 7. جدول الطلبات (Orders)
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
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
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- تفعيل الحماية (RLS) للجميع
-- =====================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.modules_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- إنشاء السياسات (Policies)
-- =====================================================

-- 1. Profiles
CREATE POLICY "Users view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
-- Admin access to profiles
CREATE POLICY "Admins view all profiles" ON public.profiles FOR SELECT USING (EXISTS (SELECT 1 FROM public.platform_admins WHERE id = auth.uid()));
CREATE POLICY "Admins update all profiles" ON public.profiles FOR UPDATE USING (EXISTS (SELECT 1 FROM public.platform_admins WHERE id = auth.uid()));

-- 2. Store Settings
CREATE POLICY "Users manage own settings" ON public.store_settings USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 3. Customers
CREATE POLICY "Users manage own customers" ON public.customers USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 4. Products
CREATE POLICY "Users manage own products" ON public.products USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 5. Orders
CREATE POLICY "Users manage own orders" ON public.orders USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 6. Platform Admins (Read Only for Authenticated to check role)
CREATE POLICY "Read admins" ON public.platform_admins FOR SELECT USING (auth.role() = 'authenticated');

-- 7. Modules Config (Read Everyone, Update Admins)
CREATE POLICY "Read modules" ON public.modules_config FOR SELECT USING (true);
CREATE POLICY "Admins update modules" ON public.modules_config FOR UPDATE USING (EXISTS (SELECT 1 FROM public.platform_admins WHERE id = auth.uid()));

-- =====================================================
-- Trigger: إنشاء بروفايل عند التسجيل
-- =====================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, phone, wilaya, trial_ends_at)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'phone',
        NEW.raw_user_meta_data->>'wilaya',
        (NEW.raw_user_meta_data->>'trial_ends_at')::TIMESTAMPTZ
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- تم الانتهاء!
