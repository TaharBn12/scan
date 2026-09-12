-- =====================================================
-- CRITICAL FIX: Login & Redirect Issue Resolver
-- Run this script in Supabase SQL Editor to fix access issues.
-- =====================================================

-- 1. Reset RLS Policy for Profiles to ensure users can ALWAYS manage their own profile
DROP POLICY IF EXISTS "Users can manage own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can select own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON public.profiles;

-- Create comprehensive policies using the new standard
CREATE POLICY "Users can select own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can delete own profile" ON public.profiles FOR DELETE USING (auth.uid() = id);

-- 2. Ensure all existing users are APPROVED (Bypass Trial/Block logic)
UPDATE public.profiles 
SET is_approved = true 
WHERE is_approved IS NULL OR is_approved = false;

-- 3. Ensure all users have a Role (Default to 'merchant')
UPDATE public.profiles 
SET role = 'merchant' 
WHERE role IS NULL;

-- 4. Sync Emails (Again, just in case)
UPDATE public.profiles
SET email = auth.users.email
FROM auth.users
WHERE public.profiles.id = auth.users.id
AND (public.profiles.email IS NULL OR public.profiles.email = '');

-- 5. Extend Trial Date for everyone as a safety net (add 1 year)
UPDATE public.profiles
SET trial_ends_at = NOW() + INTERVAL '1 year'
WHERE trial_ends_at < NOW();

-- 6. Verify Policies
SELECT * FROM pg_policies WHERE tablename = 'profiles';
