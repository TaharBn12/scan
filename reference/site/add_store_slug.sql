-- SQL script to add store_slug to store_settings table
ALTER TABLE public.store_settings
ADD COLUMN IF NOT EXISTS store_slug TEXT UNIQUE;
-- We should probably create a function to generate a default store slug from the store name if it's null on insert/update
CREATE OR REPLACE FUNCTION generate_store_slug(name TEXT) RETURNS TEXT AS $$
DECLARE base_slug TEXT;
new_slug TEXT;
counter INT := 1;
BEGIN -- basic slugification: lower case, replace spaces with hyphens, remove special chars
base_slug := lower(regexp_replace(name, '[^a-zA-Z0-9\s-]', '', 'g'));
base_slug := regexp_replace(base_slug, '\s+', '-', 'g');
new_slug := base_slug;
-- ensure uniqueness
WHILE EXISTS (
    SELECT 1
    FROM store_settings
    WHERE store_slug = new_slug
) LOOP new_slug := base_slug || '-' || counter;
counter := counter + 1;
END LOOP;
RETURN new_slug;
END;
$$ LANGUAGE plpgsql;