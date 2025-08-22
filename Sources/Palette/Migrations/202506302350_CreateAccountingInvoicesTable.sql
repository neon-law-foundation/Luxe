-- Create accounting.invoices table
-- This table stores invoice information with references to vendors and invoicing entities
CREATE TABLE IF NOT EXISTS accounting.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL,
    invoiced_from VARCHAR(50) NOT NULL,
    invoiced_amount BIGINT NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    CONSTRAINT fk_invoices_vendor FOREIGN KEY (vendor_id) REFERENCES accounting.vendors (id),
    CONSTRAINT chk_invoices_invoiced_from CHECK (
        invoiced_from IN ('neon_law', 'neon_law_foundation', 'sagebrush_services')
    ),
    CONSTRAINT chk_invoices_amount_positive CHECK (invoiced_amount > 0)
);

-- Add comments
COMMENT ON TABLE accounting.invoices IS
'Stores invoice information with vendor references and invoicing entity details';
COMMENT ON COLUMN accounting.invoices.id IS 'Unique identifier for the invoice';
COMMENT ON COLUMN accounting.invoices.vendor_id IS 'Foreign key reference to accounting.vendors';
COMMENT ON COLUMN accounting.invoices.invoiced_from IS
'Entity that issued the invoice (neon_law, neon_law_foundation, or sagebrush_services)';
COMMENT ON COLUMN accounting.invoices.invoiced_amount IS
'Invoice amount in cents (to avoid decimal precision issues)';
COMMENT ON COLUMN accounting.invoices.sent_at IS 'Timestamp when the invoice was sent';
COMMENT ON COLUMN accounting.invoices.created_at IS 'Timestamp when the invoice record was created';
COMMENT ON COLUMN accounting.invoices.updated_at IS 'Timestamp when the invoice record was last updated';

-- Create updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_accounting_invoices_updated_at'
    ) THEN
        CREATE TRIGGER update_accounting_invoices_updated_at 
        BEFORE UPDATE ON accounting.invoices
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create indexes on foreign keys and commonly queried fields
CREATE INDEX IF NOT EXISTS idx_invoices_vendor_id ON accounting.invoices (vendor_id);
CREATE INDEX IF NOT EXISTS idx_invoices_invoiced_from ON accounting.invoices (invoiced_from);
CREATE INDEX IF NOT EXISTS idx_invoices_sent_at ON accounting.invoices (sent_at);

-- Row-level security
ALTER TABLE accounting.invoices ENABLE ROW LEVEL SECURITY;

-- Policy for customer role: can only read their own invoices (we'll need to add customer identification later)
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'invoices_customer_read'
    ) THEN
        CREATE POLICY invoices_customer_read ON accounting.invoices
        FOR SELECT
        TO customer
        USING (true);
    END IF;
END $$;

-- Policy for staff role: can read all invoices
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'invoices_staff_read'
    ) THEN
        CREATE POLICY invoices_staff_read ON accounting.invoices
        FOR SELECT
        TO staff
        USING (true);
    END IF;
END $$;

-- Policy for staff role: can insert and update invoices
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'invoices_staff_write'
    ) THEN
        CREATE POLICY invoices_staff_write ON accounting.invoices
        FOR INSERT
        TO staff
        WITH CHECK (true);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'invoices_staff_update'
    ) THEN
        CREATE POLICY invoices_staff_update ON accounting.invoices
        FOR UPDATE
        TO staff
        USING (true);
    END IF;
END $$;

-- Policy for admin role: full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'invoices_admin_all'
    ) THEN
        CREATE POLICY invoices_admin_all ON accounting.invoices
        FOR ALL
        TO admin
        USING (true);
    END IF;
END $$;

-- Grant permissions
GRANT SELECT ON accounting.invoices TO customer;
GRANT SELECT, INSERT, UPDATE ON accounting.invoices TO staff;
GRANT ALL ON accounting.invoices TO admin;
