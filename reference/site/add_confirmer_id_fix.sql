-- Add the missing confirmer_id column to orders table
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS confirmer_id UUID REFERENCES public.profiles(id) ON DELETE
SET NULL;