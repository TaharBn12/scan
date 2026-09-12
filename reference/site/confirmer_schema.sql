-- =====================================================
-- CONFIRMER SYSTEM SCHEMA UPDATE
-- =====================================================

-- 1. Add columns to profiles table
DO $$ 
BEGIN 
    -- Add role column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='role') THEN
        ALTER TABLE public.profiles ADD COLUMN role TEXT DEFAULT 'merchant';
    END IF;

    -- Add merchant_id column if not exists (links confirmer to merchant)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='merchant_id') THEN
        ALTER TABLE public.profiles ADD COLUMN merchant_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;

    -- Add email column if not exists (synced from auth.users for easier lookup)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='email') THEN
        ALTER TABLE public.profiles ADD COLUMN email TEXT;
    END IF;
END $$;

-- 2. Add confirmer_id to orders table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='confirmer_id') THEN
        ALTER TABLE public.orders ADD COLUMN confirmer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 3. Function to look up merchant ID by email (Security Definer)
CREATE OR REPLACE FUNCTION public.get_merchant_id_by_email(email_input TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    merchant_uuid UUID;
BEGIN
    SELECT id INTO merchant_uuid
    FROM public.profiles
    WHERE email = email_input AND (role = 'merchant' OR role IS NULL); -- Default to merchant if role is null for old users
    
    RETURN merchant_uuid;
END;
$$;

-- 4. RLS Policies

-- Allow Confirmers to read their own profile (already covered by "Users can manage own profile")

-- Allow Merchants to read profiles of their Confirmers
DROP POLICY IF EXISTS "Merchants can view their confirmers" ON public.profiles;
CREATE POLICY "Merchants can view their confirmers" ON public.profiles FOR SELECT
USING (auth.uid() = merchant_id);

-- Allow Confirmers to read orders assigned to them
DROP POLICY IF EXISTS "Confirmers can view assigned orders" ON public.orders;
CREATE POLICY "Confirmers can view assigned orders" ON public.orders FOR SELECT
USING (auth.uid() = confirmer_id);

-- Allow Confirmers to update status of orders assigned to them
DROP POLICY IF EXISTS "Confirmers can update assigned orders" ON public.orders;
CREATE POLICY "Confirmers can update assigned orders" ON public.orders FOR UPDATE
USING (auth.uid() = confirmer_id)
WITH CHECK (auth.uid() = confirmer_id);

-- Allow Merchants to see all orders (already covered by "Users can manage own orders" if they are the owner)
-- BUT we need to make sure Merchants can Assign orders. The existing policy "Users can manage own orders"
-- checks `auth.uid() = user_id`. This is fine for the Merchant.

-- Trigger to sync email from auth.users to public.profiles on insert/update
CREATE OR REPLACE FUNCTION public.sync_user_email()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles
    SET email = NEW.email
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists to avoid duplication errors (though ON CONFLICT / TG_NAME checks are harder in pure SQL script without knowing name)
DROP TRIGGER IF EXISTS on_auth_user_created_sync_email ON auth.users;
-- Re-create trigger (Note: triggers on auth.users requires superuser, user might need to run this in dashboard SQL editor)
-- We will try to rely on the frontend passing the email to `profiles` as well during registration to be safe,
-- but having the trigger is better for consistency.
-- However, since we can't easily write to auth.users from here, we'll skip the trigger creation on auth.users 
-- and rely on the frontend or a handle_new_user trigger if it existed.
-- Instead, we'll update the `profiles` table to ensure manual updates work.

-- Let's just create a helper to search merchants
GRANT EXECUTE ON FUNCTION public.get_merchant_id_by_email TO anon, authenticated, service_role;

-- Allow reading profiles for referral check (restricted by RLS usually, so function above is needed)
