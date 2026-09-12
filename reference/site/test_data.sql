-- =====================================================
-- كود إنشاء بيانات تجريبية (عملاء + طلبات)
-- قم بتشغيل هذا الكود في Supabase SQL Editor
-- =====================================================

DO $$
DECLARE
    target_user_id UUID;
    customer1_id UUID;
    customer2_id UUID;
    customer3_id UUID;
BEGIN
    -- 1. الحصول على معرف المستخدم
    -- سيقوم هذا الكود باختيار أول مستخدم موجود في جدول profiles
    -- إذا كنت تريد تحديد مستخدم معين، قم بتغيير السطر التالي:
    -- target_user_id := 'YOUR-UUID-HERE';
    SELECT id INTO target_user_id FROM public.profiles LIMIT 1;

    -- التحقق من وجود مستخدم
    IF target_user_id IS NULL THEN
        RAISE NOTICE 'لم يتم العثور على أي مستخدم. يرجى تسجيل الدخول وإنشاء حساب أولاً.';
        RETURN;
    END IF;

    RAISE NOTICE 'جاري إنشاء بيانات تجريبية للمستخدم رقم: %', target_user_id;

    -- 2. إدخال عملاء تجريبيين (Test Customers)
    -- العميل الأول: أحمد محمد (VIP)
    INSERT INTO public.customers (user_id, full_name, phone, wilaya, address, total_orders, total_spent, customer_type)
    VALUES 
    (target_user_id, 'أحمد محمد', '0555123456', 'الجزائر', 'حي الزيتون، بئر خادم', 5, 25000, 'vip')
    RETURNING id INTO customer1_id;

    -- العميل الثاني: سارة علي (Regular)
    INSERT INTO public.customers (user_id, full_name, phone, wilaya, address, total_orders, total_spent, customer_type)
    VALUES 
    (target_user_id, 'سارة علي', '0666987654', 'وهران', 'شارع الأمير عبد القادر', 2, 8000, 'regular')
    RETURNING id INTO customer2_id;

    -- العميل الثالث: كريم بن ناصر (New)
    INSERT INTO public.customers (user_id, full_name, phone, wilaya, address, total_orders, total_spent, customer_type)
    VALUES 
    (target_user_id, 'كريم بن ناصر', '0777112233', 'قسنطينة', 'حي المنظر الجميل', 0, 0, 'new')
    RETURNING id INTO customer3_id;

    -- 3. إدخال طلبات تجريبية (Test Orders)
    
    -- طلب 1: قيد الانتظار (Pending) للعميل أحمد
    INSERT INTO public.orders (
        user_id, customer_id, order_number, product_name, customer_name,
        selling_price, purchase_cost, shipping_cost, profit,
        status, wilaya, notes
    ) VALUES (
        target_user_id, customer1_id, 'ORD-001', 'ساعة ذكية Ultra II', 'أحمد محمد',
        5000, 3000, 500, 1500,
        'pending', 'الجزائر', 'يرجى الاتصال قبل التوصيل'
    );

    -- طلب 2: تم التوصيل (Delivered) للعميل أحمد
    INSERT INTO public.orders (
        user_id, customer_id, order_number, product_name, customer_name,
        selling_price, purchase_cost, shipping_cost, profit,
        status, wilaya
    ) VALUES (
        target_user_id, customer1_id, 'ORD-002', 'سماعات بلوتوث Pro Max', 'أحمد محمد',
        4000, 2200, 400, 1400,
        'delivered', 'الجزائر'
    );

    -- طلب 3: تم الشحن (Shipped) للعميل سارة
    INSERT INTO public.orders (
        user_id, customer_id, order_number, product_name, customer_name,
        selling_price, purchase_cost, shipping_cost, profit,
        status, wilaya
    ) VALUES (
        target_user_id, customer2_id, 'ORD-003', 'حقيبة يد نسائية فاخرة', 'سارة علي',
        4500, 2500, 600, 1400,
        'shipped', 'وهران'
    );
    
    -- طلب 4: ملغى (Cancelled) للعميل سارة
    INSERT INTO public.orders (
        user_id, customer_id, order_number, product_name, customer_name,
        selling_price, purchase_cost, shipping_cost, profit,
        status, wilaya, notes
    ) VALUES (
        target_user_id, customer2_id, 'ORD-099', 'مكواة بخار محمولة', 'سارة علي',
        2800, 1500, 500, 800,
        'cancelled', 'وهران', 'الزبون غير مهتم حالياً'
    );

     -- طلب 5: قيد الانتظار (Pending) للعميل كريم
    INSERT INTO public.orders (
        user_id, customer_id, order_number, product_name, customer_name,
        selling_price, purchase_cost, shipping_cost, profit,
        status, wilaya
    ) VALUES (
        target_user_id, customer3_id, 'ORD-005', 'طقم سكاكين مطبخ احترافي', 'كريم بن ناصر',
        3500, 1800, 450, 1250,
        'pending', 'قسنطينة'
    );
    
    -- طلب 6: مرتجع (Returned)
    INSERT INTO public.orders (
        user_id, customer_id, order_number, product_name, customer_name,
        selling_price, purchase_cost, shipping_cost, profit,
        status, wilaya, notes
    ) VALUES (
        target_user_id, customer1_id, 'ORD-006', 'حذاء رياضي أصلي', 'أحمد محمد',
        7000, 5000, 600, 0, -- ربح 0 في حالة الاسترجاع عادة، أو خسارة الشحن
        'returned', 'الجزائر', 'المقاس غير مناسب'
    );

    RAISE NOTICE 'تم إنشاء البيانات التجريبية بنجاح!';
END $$;
