ALTER TABLE public.contract_attachments ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.contract_attachments TO authenticated;

DROP POLICY IF EXISTS "Authenticated users can read contract attachments" ON public.contract_attachments;
CREATE POLICY "Authenticated users can read contract attachments"
  ON public.contract_attachments
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert contract attachments" ON public.contract_attachments;
CREATE POLICY "Authenticated users can insert contract attachments"
  ON public.contract_attachments
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can update contract attachments" ON public.contract_attachments;
CREATE POLICY "Authenticated users can update contract attachments"
  ON public.contract_attachments
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can delete contract attachments" ON public.contract_attachments;
CREATE POLICY "Authenticated users can delete contract attachments"
  ON public.contract_attachments
  FOR DELETE
  TO authenticated
  USING (true);
