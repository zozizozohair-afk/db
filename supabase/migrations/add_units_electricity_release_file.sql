ALTER TABLE public.units
ADD COLUMN IF NOT EXISTS electricity_release_file_url TEXT;
