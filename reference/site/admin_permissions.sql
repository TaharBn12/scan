-- =====================================================
-- تحديث الصلاحيات: السماح للمدراء (Platform Admins) بتعديل المستخدمين
-- =====================================================

-- 1. التأكد من أن جدول المدراء مفعل عليه RLS (للحماية)
ALTER TABLE public.platform_admins ENABLE ROW LEVEL SECURITY;

-- السماح للجميع بقراءة جدول المدراء (لأغراض التحقق فقط، يمكن تقييدها أكثر إذا أردت)
-- أو الأفضل: السماح بقراءة الجدول فقط لمن هم مسجلون في auth.users
CREATE POLICY "Allow read platform_admins for authenticated" ON public.platform_admins
FOR SELECT USING (auth.role() = 'authenticated');


-- 2. تحديث سياسات جدول Profiles للسماح للمدراء بالتعديل والقراءة
-- نحتاج لسياسة تقول: "اسمح بالتعديل إذا كان المستخدم الحالي موجوداً في جدول platform_admins"

CREATE POLICY "Admins can update users" ON public.profiles
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM public.platform_admins WHERE id = auth.uid()
    )
);

CREATE POLICY "Admins can delete users" ON public.profiles
FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM public.platform_admins WHERE id = auth.uid()
    )
);

-- سياسة القراءة للمدراء
CREATE POLICY "Admins can view all users" ON public.profiles
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.platform_admins WHERE id = auth.uid()
    )
);
