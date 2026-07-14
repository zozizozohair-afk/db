
ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS agent_name TEXT;
ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS agent_id_number TEXT;
ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS agency_number TEXT;
ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS agency_date DATE;

ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS type VARCHAR(50) DEFAULT 'under_construction';

ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS created_by_id UUID;
ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS created_by_name TEXT;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS public.contract_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  contract_id UUID NULL,
  actor_id UUID NULL,
  actor_name TEXT NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL DEFAULT 'contract',
  entity_id UUID NULL,
  metadata JSONB NULL
);

CREATE INDEX IF NOT EXISTS contract_logs_contract_id_idx ON public.contract_logs (contract_id);
CREATE INDEX IF NOT EXISTS contract_logs_created_at_idx ON public.contract_logs (created_at DESC);

ALTER TABLE public.contract_logs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'contract_logs'
      AND policyname = 'contract_logs_select'
  ) THEN
    CREATE POLICY contract_logs_select ON public.contract_logs
      FOR SELECT TO authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'contract_logs'
      AND policyname = 'contract_logs_insert'
  ) THEN
    CREATE POLICY contract_logs_insert ON public.contract_logs
      FOR INSERT TO authenticated
      WITH CHECK (true);
  END IF;
END $$;

