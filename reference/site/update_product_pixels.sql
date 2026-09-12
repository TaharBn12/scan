-- =====================================================
-- تحديث جدول المنتجات: إضافة البيكسل المخصص لكل منتج
-- =====================================================

-- 1. إضافة أعمدة البيكسل لجدول المنتجات
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS facebook_pixel_id TEXT,
ADD COLUMN IF NOT EXISTS tiktok_pixel_id TEXT;

-- 2. تحديث جدول الطلبات ليشمل تفاصيل العنوان الدقيق (البلدية)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS baladiya TEXT,
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS shipping_type TEXT DEFAULT 'home'; -- desk/home

-- =====================================================
-- للتأكد من أن التعديلات سارية، سنقوم بتحديث السياسات (اختياري، لكن جيد للتذكير)
-- =====================================================
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
