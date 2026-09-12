-- =====================================================
-- FIX: Incompatible Types (UUID vs BIGINT)
-- المشكلة: هناك تعارض في أنواع البيانات بين الجداول القديمة والجديدة.
-- الحل: سنقوم بحذف الجداول المتعارضة (Products & Orders) وإعادة إنشائها بشكل صحيح (UUID).
-- تنبيه: سيتم حذف بيانات المنتجات والطلبات (إذا وجدت) لتصحيح الهيكل.
-- =====================================================

-- 1. حذف القيود والجداول القديمة لتنظيف التعارض
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;

-- 2. إعادة إنشاء جدول المنتجات (Products) مع معرف UUID
CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- تأكدنا من أنه UUID
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

-- 3. إعادة إنشاء جدول الطلبات (Orders) مع معرف UUID وربط صحيح
CREATE TABLE public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL, -- الآن كلاهما UUID
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

-- 4. تفعيل الحماية (RLS)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- 5. إعادة إنشاء السياسات
CREATE POLICY "Users manage own products" ON public.products USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users manage own orders" ON public.orders USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- تم الإصلاح!
