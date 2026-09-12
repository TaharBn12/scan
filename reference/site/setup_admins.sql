-- =====================================================
-- فصل بيانات الإدارة عن المستخدمين (Clients)
-- 1. إنشاء جدول خاص للمدراء (Platform Admins)
-- 2. إدخال مدير يدوياً
-- =====================================================

-- 1. إنشاء جدول المدراء
CREATE TABLE IF NOT EXISTS public.platform_admins (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    role TEXT DEFAULT 'super_admin',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- تفعيل الحماية
ALTER TABLE public.platform_admins ENABLE ROW LEVEL SECURITY;

-- السماح للمدراء برؤية بياناتهم
CREATE POLICY "Admins can view own data" ON public.platform_admins
FOR SELECT USING (auth.uid() = id);

-- =====================================================
-- 2. طريقة إضافة مدير يدوياً
-- بما أن "تسجيل الدخول" يعتمد على Supabase Auth (auth.users)
-- يجب عليك أولاً:
-- أ) الذهاب إلى Supabase Dashboard -> Authentication -> Users
-- ب) النقر على "Add User" وإنشاء حساب (مثلاً admin@dz.com)
-- ج) نسخ الـ User UID الخاص به.
-- د) وضع الـ UUID والبريد أدناه وتشغيل هذا الكود.
-- =====================================================

-- استبدل القيم أدناه بالقيم الحقيقية للمدير الذي أنشأته
INSERT INTO public.platform_admins (id, email, full_name)
VALUES (
    'ضع-هنا-UUID-الذي-نسخته-من-Supabase',  -- مثال: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'
    'admin@example.com',                    -- نفس البريد الإلكتروني
    'Admin User'
);

-- =====================================================
-- ملاحظة: بعد تشغيل هذا الانسرت، سيتمكن هذا المستخدم فقط من الدخول إلى لوحة الإدارة
-- ولن يظهر في جدول "المشتركين" (profiles).
-- =====================================================
