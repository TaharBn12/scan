-- =====================================================
-- DANGER: THIS SCRIPT DELETES ALL DATA FROM THE DATABASE
-- =====================================================

-- 1. Drop Tables (CASCADE handles dependencies)
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.customers CASCADE;
DROP TABLE IF EXISTS public.store_settings CASCADE;
DROP TABLE IF EXISTS public.modules_config CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 2. Drop Functions
DROP FUNCTION IF EXISTS public.get_merchant_id_by_email;
DROP FUNCTION IF EXISTS public.sync_user_email;

-- 3. Confirm Deletion
SELECT 'Database cleared successfully. Please run schema_fix.sql THEN confirmer_schema.sql to restore tables.' as message;
