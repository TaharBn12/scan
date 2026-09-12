-- =====================================================
-- تحديث قاعدة البيانات: إضافة عمود الصلاحيات (Admin)
-- قم بتنفيذ هذا السكريبت في Supabase SQL Editor
-- =====================================================

-- 1. إضافة عمود is_admin إلى جدول profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- 2. تحديث السياسات الأمنية (RLS) للسماح للمدراء بتعديل أي مستخدم (اختياري، لكن يفضل تحديثها)
-- في الوقت الحالي، السياسات تسمح للمستخدم بتعديل نفسه فقط.
-- إذا كنت تريد أن يتمكن "المدير" من تعديل الآخرين عبر Supabase مباشرة، ستحتاج إلى سياسات أكثر تعقيداً.
-- لكن تطبيقك الحالي في admin/users.html يستخدم "service_role" أو يعتمد على صلاحيات المستخدم الحالي.
-- ملاحظة: الكود في admin/users.html يستخدم مفتاح الـ anon العادي، لذا يجب أن يكون المستخدم الحالي (أنت)
-- قادراً على تعديل الآخرين. هذا يتطلب سياسة تسمح لـ is_admin=true بتعديل الجميع.

-- لنقم بإنشاء سياسة تسمح للمدراء بتعديل وتحديث جميع المستخدمين
CREATE POLICY "Admins can update everyone" ON public.profiles
FOR UPDATE USING (
  auth.uid() IN (SELECT id FROM public.profiles WHERE is_admin = true)
);

CREATE POLICY "Admins can view everyone" ON public.profiles
FOR SELECT USING (
  auth.uid() IN (SELECT id FROM public.profiles WHERE is_admin = true)
);

-- =====================================================
-- تم التحديث!
-- الآن، لكي تصبح أنت مديراً، يجب عليك تحديث صفك يدوياً لمرة واحدة:
-- UPDATE public.profiles SET is_admin = TRUE WHERE id = 'YOUR-USER-ID';
-- =====================================================
