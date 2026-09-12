-- قم بتنفيذ هذا الاستعلام في قسم SQL Editor في لوحة تحكم Supabase
-- هذا سيضيف ميزة الصور السفلية الملتصقة (bottom_images) إلى المنتجات
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS bottom_images TEXT [];