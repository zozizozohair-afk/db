CREATE TABLE IF NOT EXISTS public.contract_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  contract_id UUID NOT NULL REFERENCES public.contracts(id) ON DELETE CASCADE,
  category TEXT NOT NULL CHECK (category IN ('receipt', 'identity', 'unit_plan')),
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL CHECK (file_type IN ('pdf', 'image')),
  mime_type TEXT,
  file_url TEXT NOT NULL,
  file_path TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_contract_attachments_contract_id
  ON public.contract_attachments(contract_id);

CREATE INDEX IF NOT EXISTS idx_contract_attachments_contract_category
  ON public.contract_attachments(contract_id, category);
