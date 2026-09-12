-- =====================================================
-- GENERATE 1000 TEST ORDERS
-- Product ID: 8deef8b0-ae69-4301-8497-36f3514b00ba
-- =====================================================

DO $$
DECLARE
    -- The Product ID provided by the user
    v_product_id UUID := '8deef8b0-ae69-4301-8497-36f3514b00ba';
    
    -- Variables to hold product details
    v_user_id UUID;
    v_price DECIMAL;
    v_cost DECIMAL;
    v_shipping DECIMAL := 400; -- Default shipping
    v_title TEXT;
    
    -- Loop variable
    i INTEGER;
    
    -- Random data helpers
    v_wilayas TEXT[] := ARRAY['الجزائر', 'وهران', 'قسنطينة', 'عنابة', 'سطيف', 'باتنة', 'الجلفة', 'البليدة', 'شلف', 'تلمسان'];
    v_statuses TEXT[] := ARRAY['pending', 'confirmed', 'shipped', 'delivered', 'returned', 'cancelled'];
    v_rand_wilaya TEXT;
    v_rand_status TEXT;
    v_rand_phone TEXT;
    v_profit DECIMAL;
BEGIN
    -- 1. Fetch Product Details
    SELECT user_id, price, cost_price, title 
    INTO v_user_id, v_price, v_cost, v_title
    FROM public.products
    WHERE id = v_product_id;

    -- Check if product exists
    IF v_user_id IS NULL THEN
        RAISE NOTICE 'Product with ID % not found. Aborting.', v_product_id;
        RETURN;
    END IF;

    RAISE NOTICE 'Generating 1000 orders for Product: % (Price: %)', v_title, v_price;

    -- 2. Loop to Insert 1000 Orders
    FOR i IN 1..1000 LOOP
        -- Randomize Data
        v_rand_wilaya := v_wilayas[1 + floor(random() * array_length(v_wilayas, 1))::int];
        -- Mostly pending (50%), rest distributed
        IF random() < 0.5 THEN
            v_rand_status := 'pending';
        ELSE
             v_rand_status := v_statuses[1 + floor(random() * array_length(v_statuses, 1))::int];
        END IF;

        v_rand_phone := '05' || floor(random() * 90000000 + 10000000)::text;
        
        -- Calculate Profit
        v_profit := v_price - COALESCE(v_cost, 0) - v_shipping;

        -- Insert Order
        INSERT INTO public.orders (
            user_id,
            product_id,
            product_name,
            customer_name,
            customer_phone,
            selling_price,
            purchase_cost,
            shipping_cost,
            profit,
            status,
            wilaya,
            commune,
            address,
            order_number,
            created_at,
            updated_at
        ) VALUES (
            v_user_id,
            v_product_id,
            v_title,
            'Test Customer ' || i,
            v_rand_phone,
            v_price,
            COALESCE(v_cost, 0),
            v_shipping,
            v_profit,
            v_rand_status,
            v_rand_wilaya,
            'Commune Test',
            'Hay El-Test ' || i,
            'ORD-TEST-' || i,
            NOW() - (random() * interval '30 days'), -- Random date in last 30 days
            NOW()
        );
    END LOOP;

    RAISE NOTICE 'Successfully generated 1000 orders.';
END $$;
