ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS is_waived BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS waived_at TIMESTAMPTZ;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS waived_previous_client_id UUID;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS waived_previous_client_name TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS waived_previous_client_id_number TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS waived_previous_client_phone TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS waived_to_client_id UUID;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS waived_to_client_name TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS waived_to_client_id_number TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS waived_to_client_phone TEXT;
