-- Create Contracts Table
CREATE TABLE IF NOT EXISTS public.contracts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
    client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
    contract_date DATE NOT NULL,
    total_amount NUMERIC(15,2) DEFAULT 0,
    paid_amount NUMERIC(15,2) DEFAULT 0,
    completion_period_months INTEGER DEFAULT 12,
    payment_grace_period_months INTEGER,
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'completed')),
    notes TEXT,
    client_name TEXT,
    client_id_number TEXT,
    client_phone TEXT,
    agent_name TEXT,
    agent_id_number TEXT,
    agency_number TEXT,
    agency_date DATE
);

-- Add agent columns to existing contracts table if they don't exist
ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS agent_name TEXT;
ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS agent_id_number TEXT;
ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS agency_number TEXT;
ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS agency_date DATE;

-- Create Contract Obligations Table
CREATE TABLE IF NOT EXISTS public.contract_obligations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    contract_id UUID NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
    amount NUMERIC(15,2) NOT NULL,
    description TEXT NOT NULL,
    due_date DATE,
    paid BOOLEAN DEFAULT FALSE
);

-- Create Contract Payments Table
CREATE TABLE IF NOT EXISTS public.contract_payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    contract_id UUID NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
    amount NUMERIC(15,2) NOT NULL,
    payment_date DATE NOT NULL,
    notes TEXT,
    payment_method VARCHAR(20) CHECK (payment_method IN ('cash', 'cheque', 'transfer')),
    transaction_number TEXT,
    statement TEXT
);

-- ====================================================
-- Enable Row Level Security
-- ====================================================
ALTER TABLE public.contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contract_obligations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contract_payments ENABLE ROW LEVEL SECURITY;

-- ====================================================
-- Create RLS Policies
-- ====================================================
-- سياسات جدول contracts
CREATE POLICY "Allow full access to contracts" ON public.contracts
    FOR ALL USING (true) WITH CHECK (true);

-- سياسات جدول contract_obligations
CREATE POLICY "Allow full access to contract_obligations" ON public.contract_obligations
    FOR ALL USING (true) WITH CHECK (true);

-- سياسات جدول contract_payments
CREATE POLICY "Allow full access to contract_payments" ON public.contract_payments
    FOR ALL USING (true) WITH CHECK (true);
