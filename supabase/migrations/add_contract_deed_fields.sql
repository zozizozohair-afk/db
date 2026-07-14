ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS deed_source_contract_id UUID;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS deed_waiver_contract_id UUID;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS deed_settlement_contract_id UUID;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS deed_recipient_client_id UUID;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS deed_recipient_name TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS deed_recipient_id_number TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS deed_recipient_phone TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS deed_recipient_source TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS deed_unit_deed_number TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS deed_meter_number TEXT;

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS deed_parking_number TEXT;
