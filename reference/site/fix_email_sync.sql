-- Run this script in the Supabase SQL Editor to fix the "Invalid Merchant Email" error.

-- 1. Backfill emails from auth.users to public.profiles
UPDATE public.profiles
SET email = auth.users.email
FROM auth.users
WHERE public.profiles.id = auth.users.id
AND public.profiles.email IS NULL;

-- 2. Verify the update (Optional: shows updated rows)
SELECT id, full_name, email, role FROM public.profiles WHERE email IS NOT NULL;
