-- =====================================================
-- DZ Commerce Ultra - Users Schema (Clients Only)
-- هذا الملف يحتوي على هيكل الجداول الخاصة بالمستخدمين فقط
-- =====================================================

-- 1. جدول الملفات الشخصية (Clients/Subscribers)
-- هذا الجدول يقوم بتخزين بيانات المشتركين في المنصة
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

-- ملاحظة: عمود is_admin تم فصله إلى جدول platform_admins، لذا لا حاجة له هنا.
-- إذا كان موجوداً مسبقاً، يمكنك تجاهله أو حذفه إذا أردت التنظيف:
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS is_admin;

-- تفعيل RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- السياسات الأمنية (يسمح للمستخدم برؤية وتعديل ملفه فقط)
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- =====================================================
-- 2. Trigger لإنشاء ملف المستخدم تلقائياً عند التسجيل
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

-- ربط الـ Trigger بجدول auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
