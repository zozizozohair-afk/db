ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS settlement_source_contract_id UUID REFERENCES public.contracts(id) ON DELETE SET NULL;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS settlement_resale_contract_id UUID REFERENCES public.contracts(id) ON DELETE SET NULL;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS settlement_date DATE;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS settlement_sale_price NUMERIC(15,2);

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS settlement_new_owner_client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS settlement_new_owner_name TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS settlement_new_owner_id_number TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS settlement_new_owner_phone TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS financial_settlement_contract_id UUID REFERENCES public.contracts(id) ON DELETE SET NULL;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS financial_settlement_signed_at TIMESTAMPTZ;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS settlement_new_client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS settlement_new_client_applied_at TIMESTAMPTZ;
