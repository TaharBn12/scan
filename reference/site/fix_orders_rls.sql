-- =====================================================
-- FIX ORDERS RLS (Permissions)
-- =====================================================

-- 1. Reset Orders Policies to be clean
DROP POLICY IF EXISTS "Users can manage own orders" ON public.orders;
DROP POLICY IF EXISTS "Confirmers can view assigned orders" ON public.orders;
DROP POLICY IF EXISTS "Confirmers can update assigned orders" ON public.orders;
DROP POLICY IF EXISTS "Merchants can manage own orders" ON public.orders;
DROP POLICY IF EXISTS "Public can create orders" ON public.orders;

-- 2. Create Comprehensive Policy for Merchants (Owners)
-- Merchants can do EVERYTHING on orders where they are the user_id (Owner)
CREATE POLICY "Merchants can manage own orders" ON public.orders
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 3. Create Policy for Confirmers
-- Confirmers can VIEW orders assigned to them
CREATE POLICY "Confirmers can view assigned orders" ON public.orders FOR SELECT
USING (auth.uid() = confirmer_id);

-- Confirmers can UPDATE orders assigned to them
CREATE POLICY "Confirmers can update assigned orders" ON public.orders FOR UPDATE
USING (auth.uid() = confirmer_id)
WITH CHECK (auth.uid() = confirmer_id);

-- 4. [CRITICAL FIX] Create Policy for Public Customers
-- Allow ANYONE to insert an order (Checkout process)
-- Without this, anonymous users (customers) cannot place orders
CREATE POLICY "Public can create orders" ON public.orders FOR INSERT
WITH CHECK (true);

-- 5. Fix Profiles RLS as well just in case
DROP POLICY IF EXISTS "Merchants can view their confirmers" ON public.profiles;
CREATE POLICY "Merchants can view their confirmers" ON public.profiles FOR SELECT
USING (merchant_id = auth.uid());
