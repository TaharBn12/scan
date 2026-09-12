-- Enable RLS on the table (if not already)
ALTER TABLE shipping_rates ENABLE ROW LEVEL SECURITY;

-- 1. Allow Public Read Access (Needed for Landing Page visitors who are anon)
DROP POLICY IF EXISTS "Enable read access for all users" ON shipping_rates;
CREATE POLICY "Enable read access for all users" ON shipping_rates
FOR SELECT USING (true);

-- 2. Allow Authenticated Users (Admins/Store Owners) to Update/Insert rates
DROP POLICY IF EXISTS "Enable full access for authenticated users" ON shipping_rates;
CREATE POLICY "Enable full access for authenticated users" ON shipping_rates
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);
