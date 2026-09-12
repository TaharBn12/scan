-- Add packer_id to orders
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS packer_id UUID REFERENCES public.profiles(id);

-- Add rates to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS packaging_rate DECIMAL DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS storage_rate DECIMAL DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS printing_rate DECIMAL DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS extra_commission_rate DECIMAL DEFAULT 0;

-- Allow Packers to view orders confirmed by their merchant
CREATE POLICY "Packers can view confirmed orders of their merchant" ON public.orders
FOR SELECT
USING (
    status IN ('confirmed', 'shipped', 'cancelled', 'delivered') AND
    user_id IN (
        SELECT merchant_id FROM public.profiles WHERE id = auth.uid() AND role = 'packer'
    )
);

-- Allow Packers to update orders (to claim them and set status)
-- They can update if they are the packer OR if it's confirmed (to claim it)
CREATE POLICY "Packers can update orders" ON public.orders
FOR UPDATE
USING (
    (packer_id = auth.uid() OR packer_id IS NULL) AND
    user_id IN (
        SELECT merchant_id FROM public.profiles WHERE id = auth.uid() AND role = 'packer'
    )
)
WITH CHECK (
    (packer_id = auth.uid()) AND
    user_id IN (
        SELECT merchant_id FROM public.profiles WHERE id = auth.uid() AND role = 'packer'
    )
);

-- Allow Merchants to view/update their packers (already covered by generic merchant policy, but ensuring specifics)
-- (Existing policy "Merchants can update their confirmers" might need renaming or checking if it covers all profiles linked to them)

-- Let's enable Merchants to update ANY profile linked to them (Confirmers OR Packers)
DROP POLICY IF EXISTS "Merchants can update their confirmers" ON public.profiles;

CREATE POLICY "Merchants can update their team" ON public.profiles
FOR UPDATE
USING (
    auth.uid() = merchant_id
)
WITH CHECK (
    auth.uid() = merchant_id
);
