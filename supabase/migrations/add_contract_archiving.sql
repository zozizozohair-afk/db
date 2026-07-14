ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS is_archived BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS archived_by_id UUID;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS archived_by_name TEXT;
