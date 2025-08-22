-- Create equity.share_issuances table
-- This table stores share issuance information with references to share classes, holders, and documents
CREATE TABLE IF NOT EXISTS equity.share_issuances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    share_class_id UUID NOT NULL,
    holder_id UUID NOT NULL,
    document_id UUID,
    fair_market_value_per_share DECIMAL(20, 4),
    amount_paid_per_share DECIMAL(20, 4),
    amount_paid_for_shares DECIMAL(20, 4),
    amount_to_include_in_gross_income DECIMAL(20, 4),
    restrictions TEXT,
    taxable_year VARCHAR(4),
    calendar_year VARCHAR(4),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    CONSTRAINT fk_share_issuances_share_class FOREIGN KEY (share_class_id) REFERENCES equity.share_classes (id),
    CONSTRAINT fk_share_issuances_holder FOREIGN KEY (holder_id) REFERENCES directory.entities (id),
    CONSTRAINT fk_share_issuances_document FOREIGN KEY (document_id) REFERENCES documents.blobs (id)
);

-- Add comments
COMMENT ON TABLE equity.share_issuances IS
'Stores share issuance information including financial details and holder references';
COMMENT ON COLUMN equity.share_issuances.id IS 'Unique identifier for the share issuance';
COMMENT ON COLUMN equity.share_issuances.share_class_id IS 'Foreign key reference to the share class';
COMMENT ON COLUMN equity.share_issuances.holder_id IS 'Foreign key reference to the entity holding the shares';
COMMENT ON COLUMN equity.share_issuances.document_id IS 'Optional foreign key reference to supporting document';
COMMENT ON COLUMN equity.share_issuances.fair_market_value_per_share IS
'Fair market value per share at time of issuance';
COMMENT ON COLUMN equity.share_issuances.amount_paid_per_share IS 'Amount paid per share by the holder';
COMMENT ON COLUMN equity.share_issuances.amount_paid_for_shares IS 'Total amount paid for all shares';
COMMENT ON COLUMN equity.share_issuances.amount_to_include_in_gross_income IS
'Amount to include in gross income for tax purposes';
COMMENT ON COLUMN equity.share_issuances.restrictions IS 'Any restrictions on the share issuance';
COMMENT ON COLUMN equity.share_issuances.taxable_year IS 'Tax year for the issuance (YYYY format)';
COMMENT ON COLUMN equity.share_issuances.calendar_year IS 'Calendar year for the issuance (YYYY format)';
COMMENT ON COLUMN equity.share_issuances.created_at IS 'Timestamp when the share issuance was created';
COMMENT ON COLUMN equity.share_issuances.updated_at IS 'Timestamp when the share issuance was last updated';

-- Create updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_equity_share_issuances_updated_at'
    ) THEN
        CREATE TRIGGER update_equity_share_issuances_updated_at
        BEFORE UPDATE ON equity.share_issuances
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create indexes on foreign keys
CREATE INDEX IF NOT EXISTS idx_share_issuances_share_class_id ON equity.share_issuances (share_class_id);
CREATE INDEX IF NOT EXISTS idx_share_issuances_holder_id ON equity.share_issuances (holder_id);
CREATE INDEX IF NOT EXISTS idx_share_issuances_document_id ON equity.share_issuances (document_id);

-- Create indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_share_issuances_taxable_year ON equity.share_issuances (taxable_year);
CREATE INDEX IF NOT EXISTS idx_share_issuances_calendar_year ON equity.share_issuances (calendar_year);

-- Row-level security
ALTER TABLE equity.share_issuances ENABLE ROW LEVEL SECURITY;

-- Policy for customer role: can only read share issuances
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'share_issuances_customer_read'
    ) THEN
        CREATE POLICY share_issuances_customer_read ON equity.share_issuances
        FOR SELECT
        TO customer
        USING (true);
    END IF;
END $$;

-- Policy for staff role: can read all share issuances
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'share_issuances_staff_read'
    ) THEN
        CREATE POLICY share_issuances_staff_read ON equity.share_issuances
        FOR SELECT
        TO staff
        USING (true);
    END IF;
END $$;

-- Policy for admin role: full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'share_issuances_admin_all'
    ) THEN
        CREATE POLICY share_issuances_admin_all ON equity.share_issuances
        FOR ALL
        TO admin
        USING (true);
    END IF;
END $$;

-- Grant permissions
GRANT SELECT ON equity.share_issuances TO customer;
GRANT SELECT ON equity.share_issuances TO staff;
GRANT ALL ON equity.share_issuances TO admin;
