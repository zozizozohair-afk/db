ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS source_contract_id UUID REFERENCES public.contracts(id) ON DELETE SET NULL;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS resale_contract_id UUID REFERENCES public.contracts(id) ON DELETE SET NULL;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS resale_signed_at TIMESTAMPTZ;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS resale_agreed_amount NUMERIC(15,2);

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS resale_fee NUMERIC(15,2);

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS marketing_fee NUMERIC(15,2);

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS company_service_fee NUMERIC(15,2);

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS lawyer_fee NUMERIC(15,2);
