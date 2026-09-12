-- =====================================================
-- DZ Commerce Ultra - Complete Store Schema Update
-- 1. إصلاح مشكلة modules_config
-- 2. إنشاء جدول المنتجات (Products)
-- 3. إنشاء إعدادات المتجر (Pixels, etc.)
-- =====================================================

-- -----------------------------------------------------
-- 1. جدول إعدادات الوحدات (لإصلاح خطأ modules_config)
-- هذا الجدول يحدد ما إذا كانت الأداة مجانية أم مدفوعة (Global Config)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.modules_config (
    module_name TEXT PRIMARY KEY,
    is_premium BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- تفعيل RLS
ALTER TABLE public.modules_config ENABLE ROW LEVEL SECURITY;

-- السماح للجميع بالقراءة (لمعرفة ما هو مدفوع)
CREATE POLICY "Everyone can read modules_config" ON public.modules_config FOR SELECT USING (true);

-- السماح للمدراء فقط بالتعديل
CREATE POLICY "Admins can update modules_config" ON public.modules_config FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.platform_admins WHERE id = auth.uid())
);

CREATE POLICY "Admins can insert modules_config" ON public.modules_config FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.platform_admins WHERE id = auth.uid())
);

-- إدخال البيانات الافتراضية
INSERT INTO public.modules_config (module_name, is_premium) VALUES 
('finance', true),
('customers', true),
('marketing', false)
ON CONFLICT (module_name) DO NOTHING;


-- -----------------------------------------------------
-- 2. جدول إعدادات المتجر (Store Settings - Pixels)
-- لتخزين بيكسل فيسبوك وتيك توك وشعار المتجر
-- -----------------------------------------------------
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

-- سياسات المتجر (كل مستخدم يتحكم في متجره)
CREATE POLICY "Users can manage own store settings" ON public.store_settings
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);


-- -----------------------------------------------------
-- 3. جدول المنتجات (Products)
-- جدول متكامل للمنتجات مع الصور، السعر، والخصائص
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    slug TEXT, -- للرابط product-name-123
    description TEXT,
    price DECIMAL(10, 2) DEFAULT 0,
    compare_at_price DECIMAL(10, 2), -- السعر قبل التخفيض
    cost_price DECIMAL(10, 2), -- سعر التكلفة (لحساب الربح)
    stock_quantity INTEGER DEFAULT 0,
    sku TEXT,
    
    -- إدارة الوسائط (صور)
    main_image_url TEXT,
    images TEXT[], -- مصفوفة روابط صور
    
    -- الحالة
    status TEXT DEFAULT 'active', -- active, draft, archived
    category TEXT,
    
    -- التسويق (يمكن ربط منتج ببيكسل مخصص إذا لزم الأمر، لكن عادة البيكسل للمتجر ككل)
    -- سنضيف حقول مخصصة للأحداث (Custom Events) إذا دعت الحاجة
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- سياسات المنتجات
CREATE POLICY "Users can manage own products" ON public.products
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- السماح للعامة برؤية المنتجات (لصفحة المتجر/Landing Page)
-- ملاحظة: في حال كان المتجر عاماً، نحتاج لسياسة SELECT للجميع
-- لكن سنقيدها الآن بالمستخدم، وسنضيف سياسة عامة لاحقاً إذا كان لديك واجهة متجر عامة (Storefront).


-- -----------------------------------------------------
-- 4. تحديث جدول الطلبات (Orders) لربطه بالمنتجات
-- -----------------------------------------------------
-- (تم إنشاؤه سابقاً، لكن سنضيف عمود product_id إذا لم يكن موجوداً لربطه بالمنتج الفعلي)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES public.products(id) ON DELETE SET NULL;

