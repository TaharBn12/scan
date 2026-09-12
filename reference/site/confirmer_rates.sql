-- =====================================================
-- CONFIRMER RATES SCHEMA
-- =====================================================

-- Add rate columns to profiles
DO $$
BEGIN
    -- Confirmation Rate: Earned when order is confirmed (paid on delivery)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='confirmation_rate') THEN
        ALTER TABLE public.profiles ADD COLUMN confirmation_rate DECIMAL(10, 2) DEFAULT 0;
    END IF;

    -- Follow-up Rate: Earned when order is delivered
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='follow_up_rate') THEN
        ALTER TABLE public.profiles ADD COLUMN follow_up_rate DECIMAL(10, 2) DEFAULT 0;
    END IF;
END $$;
