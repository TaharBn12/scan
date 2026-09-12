-- =====================================================
-- FIX RLS FOR CONFIRMER RATES
-- =====================================================

-- Allow Merchants to UPDATE profiles of users who have them as merchant_id
-- This is necessary for setting confirmation_rate and follow_up_rate

CREATE POLICY "Merchants can update their confirmers" ON public.profiles
FOR UPDATE
USING (
    auth.uid() = merchant_id
)
WITH CHECK (
    auth.uid() = merchant_id
);

-- Note: existing policies usually allow users to update their OWN profile.
-- We are adding a policy to allow updating OTHER profiles if they belong to the merchant.
